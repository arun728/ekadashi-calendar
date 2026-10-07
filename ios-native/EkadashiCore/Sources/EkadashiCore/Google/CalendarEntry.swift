import Foundation

public enum CalendarEntrySource: String, Codable, Sendable { case custom, google }

/// Filter for the Calendar tab. The default is Ekadashi.
public enum CalendarFilter: String, CaseIterable, Sendable { case all, ekadashi, google, custom }

/// A custom or imported calendar entry (never an official Ekadashi row).
/// Timed entries hold UTC instants; all-day entries hold the UTC midnight of
/// their civil dates and are read as dates in any time zone.
public struct CalendarEntry: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var notes: String?
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var source: CalendarEntrySource
    public var googleEventId: String?
    public var calendarName: String?
    public var accountId: String?
    public var calendarId: String?
    public var updatedAt: Date

    public init(id: String, title: String, notes: String? = nil, start: Date, end: Date, isAllDay: Bool = false,
                source: CalendarEntrySource, googleEventId: String? = nil, calendarName: String? = nil,
                accountId: String? = nil, calendarId: String? = nil, updatedAt: Date) {
        self.id = id
        self.title = title
        self.notes = notes
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.source = source
        self.googleEventId = googleEventId
        self.calendarName = calendarName
        self.accountId = accountId
        self.calendarId = calendarId
        self.updatedAt = updatedAt
    }

    public var allDayStart: CivilDate? { isAllDay ? CivilDate(utc: start) : nil }
    /// Exclusive, as Google's.
    public var allDayEnd: CivilDate? { isAllDay ? CivilDate(utc: end) : nil }

    /// The entry's start and end as instants in [timeZone] (all-day entries at local midnight).
    public func interval(in timeZone: TimeZone) -> (Date, Date) {
        guard isAllDay else { return (start, end) }
        return (Self.midnight(CivilDate(utc: start), timeZone), Self.midnight(CivilDate(utc: end), timeZone))
    }

    public func occurs(on day: CivilDate, in timeZone: TimeZone) -> Bool {
        if let first = allDayStart, let last = allDayEnd { return first <= day && day < last }
        let from = Self.midnight(day, timeZone), to = Self.midnight(day.adding(days: 1), timeZone)
        return start < to && end > from
    }

    static func midnight(_ date: CivilDate, _ timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day))!
    }
}

/// Local storage of custom and imported entries.
public protocol CalendarEntryStore: AnyObject {
    func all() throws -> [CalendarEntry]
    func upsert(_ entry: CalendarEntry) throws
    func delete(id: String) throws
    func clearGoogle(accountId: String?) throws
    /// Atomically replaces one account's events in [calendarIds] that overlap
    /// [from, to) with [entries]: events deleted on Google disappear and a
    /// failed import leaves the cache untouched.
    func replaceGoogleWindow(accountId: String, calendarIds: [String], from: Date, to: Date, entries: [CalendarEntry]) throws
}

/// Shared rules for both stores.
public class BaseCalendarEntryStore {
    let timeZone: TimeZone
    var entries: [String: CalendarEntry] = [:]
    let lock = NSLock()

    init(timeZone: TimeZone) { self.timeZone = timeZone }

    func commit(_ next: [String: CalendarEntry]) throws { entries = next }

    public func all() throws -> [CalendarEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entries.values.sorted { ($0.start, $0.id) < ($1.start, $1.id) }
    }

    public func upsert(_ entry: CalendarEntry) throws {
        try mutate { $0[entry.id] = entry }
    }

    public func delete(id: String) throws {
        try mutate { $0.removeValue(forKey: id) }
    }

    public func clearGoogle(accountId: String?) throws {
        try mutate { all in
            all = all.filter { $0.value.source != .google || (accountId != nil && $0.value.accountId != accountId) }
        }
    }

    public func replaceGoogleWindow(accountId: String, calendarIds: [String], from: Date, to: Date, entries: [CalendarEntry]) throws {
        for entry in entries where entry.source != .google || entry.accountId != accountId
            || !calendarIds.contains(entry.calendarId ?? "") {
            throw CoreError.invalidArgument("Import scope does not match event")
        }
        try mutate { all in
            for (id, entry) in all where entry.source == .google && entry.accountId == accountId
                && calendarIds.contains(entry.calendarId ?? "") {
                let (start, end) = entry.interval(in: timeZone)
                if start < to && end > from { all.removeValue(forKey: id) }
            }
            for entry in entries { all[entry.id] = entry }
        }
    }

    func mutate(_ change: (inout [String: CalendarEntry]) -> Void) throws {
        lock.lock()
        defer { lock.unlock() }
        var next = entries
        change(&next)
        try commit(next)
    }
}

public final class InMemoryCalendarEntryStore: BaseCalendarEntryStore, CalendarEntryStore {
    public override init(timeZone: TimeZone = .current) { super.init(timeZone: timeZone) }
}

/// A JSON file written atomically (temporary file and rename).
public final class FileCalendarEntryStore: BaseCalendarEntryStore, CalendarEntryStore {
    let url: URL

    public init(url: URL, timeZone: TimeZone = .current) throws {
        self.url = url
        super.init(timeZone: timeZone)
        if FileManager.default.fileExists(atPath: url.path) {
            let list = try JSONDecoder.iso.decode([CalendarEntry].self, from: Data(contentsOf: url))
            entries = Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { _, b in b })
        }
    }

    override func commit(_ next: [String: CalendarEntry]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder.iso.encode(next.values.sorted { $0.id < $1.id })
        try data.write(to: url, options: .atomic)
        entries = next
    }
}

extension JSONEncoder {
    static var iso: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ISO8601.string(date))
        }
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var iso: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            guard let date = ISO8601.instant(text) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: text))
            }
            return date
        }
        return decoder
    }
}
