import Foundation

/// Reminder switches, stored under the Android keys (NotificationScheduler.kt).
public struct ReminderSettings: Equatable, Sendable {
    public var enabled = true
    public var twoDaysBefore = true
    public var oneDayBefore = true
    public var onFastingStart = true
    public var onParana = true

    public init() {}

    static let enabledKey = "notifications_enabled"
    static let twoDaysKey = "remind_two_days_before"
    static let oneDayKey = "remind_one_day_before"
    static let startKey = "remind_on_day"
    static let paranaKey = "remind_on_parana"

    public static func load(from store: KeyValueStore) -> ReminderSettings {
        var settings = ReminderSettings()
        settings.enabled = store.bool(forKey: enabledKey) ?? true
        settings.twoDaysBefore = store.bool(forKey: twoDaysKey) ?? true
        settings.oneDayBefore = store.bool(forKey: oneDayKey) ?? true
        settings.onFastingStart = store.bool(forKey: startKey) ?? true
        settings.onParana = store.bool(forKey: paranaKey) ?? true
        return settings
    }

    public func save(to store: KeyValueStore) {
        store.set(enabled, forKey: Self.enabledKey)
        store.set(twoDaysBefore, forKey: Self.twoDaysKey)
        store.set(oneDayBefore, forKey: Self.oneDayKey)
        store.set(onFastingStart, forKey: Self.startKey)
        store.set(onParana, forKey: Self.paranaKey)
    }

    /// How many of the four reminders are on ("{n}/4 active").
    public var activeCount: Int { [twoDaysBefore, oneDayBefore, onFastingStart, onParana].filter { $0 }.count }
}

public struct PlannedReminder: Equatable, Sendable, Identifiable {
    public enum Kind: Int, Sendable { case twoDaysBefore, oneDayBefore, onFastingStart, onParana }
    /// `ekadashiId * 10 + kind`, as on Android.
    public let id: Int
    public let ekadashiId: Int
    public let kind: Kind
    public let fireDate: Date
    public let title: String
    public let body: String
}

/// The four Ekadashi reminders (48 h and 24 h before fasting starts, at the
/// start and when Parana opens), soonest first within iOS's limit of 64
/// pending local notifications. The app plans again on every launch and
/// background refresh, so later reminders are added as earlier ones fire.
public enum ReminderPlanner {
    public static let iosPendingLimit = 64

    public static func plan(occurrences: [EkadashiOccurrence], settings: ReminderSettings, texts: (String) -> String,
                            now: Date, limit: Int = iosPendingLimit) -> [PlannedReminder] {
        guard settings.enabled else { return [] }
        var result: [PlannedReminder] = []
        for event in occurrences {
            guard let start = event.fastingStart, let parana = event.paranaStart else { continue }
            /// "06:00 AM" with the reminder language's own AM and PM.
            func clock(_ time: String) -> String {
                time.replacingOccurrences(of: " AM", with: " \(texts("panchang_am"))")
                    .replacingOccurrences(of: " PM", with: " \(texts("panchang_pm"))")
            }
            func add(_ kind: PlannedReminder.Kind, _ date: Date, _ title: String, _ body: String) {
                guard date > now else { return }
                result.append(PlannedReminder(id: event.id * 10 + kind.rawValue, ekadashiId: event.id, kind: kind,
                                              fireDate: date, title: title, body: body))
            }
            if settings.twoDaysBefore {
                add(.twoDaysBefore, start.addingTimeInterval(-48 * 3600), texts("notif_2day_title"), "\(event.name) \(texts("notif_2day_body"))")
            }
            if settings.oneDayBefore {
                add(.oneDayBefore, start.addingTimeInterval(-24 * 3600), texts("notif_1day_title"),
                    "\(event.name) \(texts("notif_1day_body")) \(clock(EkadashiTimeFormat.displayTime(event.fastingStartISO)))")
            }
            if settings.onFastingStart {
                add(.onFastingStart, start, texts("notif_start_title"),
                    "\(texts("notif_start_body")) \(event.name). \(texts("notif_start_suffix"))")
            }
            if settings.onParana {
                add(.onParana, parana, texts("notif_parana_title"), "\(event.name) \(texts("notif_parana_body"))")
            }
        }
        return Array(result.sorted { ($0.fireDate, $0.id) < ($1.fireDate, $1.id) }.prefix(limit))
    }
}
