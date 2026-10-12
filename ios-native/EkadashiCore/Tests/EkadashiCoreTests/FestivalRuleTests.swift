import Foundation
import XCTest
@testable import EkadashiCore

/// Phase 3 festivals (docs/ROADMAP.md), checked against published dates for
/// New Delhi (Drik Panchang and other calendars; see docs/PANCHANG_VALIDATION.md).
final class FestivalRuleTests: XCTestCase {
    private static var calendars: [Int: [DatedObservance]] = [:]

    private func dates(_ id: String, _ year: Int) -> [CivilDate] {
        if Self.calendars[year] == nil {
            Self.calendars[year] = PanchangEngine().observanceCalendar(year: year, city: .newDelhi)
        }
        return Self.calendars[year]!.filter { $0.observance.id == id }.map(\.date)
    }

    func testPublishedDates() {
        let expected: [(String, CivilDate)] = [
            ("raksha-bandhan", CivilDate(2026, 8, 28)), ("raksha-bandhan", CivilDate(2027, 8, 17)),
            ("nag-panchami", CivilDate(2026, 8, 17)), ("nag-panchami", CivilDate(2027, 8, 6)),
            ("onam", CivilDate(2026, 8, 26)), ("onam", CivilDate(2027, 9, 12)),
            ("ratha-yatra", CivilDate(2026, 7, 16)), ("ratha-yatra", CivilDate(2027, 7, 5)),
            ("durga-ashtami", CivilDate(2026, 10, 19)), ("durga-ashtami", CivilDate(2027, 10, 7)),
            ("karthigai-deepam", CivilDate(2026, 11, 24)),
            // Drik's rule: the Friday of Shravana Shukla nearest before (or on) Purnima.
            ("varalakshmi-vratam", CivilDate(2026, 8, 28)), ("varalakshmi-vratam", CivilDate(2027, 8, 13)),
        ]
        for (id, date) in expected {
            XCTAssertEqual(dates(id, date.year), [date], "\(id) \(date.year)")
        }
    }

    func testEachNewFestivalHappensOnceAYearAndIsMajor() {
        for id in PanchangEngine.iosFirstObservanceIds {
            for year in [2026, 2027] {
                XCTAssertEqual(dates(id, year).count, 1, "\(id) \(year)")
            }
            XCTAssertTrue(Self.calendars[2026]!.first { $0.observance.id == id }?.observance.isMajor == true, id)
        }
    }

    func testNewFestivalsAreSearchableInEveryLanguage() {
        for id in PanchangEngine.iosFirstObservanceIds {
            guard let observance = Self.calendars[2026]?.first(where: { $0.observance.id == id })?.observance
                    ?? PanchangEngine().observanceCalendar(year: 2026, city: .newDelhi).first(where: { $0.observance.id == id })?.observance
            else { return XCTFail(id) }
            XCTAssertNotNil(SearchCatalog.bundled.observance(engineId: id, name: observance.name), id)
        }
    }
}
