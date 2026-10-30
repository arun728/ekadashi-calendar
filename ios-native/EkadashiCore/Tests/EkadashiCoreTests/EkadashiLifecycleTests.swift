import XCTest
@testable import EkadashiCore

final class EkadashiLifecycleTests: XCTestCase {
    let zone = TzDatabase.shared.location("Asia/Kolkata")!
    func events() -> [EkadashiOccurrence] {
        [(20, "2026-10-22", "06:00", "2026-10-23", "08:21"),
         (21, "2026-11-05", "06:04", "2026-11-06", "08:20")].map { id, day, time, next, end in
            EkadashiOccurrence(id: id, name: "Ekadashi", date: CivilDate(iso: day)!,
                fastingStartISO: "\(day)T\(time):00+05:30", paranaStartISO: "\(next)T06:00:00+05:30",
                paranaEndISO: "\(next)T\(end):00+05:30")
        }
    }
    func snapshot(_ time: String) -> WidgetSnapshot {
        WidgetSnapshot.build(occurrences: events(), timezone: "Asia/Kolkata", locationName: "Chennai",
            language: "en", now: instant(time))
    }
    func testBeforeSunriseIsUpcomingWithoutActiveRing() {
        let time = "2026-10-22T00:00:00+05:30", now = instant(time)
        guard case .next(let item, let days) = snapshot(time).headline(at: now) else { return XCTFail("Countdown, not active") }
        XCTAssertEqual(item.id, 20); XCTAssertEqual(days, 0)
        XCTAssertEqual(snapshot(time).upcoming(after: now).first?.id, 20)
    }
    func testRingFillsFromZeroInsteadOfErasing() {
        let time = "2026-10-22T12:00:00+05:30"
        guard case .today(_, let progress) = snapshot(time).headline(at: instant(time)) else { return XCTFail("Active") }
        XCTAssertEqual(progress, 0.25, accuracy: 0.000001)
    }
    func testMidnightAndParanaRetainCurrentWidgetWithFilledProgress() {
        for (time, expected) in [("2026-10-23T00:00:00+05:30", 0.75),
                                 ("2026-10-23T06:00:00+05:30", 1.0),
                                 ("2026-10-23T08:20:59+05:30", 1.0)] {
            guard case .today(let item, let progress) = snapshot(time).headline(at: instant(time)) else { return XCTFail("Retain current until Parana end: \(time)") }
            XCTAssertEqual(item.id, 20); XCTAssertEqual(progress, expected, accuracy: 0.000001)
        }
    }
    func testParanaEndSelectsNextOnHomeAndWidgetIncludingHomeRetap() {
        let end = instant("2026-10-23T08:21:00+05:30")
        XCTAssertEqual(HomeSelection.index(of: events(), now: end.addingTimeInterval(-1), zone: zone, includeParana: false), 0)
        XCTAssertEqual(HomeSelection.index(of: events(), now: end, zone: zone, includeParana: true), 1)
        guard case .next(let item, _) = snapshot("2026-10-23T08:21:00+05:30").headline(at: end) else { return XCTFail("Next") }
        XCTAssertEqual(item.id, 21)
    }
    func testCachedWidgetSurvivesMidnightUntilParanaEnd() {
        let payload = snapshot("2026-10-21T12:00:00+05:30")
        guard case .today(let item, _) = payload.headline(at: instant("2026-10-23T07:00:00+05:30")) else { return XCTFail("Cached active occurrence") }
        XCTAssertEqual(item.id, 20)
    }
    func testUpcomingChangesAtActualStartInsteadOfMidnight() {
        let payload = snapshot("2026-10-21T12:00:00+05:30")
        XCTAssertEqual(payload.upcoming(after: instant("2026-10-22T05:59:59+05:30")).first?.id, 20)
        XCTAssertEqual(payload.upcoming(after: instant("2026-10-22T06:00:00+05:30")).first?.id, 21)
    }
    func testExactStatusCountdownProgressAndParanaBoundaries() {
        let event = events()[0]
        let cases: [(String, EkadashiLifecycle.Phase, String, Int?)] = [
            ("2026-10-22T00:00:00+05:30", .countdown, "06:00:00", nil),
            ("2026-10-22T05:59:59+05:30", .countdown, "00:00:01", nil),
            ("2026-10-22T06:00:00+05:30", .fasting, "Now", 0),
            ("2026-10-23T00:00:00+05:30", .fasting, "Now", 75),
            ("2026-10-23T05:59:59+05:30", .fasting, "Now", 99),
            ("2026-10-23T06:00:00+05:30", .parana, "Parana", 100),
            ("2026-10-23T08:20:59+05:30", .parana, "Parana", 100),
            ("2026-10-23T08:21:00+05:30", .passed, "Passed", nil)]
        for (time, phase, label, percent) in cases {
            let status = event.lifecycle(at: instant(time), zone: zone)
            XCTAssertEqual(status.phase, phase, time); XCTAssertEqual(status.label(language: "en"), label, time)
            XCTAssertEqual(status.percent, percent, time)
        }
    }
    func testLanguageAndScheduleZoneNeverChangeInstantBoundaries() {
        let event = events()[0]
        for zoneName in ["Asia/Kolkata", "Asia/Kathmandu", "America/New_York", "Australia/Sydney", "Pacific/Auckland", "UTC"] {
            let zone = TzDatabase.shared.location(zoneName)!
            for language in Localizer.languages {
                for (now, phase) in [(event.fastingStart!, EkadashiLifecycle.Phase.fasting),
                                     (event.paranaStart!, .parana), (event.paranaEnd!, .passed)] {
                    let status = event.lifecycle(at: now, zone: zone)
                    XCTAssertEqual(status.phase, phase)
                    if language != "en" { XCTAssertNil(status.label(language: language).range(of: "[A-Za-z]", options: .regularExpression)) }
                }
            }
        }
    }
    func testDSTTransitionUsesElapsedInstantsAndParanaCalendarEntryKeepsIdentity() {
        let zone = TzDatabase.shared.location("America/New_York")!
        let event = EkadashiOccurrence(id: 1, name: "Fast", date: CivilDate(2026, 10, 31),
            fastingStartISO: "2026-10-31T06:00:00-04:00", paranaStartISO: "2026-11-01T06:00:00-05:00",
            paranaEndISO: "2026-11-01T08:00:00-05:00")
        let midpoint = event.fastingStart!.addingTimeInterval(12.5 * 3600)
        XCTAssertEqual(event.lifecycle(at: midpoint, zone: zone).percent, 50)
        XCTAssertTrue(event.hasParana(on: CivilDate(2026, 11, 1), zone: zone))
        XCTAssertFalse(event.hasParana(on: event.date, zone: zone))
        XCTAssertFalse(event.hasParana(on: CivilDate(2026, 11, 2), zone: zone))
    }
    func testMalformedTimingsNeverInventAnActiveFastOrRing() {
        let event = EkadashiOccurrence(id: 0, name: "", date: CivilDate(2026, 10, 22))
        let status = event.lifecycle(at: instant("2026-10-22T06:00:00+05:30"), zone: zone)
        XCTAssertEqual(status.phase, .unavailable); XCTAssertNil(status.progress)
        XCTAssertFalse(event.hasParana(on: event.date, zone: zone))
    }
    func testActualSchedulesForBothTraditionsAndAllLanguagesRespectEveryBoundary() throws {
        let repository = try CalendarRepository.bundled()
        let schedule = EkadashiSchedule(repository: repository)
        for tradition in EkadashiTradition.allCases {
            for language in Localizer.languages {
                let events = try schedule.ekadashis(city: PanchangCity(id: "chennai", label: "Chennai", latitude: 13.08784, longitude: 80.27847, timeZoneId: "Asia/Kolkata"), tradition: tradition, language: language, years: [2026])
                for event in events {
                    let start = try XCTUnwrap(event.fastingStart), parana = try XCTUnwrap(event.paranaStart), end = try XCTUnwrap(event.paranaEnd)
                    XCTAssertNil(event.lifecycle(at: start.addingTimeInterval(-1), zone: zone).progress)
                    XCTAssertEqual(event.lifecycle(at: start, zone: zone).percent, 0)
                    XCTAssertEqual(event.lifecycle(at: parana, zone: zone).percent, 100)
                    XCTAssertEqual(event.lifecycle(at: end.addingTimeInterval(-1), zone: zone).phase, .parana)
                    XCTAssertEqual(event.lifecycle(at: end, zone: zone).phase, .passed)
                }
            }
        }
    }

    func testRefreshCadenceUsesSecondsOnlyBeforeStartAndHitsExactBoundaries() {
        let event = events()[0]
        let countdown = instant("2026-10-22T05:59:58+05:30")
        XCTAssertEqual(event.nextLifecycleUpdate(after: countdown, zone: zone), countdown.addingTimeInterval(1))
        let fasting = event.fastingStart!.addingTimeInterval(100)
        XCTAssertEqual(event.nextLifecycleUpdate(after: fasting, zone: zone), fasting.addingTimeInterval(60))
        XCTAssertEqual(event.nextLifecycleUpdate(after: event.paranaStart!.addingTimeInterval(-2), zone: zone), event.paranaStart)
        XCTAssertEqual(event.nextLifecycleUpdate(after: event.paranaEnd!.addingTimeInterval(-2), zone: zone), event.paranaEnd)
        XCTAssertNil(event.nextLifecycleUpdate(after: event.paranaEnd!, zone: zone))
    }

    func testParanaEntryDoesNotCreateAFastingDayMarker() {
        let event = events()[0]
        let fastingDay = EkadashiCalendarDay(events: [event], day: event.date, zone: zone)
        XCTAssertTrue(fastingDay.showsFastingMarker)
        XCTAssertEqual(fastingDay.fasting.map(\.occurrenceUid), [event.occurrenceUid])
        let paranaDay = EkadashiCalendarDay(events: [event], day: event.date.adding(days: 1), zone: zone)
        XCTAssertFalse(paranaDay.showsFastingMarker)
        XCTAssertTrue(paranaDay.fasting.isEmpty)
        XCTAssertEqual(paranaDay.parana.map(\.occurrenceUid), [event.occurrenceUid])
        let empty = EkadashiCalendarDay(events: [event], day: event.date.adding(days: 2), zone: zone)
        XCTAssertFalse(empty.showsFastingMarker); XCTAssertTrue(empty.parana.isEmpty)
    }

    func testMinuteCollapsedParanaWindowKeepsTheFastValidUntilItsRecordedEnd() {
        let event = EkadashiOccurrence(id: 1, name: "Fast", date: CivilDate(2026, 7, 24),
            fastingStartISO: "2026-07-24T05:45:00-04:00", paranaStartISO: "2026-07-25T08:40:00-04:00",
            paranaEndISO: "2026-07-25T08:40:00-04:00")
        let zone = TzDatabase.shared.location("America/New_York")!
        XCTAssertEqual(event.lifecycle(at: event.fastingStart!.addingTimeInterval(-1), zone: zone).countdown, "00:00:01")
        XCTAssertEqual(event.lifecycle(at: event.fastingStart!, zone: zone).phase, .fasting)
        XCTAssertEqual(event.lifecycle(at: event.paranaStart!.addingTimeInterval(-1), zone: zone).percent, 99)
        XCTAssertEqual(event.lifecycle(at: event.paranaEnd!, zone: zone).phase, .passed)
        let day = EkadashiCalendarDay(events: [event], day: CivilDate(2026, 7, 25), zone: zone)
        XCTAssertEqual(day.parana.map(\.occurrenceUid), [event.occurrenceUid])
        XCTAssertFalse(day.showsFastingMarker)
    }

}
