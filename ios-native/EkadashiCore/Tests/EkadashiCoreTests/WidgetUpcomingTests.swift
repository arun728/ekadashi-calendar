import XCTest
@testable import EkadashiCore

final class WidgetUpcomingTests: XCTestCase {
    func testBothWidgetDescriptionsAndPreviewLabelsAreTranslatedInEveryLanguage() {
        let keys = ["widget_name_ekadashi", "upcoming_ekadashis", "ios_widget_desc_ekadashi", "ios_widget_desc_next",
                    "ios_widget_preview_desc", "widget_size_small", "widget_size_medium", "widget_size_large",
                    "widget_size_lock", "widget_preview_tap", "widget_no_next"]
        for language in Localizer.languages {
            for key in keys {
                let value = Localizer.shared.translate(key, language: language)
                XCTAssertFalse(value.isEmpty)
                XCTAssertNotEqual(value, key)
                if language != "en" { XCTAssertNil(value.range(of: "[A-Za-z]", options: .regularExpression), "\(language) \(key)") }
            }
        }
        XCTAssertTrue(Localizer.shared.translate("ios_widget_desc_next", language: "en").contains("five"))
    }

    private func snapshot(_ now: Date) -> WidgetSnapshot {
        let events = (0..<8).map { offset -> EkadashiOccurrence in
            let date = CivilDate(2026, 12, 1).adding(days: offset * 14)
            let start = date.utcMidnight.addingTimeInterval(6 * 3600)
            return EkadashiOccurrence(id: offset, occurrenceUid: "fast:\(offset)", name: "Ekadashi \(offset)", date: date,
                fastingStartISO: ISO8601.string(start), paranaStartISO: ISO8601.string(start.addingTimeInterval(86400)),
                paranaEndISO: ISO8601.string(start.addingTimeInterval(93600)))
        }
        return WidgetSnapshot.build(occurrences: events.reversed(), timezone: "UTC", locationName: "Test", language: "en", now: now)
    }

    func testUpcomingIncludesTheFirstFutureOccurrenceAndExactlyFiveAcrossYears() {
        let now = utc(2026, 11, 30)
        let items = snapshot(now).upcoming(after: now)
        XCTAssertEqual(items.map(\.occurrenceUid), (0..<5).map { "fast:\($0)" })
        XCTAssertEqual(Set(items.map(\.occurrenceUid)).count, 5)
        XCTAssertEqual(items.last?.year, 2027)
        for item in items { XCTAssertEqual(AppRoute(url: item.detailsURL), .ekadashi(item.occurrenceUid)) }
    }

    func testUpcomingIncludesBeforeSunriseAndExcludesAlreadyStarted() {
        XCTAssertEqual(snapshot(utc(2026, 12, 1, 1)).upcoming(after: utc(2026, 12, 1, 1)).first?.occurrenceUid, "fast:0")
        for now in [utc(2026, 12, 1, 6), utc(2026, 12, 2, 7)] {
            XCTAssertEqual(snapshot(now).upcoming(after: now).map(\.occurrenceUid), (1...5).map { "fast:\($0)" })
        }
    }

    func testStaleSnapshotReevaluatesAtLocalMidnightAndDoesNotSkipTheNextFast() {
        let payload = snapshot(utc(2026, 11, 30))
        XCTAssertEqual(payload.upcoming(after: utc(2026, 12, 15)).map(\.occurrenceUid), (1...5).map { "fast:\($0)" })
        XCTAssertEqual(payload.upcoming(after: utc(2027, 3, 8)).map(\.occurrenceUid), ["fast:7"])
        XCTAssertTrue(payload.upcoming(after: utc(2027, 4, 1)).isEmpty)
    }
}
