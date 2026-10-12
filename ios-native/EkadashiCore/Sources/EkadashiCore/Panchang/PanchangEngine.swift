import Foundation

/// Offline Panchang calculator for explicit civil dates and location time
/// zones, a direct port of lib/services/panchang/panchang_engine.dart.
public struct PanchangEngine: Sendable {
    public init() {}

    static let tithis = ["Pratipada", "Dvitiya", "Tritiya", "Chaturthi", "Panchami", "Shashthi", "Saptami", "Ashtami",
                         "Navami", "Dashami", "Ekadashi", "Dwadashi", "Trayodashi", "Chaturdashi", "Purnima"]
    static let nakshatras = ["Ashwini", "Bharani", "Krittika", "Rohini", "Mrigashira", "Ardra", "Punarvasu", "Pushya",
                             "Ashlesha", "Magha", "Purva Phalguni", "Uttara Phalguni", "Hasta", "Chitra", "Swati",
                             "Vishakha", "Anuradha", "Jyeshtha", "Mula", "Purva Ashadha", "Uttara Ashadha", "Shravana",
                             "Dhanishtha", "Shatabhisha", "Purva Bhadrapada", "Uttara Bhadrapada", "Revati"]
    static let yogas = ["Vishkambha", "Priti", "Ayushman", "Saubhagya", "Shobhana", "Atiganda", "Sukarman", "Dhriti",
                        "Shula", "Ganda", "Vriddhi", "Dhruva", "Vyaghata", "Harshana", "Vajra", "Siddhi", "Vyatipata",
                        "Variyana", "Parigha", "Shiva", "Siddha", "Sadhya", "Shubha", "Shukla", "Brahma", "Indra", "Vaidhriti"]
    static let karanaChara = ["Bava", "Balava", "Kaulava", "Taitila", "Garaja", "Vanija", "Vishti"]
    static let lunarMonths = ["Chaitra", "Vaishakha", "Jyeshtha", "Ashadha", "Shravana", "Bhadrapada", "Ashvina",
                              "Kartika", "Margashirsha", "Pausha", "Magha", "Phalguna"]
    static let varas = ["", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    static let varaNames = Array(varas.dropFirst())
    /// Observances added on iOS first (docs/ROADMAP.md Phase 3); the Dart
    /// engine gains them with the Android port, until then the parity test skips them.
    public static let iosFirstObservanceIds: Set<String> = [
        "raksha-bandhan", "nag-panchami", "ratha-yatra", "durga-ashtami", "varalakshmi-vratam", "onam", "karthigai-deepam",
    ]
    static let karanaFixed = ["Kimstughna", "Shakuni", "Chatushpada", "Naga"]
    static let ritus = ["Vasanta", "Grishma", "Varsha", "Sharad", "Hemanta", "Shishira"]
    static let ayanas = ["Uttarayana (tropical)", "Dakshinayana (tropical)"]
    static let periodNames = ["Rahu Kalam", "Yamaganda", "Gulika Kalam", "Abhijit Muhurta", "Brahma Muhurta", "Dur Muhurta",
                              "Varjyam", "Amrit Kalam"]
    static let choghadiyaDay = ["Udveg", "Chal", "Labh", "Amrit", "Kaal", "Shubh", "Rog"]
    static let choghadiyaNight = ["Shubh", "Amrit", "Chal", "Rog", "Kaal", "Labh", "Udveg"]
    static let choghadiyaNames = choghadiyaDay
    static let horaPlanets = ["Saturn", "Jupiter", "Mars", "Sun", "Venus", "Mercury", "Moon"]
    static let anandadiNames = ["Ananda", "Kaladanda", "Dhumra", "Prajapati", "Saumya", "Dhwanksha", "Dhwaja", "Srivatsa",
                                "Vajra", "Mudgara", "Chhatra", "Mitra", "Manasa", "Padma", "Lumbaka", "Utpata", "Mrityu",
                                "Kana", "Siddhi", "Shubha", "Amrita", "Musala", "Gada", "Matanga", "Rakshasa", "Chara",
                                "Sthira", "Vardhamana"]
    static let specialYogaNames = ["Amrita Siddhi Yoga", "Ravi Yoga", "Panchaka", "Ganda Moola", "Vinchudo", "Bhadra",
                                   "Sarvartha Siddhi Yoga", "Ravi Pushya Yoga", "Guru Pushya Yoga", "Dwipushkara Yoga",
                                   "Tripushkara Yoga"]
    static let signs = ["Mesha", "Vrishabha", "Mithuna", "Karka", "Simha", "Kanya", "Tula", "Vrischika", "Dhanu",
                        "Makara", "Kumbha", "Meena"]

    // MARK: Day

    public func calculate(_ date: CivilDate, city: PanchangCity = .newDelhi) -> PanchangDay {
        let startUtc = startFor(date, city: city)
        let endUtc = endFor(date, city: city)
        let sunrise = findCrossing(startUtc, endUtc, city, moon: false, rising: true)
        var sunset = findCrossing(startUtc, endUtc, city, moon: false, rising: false)
        // The solar day's sunset follows its sunrise; at high latitudes it can
        // fall after local midnight (none, or an earlier one, in the civil day).
        if let sunrise, sunset == nil || sunset! < sunrise {
            sunset = findCrossing(sunrise, city.midnight(date, dayOffset: 2), city, moon: false, rising: false)
        }
        let moonrise = findCrossing(startUtc, endUtc, city, moon: true, rising: true)
        let moonset = findCrossing(startUtc, endUtc, city, moon: true, rising: false)
        let hasSolarDay = sunrise != nil && sunset != nil && sunset! > sunrise!
        let localSunrise = sunrise ?? city.dateAtHour(date, 6)
        let localSunset = sunset ?? city.dateAtHour(date, 18)
        let dayLength = localSunset.timeIntervalSince(localSunrise)
        let madhyahna = localSunrise.adding(truncatedMicroseconds(dayLength, dividedBy: 2))
        let nightEnd = findCrossing(localSunset, city.midnight(date, dayOffset: 2), city, moon: false, rising: true)

        let tithi = tithiAt(localSunrise)
        let nakshatra = nakshatraAt(localSunrise)
        let yoga = yogaAt(localSunrise)
        let karana = karanaAt(localSunrise)
        let month = monthFor(localSunrise)
        let purnimantaIndex = tithi.paksha == "Krishna" && !month.adhika ? (month.index + 1) % 12 : month.index
        let purnimanta = (month.adhika ? "Adhika " : "") + Self.lunarMonths[purnimantaIndex]
        let weekday = date.weekday
        let rahukala = dayPeriod(localSunrise, localSunset, weekday: weekday, segments: [2, 7, 5, 6, 4, 3, 8], name: "Rahu Kalam")
        let yamaganda = dayPeriod(localSunrise, localSunset, weekday: weekday, segments: [4, 3, 2, 1, 7, 6, 5], name: "Yamaganda")
        let gulika = dayPeriod(localSunrise, localSunset, weekday: weekday, segments: [6, 5, 4, 3, 2, 1, 7], name: "Gulika Kalam")
        // Without a full solar day only the Sankranti moment is reported.
        let events = !hasSolarDay || nightEnd == nil
            ? sankrantiOnly(city, date, sunset)
            : observances(city: city, date: date, sunrise: localSunrise, sunset: localSunset, tithi: tithi)
        let fullNight = hasSolarDay && nightEnd != nil
        let sunLongitude = AstronomyCalculator.sunLongitude(localSunrise)
        let shakaOffset = date.month <= 4 && month.index >= 9 ? 1 : 0
        let timelineEnd = nightEnd ?? endUtc
        let thirtieth = truncatedMicroseconds(dayLength, dividedBy: 30)

        return PanchangDay(
            date: date, city: city, sunrise: sunrise, sunset: sunset, moonrise: moonrise, moonset: moonset,
            nextSunrise: nightEnd, tithi: tithi, nakshatra: nakshatra, yoga: yoga, karana: karana,
            vara: Self.varas[weekday], amantaMonth: month.name, purnimantaMonth: purnimanta, isAdhikaMonth: month.adhika,
            rahukala: hasSolarDay ? rahukala : nil, yamaganda: hasSolarDay ? yamaganda : nil,
            gulika: hasSolarDay ? gulika : nil,
            abhijit: !hasSolarDay || weekday == 3 ? nil
                : PanchangPeriod(name: "Abhijit Muhurta", start: madhyahna.adding(-thirtieth), end: madhyahna.adding(thirtieth)),
            brahmaMuhurta: !hasSolarDay ? nil
                : PanchangPeriod(name: "Brahma Muhurta", start: localSunrise.adding(-96 * 60), end: localSunrise.adding(-48 * 60)),
            choghadiya: fullNight ? choghadiya(localSunrise, localSunset, nightEnd!, weekday) : [],
            hora: fullNight ? hora(localSunrise, localSunset, nightEnd!, weekday) : [],
            additionalPeriods: fullNight ? additionalPeriods(localSunrise, localSunset, nightEnd!, weekday) : [],
            lagna: !fullNight || abs(city.latitude) >= 66 ? [] : lagna(localSunrise, nightEnd!, city),
            specialYogas: specialYogas(localSunrise, weekday),
            nakshatraPada: Int(floor(dartMod(siderealMoon(localSunrise), 360.0 / 27) / (360.0 / 108))) + 1,
            ayanamsa: AstronomyCalculator.lahiriAyanamsa(localSunrise),
            ritu: Self.ritus[month.index / 2],
            ayana: Self.ayanas[sunLongitude >= 270 || sunLongitude < 90 ? 0 : 1],
            sunRashi: Self.rashi(AstronomyCalculator.normalize(sunLongitude - AstronomyCalculator.apparentLahiriAyanamsa(localSunrise))),
            moonRashi: Self.rashi(siderealMoon(localSunrise)),
            sunRashiEndsAt: nextBoundary(localSunrise, siderealSun(localSunrise), 30, siderealSun),
            moonRashiEndsAt: nextBoundary(localSunrise, siderealMoon(localSunrise), 30, siderealMoon),
            padaEndsAt: nextBoundary(localSunrise, siderealMoon(localSunrise), 360.0 / 108, siderealMoon),
            anandadiYoga: anandadi(localSunrise, weekday),
            shakaYear: date.year - shakaOffset - 78,
            vikramaYear: date.year - shakaOffset + 57,
            limbTimeline: [
                PanchangLimbTimeline(name: "Tithi", limbs: timeline(localSunrise, timelineEnd, tithiAt)),
                PanchangLimbTimeline(name: "Nakshatra", limbs: timeline(localSunrise, timelineEnd, nakshatraAt)),
                PanchangLimbTimeline(name: "Yoga", limbs: timeline(localSunrise, timelineEnd, yogaAt)),
                PanchangLimbTimeline(name: "Karana", limbs: timeline(localSunrise, timelineEnd, karanaAt)),
            ],
            observances: events)
    }

    public func startFor(_ date: CivilDate, city: PanchangCity) -> Date { city.midnight(date) }
    public func endFor(_ date: CivilDate, city: PanchangCity) -> Date { city.midnight(date, dayOffset: 1) }

    // MARK: Limbs

    public func tithiAt(_ instant: Date) -> PanchangLimb {
        let angle = elongation(instant)
        let index = min(29, max(0, Int(floor(angle / 12))))
        let paksha = index < 15 ? "Shukla" : "Krishna"
        let nameIndex = index < 15 ? index : index - 15
        let label = index == 29 ? "Amavasya" : Self.tithis[nameIndex]
        return PanchangLimb(index: index + 1, name: label, endsAt: nextBoundary(instant, angle, 12, elongation), paksha: paksha)
    }

    public func nakshatraAt(_ instant: Date) -> PanchangLimb {
        let angle = siderealMoon(instant)
        let width = 360.0 / 27
        let index = min(26, max(0, Int(floor(angle / width))))
        return PanchangLimb(index: index + 1, name: Self.nakshatras[index], endsAt: nextBoundary(instant, angle, width, siderealMoon))
    }

    func yogaAt(_ instant: Date) -> PanchangLimb {
        let angle = yogaAngle(instant)
        let width = 360.0 / 27
        let index = min(26, max(0, Int(floor(angle / width))))
        return PanchangLimb(index: index + 1, name: Self.yogas[index], endsAt: nextBoundary(instant, angle, width, yogaAngle))
    }

    func karanaAt(_ instant: Date) -> PanchangLimb {
        let angle = elongation(instant)
        let index = min(59, max(0, Int(floor(angle / 6))))
        let name: String
        switch index {
        case 0: name = "Kimstughna"
        case 57: name = "Shakuni"
        case 58: name = "Chatushpada"
        case 59: name = "Naga"
        default: name = Self.karanaChara[(index - 1) % Self.karanaChara.count]
        }
        return PanchangLimb(index: index + 1, name: name, endsAt: nextBoundary(instant, angle, 6, elongation))
    }

    public func tithiStart(_ instant: Date) -> Date { previousBoundary(instant, 12, elongation) }

    func previousBoundary(_ instant: Date, _ width: Double, _ angleAt: (Date) -> Double) -> Date {
        let index = Int(floor(angleAt(instant) / width))
        var right = instant
        for i in 1...48 {
            var left = instant.adding(-Double(i) * 3600)
            if Int(floor(angleAt(left) / width)) == index { continue }
            for _ in 0..<24 {
                let middle = left.adding(truncatedMicroseconds(right.timeIntervalSince(left), dividedBy: 2))
                if Int(floor(angleAt(middle) / width)) == index { right = middle } else { left = middle }
            }
            return right
        }
        // Unreachable for the Moon and Sun (every limb is shorter than 48 hours).
        return instant.adding(-48 * 3600)
    }

    func nextBoundary(_ start: Date, _ startAngle: Double, _ width: Double, _ angleAt: (Date) -> Double) -> Date? {
        let startIndex = floor(startAngle / width)
        let remainder = startAngle - startIndex * width
        let distance = width - remainder
        let limit = start.adding(Double(width >= 30 ? 35 * 24 : 40) * 3600)
        let step = 600.0
        var low = start
        var high: Date?
        var probe = start.adding(step)
        while probe <= limit {
            if AstronomyCalculator.normalize(angleAt(probe) - startAngle) >= distance {
                high = probe
                break
            }
            low = probe
            probe = probe.adding(step)
        }
        guard var right = high else { return nil }
        for _ in 0..<22 {
            let middle = low.adding(truncatedMicroseconds(right.timeIntervalSince(low), dividedBy: 2))
            if AstronomyCalculator.normalize(angleAt(middle) - startAngle) >= distance { right = middle } else { low = middle }
        }
        return right
    }

    func elongation(_ instant: Date) -> Double {
        AstronomyCalculator.normalize(AstronomyCalculator.moonLongitude(instant) - AstronomyCalculator.sunLongitude(instant))
    }

    func siderealSun(_ instant: Date) -> Double {
        AstronomyCalculator.normalize(AstronomyCalculator.sunLongitude(instant) - AstronomyCalculator.apparentLahiriAyanamsa(instant))
    }

    func siderealMoon(_ instant: Date) -> Double {
        AstronomyCalculator.normalize(AstronomyCalculator.moonLongitude(instant) - AstronomyCalculator.apparentLahiriAyanamsa(instant))
    }

    func yogaAngle(_ instant: Date) -> Double {
        AstronomyCalculator.normalize(AstronomyCalculator.moonLongitude(instant) + AstronomyCalculator.sunLongitude(instant)
            - 2 * AstronomyCalculator.apparentLahiriAyanamsa(instant))
    }

    static func rashi(_ angle: Double) -> String { signs[dartMod(Int(floor(angle / 30)), 12)] }

    // MARK: Months

    func monthFor(_ instant: Date) -> (index: Int, name: String, adhika: Bool) {
        // Amanta months run from new moon to new moon; the month follows the
        // sidereal solar sign at the preceding new moon.
        let newMoon = previousNewMoon(instant)
        let sun = siderealSun(newMoon)
        let index = (Int(floor(sun / 30)) + 1) % 12
        let nextNewMoon = previousNewMoon(newMoon.adding(32 * 86400))
        let nextSign = Int(floor(siderealSun(nextNewMoon) / 30))
        let adhika = nextSign == Int(floor(sun / 30))
        return (index, (adhika ? "Adhika " : "") + Self.lunarMonths[index], adhika)
    }

    func previousNewMoon(_ instant: Date) -> Date {
        let step = 12.0 * 3600
        var later = instant
        var laterPhase = elongation(later)
        for _ in 0..<64 {
            let earlier = later.adding(-step)
            let earlierPhase = elongation(earlier)
            if earlierPhase > 300 && laterPhase < 60 {
                var left = earlier
                var right = later
                for _ in 0..<24 {
                    let middle = left.adding(truncatedMicroseconds(right.timeIntervalSince(left), dividedBy: 2))
                    if elongation(middle) < 180 { right = middle } else { left = middle }
                }
                return right
            }
            later = earlier
            laterPhase = earlierPhase
        }
        return instant.adding(-30 * 86400)
    }

    // MARK: Rise and set

    func findCrossing(_ start: Date, _ end: Date, _ city: PanchangCity, moon: Bool, rising: Bool) -> Date? {
        let step = 300.0
        // Apparent upper limb on a sea-level horizon.
        func difference(_ instant: Date) -> Double {
            AstronomyCalculator.altitudeDegrees(instant: instant, latitude: city.latitude, longitude: city.longitude, moon: moon)
                + AstronomyCalculator.horizonRefraction + AstronomyCalculator.semidiameterDegrees(instant, moon: moon)
        }
        var low = start
        var lowValue = difference(low)
        var high = start.adding(step)
        while high <= end {
            let highValue = difference(high)
            let crossed = rising ? lowValue <= 0 && highValue > 0 : lowValue >= 0 && highValue < 0
            if crossed {
                var left = low
                var right = high
                for _ in 0..<20 {
                    let middle = left.adding(truncatedMicroseconds(right.timeIntervalSince(left), dividedBy: 2))
                    let value = difference(middle)
                    if rising ? value > 0 : value < 0 { right = middle } else { left = middle }
                }
                return right
            }
            low = high
            lowValue = highValue
            high = high.adding(step)
        }
        return nil
    }

    // MARK: Periods

    func dayPeriod(_ sunrise: Date, _ sunset: Date, weekday: Int, segments: [Int], name: String) -> PanchangPeriod? {
        guard sunset > sunrise else { return nil }
        let segment = truncatedMicroseconds(sunset.timeIntervalSince(sunrise), dividedBy: 8)
        let start = sunrise.adding(segment * Double(segments[weekday - 1] - 1))
        return PanchangPeriod(name: name, start: start, end: start.adding(segment))
    }

    /// `start + round(length * fraction)` in microseconds, as the Dart code.
    static func at(_ start: Date, _ length: TimeInterval, _ fraction: Double) -> Date {
        start.adding((length * 1e6 * fraction).rounded() / 1e6)
    }

    /// Boundary [i] of [n] equal parts of [start, end]; the last is [end] itself.
    static func boundary(_ start: Date, _ end: Date, _ i: Int, _ n: Int) -> Date {
        i == 0 ? start : i == n ? end : at(start, end.timeIntervalSince(start), Double(i) / Double(n))
    }

    func hora(_ sunrise: Date, _ sunset: Date, _ nextSunrise: Date, _ weekday: Int) -> [PanchangPeriod] {
        let planets = Self.horaPlanets
        let firstByWeekday = [6, 2, 5, 1, 4, 0, 3]
        var result: [PanchangPeriod] = []
        for half in 0..<2 {
            let start = half == 0 ? sunrise : sunset
            let end = half == 0 ? sunset : nextSunrise
            for i in 0..<12 {
                result.append(PanchangPeriod(name: planets[(firstByWeekday[weekday - 1] + half * 12 + i) % 7],
                                             start: Self.boundary(start, end, i, 12), end: Self.boundary(start, end, i + 1, 12)))
            }
        }
        return result
    }

    func choghadiya(_ sunrise: Date, _ sunset: Date, _ nextSunrise: Date, _ weekday: Int) -> [PanchangPeriod] {
        let names = Self.choghadiyaDay
        let dayStarts = [0, 3, 6, 2, 5, 1, 4]
        let nightStarts = [0, 2, 4, 6, 1, 3, 5]
        let nightNames = Self.choghadiyaNight
        var result: [PanchangPeriod] = []
        for night in 0..<2 {
            let start = night == 0 ? sunrise : sunset
            let end = night == 0 ? sunset : nextSunrise
            let first = (night == 0 ? dayStarts : nightStarts)[weekday % 7]
            for i in 0..<8 {
                let name = (night == 0 ? names : nightNames)[(first + i) % 7]
                result.append(PanchangPeriod(name: "\(night == 0 ? "Day" : "Night") · \(name)",
                                             start: Self.boundary(start, end, i, 8), end: Self.boundary(start, end, i + 1, 8)))
            }
        }
        return result
    }

    func additionalPeriods(_ sunrise: Date, _ sunset: Date, _ nextSunrise: Date, _ weekday: Int) -> [PanchangPeriod] {
        var result: [PanchangPeriod] = []
        // Monday-first one-based fifteenths of daylight. Tuesday also has the
        // seventh fifteenth of night. Traditional muhurta table, not clock hours.
        let dur = [[9, 12], [4], [8], [6, 12], [4, 9], [1, 2], [14]]
        func addPart(_ name: String, _ start: Date, _ length: TimeInterval, _ offset: Double, _ width: Double, _ denominator: Double) {
            let a = Self.at(start, length, offset / denominator)
            let b = Self.at(start, length, (offset + width) / denominator)
            if b > sunrise && a < nextSunrise {
                result.append(PanchangPeriod(name: name, start: a < sunrise ? sunrise : a, end: b > nextSunrise ? nextSunrise : b))
            }
        }
        for part in dur[weekday - 1] {
            addPart("Dur Muhurta", sunrise, sunset.timeIntervalSince(sunrise), Double(part) - 1, 1, 15)
        }
        if weekday == 2 {
            addPart("Dur Muhurta", sunset, nextSunrise.timeIntervalSince(sunset), 6, 1, 15)
        }
        // Ghati offsets within the actual nakshatra duration (60 ghatis).
        let varjya = [50, 24, 30, 40, 14, 21, 30, 20, 32, 30, 20, 18, 21, 20, 14, 14, 10, 14, 20, 24, 20, 10, 10, 18, 16, 24, 30]
        let amrita = [42, 48, 54, 52, 38, 35, 54, 44, 56, 54, 44, 42, 45, 44, 38, 38, 34, 38, 44, 48, 44, 34, 34, 42, 40, 48, 54]
        var cursor = sunrise
        var count = 0
        while count < 4 && cursor < nextSunrise {
            let limb = nakshatraAt(cursor)
            let start = previousBoundary(cursor, 360.0 / 27, siderealMoon)
            guard let end = limb.endsAt else { break }
            let duration = end.timeIntervalSince(start)
            addPart("Varjyam", start, duration, Double(varjya[limb.index - 1]), 4, 60)
            addPart("Amrit Kalam", start, duration, Double(amrita[limb.index - 1]), 4, 60)
            if limb.index == 19 { addPart("Varjyam", start, duration, 56, 4, 60) }
            cursor = end.adding(1)
            count += 1
        }
        // Dart's List.sort is not stable; ties keep insertion order here.
        return result.enumerated().sorted { a, b in
            a.element.start == b.element.start ? a.offset < b.offset : a.element.start < b.element.start
        }.map(\.element)
    }

    func specialYogas(_ instant: Date, _ weekday: Int) -> [String] {
        let nak = nakshatraAt(instant).index
        let moon = siderealMoon(instant)
        let tithi = tithiAt(instant).index
        let karana = karanaAt(instant)
        let sarvartha = [[4, 5, 8, 17, 22], [1, 9, 26, 3], [3, 4, 5, 13, 17], [1, 7, 8, 17, 27], [1, 7, 17, 22, 27],
                         [4, 15, 22], [1, 8, 12, 13, 19, 21, 26]]
        let solarNak = Int(floor(siderealSun(instant) / (360.0 / 27))) + 1
        let fortnight = (tithi - 1) % 15 + 1
        let pushkaraDay = [2, 7, 12].contains(fortnight) && [7, 2, 6].contains(weekday)
        var result: [String] = []
        if nak == [5, 1, 17, 8, 27, 4, 13][weekday - 1] { result.append("Amrita Siddhi Yoga") }
        if [4, 6, 9, 10, 13, 20].contains((nak - solarNak + 27) % 27 + 1) { result.append("Ravi Yoga") }
        if moon >= 300 { result.append("Panchaka") }
        if [1, 9, 10, 18, 19, 27].contains(nak) { result.append("Ganda Moola") }
        if moon >= 210 && moon < 240 { result.append("Vinchudo") }
        if karana.name == "Vishti" { result.append("Bhadra") }
        if sarvartha[weekday - 1].contains(nak) { result.append("Sarvartha Siddhi Yoga") }
        if weekday == 7 && nak == 8 { result.append("Ravi Pushya Yoga") }
        if weekday == 4 && nak == 8 { result.append("Guru Pushya Yoga") }
        if pushkaraDay && [5, 14, 23].contains(nak) { result.append("Dwipushkara Yoga") }
        if pushkaraDay && [3, 7, 12, 16, 21, 25].contains(nak) { result.append("Tripushkara Yoga") }
        return result
    }

    func anandadi(_ instant: Date, _ weekday: Int) -> String {
        let names = Self.anandadiNames
        let longitude = siderealMoon(instant)
        let nak = Int(floor(longitude / (360.0 / 27)))
        // The 28-star cycle includes Abhijit (276°40′ to 280°53′20″).
        let extended = longitude >= 276 + 2.0 / 3 && longitude < 280 + 8.0 / 9 ? 21 : (nak >= 21 ? nak + 1 : nak)
        let starts = [4, 7, 12, 16, 20, 24, 0]
        return names[(extended - starts[weekday - 1] + 28) % 28]
    }

    func lagna(_ start: Date, _ end: Date, _ city: PanchangCity) -> [PanchangPeriod] {
        func angle(_ instant: Date) -> Double {
            AstronomyCalculator.normalize(AstronomyCalculator.ascendantLongitude(instant, latitude: city.latitude,
                                                                                 longitude: city.longitude)
                - AstronomyCalculator.lahiriAyanamsa(instant))
        }
        var result: [PanchangPeriod] = []
        var cursor = start
        var i = 0
        while i < 16 && cursor < end {
            let value = angle(cursor)
            guard let boundary = nextBoundary(cursor, value, 30, angle), boundary > cursor else { break }
            let stop = boundary < end ? boundary : end
            result.append(PanchangPeriod(name: Self.rashi(value), start: cursor, end: stop))
            cursor = stop
            i += 1
        }
        return result
    }

    func timeline(_ start: Date, _ end: Date, _ at: (Date) -> PanchangLimb) -> [PanchangLimb] {
        var result: [PanchangLimb] = []
        var cursor = start
        while cursor < end && result.count < 8 {
            let limb = at(cursor)
            result.append(limb)
            guard let next = limb.endsAt, next > cursor else { break }
            cursor = next.adding(1)
        }
        return result
    }

    func solarIngress(_ start: Date, _ end: Date) -> Date? {
        var low = start
        var lowAngle = siderealSun(low)
        var high = start.adding(1800)
        while high <= end {
            let highAngle = siderealSun(high)
            if floor(highAngle / 30) != floor(lowAngle / 30) || (lowAngle > 330 && highAngle < 30) {
                var left = low
                var right = high
                let target = (floor(lowAngle / 30) + 1) * 30
                for _ in 0..<20 {
                    let middle = left.adding(truncatedMicroseconds(right.timeIntervalSince(left), dividedBy: 2))
                    let angle = siderealSun(middle)
                    let crossed = target >= 360 ? angle < 30 : angle >= target
                    if crossed { right = middle } else { left = middle }
                }
                return right
            }
            low = high
            lowAngle = highAngle
            high = high.adding(1800)
        }
        return nil
    }

    func siderealSign(_ instant: Date) -> Int { min(11, max(0, Int(floor(siderealSun(instant) / 30)))) }
}
