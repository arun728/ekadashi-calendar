import Foundation
import XCTest
@testable import EkadashiCore

/// Approved widget behaviour: one real occurrence and percentage REMAINING.
final class WidgetRemainingTests: XCTestCase {
    private let start = instant("2026-10-22T06:00:00+05:30")

    private func snapshot(_ now: Date, zone: String = "Asia/Kolkata") -> WidgetSnapshot {
        let event = EkadashiOccurrence(id: 20, occurrenceUid: "ekadashi:2026:20", name: "Papankusha Ekadashi",
            date: CivilDate(2026, 10, 22), fastingStartISO: "2026-10-22T06:00:00+05:30",
            paranaStartISO: "2026-10-23T06:00:00+05:30", paranaEndISO: "2026-10-23T08:21:00+05:30")
        let next = EkadashiOccurrence(id: 21, occurrenceUid: "ekadashi:2026:21", name: "Rama Ekadashi",
            date: CivilDate(2026, 11, 5), fastingStartISO: "2026-11-05T06:04:00+05:30",
            paranaStartISO: "2026-11-06T06:05:00+05:30", paranaEndISO: "2026-11-06T08:20:00+05:30")
        return WidgetSnapshot.build(occurrences: [next, event], timezone: zone, locationName: "Chennai",
                                    language: "en", now: now, tradition: "Smarta")
    }

    func testRingShowsRemainingNotElapsedAtAnAsymmetricTime() {
        let now = start.addingTimeInterval(15 * 3600)
        guard case .today(_, let remaining) = snapshot(now).headline(at: now) else { return XCTFail("today") }
        XCTAssertEqual(remaining, 0.375, accuracy: 0.0001)
    }

    func testRingStartsFullAndDecreasesAsTimePasses() {
        let snapshot = snapshot(start)
        for (hours, expected) in [(0.0, 1.0), (3, 0.875), (12, 0.5), (17, 7.0 / 24)] {
            guard case .today(_, let remaining) = snapshot.headline(at: start.addingTimeInterval(hours * 3600)) else {
                return XCTFail("today at \(hours)")
            }
            XCTAssertEqual(remaining, expected, accuracy: 0.0001)
        }
    }

    func testTodaysEkadashiBeforeSunriseShowsAFullRing() {
        let now = start.addingTimeInterval(-3600)
        guard case .today(let item, let remaining) = snapshot(now).headline(at: now) else { return XCTFail("today before start") }
        XCTAssertEqual(item.date, "2026-10-22")
        XCTAssertEqual(remaining, 1)
    }

    func testNonEkadashiDayShowsExactlyTheNextOccurrenceEvenDuringYesterdaysParana() {
        let now = instant("2026-10-23T07:00:00+05:30")
        guard case .next(let item, let days) = snapshot(now).headline(at: now) else { return XCTFail("next on a non-Ekadashi day") }
        XCTAssertEqual(item.occurrenceUid, "ekadashi:2026:21")
        XCTAssertEqual(days, 13)
    }

    func testTodayIsEvaluatedInTheScheduleTimeZone() {
        let now = instant("2026-10-21T23:30:00Z") // 22 Oct in Chennai, still 21 Oct in UTC.
        guard case .today = snapshot(now).headline(at: now) else { return XCTFail("Chennai date") }
        guard case .next = snapshot(now, zone: "UTC").headline(at: now) else { return XCTFail("UTC date") }
    }

    func testWidgetDatesIncludeTheWeekdayAndActualYear() {
        let now = start.addingTimeInterval(-86400)
        XCTAssertEqual(snapshot(now).nextEkadashi?.localizedDate, "Thu, 22 Oct 2026")
    }

    func testAnOccurrenceSpecificWidgetURLIsRecognized() {
        XCTAssertNotNil(AppRoute(url: URL(string: "ekadashi://ekadashi?uid=ekadashi%3A2026%3A20")!))
        XCTAssertNil(AppRoute(url: URL(string: "ekadashi://ekadashi")!))
        XCTAssertNil(AppRoute(url: URL(string: "ekadashi://ekadashi?uid=")!))
    }

    func testPreviewSelectionsUseRealOccurrencesAndNeverInventToday() throws {
        let now = start.addingTimeInterval(-86400)
        let snapshot = snapshot(now)
        XCTAssertNil(snapshot.headline(at: now, selection: .today))
        guard case .next(let item, _) = snapshot.headline(at: now, selection: .next) else { return XCTFail("next preview") }
        XCTAssertEqual(item.fastingStart, start)
        XCTAssertEqual(item.paranaStart, instant("2026-10-23T06:00:00+05:30"))
        XCTAssertEqual(item.paranaEnd, instant("2026-10-23T08:21:00+05:30"))
        XCTAssertEqual(AppRoute(url: item.detailsURL), .ekadashi(item.occurrenceUid))
        XCTAssertEqual(AppRoute(url: AppRoute.ekadashiURL("a uid:2027/2&3")), .ekadashi("a uid:2027/2&3"))
        guard case .next(let next, _) = snapshot.headline(at: start, selection: .next) else { return XCTFail("future after today") }
        XCTAssertEqual(next.name, "Rama Ekadashi")
    }

    func testRemainingPercentageClampsAndNeverShowsZeroBeforeTheBoundary() throws {
        let item = try XCTUnwrap(snapshot(start).nextEkadashi)
        for (now, expected) in [(start.addingTimeInterval(-1), 100), (start, 100),
                                (start.addingTimeInterval(15 * 3600), 38),
                                (item.paranaStart.addingTimeInterval(-1), 1), (item.paranaStart, 0), (item.paranaEnd, 0)] {
            XCTAssertEqual(item.remainingPercent(at: now), expected)
        }
    }

    func testFormatterKeepsTheRealLocalDatesAndCompleteParanaWindow() throws {
        let snapshot = snapshot(start)
        let item = try XCTUnwrap(snapshot.nextEkadashi)
        let text = WidgetText(snapshot: snapshot)
        XCTAssertEqual(text.date(item.fastingStart), "Thu, 22 Oct 2026")
        XCTAssertEqual(text.date(item.paranaStart), "Fri, 23 Oct 2026")
        XCTAssertEqual(text.time(item.fastingStart), "6:00 AM")
        XCTAssertEqual(text.window(item.paranaStart, item.paranaEnd), "6:00 AM – 8:21 AM")
        XCTAssertEqual(text.remainingLabel, "remaining")
        XCTAssertEqual(WidgetPalette.teal, 0x00A19B)
        XCTAssertEqual(WidgetPalette.ivory, 0xFAF5E8)
    }

    func testTimelineIncludesLocalMidnightAndPercentageChanges() throws {
        let now = start.addingTimeInterval(15 * 3600)
        let snapshot = snapshot(now)
        let midnight = instant("2026-10-23T00:00:00+05:30")
        XCTAssertTrue(snapshot.refreshDates(after: now).contains(midnight))
        let firstPercentChange = start.addingTimeInterval(86400 * 0.63)
        XCTAssertTrue(snapshot.refreshDates(after: now).contains(firstPercentChange))
    }

    func testAllWidgetLabelsAreTranslatedAndTimeMarkersKeepTheAppLanguage() throws {
        let events = try CalendarRepository.bundled().ekadashis(timezone: "IST", language: "en")
        for language in Localizer.languages {
            let snapshot = WidgetSnapshot.build(occurrences: events, timezone: "IST", locationName: "", language: language, now: start)
            let text = WidgetText(snapshot: snapshot)
            XCTAssertFalse(text.remainingLabel.isEmpty)
            if language != "en" {
                XCTAssertFalse(text.remainingLabel.range(of: "[A-Za-z]", options: .regularExpression) != nil)
                XCTAssertFalse(text.time(start).contains("AM"))
            }
        }
    }
}
