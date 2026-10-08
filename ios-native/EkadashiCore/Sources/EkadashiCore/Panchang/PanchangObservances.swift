import Foundation

/// Time windows (kala) used by festival rules; fifths of daylight follow the
/// five-part day (Pratah, Sangava, Madhyahna, Aparahna, Sayahna).
enum Kala { case sunrise, sunset, moonrise, purvahna, pratah, madhyahna, aparahna, pradosh, nishita, arunodaya, akshaya }

/// When a tithi covers its window on two days: the longer coverage, or the first day.
enum Tie { case longest, first }

struct SolarDay {
    let sunrise: Date?
    let sunset: Date?
    let nextSunrise: Date?
    let moonrise: Date?
}

/// Lazily computed sunrise/sunset/moonrise for neighbouring civil days.
final class SolarDays {
    let engine: PanchangEngine
    let city: PanchangCity
    private var cache: [CivilDate: SolarDay] = [:]

    init(_ engine: PanchangEngine, _ city: PanchangCity) {
        self.engine = engine
        self.city = city
    }

    func of(_ date: CivilDate) -> SolarDay {
        if let hit = cache[date] { return hit }
        let start = engine.startFor(date, city: city), end = engine.endFor(date, city: city)
        let sunrise = engine.findCrossing(start, end, city, moon: false, rising: true)
        let sunset = sunrise.flatMap { engine.findCrossing($0, city.midnight(date, dayOffset: 2), city, moon: false, rising: false) }
        let nextSunrise = sunset.flatMap { engine.findCrossing($0, city.midnight(date, dayOffset: 2), city, moon: false, rising: true) }
        let moonrise = engine.findCrossing(start, end, city, moon: true, rising: true)
        let day = SolarDay(sunrise: sunrise, sunset: sunset, nextSunrise: nextSunrise, moonrise: moonrise)
        cache[date] = day
        return day
    }

    /// [start, end] of the window on civil [date]; instants have start == end.
    func window(_ date: CivilDate, _ kala: Kala) -> (Date, Date)? {
        let day = of(date)
        guard let a = day.sunrise, let b = day.sunset, let n = day.nextSunrise else { return nil }
        let dayLength = b.timeIntervalSince(a), night = n.timeIntervalSince(b)
        let at = PanchangEngine.at
        switch kala {
        case .sunrise: return (a, a)
        case .sunset: return (b, b)
        case .moonrise: return day.moonrise.map { ($0, $0) }
        case .purvahna: return (a, at(a, dayLength, 0.5))
        case .pratah, .akshaya: return (a, at(a, dayLength, 0.2))
        case .madhyahna: return (at(a, dayLength, 0.4), at(a, dayLength, 0.6))
        case .aparahna: return (at(a, dayLength, 0.6), at(a, dayLength, 0.8))
        case .pradosh: return (b, at(b, night, 0.2))
        case .nishita: return (at(b, night, 7.0 / 15), at(b, night, 8.0 / 15))
        case .arunodaya: return (a.adding(-96 * 60), a)
        }
    }
}

struct Occurrence {
    let start: Date
    let end: Date
    let month: String

    func covers(_ instant: Date) -> Bool { instant >= start && instant < end }

    func overlap(_ window: (Date, Date)) -> TimeInterval {
        let from = window.0 > start ? window.0 : start
        let to = window.1 < end ? window.1 : end
        return to > from ? to.timeIntervalSince(from) : 0
    }

    /// The civil date on which this tithi is observed for [kala].
    func observedOn(_ kala: Kala, _ tie: Tie, _ days: SolarDays, _ city: PanchangCity) -> CivilDate? {
        let first = city.wallClock(start.adding(-86400)).date
        let last = city.wallClock(end.adding(86400)).date
        var candidates: [CivilDate] = []
        var day = first
        while day <= last {
            candidates.append(day)
            day = day.adding(days: 1)
        }
        let instant = kala == .sunrise || kala == .sunset || kala == .moonrise
        if kala == .akshaya {
            // Udaya tithi if it lasts through Pratahkala; otherwise the previous
            // day, when the tithi began during that forenoon.
            for day in candidates {
                if let window = days.window(day, .pratah), covers(window.0) {
                    if !(end < window.1) { return day }
                    let previous = day.adding(days: -1)
                    if let forenoon = days.window(previous, .purvahna), overlap(forenoon) > 0 { return previous }
                    return day
                }
            }
        }
        var best: CivilDate?
        var bestOverlap: TimeInterval = 0
        for day in candidates {
            guard let window = days.window(day, kala == .akshaya ? .purvahna : kala) else { continue }
            if instant {
                if covers(window.0) { return day }
                continue
            }
            let value = overlap(window)
            if value <= 0 { continue }
            if tie == .first { return day }
            if value > bestOverlap {
                best = day
                bestOverlap = value
            }
        }
        if let best { return best }
        // Tithi touches no window (kshaya): the civil day on which it begins,
        // counted from sunrise.
        for day in candidates {
            if let a = days.of(day).sunrise, let n = days.of(day.adding(days: 1)).sunrise, start >= a, start < n {
                return day
            }
        }
        return nil
    }
}

extension PanchangEngine {
    func observances(city: PanchangCity, date: CivilDate, sunrise: Date, sunset: Date, tithi: PanchangLimb) -> [PanchangObservance] {
        var items: [PanchangObservance] = []
        func add(_ id: String, _ name: String, major: Bool = false, note: String = "") {
            if items.contains(where: { $0.id == id }) { return }
            items.append(PanchangObservance(id: id, name: name, ruleSource: "calculated", description: note, isMajor: major))
        }
        let days = SolarDays(self, city)
        let tomorrow = days.of(date.adding(days: 1)).sunrise.map { tithiAt($0).index }

        // Occurrences of tithi [index] (1-30) that can be observed on [date].
        func near(_ index: Int) -> Bool {
            func same(_ a: Int, _ b: Int) -> Bool { dartMod(a - b, 30) == 0 }
            if same(index, tithi.index) || same(index, tithi.index + 1) || same(index, tithi.index - 1) { return true }
            if let tomorrow, same(index, tomorrow) || same(index, tomorrow + 1) { return true }
            return false
        }
        func occurrence(_ index: Int) -> Occurrence? {
            near(index) ? self.occurrence(index, date, sunrise, tithi, days) : nil
        }
        func observed(_ index: Int, _ kala: Kala, month: String? = nil, tie: Tie = .longest) -> Bool {
            guard let found = occurrence(index) else { return false }
            if let month, found.month != month { return false }
            return found.observedOn(kala, tie, days, city) == date
        }

        // Monthly observances.
        if smartaEkadashi(date, days) {
            add("ekadashi", "Ekadashi", major: true,
                note: "Smarta fasting day for this location (Drik rules); Gaudiya days are in the Ekadashi tab.")
        }
        if [12, 27].contains(tithi.index) { add("dwadashi", "Dwadashi") }
        if observed(15, .sunrise) { add("purnima", "Purnima", major: true) }
        if observed(30, .sunrise) { add("amavasya", "Amavasya", major: true) }
        if [8, 23].contains(tithi.index) { add("ashtami", "Ashtami") }
        if [9, 24].contains(tithi.index) { add("navami", "Navami") }
        if let chaturthi = occurrence(4), chaturthi.observedOn(.madhyahna, .longest, days, city) == date {
            add("vinayaka-chaturthi", chaturthi.month == "Bhadrapada" ? "Ganesh Chaturthi" : "Vinayaka Chaturthi (monthly)",
                major: true, note: "Shukla Chaturthi during Madhyahna (the third fifth of the day).")
        }
        for index in [13, 28] where observed(index, .pradosh) {
            add("pradosham", "Pradosham", major: true, note: "Trayodashi during Pradosh (the first fifth of the night).")
        }
        if observed(19, .moonrise, tie: .first) {
            add("sankashti-chaturthi", "Sankashti Chaturthi", major: true, note: "Krishna Chaturthi is present at local moonrise.")
        }
        if let chaturdashi = occurrence(29), chaturdashi.observedOn(.nishita, .longest, days, city) == date {
            if chaturdashi.month == "Magha" {
                add("maha-shivaratri", "Maha Shivaratri", major: true,
                    note: "Krishna Chaturdashi at Nishita (Magha Amanta, Phalguna Purnimanta).")
            } else {
                add("masik-shivaratri", "Masik Shivaratri", major: true,
                    note: "Krishna Chaturdashi at Nishita, the eighth fifteenth of the night.")
            }
        }

        // Annual festivals. Months are Amanta; each tithi keeps its own month.
        if observed(1, .sunrise, month: "Chaitra") {
            add("ugadi", "Ugadi / Gudi Padwa", major: true)
            add("chaitra-navratri", "Chaitra Navaratri begins", major: true)
        }
        if observed(5, .purvahna, month: "Magha") { add("vasant-panchami", "Vasant Panchami", major: true) }
        if observed(9, .madhyahna, month: "Chaitra") { add("rama-navami", "Rama Navami", major: true) }
        if observed(15, .sunrise, month: "Chaitra") {
            add("hanuman-jayanti", "Hanuman Jayanti", major: true, note: "Common North Indian Chaitra Purnima observance.")
        }
        if observed(3, .akshaya, month: "Vaishakha") { add("akshaya-tritiya", "Akshaya Tritiya", major: true) }
        if observed(15, .sunrise, month: "Ashadha") { add("guru-purnima", "Guru Purnima", major: true) }
        if let ashtami = occurrence(23), ashtami.month == "Shravana", janmashtami(ashtami, days, city) == date {
            add("janmashtami", "Krishna Janmashtami", major: true,
                note: "Smarta: Krishna Ashtami at Nishita, preferring the night with Rohini.")
        }
        if observed(1, .sunrise, month: "Ashvina") { add("sharad-navratri", "Sharad Navaratri begins", major: true) }
        if observed(10, .aparahna, month: "Ashvina") { add("vijayadashami", "Vijayadashami", major: true) }
        if observed(19, .moonrise, month: "Ashvina", tie: .first) {
            add("karwa-chauth", "Karwa Chauth", major: true, note: "Krishna Chaturthi is present at moonrise.")
        }
        if observed(28, .pradosh, month: "Ashvina") { add("dhanteras", "Dhanteras", major: true) }
        if observed(29, .arunodaya, month: "Ashvina") { add("naraka-chaturdashi", "Naraka Chaturdashi", major: true) }
        if observed(30, .pradosh, month: "Ashvina") {
            add("deepavali", "Deepavali", major: true, note: "Amavasya during Pradosh (Lakshmi Puja).")
        }
        if observed(1, .pratah, month: "Kartika") { add("govardhan-puja", "Govardhan Puja", major: true) }
        if observed(2, .aparahna, month: "Kartika") { add("bhai-dooj", "Bhai Dooj", major: true) }
        if observed(6, .sunset, month: "Kartika", tie: .first) { add("chhath-puja", "Chhath Puja", major: true) }
        if observed(15, .pradosh, month: "Phalguna") {
            add("holika-dahan", "Holika Dahan", major: true, note: "Purnima during Pradosh. Bhadra is not evaluated.")
        }
        let yesterday = date.adding(days: -1)
        if let holika = holikaDate(yesterday, city, days), holika == yesterday {
            add("holi", "Holi", major: true, note: "The day after Holika Dahan.")
        }

        addSankranti(add, city, date, sunset, days)

        return items.enumerated().sorted { a, b in
            if a.element.isMajor != b.element.isMajor { return a.element.isMajor }
            if a.element.name != b.element.name { return a.element.name < b.element.name }
            return a.offset < b.offset
        }.map(\.element)
    }

    func sankrantiOnly(_ city: PanchangCity, _ date: CivilDate, _ sunset: Date?) -> [PanchangObservance] {
        var items: [PanchangObservance] = []
        addSankranti({ id, name, major, note in
            items.append(PanchangObservance(id: id, name: name, ruleSource: "calculated", description: note, isMajor: major))
        }, city, date, sunset, SolarDays(self, city))
        return items
    }

    /// Solar ingress: the Sankranti moment on its civil date. Makar Sankranti
    /// and Pongal move to the next day when the ingress is after sunset (and
    /// stay on the ingress day where the Sun does not set).
    func addSankranti(_ add: (String, String, Bool, String) -> Void, _ city: PanchangCity, _ date: CivilDate,
                      _ sunset: Date?, _ days: SolarDays) {
        if let ingress = solarIngress(startFor(date, city: city), endFor(date, city: city)) {
            let sign = siderealSign(ingress)
            if sign != 9 {
                add("sankranti-\(sign)", sign == 0 ? "Mesha Sankranti" : "\(Self.signs[sign]) Sankranti", true,
                    "Sidereal solar ingress at \(formatPanchangTime(ingress, city: city, date: date)).")
            } else if sunset == nil || ingress < sunset! {
                addMakar(add, ingress, city, date)
            }
        }
        let previous = date.adding(days: -1)
        if let yesterdayIngress = solarIngress(startFor(previous, city: city), startFor(date, city: city)),
           siderealSign(yesterdayIngress) == 9, let previousSunset = days.of(previous).sunset, !(yesterdayIngress < previousSunset) {
            addMakar(add, yesterdayIngress, city, date)
        }
    }

    func addMakar(_ add: (String, String, Bool, String) -> Void, _ ingress: Date, _ city: PanchangCity, _ date: CivilDate) {
        add("sankranti-9", "Makar Sankranti", true,
            "Sidereal ingress into Makara at \(formatPanchangTime(ingress, city: city, date: date)); after sunset it is observed the next day.")
        add("pongal", "Pongal", false, "")
    }

    /// The occurrence of tithi [index] (1-30) closest to [date]'s sunrise.
    func occurrence(_ index: Int, _ date: CivilDate, _ sunrise: Date, _ current: PanchangLimb, _ days: SolarDays) -> Occurrence? {
        let probe: Date
        if current.index == index {
            probe = sunrise
        } else if dartMod(index - current.index, 30) == 1 {
            guard let end = current.endsAt else { return nil }
            probe = end.adding(1)
        } else if dartMod(current.index - index, 30) == 1 {
            probe = tithiStart(sunrise).adding(-1)
        } else {
            guard let next = days.of(date.adding(days: 1)).sunrise else { return nil }
            let limb = tithiAt(next)
            if limb.index == index {
                probe = next
            } else {
                guard let end = limb.endsAt else { return nil }
                probe = end.adding(1)
            }
        }
        let limb = tithiAt(probe)
        guard limb.index == index, let end = limb.endsAt else { return nil }
        let start = tithiStart(probe)
        let middle = start.adding(truncatedMicroseconds(end.timeIntervalSince(start), dividedBy: 2))
        let month = monthFor(middle)
        return Occurrence(start: start, end: end, month: (month.adhika ? "Adhika " : "") + Self.lunarMonths[month.index])
    }

    /// Smarta Janmashtami: Krishna Ashtami at Nishita. If Rohini is not at
    /// that midnight but is at the next one, while Ashtami still prevails at
    /// that day's sunrise, the next day is preferred (Rohini-yukta Ashtami).
    func janmashtami(_ ashtami: Occurrence, _ days: SolarDays, _ city: PanchangCity) -> CivilDate? {
        guard let chosen = ashtami.observedOn(.nishita, .longest, days, city) else { return nil }
        func rohiniAtNishita(_ day: CivilDate) -> Bool {
            guard let window = days.window(day, .nishita) else { return false }
            let middle = window.0.adding(truncatedMicroseconds(window.1.timeIntervalSince(window.0), dividedBy: 2))
            return nakshatraAt(middle).index == 4
        }
        let next = chosen.adding(days: 1)
        if !rohiniAtNishita(chosen), rohiniAtNishita(next), let nextSunrise = days.of(next).sunrise, nextSunrise < ashtami.end {
            return next
        }
        return chosen
    }

    func holikaDate(_ date: CivilDate, _ city: PanchangCity, _ days: SolarDays) -> CivilDate? {
        guard let sunrise = days.of(date).sunrise else { return nil }
        let current = tithiAt(sunrise)
        guard [14, 15, 16].contains(current.index),
              let found = occurrence(15, date, sunrise, current, days), found.month == "Phalguna" else { return nil }
        return found.observedOn(.pradosh, .longest, days, city)
    }

    func smartaEkadashi(_ date: CivilDate, _ days: SolarDays) -> Bool {
        func fortnight(_ offset: Int) -> Int? {
            days.of(date.adding(days: offset)).sunrise.map { (tithiAt($0).index - 1) % 15 + 1 }
        }
        let t = fortnight(0)
        guard t == 10 || t == 11 else { return false }
        guard let p = fortnight(-1), let n = fortnight(1), let nn = fortnight(2) else { return false }
        guard fortnight(-2) != nil, fortnight(3) != nil else { return false }
        for offset in [-1, 0, 1] where days.of(date.adding(days: offset)).sunset == nil { return false }
        if t == 11 && p != 11 { return n == 11 ? nn != 12 : n == 12 }
        if t == 11 && p == 11 { return n == 12 }
        return n == 12 || (n == 11 && nn == 13)
    }
}

/// An observance on its civil date at a location.
public struct DatedObservance: Equatable, Sendable {
    public let date: CivilDate
    public let observance: PanchangObservance
}

extension PanchangEngine {
    /// The day's observances without the rest of the Panchang (muhurtas,
    /// choghadiya, lagna ...): the same result as `calculate(date).observances`.
    public func observances(on date: CivilDate, city: PanchangCity) -> [PanchangObservance] {
        let startUtc = startFor(date, city: city)
        let endUtc = endFor(date, city: city)
        let sunrise = findCrossing(startUtc, endUtc, city, moon: false, rising: true)
        var sunset = findCrossing(startUtc, endUtc, city, moon: false, rising: false)
        if let sunrise, sunset == nil || sunset! < sunrise {
            sunset = findCrossing(sunrise, city.midnight(date, dayOffset: 2), city, moon: false, rising: false)
        }
        let hasSolarDay = sunrise != nil && sunset != nil && sunset! > sunrise!
        let localSunrise = sunrise ?? city.dateAtHour(date, 6)
        let localSunset = sunset ?? city.dateAtHour(date, 18)
        let nightEnd = findCrossing(localSunset, city.midnight(date, dayOffset: 2), city, moon: false, rising: true)
        guard hasSolarDay, nightEnd != nil else { return sankrantiOnly(city, date, sunset) }
        return observances(city: city, date: date, sunrise: localSunrise, sunset: localSunset, tithi: tithiAt(localSunrise))
    }

    /// Every observance of [year] at [city], in date order.
    public func observanceCalendar(year: Int, city: PanchangCity) -> [DatedObservance] {
        var result: [DatedObservance] = []
        var date = CivilDate(year, 1, 1)
        while date.year == year {
            for observance in observances(on: date, city: city) { result.append(DatedObservance(date: date, observance: observance)) }
            date = date.adding(days: 1)
        }
        return result
    }
}
