import Foundation
import XCTest
@testable import EkadashiCore

/// Phase 7: reminders for festivals, Panchang days and calendar entries,
/// each a chosen number of days before at a chosen time.
final class EventReminderTests: XCTestCase {
    private let zone = TimeZone(identifier: "Asia/Kolkata")!
    private let observances = PanchangEngine().observanceCalendar(year: 2026, city: .newDelhi)

    private func plan(_ reminders: [EventReminder], entries: [CalendarEntry] = [], now: Date, premium: Bool = true,
                      enabled: Bool = true, limit: Int = 64) -> [PlannedEventReminder] {
        EventReminderPlanner.plan(settings: EventReminderSettings(enabled: enabled, reminders: reminders),
                                  observances: observances, entries: entries, observanceZone: zone, entryZone: zone,
                                  language: "en", premium: premium, now: now, limit: limit)
    }

    func testSettingsRoundTripAndDefaults() {
        let store = InMemoryKeyValueStore()
        XCTAssertEqual(EventReminderSettings.load(from: store), EventReminderSettings())
        XCTAssertTrue(EventReminderSettings().reminders.isEmpty)
        let settings = EventReminderSettings(enabled: true, reminders: [
            EventReminder(target: .observance("amavasya"), daysBefore: [1, 2], hour: 7, minute: 30),
            EventReminder(target: .calendar(.custom), daysBefore: [0], hour: 6, minute: 0),
        ])
        settings.save(to: store)
        XCTAssertEqual(EventReminderSettings.load(from: store), settings)
    }

    func testAmavasyaOneDayBeforeAtSevenThirty() {
        let reminder = EventReminder(target: .observance("amavasya"), daysBefore: [1], hour: 7, minute: 30)
        let result = plan([reminder], now: instant("2026-10-08T10:00:00+05:30"))
        XCTAssertEqual(result.first?.fireDate, instant("2026-10-09T07:30:00+05:30"), "Amavasya is on 10 October")
        XCTAssertEqual(result.first?.title, "Amavasya")
        XCTAssertEqual(result.first?.body, "Amavasya is tomorrow (Sat, 10 Oct 2026)")
        XCTAssertEqual(result.count, 3, "October, November and December 2026")
        XCTAssertTrue(result.allSatisfy { $0.url.absoluteString.hasPrefix("ekadashi://panchang") })
    }

    func testSeveralLeadTimesAndSameDay() {
        let reminder = EventReminder(target: .observance("deepavali"), daysBefore: [0, 2], hour: 6, minute: 0)
        let result = plan([reminder], now: instant("2026-10-08T10:00:00+05:30"))
        XCTAssertEqual(result.map(\.fireDate), [instant("2026-11-06T06:00:00+05:30"), instant("2026-11-08T06:00:00+05:30")])
        XCTAssertEqual(result.map(\.body), ["Deepavali (Lakshmi Puja) is in 2 days (Sun, 8 Nov 2026)",
                                            "Deepavali (Lakshmi Puja) is today (Sun, 8 Nov 2026)"])
        XCTAssertEqual(Set(result.map(\.id)).count, 2, "stable, distinct ids")
    }

    func testCalendarEntriesBySource() {
        let start = instant("2026-10-20T09:00:00+05:30")
        let entries = [
            CalendarEntry(id: "c1", title: "Temple visit", start: start, end: start.addingTimeInterval(3600), source: .custom,
                          updatedAt: start),
            CalendarEntry(id: "g1", title: "Satsang", start: start, end: start.addingTimeInterval(3600), source: .google,
                          updatedAt: start),
        ]
        let custom = EventReminder(target: .calendar(.custom), daysBefore: [1], hour: 20, minute: 0)
        let result = plan([custom], entries: entries, now: instant("2026-10-08T10:00:00+05:30"), premium: false)
        XCTAssertEqual(result.map(\.title), ["Temple visit"])
        XCTAssertEqual(result.first?.fireDate, instant("2026-10-19T20:00:00+05:30"))
        XCTAssertEqual(result.first?.url, AppRoute.calendarURL(CivilDate(2026, 10, 20)))
    }

    func testPanchangRemindersNeedPremiumAndTheMasterSwitch() {
        let reminder = EventReminder(target: .observance("purnima"), daysBefore: [1], hour: 7, minute: 0)
        let now = instant("2026-10-08T10:00:00+05:30")
        XCTAssertTrue(plan([reminder], now: now, premium: false).isEmpty)
        XCTAssertTrue(plan([reminder], now: now, enabled: false).isEmpty)
        XCTAssertFalse(plan([reminder], now: now).isEmpty)
    }

    func testPastTimesAreSkippedAndTheLimitKeepsTheSoonest() {
        let every = SearchCatalog.bundled.observances.map {
            EventReminder(target: .observance($0.key), daysBefore: [0, 1, 2], hour: 7, minute: 0)
        }
        let now = instant("2026-10-08T10:00:00+05:30")
        let result = plan(every, now: now, limit: 20)
        XCTAssertEqual(result.count, 20)
        XCTAssertTrue(result.allSatisfy { $0.fireDate > now })
        XCTAssertEqual(result.map(\.fireDate), result.map(\.fireDate).sorted())
    }

    func testChoicesListFestivalsMonthlyDaysAndCalendars() {
        let choices = EventReminderChoice.all(language: "hi")
        XCTAssertTrue(choices.contains { $0.target == .observance("deepavali") && $0.title == "दीपावली (लक्ष्मी पूजा)" })
        XCTAssertTrue(choices.contains { $0.target == .observance("amavasya") && $0.group == .monthly })
        XCTAssertTrue(choices.contains { $0.target == .calendar(.google) && $0.group == .myCalendar })
        XCTAssertFalse(choices.contains { $0.group == .festival && $0.target == .observance("amavasya") })
        XCTAssertTrue(choices.filter { $0.group != .myCalendar }.allSatisfy(\.requiresPremium))
        XCTAssertFalse(choices.filter { $0.group == .myCalendar }.contains(where: \.requiresPremium))
        XCTAssertEqual(Set(choices.map(\.id)).count, choices.count)
        XCTAssertFalse(choices.contains { $0.title.hasPrefix("event_reminder_") }, "every title is translated")
    }

    func testRemindersOpenTheDayInPanchang() {
        XCTAssertEqual(AppRoute(url: AppRoute.panchangURL(CivilDate(2026, 10, 10))), .panchang(CivilDate(2026, 10, 10)))
        XCTAssertEqual(AppRoute(url: URL(string: "ekadashi://panchang")!), .tab(.panchang))
    }

    func testStoredRemindersSurviveBadDataAndReplaceByEvent() {
        let store = InMemoryKeyValueStore(["event_reminders": "not json", "notifications_enabled": false])
        XCTAssertEqual(EventReminderSettings.load(from: store), EventReminderSettings(enabled: false))
        var settings = EventReminderSettings()
        settings.upsert(EventReminder(target: .observance("holi"), daysBefore: [2, 1, 1, 40], hour: 30, minute: -5))
        settings.upsert(EventReminder(target: .observance("holi"), daysBefore: [0]))
        XCTAssertEqual(settings.reminders.count, 1)
        XCTAssertEqual(settings.reminders.first?.daysBefore, [0])
        XCTAssertEqual(EventReminder(target: .observance("holi"), daysBefore: [2, 1, 1, 40], hour: 30, minute: -5),
                       EventReminder(target: .observance("holi"), daysBefore: [1, 2], hour: 23, minute: 0))
        settings.remove(.observance("holi"))
        XCTAssertTrue(settings.reminders.isEmpty)
    }
}

/// Ekadashi and event reminders share iOS's 64 pending notifications.
final class PendingNotificationTests: XCTestCase {
    func testMergeKeepsTheSoonestAcrossBothKinds() {
        let now = instant("2026-10-08T10:00:00+05:30")
        let ekadashi: [PlannedReminder] = (0..<40).map { (index: Int) -> PlannedReminder in
            let kind: PlannedReminder.Kind = index % 2 == 0 ? .onFastingStart : .onParana
            let fire = now.addingTimeInterval(Double(index * 2 + 1) * 3600)
            return PlannedReminder(id: 1000 + index, ekadashiId: 100 + index, kind: kind, fireDate: fire, title: "E\(index)", body: "")
        }
        let day = CivilDate(2026, 10, 9)
        let events: [PlannedEventReminder] = (0..<40).map { (index: Int) -> PlannedEventReminder in
            let fire = now.addingTimeInterval(Double(index * 2 + 2) * 3600)
            return PlannedEventReminder(id: "event.e\(index)", target: .calendar(.custom), eventDate: day, fireDate: fire,
                                        title: "V\(index)", body: "", url: AppRoute.calendarURL(day))
        }
        let merged = PendingNotification.merge(ekadashi: ekadashi, events: events, limit: 64)
        XCTAssertEqual(merged.count, 64)
        XCTAssertEqual(merged.map(\.fireDate), merged.map(\.fireDate).sorted())
        XCTAssertEqual(merged.filter { $0.id.hasPrefix("event.") }.count, 32)
        XCTAssertEqual(merged.first?.id, "1000")
        XCTAssertEqual(merged.first?.url, AppRoute.todayURL)
        XCTAssertEqual(merged[2].url, AppRoute.paranaURL, "Parana opens the Parana card")
        XCTAssertEqual(merged[1].url, AppRoute.calendarURL(CivilDate(2026, 10, 9)))
    }
}
