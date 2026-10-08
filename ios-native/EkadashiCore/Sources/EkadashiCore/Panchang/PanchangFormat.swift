import Foundation

/// Panchang times and dates in the app language (docs/ROADMAP.md Phase 2).
/// Times are the location's wall clock; the time zone is shown once per
/// screen rather than after every time.
public enum PanchangFormat {
    /// "6:24 PM", "6:24 PM (next day)", "—" when unavailable.
    public static func time(_ instant: Date?, city: PanchangCity, date: CivilDate, language: String) -> String {
        guard let instant else { return "—" }
        let local = city.wallClock(instant)
        let hour = local.hour % 12 == 0 ? 12 : local.hour % 12
        let minute = local.minute < 10 ? "0\(local.minute)" : "\(local.minute)"
        let marker = Localizer.shared.translate(local.hour < 12 ? "panchang_am" : "panchang_pm", language: language)
        var text = "\(hour):\(minute) \(marker)"
        let delta = date.days(until: local.date)
        if delta == 1 {
            text += " " + Localizer.shared.translate("panchang_next_day_marker", language: language)
        } else if delta == -1 {
            text += " " + Localizer.shared.translate("panchang_previous_day_marker", language: language)
        } else if delta != 0 {
            text += " (\(delta > 0 ? "+" : "")\(delta))"
        }
        return text
    }

    /// "6:24 PM – 7:55 PM".
    public static func range(_ start: Date?, _ end: Date?, city: PanchangCity, date: CivilDate, language: String) -> String {
        "\(time(start, city: city, date: date, language: language)) – \(time(end, city: city, date: date, language: language))"
    }

    /// "Thu, 8 Oct 2026" in the language's script and month names.
    public static func date(_ date: CivilDate, language: String) -> String {
        format(date, "EEE, d MMM yyyy", language)
    }

    /// "October 2026".
    public static func monthTitle(_ date: CivilDate, language: String) -> String {
        format(date, "LLLL yyyy", language)
    }

    /// Short weekday ("Thu") for date badges.
    public static func weekday(_ date: CivilDate, language: String) -> String {
        format(date, "EEE", language)
    }

    static func format(_ date: CivilDate, _ pattern: String, _ language: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Localizer.locale(language)
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = pattern
        return formatter.string(from: date.utcMidnight)
    }
}
