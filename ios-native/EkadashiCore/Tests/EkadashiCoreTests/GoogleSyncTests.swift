import Foundation
import XCTest
@testable import EkadashiCore

/// Ports google_event_mapper_test.dart, google_reconciliation_test.dart,
/// free_sync_registry_test.dart and the Calendar screen's free/premium sync
/// rules (PR #13) to the iOS core.
final class GoogleEventMapperTests: XCTestCase {
    private func timed(_ start: String, _ end: String?) -> GoogleEvent {
        GoogleEvent(id: "e1", calendarId: "c", summary: "Reminder", start: .init(dateTime: start),
                    end: end.map { .init(dateTime: $0) })
    }

    func testZeroLengthEventIsImported() throws {
        let entry = try XCTUnwrap(GoogleEventMapper.entry(from: timed("2026-10-05T10:00:00+05:30", "2026-10-05T10:00:00+05:30"),
                                                          accountId: "a"))
        XCTAssertEqual(entry.start, entry.end)
        XCTAssertEqual(entry.start, utc(2026, 10, 5, 4, 30))
    }

    func testEventEndingBeforeItStartsBecomesAnInstant() throws {
        let entry = try XCTUnwrap(GoogleEventMapper.entry(from: timed("2026-10-05T11:00:00+05:30", "2026-10-05T10:00:00+05:30"),
                                                          accountId: "a"))
        XCTAssertEqual(entry.end, entry.start)
    }

    func testAllDayEventWithoutALaterEndCoversItsStartDay() throws {
        for end in [nil, "2026-10-05", "2026-10-04"] {
            let event = GoogleEvent(id: "e2", calendarId: "c", start: .init(date: "2026-10-05"), end: end.map { .init(date: $0) })
            let entry = try XCTUnwrap(GoogleEventMapper.entry(from: event, accountId: "a"))
            XCTAssertTrue(entry.isAllDay)
            XCTAssertEqual(entry.allDayStart, CivilDate(2026, 10, 5))
            XCTAssertEqual(entry.allDayEnd, CivilDate(2026, 10, 6), "end \(String(describing: end))")
        }
    }

    func testEventWithoutAStartIsRejectedAndCancelledIsSkipped() {
        let missing = GoogleEvent(id: "e3", calendarId: "c", start: .init(), end: .init(date: "2026-10-06"))
        XCTAssertThrowsError(try GoogleEventMapper.entry(from: missing, accountId: "a"))
        var cancelled = timed("2026-10-05T10:00:00Z", nil)
        cancelled.status = "cancelled"
        XCTAssertNil(try GoogleEventMapper.entry(from: cancelled, accountId: "a"))
    }

    func testIdentityIsScopedToAccountCalendarAndEvent() throws {
        let a = try XCTUnwrap(GoogleEventMapper.entry(from: timed("2026-10-05T10:00:00Z", nil), accountId: "a"))
        let b = try XCTUnwrap(GoogleEventMapper.entry(from: timed("2026-10-05T10:00:00Z", nil), accountId: "b"))
        XCTAssertNotEqual(a.id, b.id)
        XCTAssertTrue(a.id.hasPrefix("google_"))
        XCTAssertEqual(a.source, .google)
    }

    func testDecodesTheCalendarApiJson() throws {
        let json = """
        {"items":[{"id":"x","status":"confirmed","summary":"Puja","description":"d",
          "start":{"dateTime":"2027-01-01T09:00:00+05:30"},"end":{"dateTime":"2027-01-01T10:00:00+05:30"}},
          {"id":"y","start":{"date":"2027-01-02"},"end":{"date":"2027-01-03"}}],"nextPageToken":"p2"}
        """
        let page = try JSONDecoder().decode(GoogleEventPage.self, from: Data(json.utf8))
        XCTAssertEqual(page.items.count, 2)
        XCTAssertEqual(page.nextPageToken, "p2")
        XCTAssertEqual(page.items[1].start?.date, "2027-01-02")
    }
}

final class FakeGoogle: GoogleAuthGateway {
    var account: String? = "account-a"
    var nextAccount: String?
    var fail = false
    var failSignIn = false
    var events: [GoogleEvent] = []
    var calendars = [GoogleCalendarInfo(id: "primary", summary: "Me", primary: true)]
    var range: (Date, Date)?
    var signedOut = 0

    func accountId() async -> String? { account }
    func isSignedIn() async -> Bool { account != nil }
    func signIn() async throws -> Bool {
        if failSignIn { throw URLError(.notConnectedToInternet) }
        if account == nil { account = nextAccount }
        return account != nil
    }
    func signOut() async { account = nil; signedOut += 1 }
    func idToken() async throws -> String? { account.map { "google-id-token-\($0)" } }
    func accountEmail() async -> String? { account.map { "\($0)@example.com" } }
    func listCalendars() async throws -> [GoogleCalendarInfo] { calendars }
    func fetchEvents(from: Date, to: Date, calendarIds: [String]) async throws -> [GoogleEvent] {
        range = (from, to)
        if fail { throw URLError(.badServerResponse) }
        return events
    }
}

final class GoogleReconciliationTests: XCTestCase {
    var store: InMemoryCalendarEntryStore!
    var auth: FakeGoogle!
    var importer: GoogleCalendarImporter!
    let zone = TimeZone(identifier: "Asia/Kolkata")!

    override func setUp() {
        store = InMemoryCalendarEntryStore(timeZone: zone)
        auth = FakeGoogle()
        importer = GoogleCalendarImporter(auth: auth, store: store, timeZone: zone)
    }

    private func event(_ id: String, calendar: String = "primary", start: String = "2027-01-01",
                       end: String = "2027-01-02") -> GoogleEvent {
        GoogleEvent(id: id, calendarId: calendar, summary: id, start: .init(date: start), end: .init(date: end))
    }

    private func imported(_ account: String, _ calendar: String, _ id: String, _ date: String) -> CalendarEntry {
        let day = CivilDate(iso: date)!
        return try! GoogleEventMapper.entry(from: event(id, calendar: calendar, start: date, end: day.adding(days: 1).iso),
                                            accountId: account)!
    }

    private var window: (Date, Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return (calendar.date(from: DateComponents(year: 2027))!, calendar.date(from: DateComponents(year: 2028))!)
    }

    @discardableResult
    private func sync() async throws -> Int {
        try await importer.syncImport(from: window.0, to: window.1, calendarIds: ["primary"])
    }

    func testReimportRemovesEventsDeletedOnGoogleIncludingAnEmptyYear() async throws {
        auth.events = [event("January"), event("December", start: "2027-12-31", end: "2028-01-01")]
        let first = try await sync()
        XCTAssertEqual(first, 2)
        auth.events = [event("December", start: "2027-12-31", end: "2028-01-01")]
        let second = try await sync()
        XCTAssertEqual(second, 1)
        XCTAssertEqual(try store.all().map(\.title), ["December"])
        auth.events = []
        try await sync()
        XCTAssertTrue(try store.all().isEmpty)
        XCTAssertEqual(auth.range?.0, window.0)
        XCTAssertEqual(auth.range?.1, window.1)
    }

    func testRepeatedImportsUpdateOneEvent() async throws {
        auth.events = [event("a")]
        try await sync()
        var changed = event("a")
        changed.summary = "Changed"
        auth.events = [changed]
        try await sync()
        try await sync()
        XCTAssertEqual(try store.all().count, 1)
        XCTAssertEqual(try store.all().first?.title, "Changed")
    }

    func testFailedFetchPreservesPreviousCacheAndCustomNotes() async throws {
        auth.events = [event("a")]
        try await sync()
        try store.upsert(CalendarEntry(id: "custom", title: "Private", notes: "Keep", start: CivilDate(2027, 1, 1).utcMidnight,
                                       end: CivilDate(2027, 1, 2).utcMidnight, isAllDay: true, source: .custom,
                                       updatedAt: Date()))
        auth.fail = true
        do {
            try await sync()
            XCTFail("expected failure")
        } catch {}
        XCTAssertTrue(try store.all().contains { $0.id == "custom" })
        XCTAssertEqual(try store.all().filter { $0.source == .google }.count, 1)
    }

    func testAccountCalendarAndYearIsolationSurvivesReconciliation() async throws {
        for entry in [imported("account-b", "primary", "same", "2027-02-01"),
                      imported("account-a", "holidays", "same", "2027-02-01"),
                      imported("account-a", "primary", "old-year", "2026-02-01"),
                      imported("account-a", "primary", "same", "2027-02-01")] {
            try store.upsert(entry)
        }
        try await sync()
        let remaining = try store.all()
        XCTAssertEqual(remaining.count, 3)
        XCTAssertEqual(remaining.filter { $0.allDayStart?.year == 2026 }.count, 1)
        XCTAssertEqual(remaining.filter { $0.accountId == "account-b" }.count, 1)
        XCTAssertEqual(remaining.filter { $0.calendarId == "holidays" }.count, 1)
    }

    func testCancelledEventIsRemovedAndSignOutRemovesOnlyThatAccount() async throws {
        auth.events = [event("a")]
        try await sync()
        try store.upsert(imported("account-b", "primary", "b", "2027-01-01"))
        var cancelled = event("a")
        cancelled.status = "cancelled"
        auth.events = [cancelled]
        try await sync()
        XCTAssertEqual(try store.all().map(\.accountId), ["account-b"])
        auth.events = [event("a")]
        try await sync()
        try await importer.signOut()
        XCTAssertEqual(try store.all().map(\.accountId), ["account-b"])
    }

    func testMalformedEventAbortsWithoutDeletingValidCache() async throws {
        auth.events = [event("a")]
        try await sync()
        auth.events = [GoogleEvent(id: "b", calendarId: "primary", start: .init(), end: nil)]
        do {
            try await sync()
            XCTFail("expected failure")
        } catch {}
        XCTAssertEqual(try store.all().map(\.title), ["a"])
    }

    func testGoogleExclusiveEndExcludesTheNextDayAndExactMidnight() throws {
        let allDay = imported("account-a", "primary", "all", "2027-01-01")
        XCTAssertTrue(allDay.occurs(on: CivilDate(2027, 1, 1), in: zone))
        XCTAssertFalse(allDay.occurs(on: CivilDate(2027, 1, 2), in: zone))
        let timed = try XCTUnwrap(GoogleEventMapper.entry(
            from: GoogleEvent(id: "night", calendarId: "primary", start: .init(dateTime: "2027-01-01T23:00:00+05:30"),
                              end: .init(dateTime: "2027-01-02T00:00:00+05:30")), accountId: "account-a"))
        XCTAssertTrue(timed.occurs(on: CivilDate(2027, 1, 1), in: zone))
        XCTAssertFalse(timed.occurs(on: CivilDate(2027, 1, 2), in: zone))
    }

    func testFileStoreWritesAtomicallyAndReloads() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = directory.appendingPathComponent("entries.json")
        let file = try FileCalendarEntryStore(url: url, timeZone: zone)
        try file.upsert(imported("a", "primary", "x", "2027-01-01"))
        XCTAssertEqual(try FileCalendarEntryStore(url: url, timeZone: zone).all().count, 1)
        try file.delete(id: try file.all()[0].id)
        XCTAssertTrue(try FileCalendarEntryStore(url: url, timeZone: zone).all().isEmpty)
        try? FileManager.default.removeItem(at: directory)
    }
}

final class FakeTransport: HTTPTransport {
    var calls: [URLRequest] = []
    var firestore: (URLRequest) -> (Int, String) = { _ in (404, "{}") }

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        calls.append(request)
        if request.url?.host == "identitytoolkit.googleapis.com" {
            let body = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as! [String: Any]
            XCTAssertEqual(body["postBody"] as? String, "id_token=google-token&providerId=google.com")
            return (Data(#"{"idToken":"firebase-token","localId":"uid-1"}"#.utf8), 200)
        }
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer firebase-token")
        let (status, body) = firestore(request)
        return (Data(body.utf8), status)
    }
}

final class FreeSyncRegistryTests: XCTestCase {
    let doc = "https://firestore.googleapis.com/v1/projects/ekadashi-test/databases/(default)/documents/freeGoogleSyncs"

    private func registry(_ transport: FakeTransport) -> FirestoreFreeSyncRegistry {
        FirestoreFreeSyncRegistry(apiKey: "web-api-key", projectId: "ekadashi-test", transport: transport)
    }

    func testSignsInWithTheGoogleIdTokenAndReadsTheAccountRecord() async throws {
        let transport = FakeTransport()
        let unused = try await registry(transport).isUsed(googleIdToken: "google-token")
        XCTAssertFalse(unused)
        XCTAssertTrue(transport.calls.first!.url!.absoluteString.contains("key=web-api-key"))
        XCTAssertEqual(transport.calls.last?.httpMethod, "GET")
        XCTAssertEqual(transport.calls.last?.url?.absoluteString, "\(doc)/uid-1")
        transport.firestore = { _ in (200, #"{"name":"x"}"#) }
        let used = try await registry(transport).isUsed(googleIdToken: "google-token")
        XCTAssertTrue(used)
    }

    func testRecordsTheMonthOncePerAccount() async throws {
        let transport = FakeTransport()
        transport.firestore = { _ in (200, "{}") }
        try await registry(transport).record(googleIdToken: "google-token", month: CivilDate(2026, 10, 1))
        let create = transport.calls.last!
        XCTAssertEqual(create.httpMethod, "POST")
        XCTAssertTrue(create.url!.absoluteString.contains("documentId=uid-1"))
        let fields = (try JSONSerialization.jsonObject(with: create.httpBody!) as! [String: Any])["fields"] as! [String: Any]
        XCTAssertEqual(fields["month"] as? [String: String], ["stringValue": "2026-10"])
        transport.firestore = { _ in (409, "{}") }
        try await registry(transport).record(googleIdToken: "google-token", month: CivilDate(2026, 10, 1))
    }

    func testUnreachableRegistryThrows() async {
        let transport = FakeTransport()
        transport.firestore = { _ in (503, "oops") }
        do {
            _ = try await registry(transport).isUsed(googleIdToken: "google-token")
            XCTFail("expected failure")
        } catch {}
    }

    func testOnlyEnabledWhenFirebaseSettingsAreBuiltIn() {
        XCTAssertNil(FirestoreFreeSyncRegistry.fromConfiguration(apiKey: "", projectId: "x"))
        XCTAssertNotNil(FirestoreFreeSyncRegistry.fromConfiguration(apiKey: "k", projectId: "x"))
    }
}

final class FakeRegistry: FreeSyncRegistry {
    var used = false
    var fail = false
    var recorded: [CivilDate] = []
    func isUsed(googleIdToken: String) async throws -> Bool {
        if fail { throw URLError(.timedOut) }
        return used
    }
    func record(googleIdToken: String, month: CivilDate) async throws { recorded.append(month) }
}

/// The free sync and premium rules from PR #13's Calendar screen.
final class GoogleSyncCoordinatorTests: XCTestCase {
    var prefs: InMemoryKeyValueStore!
    var store: InMemoryCalendarEntryStore!
    var auth: FakeGoogle!
    var registry: FakeRegistry!
    var premium: PremiumState!
    var paywallReasons: [String] = []
    var paywallGrants = false
    var picker: GoogleCalendarPickerResult = .chosen(["primary"])
    var messages: [String] = []
    let zone = TimeZone(identifier: "Asia/Kolkata")!
    lazy var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }()

    override func setUp() {
        prefs = InMemoryKeyValueStore()
        store = InMemoryCalendarEntryStore(timeZone: zone)
        auth = FakeGoogle()
        auth.events = [GoogleEvent(id: "e", calendarId: "primary", summary: "Puja", start: .init(date: "2026-10-10"),
                                   end: .init(date: "2026-10-11"))]
        registry = FakeRegistry()
        premium = PremiumState()
        premium.apply(owned: [])
        paywallReasons = []
        messages = []
        picker = .chosen(["primary"])
    }

    private func coordinator(registry: FreeSyncRegistry?) -> GoogleSyncCoordinator {
        GoogleSyncCoordinator(
            importer: GoogleCalendarImporter(auth: auth, store: store, timeZone: zone),
            registry: registry, preferences: prefs, calendar: calendar,
            premium: { [unowned self] in self.premium },
            refreshPremium: { [unowned self] in self.premium },
            presentPaywall: { [unowned self] reason in
                self.paywallReasons.append(reason)
                if self.paywallGrants { self.premium.apply(owned: [OwnedProduct(productId: PremiumProduct.yearly,
                                                                              purchaseDate: self.calendar.date(from: DateComponents(year: 2026, month: 10)))]) }
                return self.paywallGrants
            },
            pickCalendars: { [unowned self] _, _, _ in self.picker },
            message: { [unowned self] key, _, _ in self.messages.append(key) })
    }

    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 7))! }

    func testTheOneFreeSyncImportsTheViewedMonthAndIsRecordedEverywhere() async throws {
        let outcome = await coordinator(registry: registry).sync(viewedMonth: CivilDate(2026, 10, 1), now: now, calendarYears: 2026...2027)
        XCTAssertEqual(outcome, .imported(count: 1, premium: false))
        XCTAssertEqual(auth.range?.0, calendar.date(from: DateComponents(year: 2026, month: 10)))
        XCTAssertEqual(auth.range?.1, calendar.date(from: DateComponents(year: 2026, month: 11)))
        XCTAssertEqual(prefs.bool(forKey: GoogleSyncCoordinator.freeSyncUsedKey), true)
        XCTAssertEqual(prefs.string(forKey: GoogleSyncCoordinator.freeSyncMonthKey), "2026-10")
        XCTAssertEqual(registry.recorded, [CivilDate(2026, 10, 1)])
        XCTAssertEqual(messages.last, "google_free_sync_used")
    }

    func testASecondFreeSyncOpensThePaywall() async {
        _ = prefs.set(true, forKey: GoogleSyncCoordinator.freeSyncUsedKey)
        let outcome = await coordinator(registry: registry).sync(viewedMonth: CivilDate(2026, 10, 1), now: now, calendarYears: 2026...2027)
        XCTAssertEqual(outcome, .paywallDeclined)
        XCTAssertEqual(paywallReasons, ["google_free_sync_used"])
        XCTAssertNil(auth.range)
    }

    func testTheRegistryRemembersAFreeSyncUsedBeforeAReinstall() async {
        registry.used = true
        let outcome = await coordinator(registry: registry).sync(viewedMonth: CivilDate(2026, 10, 1), now: now, calendarYears: 2026...2027)
        XCTAssertEqual(outcome, .paywallDeclined)
        XCTAssertEqual(paywallReasons, ["google_free_sync_used"])
        XCTAssertEqual(prefs.bool(forKey: GoogleSyncCoordinator.freeSyncUsedKey), true)
    }

    func testAnUnreachableRegistryHandsNothingOutButKeepsTheFreeSync() async {
        registry.fail = true
        let outcome = await coordinator(registry: registry).sync(viewedMonth: CivilDate(2026, 10, 1), now: now, calendarYears: 2026...2027)
        XCTAssertEqual(outcome, .paywallDeclined)
        XCTAssertEqual(paywallReasons, ["free_sync_unverified"])
        XCTAssertNil(prefs.bool(forKey: GoogleSyncCoordinator.freeSyncUsedKey))
    }

    func testClosingThePickerOrAFailedImportKeepsTheFreeSync() async {
        picker = .cancelled
        var outcome = await coordinator(registry: registry).sync(viewedMonth: CivilDate(2026, 10, 1), now: now, calendarYears: 2026...2027)
        XCTAssertEqual(outcome, .cancelled)
        auth.fail = true
        picker = .chosen(["primary"])
        outcome = await coordinator(registry: registry).sync(viewedMonth: CivilDate(2026, 10, 1), now: now, calendarYears: 2026...2027)
        XCTAssertEqual(outcome, .failed)
        XCTAssertEqual(messages.last, "google_sync_failed")
        XCTAssertNil(prefs.bool(forKey: GoogleSyncCoordinator.freeSyncUsedKey))
        XCTAssertTrue(registry.recorded.isEmpty)
    }

    func testBuyingFromThePaywallContinuesIntoTheSubscriptionYear() async {
        _ = prefs.set(true, forKey: GoogleSyncCoordinator.freeSyncUsedKey)
        paywallGrants = true
        let outcome = await coordinator(registry: registry).sync(viewedMonth: CivilDate(2026, 10, 1), now: now, calendarYears: 2026...2027)
        XCTAssertEqual(outcome, .imported(count: 1, premium: true))
        XCTAssertEqual(auth.range?.0, calendar.date(from: DateComponents(year: 2026, month: 10)))
        XCTAssertEqual(auth.range?.1, calendar.date(from: DateComponents(year: 2027, month: 10)))
        XCTAssertNotNil(prefs.string(forKey: GoogleSyncCoordinator.premiumSyncKey))
        XCTAssertEqual(messages.last, "imported_google_range")
    }

    func testLifetimeImportsEveryCalendarYear() async {
        premium.apply(owned: [OwnedProduct(productId: PremiumProduct.lifetime, purchaseDate: now, willAutoRenew: nil)])
        _ = await coordinator(registry: registry).sync(viewedMonth: CivilDate(2026, 10, 1), now: now, calendarYears: 2026...2027)
        XCTAssertEqual(auth.range?.0, calendar.date(from: DateComponents(year: 2026)))
        XCTAssertEqual(auth.range?.1, calendar.date(from: DateComponents(year: 2028)))
    }

    func testSwitchAccountForgetsTheSignInAndRetries() async {
        premium.apply(owned: [OwnedProduct(productId: PremiumProduct.lifetime, purchaseDate: now, willAutoRenew: nil)])
        var calls = 0
        let sut = GoogleSyncCoordinator(
            importer: GoogleCalendarImporter(auth: auth, store: store, timeZone: zone), registry: nil, preferences: prefs,
            calendar: calendar, premium: { [unowned self] in self.premium }, refreshPremium: { [unowned self] in self.premium },
            presentPaywall: { _ in false },
            pickCalendars: { [unowned self] _, _, _ in
                calls += 1
                return calls == 1 ? .switchAccount : .chosen(["primary"])
            },
            message: { _, _, _ in })
        auth.account = "account-a"
        auth.nextAccount = "account-b"
        let outcome = await sut.sync(viewedMonth: CivilDate(2026, 10, 1), now: now, calendarYears: 2026...2027)
        XCTAssertEqual(auth.signedOut, 1)
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(outcome, .imported(count: 1, premium: true))
        XCTAssertEqual(try store.all().map(\.accountId), ["account-b"])
    }

    func testSignInFailuresAreReportedPlainly() async {
        auth.account = nil
        var outcome = await coordinator(registry: registry).sync(viewedMonth: CivilDate(2026, 10, 1), now: now, calendarYears: 2026...2027)
        XCTAssertEqual(outcome, .cancelled)
        XCTAssertEqual(messages.last, "sign_in_cancelled")
        auth.failSignIn = true
        outcome = await coordinator(registry: registry).sync(viewedMonth: CivilDate(2026, 10, 1), now: now, calendarYears: 2026...2027)
        XCTAssertEqual(outcome, .failed)
        XCTAssertEqual(messages.last, "google_sign_in_failed")
    }

    func testConfirmedLapseRemovesPremiumEventsButKeepsTheFreeMonth() throws {
        let sut = coordinator(registry: registry)
        func entry(_ id: String, _ date: String) -> CalendarEntry {
            let day = CivilDate(iso: date)!
            return try! GoogleEventMapper.entry(from: GoogleEvent(id: id, calendarId: "primary", start: .init(date: date),
                                                                  end: .init(date: day.adding(days: 1).iso)), accountId: "account-a")!
        }
        try store.upsert(entry("free", "2026-10-10"))
        try store.upsert(entry("premium-before", "2026-09-10"))
        try store.upsert(entry("premium-after", "2027-03-10"))
        _ = prefs.set("2026-10", forKey: GoogleSyncCoordinator.freeSyncMonthKey)
        sut.rememberPremiumSync(account: "account-a", calendars: ["primary"],
                                start: calendar.date(from: DateComponents(year: 2026, month: 9))!,
                                end: calendar.date(from: DateComponents(year: 2027, month: 9))!)
        // Store unavailable: nothing is removed.
        premium.storeUnavailable()
        XCTAssertFalse(try sut.removeLapsedPremiumSync())
        XCTAssertEqual(try store.all().count, 3)
        // The store confirms nothing is owned.
        premium.apply(owned: [])
        XCTAssertTrue(try sut.removeLapsedPremiumSync())
        XCTAssertEqual(try store.all().map(\.googleEventId), ["free"])
        XCTAssertNil(prefs.string(forKey: GoogleSyncCoordinator.premiumSyncKey))
    }

    func testPremiumSyncRecordsMergeForTheSameAccount() throws {
        let sut = coordinator(registry: registry)
        sut.rememberPremiumSync(account: "a", calendars: ["primary"], start: utc(2026, 10, 1), end: utc(2027, 10, 1))
        sut.rememberPremiumSync(account: "a", calendars: ["holidays"], start: utc(2026, 1, 1), end: utc(2027, 1, 1))
        let record = try XCTUnwrap(sut.premiumSyncRecord())
        XCTAssertEqual(record.start, utc(2026, 1, 1))
        XCTAssertEqual(record.end, utc(2027, 10, 1))
        XCTAssertEqual(Set(record.calendars), ["primary", "holidays"])
        sut.rememberPremiumSync(account: "b", calendars: ["x"], start: utc(2026, 1, 1), end: utc(2026, 2, 1))
        XCTAssertEqual(sut.premiumSyncRecord()?.account, "b")
    }
}
