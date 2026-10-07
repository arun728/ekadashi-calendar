import Foundation

public struct GoogleCalendarInfo: Equatable, Sendable, Identifiable {
    public let id: String
    public let summary: String
    public let primary: Bool
    public let selected: Bool

    public init(id: String, summary: String, primary: Bool = false, selected: Bool = true) {
        self.id = id
        self.summary = summary
        self.primary = primary
        self.selected = selected
    }
}

public struct GoogleEventTime: Codable, Equatable, Sendable {
    public var date: String?
    public var dateTime: String?
    public init(date: String? = nil, dateTime: String? = nil) {
        self.date = date
        self.dateTime = dateTime
    }
}

/// A Google Calendar API event (singleEvents=true expands recurrences).
public struct GoogleEvent: Codable, Equatable, Sendable {
    public var id: String?
    public var status: String?
    public var summary: String?
    public var description: String?
    public var calendarId: String
    public var calendarName: String?
    public var start: GoogleEventTime?
    public var end: GoogleEventTime?

    public init(id: String?, status: String? = nil, calendarId: String, calendarName: String? = nil, summary: String? = nil,
                description: String? = nil, start: GoogleEventTime?, end: GoogleEventTime?) {
        self.id = id
        self.status = status
        self.summary = summary
        self.description = description
        self.calendarId = calendarId
        self.calendarName = calendarName
        self.start = start
        self.end = end
    }

    enum CodingKeys: String, CodingKey { case id, status, summary, description, calendarId, calendarName, start, end }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        calendarId = try c.decodeIfPresent(String.self, forKey: .calendarId) ?? ""
        calendarName = try c.decodeIfPresent(String.self, forKey: .calendarName)
        start = try c.decodeIfPresent(GoogleEventTime.self, forKey: .start)
        end = try c.decodeIfPresent(GoogleEventTime.self, forKey: .end)
    }
}

public struct GoogleEventPage: Decodable, Sendable {
    public let items: [GoogleEvent]
    public let nextPageToken: String?

    enum CodingKeys: String, CodingKey { case items, nextPageToken }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = try c.decodeIfPresent([GoogleEvent].self, forKey: .items) ?? []
        nextPageToken = try c.decodeIfPresent(String.self, forKey: .nextPageToken)
    }
}

/// Google end dates are exclusive. Timed instants are stored in UTC and
/// shown in the phone's time zone (google_event_mapper.dart).
public enum GoogleEventMapper {
    public static func entry(from event: GoogleEvent, accountId: String, now: Date = Date()) throws -> CalendarEntry? {
        if event.status == "cancelled" { return nil }
        guard let id = event.id, !event.calendarId.isEmpty else {
            throw CoreError.invalidData("Google event has no scoped identity")
        }
        let allDay = event.start?.date != nil
        let start: Date
        var end: Date
        if allDay {
            guard let day = event.start?.date.flatMap(CivilDate.init(iso:)) else { throw CoreError.invalidData("Google event has no start") }
            start = day.utcMidnight
            end = event.end?.date.flatMap(CivilDate.init(iso:))?.utcMidnight ?? start
            // An all-day event without a later end covers its start day.
            if !(end > start) { end = day.adding(days: 1).utcMidnight }
        } else {
            // Without a start the event cannot be placed: abort the import,
            // which keeps the previously cached events.
            guard let value = event.start?.dateTime.flatMap(ISO8601.instant) else {
                throw CoreError.invalidData("Google event has no start")
            }
            start = value
            end = event.end?.dateTime.flatMap(ISO8601.instant) ?? start
            // Missing, equal or earlier ends become an instant at the start.
            if !(end > start) { end = start }
        }
        let identity = try JSONSerialization.data(withJSONObject: [accountId, event.calendarId, id])
        let encoded = identity.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        return CalendarEntry(id: "google_\(encoded)", title: event.summary ?? "", notes: event.description, start: start, end: end,
                             isAllDay: allDay, source: .google, googleEventId: id, calendarName: event.calendarName,
                             accountId: accountId, calendarId: event.calendarId, updatedAt: now)
    }
}

/// Google sign-in and the read-only Calendar API, as used by the app.
public protocol GoogleAuthGateway: AnyObject {
    func accountId() async -> String?
    func isSignedIn() async -> Bool
    /// False when the user cancels; throws for configuration or network failures.
    func signIn() async throws -> Bool
    func signOut() async
    /// A fresh Google ID token for the free-sync registry.
    func idToken() async throws -> String?
    func accountEmail() async -> String?
    func listCalendars() async throws -> [GoogleCalendarInfo]
    func fetchEvents(from: Date, to: Date, calendarIds: [String]) async throws -> [GoogleEvent]
}

/// Imports a whole window and reconciles deletions (google_calendar_service.dart).
public final class GoogleCalendarImporter {
    public let auth: GoogleAuthGateway
    public let store: CalendarEntryStore
    let timeZone: TimeZone
    private var revision = 0

    public init(auth: GoogleAuthGateway, store: CalendarEntryStore, timeZone: TimeZone = .current) {
        self.auth = auth
        self.store = store
        self.timeZone = timeZone
    }

    /// Imports events of [calendarIds] in [from, to); returns how many.
    public func syncImport(from: Date, to: Date, calendarIds: [String]) async throws -> Int {
        revision += 1
        let current = revision
        guard to > from else { throw CoreError.invalidArgument("Invalid import window") }
        let signedIn: Bool
        if await auth.isSignedIn() { signedIn = true } else { signedIn = try await auth.signIn() }
        guard signedIn, !calendarIds.isEmpty else { return 0 }
        guard let account = await auth.accountId() else { throw CoreError.invalidArgument("No Google account") }
        let raw = try await auth.fetchEvents(from: from, to: to, calendarIds: calendarIds)
        let entries = try raw.compactMap { try GoogleEventMapper.entry(from: $0, accountId: account) }
        let latestAccount = await auth.accountId()
        guard current == revision, latestAccount == account else {
            throw CoreError.invalidArgument("Google account or import changed during sync")
        }
        try store.replaceGoogleWindow(accountId: account, calendarIds: calendarIds, from: from, to: to, entries: entries)
        return entries.count
    }

    /// Signs out and removes only that account's imported events.
    public func signOut() async throws {
        revision += 1
        let account = await auth.accountId()
        await auth.signOut()
        if let account { try store.clearGoogle(accountId: account) }
    }
}
