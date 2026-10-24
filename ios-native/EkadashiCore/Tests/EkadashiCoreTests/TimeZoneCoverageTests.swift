import Foundation
import XCTest
@testable import EkadashiCore

final class TimeZoneCoverageTests: XCTestCase {
    func testRecurringSummerTimeContinuesAfter2037() throws {
        for year in [2038, 2050, 2100, 2101] {
            for (name, expected) in [("Europe/London", 3600), ("Europe/Oslo", 7200),
                                     ("America/New_York", -14400), ("Australia/Sydney", 36000)] {
                let zone = try XCTUnwrap(TzDatabase.shared.location(name))
                XCTAssertEqual(zone.zone(at: utc(year, 7, 15, 12)).offsetSeconds, expected, "\(name) \(year)")
            }
        }
    }

    func testHistoricalOffsetBeforeFirstRealTransitionIsPreserved() throws {
        for (name, expected) in [("Africa/Luanda", 815), ("America/Detroit", -19931)] {
            let zone = try XCTUnwrap(TzDatabase.shared.location(name))
            XCTAssertEqual(zone.zone(at: utc(1900, 6, 21, 12)).offsetSeconds, expected, name)
        }
    }

    func testEveryIanaZoneAcross1900Through2100MatchesIndependentTzif() throws {
        let fixture = try Repo.json("test/fixtures/time_zones/iana_2026b_1900_2100.json") as! [String: Any]
        let dates = (fixture["utc"] as! [String]).map { instant($0) }
        let expected = fixture["offsetSecondsByZone"] as! [String: [Int]]
        var failures = 0
        var examples: [String] = []
        for (name, offsets) in expected.sorted(by: { $0.key < $1.key }) {
            let zone = try XCTUnwrap(TzDatabase.shared.location(name), name)
            XCTAssertEqual(offsets.count, dates.count)
            for (date, offset) in zip(dates, offsets) {
                let actual = zone.zone(at: date).offsetSeconds
                if actual != offset {
                    failures += 1
                    if examples.count < 12 { examples.append("\(name) \(date): \(actual), expected \(offset)") }
                }
            }
        }
        XCTAssertEqual(failures, 0, examples.joined(separator: "\n"))
    }

    func testPolarFallbackSampleUsesCorrectLocalSixAMIn2100() {
        let city = PanchangCity(id: "tromso", label: "Tromso", latitude: 69.6492,
                                longitude: 18.9553, timeZoneId: "Europe/Oslo")
        let day = PanchangEngine().calculate(CivilDate(2100, 6, 21), city: city)
        XCTAssertNil(day.sunrise)
        // Independent Swiss Ephemeris: tithi 14 ends at 04:00:17 UTC.
        // Local 06:00 is 04:00 UTC under the pinned IANA summer-time rule.
        XCTAssertEqual(day.tithi.index, 14)
        XCTAssertEqual(day.karana.index, 28)
    }

    func testSchedulesDoNotReuseCachesCalculatedWithTruncatedTimezoneData() {
        let key = EkadashiScheduleKey(city: .london, tradition: .smarta, year: 2100)
        XCTAssertFalse(key.cacheId.hasPrefix("schedule-2|"), "Old disk caches contain the wrong future wall-clock times")
    }
}
