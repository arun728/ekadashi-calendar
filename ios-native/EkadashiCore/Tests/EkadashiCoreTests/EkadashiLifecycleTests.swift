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
}
