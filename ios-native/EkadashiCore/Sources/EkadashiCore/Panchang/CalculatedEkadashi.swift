import Foundation

public enum EkadashiTradition: String, CaseIterable, Sendable, Codable {
    case smarta
    case gaudiya

    public var label: String { self == .smarta ? "Smarta" : "Vaishnava · Gaudiya/ISKCON" }
}

/// Rule inputs, separated from astronomy to test rare tithi configurations.
public struct EkadashiSample: Sendable {
    public let date: CivilDate
    public let sunrise: Date?
    public let sunset: Date?
    public let tithi: Int
    public let arunodayaTithi: Int
    public let sunsetTithi: Int
    public let nakshatra: Int

    public init(date: CivilDate, sunrise: Date?, sunset: Date?, tithi: Int, arunodayaTithi: Int, sunsetTithi: Int, nakshatra: Int) {
        self.date = date
        self.sunrise = sunrise
        self.sunset = sunset
        self.tithi = tithi
        self.arunodayaTithi = arunodayaTithi
        self.sunsetTithi = sunsetTithi
        self.nakshatra = nakshatra
    }

    var fortnightTithi: Int { dartMod(tithi - 1, 15) + 1 }
    var arunodaya: Int { dartMod(arunodayaTithi - 1, 15) + 1 }
}

/// Current-location profiles; astronomical apparent upper-limb sunrise. The
/// Gaudiya decision table follows the GCAL program (see docs/PANCHANG_ACCURACY.md).
public enum EkadashiRules {
    public static func select(_ days: [EkadashiSample], _ index: Int, _ tradition: EkadashiTradition) -> String? {
        guard index >= 1, index + 1 < days.count else { return nil }
        let previous = days[index - 1], today = days[index], next = days[index + 1]
        if [previous, today, next].contains(where: { $0.sunrise == nil || $0.sunset == nil }) { return nil }
        if tradition == .smarta { return smarta(days, index) }
        if let mahadvadashi = mahadvadashi(days, index) { return mahadvadashi }
        let t = today.fortnightTithi
        if t != 11 || today.arunodaya < 11 { return nil }
        let repeated = previous.fortnightTithi == 11 && previous.arunodaya == 11
        if next.fortnightTithi == 13 { return repeated ? "Unmilani-Trisprisha" : "Trisprisha" }
        if repeated { return "Unmilani" }
        if next.fortnightTithi == 11 || mahadvadashi(days, index + 1) != nil { return nil }
        return "Shuddha Ekadashi"
    }

    /// Smarta householder rules, as published by Drik Panchang.
    static func smarta(_ days: [EkadashiSample], _ i: Int) -> String? {
        // A decision needs sunrises from two days before to three days after.
        guard i >= 2, i + 3 < days.count else { return nil }
        for k in (i - 2)...(i + 3) where days[k].sunrise == nil { return nil }
        let p = days[i - 1].fortnightTithi, t = days[i].fortnightTithi
        let n = days[i + 1].fortnightTithi, nn = days[i + 2].fortnightTithi
        if t == 11 && p != 11 {
            if n == 11 { return nn == 12 ? nil : "Sunrise Ekadashi (first of two)" }
            return n == 12 ? "Sunrise Ekadashi" : nil
        }
        if t == 11 && p == 11 { return n == 12 ? "Ekadashi and Dwadashi both extended" : nil }
        if t == 10 {
            if n == 12 { return "Kshaya Ekadashi: fast on Dashami day" }
            if n == 11 && nn == 13 { return "Kshaya Dwadashi: fast on Dashami day" }
        }
        return nil
    }

    static func mahadvadashi(_ days: [EkadashiSample], _ i: Int) -> String? {
        guard i >= 1, i + 1 < days.count else { return nil }
        let p = days[i - 1], t = days[i], n = days[i + 1]
        if p.fortnightTithi == 12 || t.fortnightTithi != 12 { return nil }
        if t.tithi == 12 && t.sunsetTithi == 12 && t.nakshatra == n.nakshatra,
           let name = [7: "Jaya", 4: "Jayanti", 8: "Papanashini", 22: "Vijaya"][t.nakshatra] {
            return name
        }
        if n.fortnightTithi == 12 && p.fortnightTithi == 11 && p.arunodaya == 11 { return "Vyanjuli" }
        var j = i + 1
        while j < days.count && j < i + 8 {
            if days[j].sunrise != nil && days[j - 1].sunrise != nil && days[j].fortnightTithi == 15
                && days[j].tithi == days[j - 1].tithi {
                return "Pakshavardhini"
            }
            j += 1
        }
        if p.arunodaya < 11 { return "Viddha / shifted to Dwadashi" }
        return nil
    }
}

public struct CalculatedEkadashi: Sendable, Identifiable {
    public var id: String { "\(tradition.rawValue):\(date.iso)" }
    public let date: CivilDate
    public let name: String
    public let tradition: EkadashiTradition
    public let rule: String
    public let city: PanchangCity
    public let fastStarts: Date
    public let paranaDate: CivilDate
    public let paranaStart: Date?
    public let paranaEnd: Date?
    public let paranaReason: String
    public let hariVasaraEnd: Date?
    public let tithiStart: Date
    public let tithiEnd: Date
    public let nearBoundary: Bool
    public static let ruleVersion = "current-location-v2"
}

public struct CalculatedEkadashiEngine: Sendable {
    public let engine: PanchangEngine
    public init(engine: PanchangEngine = PanchangEngine()) { self.engine = engine }

    public func calculate(start: CivilDate, count: Int, city: PanchangCity, tradition: EkadashiTradition) throws -> [CalculatedEkadashi] {
        guard (1...366).contains(count) else { throw CoreError.invalidArgument("Choose 1–366 civil days") }
        var days: [PanchangDay] = []
        var samples: [EkadashiSample] = []
        // Neighbours across month/year boundaries and the next full/new moon are
        // necessary for repeated/skipped tithi and Pakshavardhini decisions.
        for offset in -2..<(count + 9) {
            let day = engine.calculate(start.adding(days: offset), city: city)
            days.append(day)
            samples.append(EkadashiSample(
                date: day.date, sunrise: day.sunrise, sunset: day.sunset, tithi: day.tithi.index,
                arunodayaTithi: day.sunrise.map { engine.tithiAt($0.adding(-96 * 60)).index } ?? 0,
                sunsetTithi: day.sunset.map { engine.tithiAt($0).index } ?? 0,
                nakshatra: day.nakshatra.index))
        }
        var result: [CalculatedEkadashi] = []
        for i in 2..<(count + 2) {
            guard let rule = EkadashiRules.select(samples, i, tradition) else { continue }
            let day = days[i], next = days[i + 1]
            guard let sunrise = day.sunrise, let nextSunrise = next.sunrise else { continue }
            // Locate the Ekadashi interval: later the same day when the fast is
            // on the Dashami day, earlier when fasting on Dwadashi.
            let forward = samples[i].fortnightTithi == 10
            var probe = sunrise
            var hours = 0
            while hours < 72 && dartMod(engine.tithiAt(probe).index - 1, 15) + 1 != 11 {
                probe = probe.adding(forward ? 3600 : -3600)
                hours += 1
            }
            let ekadashi = engine.tithiAt(probe)
            guard dartMod(ekadashi.index - 1, 15) + 1 == 11, let tithiEnd = ekadashi.endsAt,
                  let dwadashiEnd = engine.tithiAt(tithiEnd.adding(1)).endsAt else { continue }
            let tithiStart = engine.tithiStart(probe)
            let hariVasara = tithiEnd.adding(truncatedMicroseconds(dwadashiEnd.timeIntervalSince(tithiEnd), dividedBy: 4))
            let parana = tradition == .smarta
                ? smartaParana(next, tithiEnd, dwadashiEnd)
                : gaudiyaParana(day, next, rule, hariVasara)
            let arunodaya = sunrise.adding(-96 * 60)
            func near(_ a: Date, _ b: Date) -> Bool { abs(a.timeIntervalSince(b).rounded(.towardZero)) <= 300 }
            let nearBoundary = [day.nakshatra, next.nakshatra].contains { limb in
                guard let end = limb.endsAt else { return false }
                return near(sunrise, end) || near(nextSunrise, end)
            } || [sunrise, arunodaya, nextSunrise].contains { instant in
                [tithiStart, tithiEnd, dwadashiEnd].contains { near(instant, $0) }
            }
            result.append(CalculatedEkadashi(
                date: day.date, name: name(day, bright: ekadashi.paksha == "Shukla"), tradition: tradition, rule: rule,
                city: city, fastStarts: sunrise, paranaDate: next.date, paranaStart: parana.start, paranaEnd: parana.end,
                paranaReason: parana.reason, hariVasaraEnd: hariVasara, tithiStart: tithiStart, tithiEnd: tithiEnd,
                nearBoundary: nearBoundary))
        }
        return result
    }

    /// Drik Panchang's Smarta Parana: after sunrise and Hari Vasara (the first
    /// quarter of Dwadashi), preferably in Pratahkala (the first fifth of the
    /// day); if Hari Vasara outlasts Pratahkala, after Madhyahna until the end
    /// of Aparahna. Always before Dwadashi ends, unless it ended before sunrise.
    func smartaParana(_ next: PanchangDay, _ ekadashiEnd: Date, _ dwadashiEnd: Date) -> (start: Date?, end: Date?, reason: String) {
        guard let sunrise = next.sunrise, let sunset = next.sunset, sunset > sunrise else {
            return (nil, nil, "Solar day unavailable")
        }
        let fifth = truncatedMicroseconds(sunset.timeIntervalSince(sunrise), dividedBy: 5)
        let hariVasara = ekadashiEnd.adding(truncatedMicroseconds(dwadashiEnd.timeIntervalSince(ekadashiEnd), dividedBy: 4))
        func later(_ a: Date, _ b: Date) -> Date { a > b ? a : b }
        var begin = later(sunrise, hariVasara)
        var end: Date
        var reason: String
        if begin < sunrise.adding(fifth) {
            end = sunrise.adding(fifth)
            reason = "After sunrise and Hari Vasara, within Pratahkala"
        } else {
            begin = later(begin, sunrise.adding(fifth * 3))
            end = sunrise.adding(fifth * 4)
            reason = "Hari Vasara outlasts Pratahkala: after Madhyahna"
        }
        if dwadashiEnd > sunrise && dwadashiEnd < end {
            end = dwadashiEnd
            reason += ", before Dwadashi ends"
        }
        if !(end > begin) { return (begin, nil, "\(reason). No bounded window; shown as after-only.") }
        return (begin, end, reason)
    }

    func gaudiyaParana(_ fast: PanchangDay, _ next: PanchangDay, _ rule: String, _ hariVasara: Date)
        -> (start: Date?, end: Date?, reason: String) {
        guard let sunrise = next.sunrise, let sunset = next.sunset, sunset > sunrise else {
            return (nil, nil, "Solar day unavailable")
        }
        let third = sunrise.adding(truncatedMicroseconds(sunset.timeIntervalSince(sunrise), dividedBy: 3))
        let limb = engine.tithiAt(sunrise)
        guard let tithiEnd = limb.endsAt else { return (sunrise, nil, "Tithi transition unavailable") }
        func earlier(_ a: Date, _ b: Date) -> Date { a < b ? a : b }
        func later(_ a: Date, _ b: Date) -> Date { a > b ? a : b }
        var begin = sunrise
        var end: Date? = earlier(tithiEnd, third)
        var reason = "Sunrise to the earlier of tithi end and one third of daylight"
        if rule == "Trisprisha" || rule == "Unmilani-Trisprisha" {
            end = third
            reason = "Trisprisha: sunrise to one third of daylight"
        } else if ["Jaya", "Jayanti", "Papanashini", "Vijaya"].contains(rule), let nakEnd = fast.nakshatra.endsAt {
            if dartMod(limb.index - 1, 15) + 1 == 12 {
                if nakEnd < tithiEnd {
                    begin = later(sunrise, nakEnd)
                    end = nakEnd < third ? earlier(tithiEnd, third) : tithiEnd
                }
            } else if rule == "Jayanti" || rule == "Vijaya" {
                end = earlier(nakEnd, third)
            } else {
                begin = later(sunrise, nakEnd)
                end = nakEnd < third ? third : nil
            }
            reason = "\(rule): nakshatra end, Dwadashi end and morning limit evaluated together"
        } else if rule != "Unmilani" && rule != "Vyanjuli" && dartMod(fast.tithi.index - 1, 15) + 1 != 12 {
            begin = later(sunrise, hariVasara)
            reason = "After sunrise and Hari Vasara; before tithi end or one third of daylight"
        }
        if let value = end, !(value > begin) { end = nil }
        return (begin, end, end == nil ? "\(reason). No bounded morning window; shown as after-only." : reason)
    }

    func name(_ day: PanchangDay, bright: Bool) -> String {
        if day.isAdhikaMonth { return bright ? "Padmini Ekadashi" : "Parama Ekadashi" }
        let shukla = ["Kamada", "Mohini", "Nirjala", "Devshayani", "Shravana Putrada", "Parivartini", "Papankusha",
                      "Devutthana", "Mokshada", "Pausha Putrada", "Jaya", "Amalaki"]
        let krishna = ["Varuthini", "Apara", "Yogini", "Kamika", "Aja", "Indira", "Rama", "Utpanna", "Saphala",
                       "Shattila", "Vijaya", "Papamochani"]
        guard let index = PanchangEngine.lunarMonths.firstIndex(of: day.amantaMonth) else { return "Ekadashi" }
        return "\((bright ? shukla : krishna)[index]) Ekadashi"
    }
}
