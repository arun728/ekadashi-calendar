import Foundation

public enum WidgetState: String, Codable, Sendable {
    case beforeEkadashi = "BEFORE_EKADASHI"
    case fastingActive = "FASTING_ACTIVE"
    case paranaAvailable = "PARANA_AVAILABLE"
    case paranaCompleted = "PARANA_COMPLETED"
    case fallback = "FALLBACK"
    case noEkadashiToday = "NO_EKADASHI_TODAY"
}

public struct WidgetItem: Codable, Equatable, Sendable, Identifiable {
    public let id: Int
    public let occurrenceUid: String
    public let year: Int
    public let name: String
    public let date: String
    public let localizedDate: String
    public let paksha: String
    public let month: String
    public let fastingStart: Date
    public let paranaStart: Date
    public let paranaEnd: Date
    public let countdownTarget: Date
    public let description: String

    public func state(at now: Date) -> WidgetState {
        if now < fastingStart { return .beforeEkadashi }
        if now < paranaStart { return .fastingActive }
        if now < paranaEnd { return .paranaAvailable }
        return .paranaCompleted
    }

    /// The instant the countdown points at in [state].
    public func target(for state: WidgetState) -> Date {
        switch state {
        case .fastingActive: return paranaStart
        case .paranaAvailable: return paranaEnd
        default: return fastingStart
        }
    }
}

public struct WidgetToday: Codable, Equatable, Sendable {
    public let isEkadashi: Bool
    public let name: String
    public let state: WidgetState
    public let fastingStart: Date?
    public let paranaStart: Date?
    public let paranaEnd: Date?
}

/// The one payload all three widgets read from the App Group
/// (widget_sync_manager.dart, schema 2).
public struct WidgetSnapshot: Codable, Equatable, Sendable {
    public var schemaVersion = 2
    public let generatedAt: Date
    public let locale: String
    /// IANA time zone of the schedule shown.
    public let timeZone: String
    public let locationName: String
    public let tradition: String
    public let calculationVersion: String
    public let currentState: WidgetState
    public let nextEkadashi: WidgetItem?
    public let today: WidgetToday
    public let upcoming: [WidgetItem]
    public let strings: [String: String]

    public static let appGroupKey = "widget_snapshot_v2"

    static let stringKeys: [String: String] = [
        "title": "app_title", "next_ekadashi": "next_ekadashi", "fasting_active": "fasting_active",
        "parana_available": "parana_available", "parana_completed": "parana_completed",
        "open_app_to_refresh": "open_app_to_refresh", "fasting_starts": "start_fasting", "parana_window": "break_fasting",
        "upcoming_ekadashis": "upcoming_ekadashis", "today": "today", "tomorrow": "tomorrow", "days_remaining": "in_days",
        "view_details": "view_details", "today_title": "widget_today_title", "parana_in": "widget_parana_in",
        "parana_ends": "widget_parana_ends", "starts_in": "widget_starts_in", "notice": "widget_notice", "now": "widget_now",
        "day_unit": "widget_day_unit", "hour_unit": "widget_hour_unit", "minute_unit": "widget_minute_unit",
        "no_ekadashi": "no_ekadashi", "today_is_ekadashi": "widget_today_is_ekadashi", "days_to_go": "widget_days_to_go",
        "fast_done": "widget_fast_done", "am": "panchang_am", "pm": "panchang_pm",
    ]

    public static func state(of event: EkadashiOccurrence, at now: Date) -> WidgetState {
        guard let start = event.fastingStart, let parana = event.paranaStart, let end = event.paranaEnd else { return .fallback }
        if now < start { return .beforeEkadashi }
        if now < parana { return .fastingActive }
        if now < end { return .paranaAvailable }
        return .paranaCompleted
    }

    public static func build(occurrences: [EkadashiOccurrence], timezone: String, locationName: String, language: String,
                             now: Date, tradition: String = "General", localizer: Localizer = .shared) -> WidgetSnapshot {
        let zoneId = AppTimezone.iana(timezone)
        let zone = TzDatabase.shared.location(zoneId) ?? AppTimezone.ist.location
        let localToday = zone.wallClock(now).date
        let events = occurrences.sorted { $0.date < $1.date }
        let future = events.filter { $0.paranaEnd.map { now < $0 } ?? false }
        let todayEvent = events.first { $0.date == localToday }
        let formatter = DateFormatter()
        formatter.locale = Localizer.locale(language)
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "d MMM yyyy"
        func item(_ e: EkadashiOccurrence) -> WidgetItem {
            let start = e.fastingStart!, parana = e.paranaStart!, end = e.paranaEnd!
            let state = Self.state(of: e, at: now)
            let target = state == .fastingActive ? parana : state == .paranaAvailable ? end : start
            return WidgetItem(id: e.id, occurrenceUid: e.occurrenceUid, year: e.date.year, name: e.name, date: e.date.iso,
                              localizedDate: formatter.string(from: e.date.utcMidnight), paksha: e.paksha, month: e.month,
                              fastingStart: start, paranaStart: parana, paranaEnd: end, countdownTarget: target,
                              description: e.description)
        }
        var strings: [String: String] = [:]
        for (key, value) in stringKeys { strings["widget.\(key)"] = localizer.translate(value, language: language) }
        let next = future.first
        return WidgetSnapshot(
            generatedAt: now, locale: language, timeZone: zoneId, locationName: locationName, tradition: tradition,
            calculationVersion: "bundled-v2", currentState: next.map { state(of: $0, at: now) } ?? .fallback,
            nextEkadashi: next.map(item),
            today: WidgetToday(isEkadashi: todayEvent != nil, name: todayEvent?.name ?? "",
                               state: todayEvent.map { state(of: $0, at: now) } ?? .noEkadashiToday,
                               fastingStart: todayEvent?.fastingStart, paranaStart: todayEvent?.paranaStart,
                               paranaEnd: todayEvent?.paranaEnd),
            upcoming: future.dropFirst().map(item), strings: strings)
    }

    /// The Ekadashi a widget shows now: the next one whose Parana has not
    /// ended, re-evaluated at render time (the app may not have run since).
    public func activeItem(at now: Date) -> WidgetItem? {
        ([nextEkadashi].compactMap { $0 } + upcoming).first { now < $0.paranaEnd }
    }

    public func upcoming(after now: Date) -> [WidgetItem] {
        let all = [nextEkadashi].compactMap { $0 } + upcoming
        return Array(all.filter { now < $0.paranaEnd }.dropFirst())
    }

    /// When the widget timeline must refresh: every state change ahead.
    public func refreshDates(after now: Date) -> [Date] {
        ([nextEkadashi].compactMap { $0 } + upcoming)
            .flatMap { [$0.fastingStart, $0.paranaStart, $0.paranaEnd] }
            .filter { $0 > now }
            .sorted()
    }

    public func string(_ key: String, _ fallback: String) -> String { strings["widget.\(key)"] ?? fallback }

    /// "2 d 3 h", "3 h 2 min", "0 min" or "Now", as the Android widgets.
    public static func remaining(until target: Date?, now: Date, strings: [String: String]) -> String {
        guard let target else { return "--" }
        let seconds = Int(target.timeIntervalSince(now).rounded(.towardZero))
        if target < now { return strings["widget.now"] ?? "Now" }
        let days = seconds / 86400, hours = seconds / 3600 % 24, minutes = seconds / 60 % 60
        let d = strings["widget.day_unit"] ?? "d", h = strings["widget.hour_unit"] ?? "h", m = strings["widget.minute_unit"] ?? "min"
        if days > 0 { return "\(days) \(d) \(hours) \(h)" }
        if hours > 0 { return "\(hours) \(h) \(minutes) \(m)" }
        return "\(minutes) \(m)"
    }

    public func remaining(until target: Date?, now: Date) -> String { Self.remaining(until: target, now: now, strings: strings) }
}

/// What the Ekadashi widget leads with (docs/ROADMAP.md Phase 6).
public enum WidgetHeadline: Equatable, Sendable {
    /// Today is an Ekadashi (fasting or Parana): the fast's progress, 0...1.
    case today(WidgetItem, progress: Double)
    /// The next Ekadashi and the calendar days until it.
    case next(WidgetItem, days: Int)
}

extension WidgetItem {
    /// How much of the fast (fasting start to Parana start) has passed.
    public func fastProgress(at now: Date) -> Double {
        let total = paranaStart.timeIntervalSince(fastingStart)
        guard total > 0 else { return now >= paranaStart ? 1 : 0 }
        return min(1, max(0, now.timeIntervalSince(fastingStart) / total))
    }
}

extension WidgetSnapshot {
    public func headline(at now: Date) -> WidgetHeadline? {
        guard let item = activeItem(at: now) else { return nil }
        switch item.state(at: now) {
        case .fastingActive, .paranaAvailable:
            return .today(item, progress: item.fastProgress(at: now))
        default:
            let today = TzDatabase.shared.location(timeZone)?.wallClock(now).date ?? CivilDate(utc: now)
            let days = CivilDate(iso: item.date).map { today.days(until: $0) } ?? 0
            return .next(item, days: max(0, days))
        }
    }

    /// "Today", "Tomorrow" or "14 days to go".
    public func daysToGo(_ days: Int) -> String {
        if days <= 0 { return string("today", "Today") }
        if days == 1 { return string("tomorrow", "Tomorrow") }
        return string("days_to_go", "{value0} days to go").replacingOccurrences(of: "{value0}", with: "\(days)")
    }
}
