import Foundation

/// One published Ekadashi in one schedule and language (`EkadashiDate`).
public struct EkadashiOccurrence: Identifiable, Hashable, Sendable {
    /// The permanent notification id (`notification_id`).
    public let id: Int
    /// The durable cross-year identity, e.g. `ekadashi:2026:01`.
    public let occurrenceUid: String
    public let legacyId: Int
    public let contentId: String
    public let usesContentFallback: Bool
    public let name: String
    public let date: CivilDate
    public let fastStartTime: String
    public let fastBreakTime: String
    public let description: String
    public let story: String
    public let fastingRules: String
    public let benefits: String
    public let paksha: String
    public let month: String
    public let fastingStartISO: String
    public let paranaStartISO: String
    public let paranaEndISO: String
    public let contextExpiresAtISO: String

    public init(id: Int, occurrenceUid: String? = nil, legacyId: Int? = nil, contentId: String = "",
                usesContentFallback: Bool = false, name: String, date: CivilDate, fastStartTime: String = "",
                fastBreakTime: String = "", description: String = "", story: String = "", fastingRules: String = "",
                benefits: String = "", paksha: String = "", month: String = "", fastingStartISO: String = "",
                paranaStartISO: String = "", paranaEndISO: String = "", contextExpiresAtISO: String = "") {
        self.id = id
        self.occurrenceUid = occurrenceUid ?? "ekadashi:\(date.year):\(pad2(id))"
        self.legacyId = legacyId ?? id
        self.contentId = contentId
        self.usesContentFallback = usesContentFallback
        self.name = name
        self.date = date
        self.fastStartTime = fastStartTime
        self.fastBreakTime = fastBreakTime
        self.description = description
        self.story = story
        self.fastingRules = fastingRules
        self.benefits = benefits
        self.paksha = paksha
        self.month = month
        self.fastingStartISO = fastingStartISO
        self.paranaStartISO = paranaStartISO
        self.paranaEndISO = paranaEndISO
        self.contextExpiresAtISO = contextExpiresAtISO
    }

    public var fastingStart: Date? { ISO8601.instant(fastingStartISO) }
    public var paranaStart: Date? { ISO8601.instant(paranaStartISO) }
    public var paranaEnd: Date? { ISO8601.instant(paranaEndISO) }
    /// The daily context expires at local midnight for after-only results. This is
    /// deliberately separate from an unknown religious Parana end.
    public var activeUntil: Date? { paranaEnd ?? ISO8601.instant(contextExpiresAtISO) }
}

public enum EkadashiTimeFormat {
    /// `hh:mm AM` read from the stored wall clock, without converting zones:
    /// each schedule already holds its own local times.
    public static func displayTime(_ iso: String) -> String {
        guard !iso.isEmpty, let time = ISO8601.wallClockTime(iso) else { return "" }
        let period = time.hour >= 12 ? "PM" : "AM"
        let hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour)
        return "\(pad2(hour)):\(pad2(time.minute)) \(period)"
    }

    public static func window(_ startISO: String, _ endISO: String, language: String = "en") -> String {
        guard let startDate = ISO8601.instant(startISO) else { return "" }
        let endDate = ISO8601.instant(endISO)
        if let endDate, endDate <= startDate { return "" }
        let seconds = startISO.contains(".") || endISO.contains(".")
            || startISO.dropFirst(17).prefix(2) != "00" || (!endISO.isEmpty && endISO.dropFirst(17).prefix(2) != "00")
        // Less than a second needs milliseconds; otherwise second boundaries
        // are rounded into the allowed interval, never outward into Hari Vasara.
        let milliseconds = endDate.map {
            floor($0.timeIntervalSince1970) <= ceil(startDate.timeIntervalSince1970)
        } ?? false
        let start = boundaryTime(startISO, up: true, seconds: seconds, milliseconds: milliseconds)
        guard let endDate else {
            return Localizer.shared.translate("panchang_after", language: language, args: [start])
        }
        guard endDate > startDate else { return "" }
        return "\(start) - \(boundaryTime(endISO, up: false, seconds: seconds, milliseconds: milliseconds))"
    }

    private static func boundaryTime(_ iso: String, up: Bool, seconds: Bool, milliseconds: Bool) -> String {
        guard let t = iso.firstIndex(of: "T") else { return "" }
        let time = iso[iso.index(after: t)...]
        let stop = time.firstIndex { $0 == "+" || $0 == "-" || $0 == "Z" } ?? iso.endIndex
        guard let wall = ISO8601.instant(String(iso[..<stop])) else { return "" }
        let unit = milliseconds ? 1.0 : seconds ? 1000.0 : 60_000.0
        let ticks = Int64((wall.timeIntervalSince1970 * 1000 / unit).rounded(up ? .up : .down) * unit)
        let day = (ticks % 86_400_000 + 86_400_000) % 86_400_000
        let hour = Int(day / 3_600_000), minute = Int(day / 60_000 % 60), second = Int(day / 1000 % 60)
        let shown = hour % 12 == 0 ? 12 : hour % 12
        let suffix = milliseconds ? ".\(String(format: "%03d", Int(day % 1000)))" : ""
        return "\(pad2(shown)):\(pad2(minute))\(seconds ? ":\(pad2(second))\(suffix)" : "") \(hour < 12 ? "AM" : "PM")"
    }
}

/// Which card the Today tab opens (`_scrollToNextEkadashi`).
public enum HomeSelection {
    public static func daysUntil(_ date: CivilDate, now: Date, zone: TzLocation) -> Int {
        zone.wallClock(now).date.days(until: date)
    }

    /// The next Ekadashi from today; a passed one while its Parana is still
    /// open when [includeParana]; the last one after every fast.
    public static func index(of events: [EkadashiOccurrence], now: Date, zone: TzLocation, includeParana: Bool) -> Int {
        guard !events.isEmpty else { return 0 }
        let today = zone.wallClock(now).date
        for (i, event) in events.enumerated() {
            let days = today.days(until: event.date)
            if days >= 0 { return i }
            if includeParana, let end = event.activeUntil, now < end { return i }
        }
        return events.count - 1
    }
}
