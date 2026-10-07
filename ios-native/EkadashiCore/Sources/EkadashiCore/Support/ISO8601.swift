import Foundation

/// Parses and writes the ISO 8601 forms used by the calendar data, the
/// Google Calendar API and the fixtures, independent of the device locale.
public enum ISO8601 {
    /// `yyyy-MM-ddTHH:mm[:ss[.fraction]][Z|±HH:MM]`. Without an offset the
    /// time is read as UTC.
    public static func instant(_ text: String) -> Date? {
        let s = Array(text.trimmingCharacters(in: .whitespaces).utf8)
        guard s.count >= 16, let date = CivilDate(iso: String(decoding: s[0..<10], as: UTF8.self)),
              s[10] == UInt8(ascii: "T") || s[10] == UInt8(ascii: " ") else { return nil }
        func number(_ range: Range<Int>) -> Int? {
            guard range.upperBound <= s.count else { return nil }
            var value = 0
            for c in s[range] {
                guard c >= 48, c <= 57 else { return nil }
                value = value * 10 + Int(c - 48)
            }
            return value
        }
        guard let hour = number(11..<13), s[13] == UInt8(ascii: ":"), let minute = number(14..<16) else { return nil }
        var i = 16
        var second = 0.0
        if i < s.count, s[i] == UInt8(ascii: ":") {
            guard let whole = number(i + 1..<i + 3) else { return nil }
            second = Double(whole)
            i += 3
            if i < s.count, s[i] == UInt8(ascii: ".") || s[i] == UInt8(ascii: ",") {
                var j = i + 1
                var scale = 0.1
                while j < s.count, s[j] >= 48, s[j] <= 57 {
                    second += Double(s[j] - 48) * scale
                    scale /= 10
                    j += 1
                }
                i = j
            }
        }
        var offset = 0
        if i < s.count {
            if s[i] == UInt8(ascii: "Z") || s[i] == UInt8(ascii: "z") {
                i += 1
            } else if s[i] == UInt8(ascii: "+") || s[i] == UInt8(ascii: "-") {
                let sign = s[i] == UInt8(ascii: "-") ? -1 : 1
                guard let h = number(i + 1..<i + 3) else { return nil }
                var m = 0
                var next = i + 3
                if next < s.count, s[next] == UInt8(ascii: ":") { next += 1 }
                if next + 2 <= s.count, let mm = number(next..<next + 2) { m = mm; next += 2 }
                offset = sign * (h * 3600 + m * 60)
                i = next
            }
        }
        guard i == s.count else { return nil }
        let seconds = Double(date.daysSinceEpoch) * 86400 + Double(hour * 3600 + minute * 60) + second - Double(offset)
        return Date(timeIntervalSince1970: seconds)
    }

    /// UTC with milliseconds, as Dart's `toUtc().toIso8601String()`.
    public static func string(_ date: Date) -> String {
        let millis = Int64((date.timeIntervalSince1970 * 1000).rounded(.down))
        let days = Int(floor(Double(millis) / 86_400_000))
        let rest = millis - Int64(days) * 86_400_000
        let civil = CivilDate(daysSinceEpoch: days)
        let h = rest / 3_600_000, m = rest / 60_000 % 60, s = rest / 1000 % 60, ms = rest % 1000
        return "\(civil.iso)T\(pad2(Int(h))):\(pad2(Int(m))):\(pad2(Int(s))).\(String(format: "%03d", Int(ms)))Z"
    }

    /// The wall-clock hour and minute written in the string, ignoring its offset.
    static func wallClockTime(_ text: String) -> (hour: Int, minute: Int)? {
        guard let t = text.firstIndex(of: "T") else { return nil }
        let time = text[text.index(after: t)...]
        let parts = time.split(separator: ":")
        guard parts.count >= 2, let hour = Int(parts[0]), let minute = Int(parts[1].prefix(2)) else { return nil }
        return (hour, minute)
    }
}
