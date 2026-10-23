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

/// The payload both iOS widgets read from the App Group
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
    /// Optional for compatibility with snapshots written before the redesign.
    public var todayEkadashi: WidgetItem? = nil

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
        "remaining": "widget_remaining",
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
        let timed = events.filter { $0.fastingStart != nil && $0.paranaStart != nil && $0.paranaEnd != nil }
        let future = timed.filter { $0.paranaEnd.map { now < $0 } ?? false }
        let todayEvent = timed.first { $0.date == localToday }
        let formatter = DateFormatter()
        formatter.locale = Localizer.locale(language)
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "EEE, d MMM yyyy"
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
        var snapshot = WidgetSnapshot(
            generatedAt: now, locale: language, timeZone: zoneId, locationName: locationName, tradition: tradition,
            calculationVersion: "bundled-v2", currentState: next.map { state(of: $0, at: now) } ?? .fallback,
            nextEkadashi: next.map(item),
            today: WidgetToday(isEkadashi: todayEvent != nil, name: todayEvent?.name ?? "",
                               state: todayEvent.map { state(of: $0, at: now) } ?? .noEkadashiToday,
                               fastingStart: todayEvent?.fastingStart, paranaStart: todayEvent?.paranaStart,
                               paranaEnd: todayEvent?.paranaEnd),
            upcoming: future.dropFirst().map(item), strings: strings)
        snapshot.todayEkadashi = todayEvent.map(item)
        return snapshot
    }

    /// The Ekadashi a widget shows now: the next one whose Parana has not
    /// ended, re-evaluated at render time (the app may not have run since).
    public func activeItem(at now: Date) -> WidgetItem? {
        ([nextEkadashi].compactMap { $0 } + upcoming).first { now < $0.paranaEnd }
    }

    /// The exclusive upcoming widget: the first five not-yet-started occurrences,
    /// including this fasting date before sunrise. Reevaluate cached data at render time.
    public func upcoming(after now: Date) -> [WidgetItem] {
        var seen = Set<String>()
        let items = ([todayEkadashi, nextEkadashi].compactMap { $0 } + upcoming)
            .sorted { $0.date < $1.date }
            .filter { item in
                guard item.fastingStart > now else { return false }
                return seen.insert(item.occurrenceUid).inserted
            }
        return Array(items.prefix(5))
    }

    /// When the widget timeline must refresh: every state change ahead.
    public func refreshDates(after now: Date) -> [Date] {
        let items = [todayEkadashi, nextEkadashi].compactMap { $0 } + upcoming
        var dates = items.flatMap { [$0.fastingStart, $0.fastingStart.addingTimeInterval(-36000), $0.paranaStart, $0.paranaEnd] }
        // Text and arc change together at each percentage boundary.
        for item in items where item.paranaStart > item.fastingStart {
            let interval = item.paranaStart.timeIntervalSince(item.fastingStart)
            dates += (1...100).map { item.fastingStart.addingTimeInterval(interval * Double($0) / 100) }
        }
        // Civil-date selection also changes at midnight in the schedule's zone.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone) ?? TimeZone(secondsFromGMT: 0)!
        if let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) { dates.append(midnight) }
        return Set(dates.filter { $0 > now }).sorted()
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
    /// An ongoing occurrence, including overnight and Parana: completed fraction.
    /// The legacy case name is retained for source compatibility.
    case today(WidgetItem, progress: Double)
    /// The next Ekadashi; zero civil days means a pre-start seconds countdown.
    case next(WidgetItem, days: Int)
}

extension WidgetItem {
    public var detailsURL: URL { AppRoute.ekadashiURL(occurrenceUid) }

    public func remainingFraction(at now: Date) -> Double { 1 - fastProgress(at: now) }

    public func remainingPercent(at now: Date) -> Int {
        // Keep 1% until the actual boundary; floating-point noise must not add 1%.
        Int(ceil(max(0, min(100, remainingFraction(at: now) * 100)) - 0.000000001))
    }
    /// How much of the fast (fasting start to Parana start) has passed.
    public func fastProgress(at now: Date) -> Double {
        let total = paranaStart.timeIntervalSince(fastingStart)
        guard total > 0 else { return now >= paranaStart ? 1 : 0 }
        return min(1, max(0, now.timeIntervalSince(fastingStart) / total))
    }
}

extension WidgetSnapshot {
    public func headline(at now: Date, selection: WidgetSelection = .automatic) -> WidgetHeadline? {
        let today = TzDatabase.shared.location(timeZone)?.wallClock(now).date ?? CivilDate(utc: now)
        let items = ([todayEkadashi, nextEkadashi].compactMap { $0 } + upcoming).sorted { $0.date < $1.date }
        let unique = items.reduce(into: [WidgetItem]()) { result, item in
            if !result.contains(where: { $0.occurrenceUid == item.occurrenceUid }) { result.append(item) }
        }
        if selection != .next, let item = unique.first(where: { $0.fastingStart <= now && now < $0.paranaEnd }) {
            return .today(item, progress: item.fastProgress(at: now))
        }
        guard selection != .today, let item = unique.first(where: { $0.fastingStart > now }),
              let day = CivilDate(iso: item.date) else { return nil }
        return .next(item, days: today.days(until: day))
    }

    /// "Today", "Tomorrow" or "14 days to go".
    public func daysToGo(_ days: Int) -> String {
        if days <= 0 { return string("today", "Today") }
        if days == 1 { return string("tomorrow", "Tomorrow") }
        return string("days_to_go", "{value0} days to go").replacingOccurrences(of: "{value0}", with: "\(days)")
    }
}

public extension WidgetHeadline {
    var item: WidgetItem {
        switch self {
        case .today(let item, _), .next(let item, _): return item
        }
    }
    var isToday: Bool {
        if case .today = self { return true }
        return false
    }
}
