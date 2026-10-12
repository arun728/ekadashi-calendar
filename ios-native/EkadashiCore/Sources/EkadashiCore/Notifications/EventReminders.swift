import Foundation

/// What an event reminder is for (docs/ROADMAP.md Phase 7): a Panchang
/// observance from the search catalogue (a festival or a monthly day such as
/// Amavasya), or every entry of one of the user's calendars.
public enum EventReminderTarget: Hashable, Sendable, Codable {
    case observance(String)
    case calendar(CalendarEntrySource)

    /// "observance:amavasya", "calendar:custom": the stored form and the reminder's id.
    public var key: String {
        switch self {
        case .observance(let key): return "observance:\(key)"
        case .calendar(let source): return "calendar:\(source.rawValue)"
        }
    }

    public init?(key: String) {
        let parts = key.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, !parts[1].isEmpty else { return nil }
        switch parts[0] {
        case "observance": self = .observance(parts[1])
        case "calendar":
            guard let source = CalendarEntrySource(rawValue: parts[1]) else { return nil }
            self = .calendar(source)
        default: return nil
        }
    }

    /// Panchang observances are calculated, so they are Premium like Key days.
    public var requiresPremium: Bool {
        if case .observance = self { return true }
        return false
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let target = EventReminderTarget(key: raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: raw))
        }
        self = target
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(key)
    }
}

/// One reminder: its event, how many days before (0 is the day itself) and
/// the time of day, on the event's own clock.
public struct EventReminder: Codable, Equatable, Identifiable, Sendable {
    public static let leadDays = [0, 1, 2, 3, 7]
    /// Devotees plan a day or two ahead.
    public static let defaultLeadDays = [1, 2]

    public var target: EventReminderTarget
    /// Distinct, ascending.
    public var daysBefore: [Int]
    public var hour: Int
    public var minute: Int

    public var id: String { target.key }

    public init(target: EventReminderTarget, daysBefore: [Int] = defaultLeadDays, hour: Int = 7, minute: Int = 0) {
        self.target = target
        self.daysBefore = Array(Set(daysBefore.filter { (0...30).contains($0) })).sorted()
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }
}

/// The reminders the user chose, stored as JSON next to the Ekadashi
/// reminders. `enabled` is the master Notifications switch they share.
public struct EventReminderSettings: Equatable, Sendable {
    public var enabled: Bool
    public var reminders: [EventReminder]

    public init(enabled: Bool = true, reminders: [EventReminder] = []) {
        self.enabled = enabled
        self.reminders = reminders
    }

    static let remindersKey = "event_reminders"

    public static func load(from store: KeyValueStore) -> EventReminderSettings {
        let reminders = store.string(forKey: remindersKey)
            .flatMap { try? JSONDecoder().decode([EventReminder].self, from: Data($0.utf8)) } ?? []
        return EventReminderSettings(enabled: store.bool(forKey: ReminderSettings.enabledKey) ?? true, reminders: reminders)
    }

    public func save(to store: KeyValueStore) {
        store.set(enabled, forKey: ReminderSettings.enabledKey)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(reminders), let text = String(data: data, encoding: .utf8) {
            store.set(text, forKey: Self.remindersKey)
        }
    }

    public func reminder(for target: EventReminderTarget) -> EventReminder? { reminders.first { $0.target == target } }

    /// Adds [reminder], or replaces the one for the same event.
    public mutating func upsert(_ reminder: EventReminder) {
        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[index] = reminder
        } else {
            reminders.append(reminder)
        }
    }

    public mutating func remove(_ target: EventReminderTarget) { reminders.removeAll { $0.target == target } }
}

public struct PlannedEventReminder: Equatable, Sendable, Identifiable {
    /// "event.observance:amavasya.2026-10-10.1": stable across plans.
    public let id: String
    public let target: EventReminderTarget
    public let eventDate: CivilDate
    public let fireDate: Date
    public let title: String
    public let body: String
    public let url: URL
}

/// Plans event reminders, soonest first within [limit]. Panchang reminders
/// need Premium; calendar reminders are free. The app plans again on every
/// launch and background refresh, as for the Ekadashi reminders.
public enum EventReminderPlanner {
    /// [observances] are calculated at the Panchang location and fire on its
    /// clock ([observanceZone]); entries fire on the device's ([entryZone]).
    public static func plan(settings: EventReminderSettings, observances: [DatedObservance], entries: [CalendarEntry],
                            observanceZone: TimeZone, entryZone: TimeZone, language: String, premium: Bool, now: Date,
                            limit: Int = ReminderPlanner.iosPendingLimit, catalog: SearchCatalog = .bundled,
                            localizer: Localizer = .shared) -> [PlannedEventReminder] {
        guard settings.enabled, limit > 0 else { return [] }
        var result: [PlannedEventReminder] = []
        var observanceDays: [String: [CivilDate]] = [:]
        for dated in observances where !catalog.excludedEngineIds.contains(dated.observance.id) {
            guard let entry = catalog.observance(engineId: dated.observance.id, name: dated.observance.name) else { continue }
            if observanceDays[entry.key]?.contains(dated.date) != true { observanceDays[entry.key, default: []].append(dated.date) }
        }
        for reminder in settings.reminders {
            if reminder.target.requiresPremium && !premium { continue }
            switch reminder.target {
            case .observance(let key):
                guard let entry = catalog.observances.first(where: { $0.key == key }) else { continue }
                let name = entry.name(language)
                for day in observanceDays[key] ?? [] {
                    result += planned(reminder, name: name, day: day, zone: observanceZone, url: AppRoute.panchangURL(day),
                                      language: language, now: now, localizer: localizer)
                }
            case .calendar(let source):
                for item in entries where item.source == source {
                    let day = item.allDayStart ?? CivilDate.today(in: entryZone, now: item.start)
                    result += planned(reminder, name: item.title, day: day, zone: entryZone, url: AppRoute.calendarURL(day),
                                      language: language, now: now, localizer: localizer, entryId: item.id)
                }
            }
        }
        return Array(result.sorted { ($0.fireDate, $0.id) < ($1.fireDate, $1.id) }.prefix(limit))
    }

    private static func planned(_ reminder: EventReminder, name: String, day: CivilDate, zone: TimeZone, url: URL,
                                language: String, now: Date, localizer: Localizer,
                                entryId: String? = nil) -> [PlannedEventReminder] {
        reminder.daysBefore.compactMap { lead in
            let fire = instant(day.adding(days: -lead), hour: reminder.hour, minute: reminder.minute, zone: zone)
            guard fire > now else { return nil }
            let id = ["event", reminder.target.key, entryId, day.iso, "\(lead)"].compactMap { $0 }.joined(separator: ".")
            return PlannedEventReminder(id: id, target: reminder.target, eventDate: day, fireDate: fire, title: name,
                                        body: body(name: name, day: day, lead: lead, language: language, localizer: localizer),
                                        url: url)
        }
    }

    /// "Amavasya is tomorrow (Sat, 10 Oct 2026)".
    public static func body(name: String, day: CivilDate, lead: Int, language: String,
                            localizer: Localizer = .shared) -> String {
        let key = lead == 0 ? "event_reminder_today" : lead == 1 ? "event_reminder_tomorrow" : "event_reminder_in_days"
        return localizer.translate(key, language: language,
                                   args: [name, PanchangFormat.date(day, language: language), "\(lead)"])
    }

    static func instant(_ day: CivilDate, hour: Int, minute: Int, zone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: hour, minute: minute))!
    }
}

/// The events a reminder can be set for, in the app language: festivals
/// (alphabetical), monthly days (catalogue order) and the user's calendars.
public struct EventReminderChoice: Equatable, Identifiable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        case festival, monthly
        case myCalendar = "my_calendar"

        public var titleKey: String { "event_reminder_group_\(rawValue)" }
    }

    public let target: EventReminderTarget
    public let title: String
    public let group: Kind

    public var id: String { target.key }
    public var requiresPremium: Bool { target.requiresPremium }

    public static func all(language: String, catalog: SearchCatalog = .bundled,
                           localizer: Localizer = .shared) -> [EventReminderChoice] {
        let locale = Localizer.locale(language)
        var festivals: [EventReminderChoice] = []
        var monthly: [EventReminderChoice] = []
        for entry in catalog.observances where !catalog.excludedEngineIds.contains(entry.engineId) {
            let choice = EventReminderChoice(target: .observance(entry.key), title: entry.name(language),
                                             group: entry.categories.contains(.festival) ? .festival : .monthly)
            if choice.group == .festival { festivals.append(choice) } else { monthly.append(choice) }
        }
        festivals.sort { $0.title.compare($1.title, locale: locale) == .orderedAscending }
        let calendars = [CalendarEntrySource.custom, .google].map {
            EventReminderChoice(target: .calendar($0), title: localizer.translate("event_reminder_all_\($0.rawValue)", language: language),
                                group: .myCalendar)
        }
        return festivals + monthly + calendars
    }

    /// The title of a stored reminder's event.
    public static func title(_ target: EventReminderTarget, language: String, catalog: SearchCatalog = .bundled,
                             localizer: Localizer = .shared) -> String {
        switch target {
        case .observance(let key): return catalog.observances.first { $0.key == key }?.name(language) ?? key
        case .calendar(let source): return localizer.translate("event_reminder_all_\(source.rawValue)", language: language)
        }
    }
}

/// A local notification to schedule: Ekadashi and event reminders merged,
/// soonest first, within iOS's limit of 64 pending notifications.
public struct PendingNotification: Equatable, Sendable, Identifiable {
    public let id: String
    public let fireDate: Date
    public let title: String
    public let body: String
    public let url: URL

    public static func merge(ekadashi: [PlannedReminder], events: [PlannedEventReminder],
                             limit: Int = ReminderPlanner.iosPendingLimit) -> [PendingNotification] {
        let fasts = ekadashi.map {
            PendingNotification(id: "\($0.id)", fireDate: $0.fireDate, title: $0.title, body: $0.body,
                                url: $0.kind == .onParana ? AppRoute.paranaURL : AppRoute.todayURL)
        }
        let others = events.map { PendingNotification(id: $0.id, fireDate: $0.fireDate, title: $0.title, body: $0.body, url: $0.url) }
        return Array((fasts + others).sorted { ($0.fireDate, $0.id) < ($1.fireDate, $1.id) }.prefix(max(limit, 0)))
    }
}
