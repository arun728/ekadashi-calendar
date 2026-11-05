import Foundation

/// GCal 11's astronomy and Vaishnava Ekadashi rules, so Vaishnava fasts and
/// Parana match ISKCON calendars. GCal is the GBC Calendar Committee's
/// program; this follows gaurabda 0.8.4 (MIT), its Python port, line by line
/// and with its names, plus one fix: IsMhd58's no-match value (see
/// docs/PANCHANG_ACCURACY.md, "ISKCON Vaishnava"). GCal's sun is table based,
/// its sunrise is the disc centre at -0.83°, its moon is Meeus' 60-term series
/// with short nutation and no Delta T, and its ayanamsa is a Lahiri formula.
/// Times are day fractions in the zone's standard time, as in GCal.
enum Gcal {
    static let dg = 3.1415926535897932385 / 180
    static func sinDeg(_ x: Double) -> Double { sin(x * dg) }
    static func cosDeg(_ x: Double) -> Double { cos(x * dg) }
    static func putIn360(_ x: Double) -> Double {
        let d = x.truncatingRemainder(dividingBy: 360)
        return d < 0 ? d + 360 : d
    }

    /// GCGregorianDate: a civil date, a day fraction and the zone's standard offset in hours.
    struct Moment {
        var date: CivilDate
        var shour: Double
        let tzone: Double
        var julian: Double { Double(date.daysSinceEpoch + 2_440_588) }
        var julianComplete: Double { julian - 0.5 + shour - tzone / 24 }

        mutating func normalizeHours() {
            while shour < 0 {
                shour += 1
                date = date.adding(days: -1)
            }
            while shour > 1 {
                shour -= 1
                date = date.adding(days: 1)
            }
        }
    }

    // MARK: Sun (GCSunData)

    static func sunMeanLong(_ date: CivilDate) -> Double {
        var year = date.year
        var mel = sunLong[(date.day - 1) * 12 + (date.month + 9) % 12]
        if date.month < 3 { year -= 1 }
        let y = year / 100, yy = year % 100
        if y <= 15 {
            mel += sun1Col[y % 4] + sun1Row[y / 4]
        } else if y < 40 {
            mel += sun2Col[y % 4] + sun2Row[y / 4]
        }
        mel += sun3Col[yy % 4] + sun3Row[yy / 4]
        return mel
    }

    static func sunPerigee(_ date: CivilDate) -> Double {
        let year = date.month < 3 ? date.year - 1 : date.year
        let y = year / 100, yy = year % 100
        return sun4Row[y / 4] + sun4Col[y % 4] + sun5Row[yy / 4] + sun5Col[yy % 4]
    }

    static func eclipticLongitude(_ mel: Double, _ date: CivilDate) -> Double {
        let mas = mel - sunPerigee(date)
        return mel + 1.915 * sin(mas * dg) + 0.02 * sin(2 * dg * mas)
    }

    /// GetSunLongitude: at the moment's local time.
    static func sunLongitude(_ m: Moment) -> Double {
        eclipticLongitude(sunMeanLong(m.date) + (360 / 365.25) * (m.shour - 0.5 - m.tzone / 24), m.date)
    }

    /// SUNDATA.SunPosition: degrees of UT for rise and set (-360: none).
    struct SunPosition {
        var longitude = 0.0, sunrise = 180.0, sunset = 0.0

        mutating func calculate(_ date: CivilDate, _ latitude: Double, _ longitudeEast: Double, _ dayHours: Double) {
            let rad = 180 / 3.1415926535897932385
            let mel = sunMeanLong(date) + (360 / 365.25) * dayHours / 360
            let els = eclipticLongitude(mel, date)
            longitude = els
            let declination = rad * asin(0.39777 * sin(els * dg))
            let rightAscension = els - rad * atan2(sin(2 * els * dg), 23.2377 + cos(2 * dg * els))
            let eqt = rightAscension - mel
            let eventdef = (0.01454 / cos(latitude * dg)) / cos(declination * dg)
            let x = tan(latitude * dg) * tan(declination * dg) + eventdef
            sunrise = -360
            sunset = -360
            if x >= -1, x <= 1 {
                sunrise = 90 - longitudeEast - rad * asin(x) + eqt
                sunset = 270 - longitudeEast + rad * asin(x) + eqt
            }
        }
    }

    /// SUNDATA.SunCalc.
    struct Sun {
        let sunrise: Double, sunset: Double, arunodaya: Double, length: Double
        let longitude: Double, longitudeSet: Double, longitudeArun: Double
        var exists: Bool { sunrise > -360 && sunset > -360 }

        init(_ date: CivilDate, _ latitude: Double, _ longitudeEast: Double) {
            var rise = SunPosition(), set = SunPosition()
            for _ in 0..<3 {
                rise.calculate(date, latitude, longitudeEast, rise.sunrise - 180)
                set.calculate(date, latitude, longitudeEast, set.sunset - 180)
            }
            longitudeArun = rise.longitude - 24 / 365.25
            longitude = rise.longitude
            longitudeSet = set.longitude
            arunodaya = rise.sunrise - 24
            sunrise = rise.sunrise
            sunset = set.sunset
            length = set.sunset - rise.sunrise
        }
    }

    // MARK: Moon (GCMoonData, GCEarthData)

    /// Apparent ecliptic longitude: the 60-term series plus GCal's short nutation.
    static func moonLongitude(_ jdate: Double) -> Double {
        let t = (jdate - 2_451_545.0) / 36525.0
        let d = 297.8502042 + (445_267.1115168 + (-0.0016300 + (1.0 / 545_868 - 1.0 / 113_065_000 * t) * t) * t) * t
        let m = 357.5291092 + (35999.0502909 + (-0.0001536 + 1.0 / 24_490_000 * t) * t) * t
        let ms = 134.9634114 + (477_198.8676313 + (0.0089970 + (1.0 / 69699 - 1.0 / 1_471_200 * t) * t) * t) * t
        let f = 93.2720993 + (483_202.0175273 + (-0.0034029 + (-1.0 / 3_526_000 + 1.0 / 863_310_000 * t) * t) * t) * t
        let e = 1.0 + (-0.002516 - 0.0000074 * t) * t
        let ls = 218.3164591 + (481_267.88134236 + (-0.0013268 + (1.0 / 538_841 - 1.0 / 65_194_000 * t) * t) * t) * t
        let a1 = 119.75 + 131.849 * t
        let a2 = 53.09 + 479_264.290 * t
        var sl = 0.0
        for i in 0..<60 {
            let k = i * 4, sunTerm = argLr[k + 1]
            let argument = Double(argLr[k]) * d + Double(sunTerm) * m + Double(argLr[k + 2]) * ms + Double(argLr[k + 3]) * f
            var temp = Double(sigmaL[i]) * sinDeg(argument)
            if abs(sunTerm) == 1 { temp = temp * e }
            if abs(sunTerm) == 2 { temp = temp * e * e }
            sl = sl + temp
        }
        sl = sl + 3958 * sinDeg(a1) + 1962 * sinDeg(ls - f) + 318 * sinDeg(a2)
        let longitude = ls + sl / 1_000_000
        // calc_epsilon_phi (short form).
        let omega = putIn360(125.04452 + (-1934.136261 + (0.0020708 + 1.0 / 450_000 * t) * t) * t)
        let l = 280.4665 + 36000.7698 * t
        let lm = 218.3165 + 481_267.8813 * t
        let deltaPhi = (-17.20 * sinDeg(omega) - 1.32 * sinDeg(2 * l) - 0.23 * sinDeg(2 * lm) + 0.21 * sinDeg(2 * omega)) / 3600
        return putIn360(longitude + deltaPhi)
    }

    /// GCAyanamsha.GetAyanamsa (Lahiri).
    static func ayanamsa(_ jdate: Double) -> Double {
        let t = (jdate - 2_451_545.0) / 36525.0
        return 23.85305555555 + (5028.796195 - 1.1054348 * t) * t / 3600.0
    }

    // MARK: Day (GCDayData.DayCalc)

    struct Day {
        let date: CivilDate
        let sun: Sun
        /// 0-29 from Krishna Pratipat; 15-29 are Gaura.
        let tithi: Int, tithiSunset: Int, tithiArunodaya: Int
        /// 0-26 from Ashvini.
        let naksatra: Int
        var mhd: Mhd = .null
        var fast = false
        var parana: Parana?
        var paksa: Int { tithi >= 15 ? 1 : 0 }

        init(_ date: CivilDate, _ latitude: Double, _ longitudeEast: Double) {
            self.date = date
            sun = Sun(date, latitude, longitudeEast)
            let julian = Double(date.daysSinceEpoch + 2_440_588)
            let jdate = julian - 0.5 + sun.sunrise / 360
            let moon = moonLongitude(jdate)
            tithi = Int(floor(putIn360(moon - sun.longitude - 180) / 12))
            naksatra = Int(floor(putIn360(moon - ayanamsa(jdate)) * 3 / 40))
            tithiSunset = Int(floor(putIn360(moonLongitude(julian - 0.5 + sun.sunset / 360) - sun.longitudeSet - 180) / 12))
            tithiArunodaya = Int(floor(putIn360(moonLongitude(julian - 0.5 + sun.arunodaya / 360) - sun.longitudeArun - 180) / 12))
        }
    }

    enum Mhd { case null, suddha, unmilani, vyanjuli, trisprsa, unmilaniTrisprsa, paksavardhini, jaya, jayanti, papaNasini, vijaya }

    /// Begin and end as standard-time day fractions of the Parana day (end -1: none).
    struct Parana {
        let begin: Double, end: Double
        /// GetTithiTimes' first quarter of the tithi at the Parana sunrise.
        let quarter: Double
    }

    static func isEkadasi(_ a: Int) -> Bool { a == 10 || a == 25 }
    static func isDvadasi(_ a: Int) -> Bool { a == 11 || a == 26 }
    static func isTrayodasi(_ a: Int) -> Bool { a == 12 || a == 27 }
    static func isLessEkadasi(_ a: Int) -> Bool { [9, 24, 8, 23].contains(a) }
    static func isFullNewMoon(_ a: Int) -> Bool { a == 14 || a == 29 }

    // MARK: Tithi and naksatra ends (GCTithi, GCNaksatra)

    /// GetNextTithiStart / GetPrevTithiStart: the last moment of the current tithi.
    static func tithiStart(_ start: Moment, forward: Bool) -> Moment {
        boundary(start, forward: forward) { jday, d in Int(floor(putIn360(moonLongitude(jday) - sunLongitude(d) - 180) / 12)) }
    }

    /// GetNextNaksatra.
    static func naksatraStart(_ start: Moment) -> Moment {
        let ayanamsa = ayanamsa(start.julianComplete)
        return boundary(start, forward: true) { jday, _ in Int(floor(putIn360(moonLongitude(jday) - ayanamsa) / (40.0 / 3.0))) }
    }

    private static func boundary(_ start: Moment, forward: Bool, _ index: (Double, Moment) -> Int) -> Moment {
        var jday = start.julianComplete
        var d = start
        var step = forward ? 0.5 : -0.5
        let previous = index(jday, d)
        var counter = 0
        while counter < 20 {
            let xj = jday, xd = d
            jday += step
            d.shour += step
            d.normalizeHours()
            if index(jday, d) != previous {
                jday = xj
                d = xd
                step *= 0.5
                counter += 1
            }
        }
        return d
    }

    // MARK: Calendar (TCalendar)

    static let beforeDays = 8

    /// The fasts on [start, start + count): CalculateCalendar's Mahadvadasi,
    /// Ekadasi and Parana passes.
    static func fasts(start: CivilDate, count: Int, latitude: Double, longitude: Double, tzone: Double) -> [(Day, Day)] {
        var days = (0..<(count + 2 * beforeDays)).map { Day(start.adding(days: $0 - beforeDays), latitude, longitude) }
        // Polar days have no GCal sunrise: no fasts are decided around them.
        let usable = days.map(\.sun.exists)
        for i in 2..<(count + beforeDays + 3) where usable[(i - 1)...(i + 1)].allSatisfy({ $0 }) {
            mahadvadasiCalc(&days, i)
        }
        for i in 3..<(count + beforeDays + 3) where usable[(i - 1)...(i + 1)].allSatisfy({ $0 }) {
            ekadasiCalc(&days, i, tzone)
        }
        return (beforeDays..<(beforeDays + count)).compactMap { i in days[i].fast ? (days[i], days[i + 1]) : nil }
    }

    static func isMhd58(_ days: [Day], _ i: Int) -> Mhd {
        let t = days[i], u = days[i + 1]
        if t.naksatra != u.naksatra || t.paksa != 1 { return .null }
        if t.tithi == t.tithiSunset {
            return [6: Mhd.jaya, 3: .jayanti, 7: .papaNasini, 21: .vijaya][t.naksatra] ?? .null
        }
        return t.naksatra == 21 ? .vijaya : .null
    }

    static func nextNewFullIsVriddhi(_ days: [Day], _ index: Int) -> Bool {
        var previous = 100
        for i in index..<min(index + beforeDays, days.count) {
            let tithi = days[i].tithi
            if tithi == previous && isFullNewMoon(tithi) { return true }
            previous = tithi
        }
        return false
    }

    static func mahadvadasiCalc(_ days: inout [Day], _ i: Int) {
        let s = days[i - 1], t = days[i], u = days[i + 1]
        if isDvadasi(s.tithi) { return }
        let type = isMhd58(days, i)
        var found: Mhd?
        if t.tithi == 26 && t.tithiSunset == 26 && type != .null {
            found = type
        } else if isDvadasi(t.tithi) {
            if isDvadasi(u.tithi) && isEkadasi(s.tithi) && isEkadasi(s.tithiArunodaya) {
                found = .vyanjuli
            } else if nextNewFullIsVriddhi(days, i) {
                found = .paksavardhini
            } else if isLessEkadasi(s.tithiArunodaya) {
                found = .suddha
            }
        }
        if let found {
            days[i].mhd = found
            days[i].fast = true
        }
    }

    static func ekadasiCalc(_ days: inout [Day], _ i: Int, _ tzone: Double) {
        let s = days[i - 1], t = days[i], u = days[i + 1]
        if isEkadasi(t.tithi) {
            var type = Mhd.null
            if isLessEkadasi(t.tithiArunodaya) {
                type = .null
            } else if isEkadasi(s.tithi) && isEkadasi(s.tithiArunodaya) {
                type = isTrayodasi(u.tithi) ? .unmilaniTrisprsa : .unmilani
            } else if isTrayodasi(u.tithi) {
                type = .trisprsa
            } else if !isEkadasi(u.tithi) && u.mhd == .null {
                type = .suddha
            }
            days[i].mhd = type
            days[i].fast = type != .null
        }
        if s.fast {
            days[i].mhd = .null
            days[i].fast = false
            days[i].parana = calculateEParana(s, days[i], tzone)
        }
    }

    static func calculateEParana(_ s: Day, _ t: Day, _ tzone: Double) -> Parana {
        let sunRise = t.sun.sunrise / 360 + tzone / 24
        let thirdDay = sunRise + t.sun.length / 1080
        let vc = Moment(date: t.date, shour: sunRise, tzone: tzone)
        let d1 = tithiStart(vc, forward: false), d2 = tithiStart(vc, forward: true)
        let titBeg = d1.shour + d1.julian - vc.julian
        let titEnd = d2.shour + d2.julian - vc.julian
        let tithiQuart = (titEnd - titBeg) / 4 + titBeg
        var parBeg = -1.0, parEnd = -1.0
        func naksatraEnd() -> Double {
            let end = naksatraStart(Moment(date: s.date, shour: 0.5, tzone: tzone))
            return end.julian - vc.julian + end.shour
        }
        switch s.mhd {
        case .unmilani:
            parEnd = min(titEnd, thirdDay)
            parBeg = sunRise
        case .vyanjuli:
            parBeg = sunRise
            parEnd = min(titEnd, thirdDay)
        case .trisprsa:
            parBeg = sunRise
            parEnd = thirdDay
        case .jayanti, .vijaya, .jaya, .papaNasini:
            let naksEnd = naksatraEnd()
            if isDvadasi(t.tithi) {
                if naksEnd < titEnd {
                    parBeg = naksEnd
                    parEnd = naksEnd < thirdDay ? min(titEnd, thirdDay) : titEnd
                } else {
                    parBeg = sunRise
                    parEnd = min(titEnd, thirdDay)
                }
            } else if s.mhd == .jayanti || s.mhd == .vijaya {
                parBeg = sunRise
                parEnd = min(naksEnd, thirdDay)
            } else {
                parBeg = naksEnd
                parEnd = naksEnd < thirdDay ? thirdDay : -1
            }
        default:
            parEnd = min(titEnd, thirdDay)
            parBeg = isDvadasi(s.tithi) ? sunRise : max(sunRise, tithiQuart)
            if parBeg > parEnd { parEnd = -1 }
        }
        return Parana(begin: parBeg, end: parEnd, quarter: tithiQuart)
    }

    /// The longitude on the time zone's side of the date line (Chatham,
    /// 176.6°W, keeps UTC+12:45), so each GCal sunrise falls on its local date.
    static func longitude(_ longitude: Double, tzone: Double) -> Double {
        let hours = longitude / 15 - tzone
        return hours > 12 ? longitude - 360 : hours < -12 ? longitude + 360 : longitude
    }

    /// The instant of a standard-time day fraction of [date].
    static func instant(_ date: CivilDate, _ fraction: Double, _ tzone: Double) -> Date {
        Date(timeIntervalSince1970: (Double(date.daysSinceEpoch) + fraction - tzone / 24) * 86400)
    }

    /// Sunrise of a GCal day (degrees of UT).
    static func sunrise(_ day: Day) -> Date {
        Date(timeIntervalSince1970: (Double(day.date.daysSinceEpoch) + day.sun.sunrise / 360) * 86400)
    }
    static let sunLong: [Double] = [
        339.226, 9.781, 39.351, 69.906, 99.475, 130.03, 160.585, 190.155, 220.71, 250.279, 280.834, 311.39,
        340.212, 10.767, 40.337, 70.892, 100.461, 131.016, 161.571, 191.141, 221.696, 251.265, 281.82, 312.375,
        341.198, 11.753, 41.322, 71.877, 101.447, 132.002, 162.557, 192.126, 222.681, 252.251, 282.806, 313.361,
        342.183, 12.738, 42.308, 72.863, 102.432, 132.987, 163.542, 193.112, 223.667, 253.236, 283.791, 314.346,
        343.169, 13.724, 43.293, 73.849, 103.418, 133.973, 164.528, 194.098, 224.653, 254.222, 284.777, 315.332,
        344.155, 14.71, 44.279, 74.834, 104.404, 134.959, 165.514, 195.083, 225.638, 255.208, 285.763, 316.318,
        345.14, 15.695, 45.265, 75.82, 105.389, 135.944, 166.499, 196.069, 226.624, 256.193, 286.748, 317.303,
        346.126, 16.681, 46.25, 76.805, 106.375, 136.93, 167.485, 197.054, 227.61, 257.179, 287.734, 318.289,
        347.112, 17.667, 47.236, 77.791, 107.361, 137.916, 168.471, 198.04, 228.595, 258.165, 288.72, 319.275,
        348.097, 18.652, 48.222, 78.777, 108.346, 138.901, 169.456, 199.026, 229.581, 259.15, 289.705, 320.26,
        349.083, 19.638, 49.207, 79.762, 109.332, 139.887, 170.442, 200.011, 230.566, 260.136, 290.691, 321.246,
        350.068, 20.624, 50.193, 80.748, 110.317, 140.873, 171.428, 200.997, 231.552, 261.122, 291.677, 322.232,
        351.054, 21.609, 51.179, 81.734, 111.303, 141.858, 172.413, 201.983, 232.538, 262.107, 292.662, 323.217,
        352.04, 22.595, 52.164, 82.719, 112.289, 142.844, 173.399, 202.968, 233.523, 263.093, 293.648, 324.203,
        353.025, 23.581, 53.15, 83.705, 113.274, 143.829, 174.385, 203.954, 234.509, 264.078, 294.634, 325.189,
        354.011, 24.566, 54.136, 84.691, 114.26, 144.815, 175.37, 204.94, 235.495, 265.064, 295.619, 326.174,
        354.997, 25.552, 55.121, 85.676, 115.246, 145.801, 176.356, 205.925, 236.48, 266.05, 296.605, 327.16,
        355.982, 26.537, 56.107, 86.662, 116.231, 146.786, 177.341, 206.911, 237.466, 267.035, 297.59, 328.146,
        356.968, 27.523, 57.093, 87.648, 117.217, 147.772, 178.327, 207.897, 238.452, 268.021, 298.576, 329.131,
        357.954, 28.509, 58.078, 88.633, 118.203, 148.758, 179.313, 208.882, 239.437, 269.007, 299.562, 330.117,
        358.939, 29.494, 59.064, 89.619, 119.188, 149.743, 180.298, 209.868, 240.423, 269.992, 300.547, 331.102,
        359.925, 30.48, 60.049, 90.605, 120.174, 150.729, 181.284, 210.854, 241.409, 270.978, 301.533, 332.088,
        0.911, 31.466, 61.035, 91.59, 121.16, 151.715, 182.27, 211.839, 242.394, 271.964, 302.519, 333.074,
        1.896, 32.451, 62.021, 92.576, 122.145, 152.7, 183.255, 212.825, 243.38, 272.949, 303.504, 334.059,
        2.882, 33.437, 63.006, 93.561, 123.131, 153.686, 184.241, 213.81, 244.366, 273.935, 304.49, 335.045,
        3.868, 34.423, 63.992, 94.547, 124.117, 154.672, 185.227, 214.796, 245.351, 274.921, 305.476, 336.031,
        4.853, 35.408, 64.978, 95.533, 125.102, 155.657, 186.212, 215.782, 246.337, 275.906, 306.461, 337.016,
        5.839, 36.394, 65.963, 96.518, 126.088, 156.643, 187.198, 216.767, 247.322, 276.892, 307.447, 338.002,
        6.824, 37.38, 66.949, 97.504, 127.073, 157.629, 188.184, 217.753, 248.308, 277.878, 308.433, 338.988,
        7.81, 38.365, 67.935, 98.49, 128.059, 158.614, 189.169, 218.739, 249.294, 278.863, 309.418, 339.1,
        8.796, 38.365, 68.92, 98.49, 129.045, 159.6, 189.169, 219.724, 249.294, 279.849, 310.404, 339.226,
    ]
    static let sun1Col: [Double] = [
        -1.157, -0.386, 0.386, 1.157,
    ]
    static let sun1Row: [Double] = [
        -1.07, 2.015, 5.101, 8.186, 11.271, 14.356, 17.441, 20.526, 23.611, 26.697,
    ]
    static let sun2Col: [Double] = [
        0.322, 0.107, -0.107, -0.322,
    ]
    static let sun2Row: [Double] = [
        -0.577, -0.449, -0.32, -0.192, -0.064, 0.064, 0.192, 0.32, 0.449, 0.577,
    ]
    static let sun3Row: [Double] = [
        -0.37, -0.339, -0.309, -0.278, -0.247, -0.216, -0.185, -0.154, -0.123, -0.093, -0.062, -0.031,
        0.0, 0.031, 0.062, 0.093, 0.123, 0.154, 0.185, 0.216, 0.247, 0.278, 0.309, 0.339,
        0.37,
    ]
    static let sun3Col: [Double] = [
        0.358, 0.119, -0.119, -0.358,
    ]
    static let sun4Row: [Double] = [
        251.97, 258.85, 265.73, 272.61, 279.49, 286.37, 293.25, 300.14, 307.02, 313.9,
    ]
    static let sun4Col: [Double] = [
        -2.58, -0.86, 0.86, 2.58,
    ]
    static let sun5Row: [Double] = [
        -0.83, -0.76, -0.69, -0.62, -0.55, -0.48, -0.41, -0.34, -0.28, -0.21, -0.14, -0.07,
        0.0, 0.07, 0.14, 0.21, 0.28, 0.34, 0.41, 0.48, 0.55, 0.62, 0.69, 0.76,
        0.83,
    ]
    static let sun5Col: [Double] = [
        -0.03, -0.01, 0.01, 0.03,
    ]
    static let argLr: [Int] = [
        0, 0, 1, 0, 2, 0, -1, 0, 2, 0, 0, 0, 0, 0, 2, 0,
        0, 1, 0, 0, 0, 0, 0, 2, 2, 0, -2, 0, 2, -1, -1, 0,
        2, 0, 1, 0, 2, -1, 0, 0, 0, 1, -1, 0, 1, 0, 0, 0,
        0, 1, 1, 0, 2, 0, 0, -2, 0, 0, 1, 2, 0, 0, 1, -2,
        4, 0, -1, 0, 0, 0, 3, 0, 4, 0, -2, 0, 2, 1, -1, 0,
        2, 1, 0, 0, 1, 0, -1, 0, 1, 1, 0, 0, 2, -1, 1, 0,
        2, 0, 2, 0, 4, 0, 0, 0, 2, 0, -3, 0, 0, 1, -2, 0,
        2, 0, -1, 2, 2, -1, -2, 0, 1, 0, 1, 0, 2, -2, 0, 0,
        0, 1, 2, 0, 0, 2, 0, 0, 2, -2, -1, 0, 2, 0, 1, -2,
        2, 0, 0, 2, 4, -1, -1, 0, 0, 0, 2, 2, 3, 0, -1, 0,
        2, 1, 1, 0, 4, -1, -2, 0, 0, 2, -1, 0, 2, 2, -1, 0,
        2, 1, -2, 0, 2, -1, 0, -2, 4, 0, 1, 0, 0, 0, 4, 0,
        4, -1, 0, 0, 1, 0, -2, 0, 2, 1, 0, -2, 0, 0, 2, -2,
        1, 1, 1, 0, 3, 0, -2, 0, 4, 0, -3, 0, 2, -1, 2, 0,
        0, 2, 1, 0, 1, 1, -1, 0, 2, 0, 3, 0, 2, 0, -1, -2,
    ]
    static let sigmaL: [Int] = [
        6288774, 1274027, 658314, 213618, -185116, -114332, 58793, 57066, 53322, 45758, -40923, -34720,
        -30383, 15327, -12528, 10980, 10675, 10034, 8548, -7888, -6766, -5163, 4987, 4036,
        3994, 3861, 3665, -2689, -2602, 2390, -2348, 2236, -2120, -2069, 2048, -1773,
        -1595, 1215, -1110, -892, -810, 759, -713, -700, 691, 596, 549, 537,
        520, -487, -399, -381, 351, -340, 330, 327, -323, 299, 294, 0,
    ]
}
