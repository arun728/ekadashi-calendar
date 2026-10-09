import Foundation

/// A calendar date without a time zone (the Dart code's `DateTime.utc(y, m, d)`).
/// Out-of-range months and days roll over like Dart: `CivilDate(2026, 13, 0)`
/// is 31 December 2026.
public struct CivilDate: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(_ year: Int, _ month: Int, _ day: Int) {
        let months = year * 12 + (month - 1)
        let y = Int(floor(Double(months) / 12))
        let m = months - y * 12 + 1
        self.init(daysSinceEpoch: CivilDate.daysFromCivil(y, m, 1) + day - 1)
    }

    public init(daysSinceEpoch days: Int) {
        let (y, m, d) = CivilDate.civilFromDays(days)
        year = y
        month = m
        day = d
    }

    /// `yyyy-MM-dd`, optionally followed by a time (which is ignored).
    public init?(iso: String) {
        let parts = iso.prefix(10).split(separator: "-")
        guard parts.count == 3, iso.count >= 10, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), d >= 1, d <= CivilDate.daysIn(y, m) else { return nil }
        self.init(y, m, d)
    }

    /// The civil date of [instant] in UTC.
    public init(utc instant: Date) {
        self.init(daysSinceEpoch: Int(floor(instant.timeIntervalSince1970 / 86400)))
    }

    /// Today's date in [timeZone] (the device's by default).
    public static func today(in timeZone: TimeZone = .current, now: Date = Date()) -> CivilDate {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        return CivilDate(parts.year!, parts.month!, parts.day!)
    }

    public var daysSinceEpoch: Int { CivilDate.daysFromCivil(year, month, day) }
    public var iso: String { String(format: "%04d-%02d-%02d", year, month, day) }
    public var description: String { iso }
    public var utcMidnight: Date { Date(timeIntervalSince1970: Double(daysSinceEpoch) * 86400) }
    public var daysInMonth: Int { CivilDate.daysIn(year, month) }
    public var firstOfMonth: CivilDate { CivilDate(year, month, 1) }

    /// Monday = 1 ... Sunday = 7, as Dart's `DateTime.weekday`.
    public var weekday: Int {
        // 1970-01-01 was a Thursday (4).
        let value = (daysSinceEpoch + 3) % 7
        return (value < 0 ? value + 7 : value) + 1
    }

    public func adding(days: Int) -> CivilDate { CivilDate(daysSinceEpoch: daysSinceEpoch + days) }
    public func adding(months: Int) -> CivilDate { CivilDate(year, month + months, day) }
    /// The same day [months] later, or the last day of a shorter month
    /// (month steps in the Calendar and Panchang).
    public func steppingMonths(_ months: Int) -> CivilDate {
        let first = CivilDate(year, month + months, 1)
        return CivilDate(first.year, first.month, min(day, first.daysInMonth))
    }
    public func days(until other: CivilDate) -> Int { other.daysSinceEpoch - daysSinceEpoch }

    public static func < (a: CivilDate, b: CivilDate) -> Bool { a.daysSinceEpoch < b.daysSinceEpoch }

    static func daysIn(_ year: Int, _ month: Int) -> Int {
        switch month {
        case 2: return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }

    // Howard Hinnant's days-from-civil algorithms (proleptic Gregorian).
    static func daysFromCivil(_ year: Int, _ month: Int, _ day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (month + 9) % 12
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146097 + doe - 719468
    }

    static func civilFromDays(_ days: Int) -> (Int, Int, Int) {
        let z = days + 719468
        let era = (z >= 0 ? z : z - 146096) / 146097
        let doe = z - era * 146097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        return (yoe + era * 400 + (m <= 2 ? 1 : 0), m, d)
    }
}

/// Dart's `%`: the result has the sign of a positive divisor (never negative).
@inline(__always)
func dartMod(_ a: Double, _ b: Double) -> Double {
    let r = a.truncatingRemainder(dividingBy: b)
    return r < 0 ? r + abs(b) : r
}

@inline(__always)
func dartMod(_ a: Int, _ b: Int) -> Int {
    let r = a % b
    return r < 0 ? r + abs(b) : r
}

/// Dart's `Duration ~/ n` on microseconds, applied to an interval in seconds.
@inline(__always)
func truncatedMicroseconds(_ seconds: TimeInterval, dividedBy divisor: Double) -> TimeInterval {
    (seconds * 1e6 / divisor).rounded(.towardZero) / 1e6
}

extension Date {
    @inline(__always)
    func adding(_ seconds: TimeInterval) -> Date { addingTimeInterval(seconds) }
}

/// Two-digit zero padding.
@inline(__always)
func pad2(_ value: Int) -> String { value < 10 && value >= 0 ? "0\(value)" : "\(value)" }
