import Foundation
import XCTest
@testable import EkadashiCore

/// Independently generated references and domain invariants missing from the
/// previous aggregate score. Frozen before the implementation changed.
final class PanchangPrecisionTests: XCTestCase {
    private let engine = PanchangEngine()

    func testTuesdayAshleshaBeginsWithAnanda() {
        let day = engine.calculate(CivilDate(2026, 1, 6), city: .chennai)
        XCTAssertEqual(day.nakshatra.name, "Ashlesha")
        XCTAssertEqual(day.anandadiYoga, "Ananda", "Tuesday counts from Ashlesha, not Pushya")
    }

    func testApparentLagnaMatchesIndependentSwissGeometry() throws {
        let fixture = try Repo.json("test/fixtures/panchang/precision_regressions.json") as! [String: Any]
        for row in fixture["ascendants"] as! [[String: Any]] {
            let time = instant(row["utc"] as! String)
            let city = PanchangCity(id: "fixture", label: "Fixture", latitude: row["lat"] as! Double,
                                    longitude: row["lon"] as! Double, timeZoneId: "UTC")
            let angle = AstronomyCalculator.normalize(AstronomyCalculator.ascendantLongitude(time, latitude: city.latitude,
                                                                                            longitude: city.longitude)
                - AstronomyCalculator.apparentLahiriAyanamsa(time))
            let error = abs(AstronomyCalculator.signedAngle(angle - (row["siderealLongitude"] as! Double))) * 3600
            XCTAssertLessThan(error, 0.2, "Consistent true equinox and obliquity: \(row)")
            let first = try XCTUnwrap(engine.lagna(time, time.addingTimeInterval(86400), city).first)
            XCTAssertLessThan(abs(first.end.timeIntervalSince(instant(row["firstLagnaEndsUtc"] as! String))), 0.2,
                              "The Panchang caller must use the same apparent ayanamsa")
        }
    }

    func testGrazingSunriseAndSunsetAreNotLostBetweenFiveMinuteSamples() throws {
        let fixture = try Repo.json("test/fixtures/panchang/precision_regressions.json") as! [String: Any]
        let row = fixture["grazing"] as! [String: Any]
        let city = PanchangCity(id: "grazing", label: "Grazing horizon", latitude: row["lat"] as! Double,
                                longitude: row["lon"] as! Double, timeZoneId: "UTC")
        let day = engine.calculate(CivilDate(2026, 12, 21), city: city)
        let sunrise = try XCTUnwrap(day.sunrise), sunset = try XCTUnwrap(day.sunset)
        XCTAssertLessThan(abs(sunrise.timeIntervalSince(instant(row["sunriseUtc"] as! String))), 3)
        XCTAssertLessThan(abs(sunset.timeIntervalSince(instant(row["sunsetUtc"] as! String))), 3)
        XCTAssertLessThan(sunset.timeIntervalSince(sunrise), 100)
        // The same roots must be found in ranges shorter than one scan step.
        let a = instant("2026-12-21T12:01:00Z"), b = instant("2026-12-21T12:04:00Z")
        XCTAssertNotNil(engine.findCrossing(a, b, city, moon: false, rising: true))
        XCTAssertNotNil(engine.findCrossing(a, b, city, moon: false, rising: false))
        XCTAssertNil(engine.findCrossing(a, instant("2026-12-21T12:01:30Z"), city, moon: false, rising: true))
    }

    func testStoredStartsNeverPrecedeTheCalculatedBoundary() throws {
        let raw = try CalculatedEkadashiEngine().calculate(start: CivilDate(2026, 1, 1), count: 20,
                                                         city: .chennai, tradition: .smarta).first!
        let schedule = EkadashiSchedule(repository: try CalendarRepository.bundled())
        let stored = try schedule.scheduled(EkadashiScheduleKey(city: .chennai, tradition: .smarta, year: 2026)).first!
        let start = try XCTUnwrap(ISO8601.instant(stored.paranaStart))
        XCTAssertGreaterThanOrEqual(start, raw.paranaStart!)
        XCTAssertLessThan(start.timeIntervalSince(raw.paranaStart!), 0.002)
        let fasting = try XCTUnwrap(ISO8601.instant(stored.fastingStart))
        XCTAssertGreaterThanOrEqual(fasting, raw.fastStarts)
        XCTAssertLessThan(fasting.timeIntervalSince(raw.fastStarts), 0.002)
    }

    func testAnAfterOnlyParanaDoesNotAcquireAnInventedEnd() throws {
        let schedule = EkadashiSchedule(repository: try CalendarRepository.bundled())
        let stored = try schedule.scheduled(EkadashiScheduleKey(city: .newYork, tradition: .smarta, year: 2026))
            .first { $0.date == "2026-12-19" }!
        XCTAssertEqual(stored.paranaEnd, "")
        let event = try schedule.ekadashis(city: .newYork, tradition: .smarta, language: "en", years: [2026])
            .first { $0.date.iso == "2026-12-19" }!
        XCTAssertNil(event.paranaEnd)
        XCTAssertTrue(event.fastBreakTime.hasPrefix("After "))
    }

    func testNarrowParanaDisplayStaysWithinItsCalculatedWindow() {
        XCTAssertEqual(EkadashiTimeFormat.window("2027-09-13T06:04:56.374+05:30", "2027-09-13T06:05:09.097+05:30"),
                       "06:04:57 AM - 06:05:09 AM")
        XCTAssertEqual(EkadashiTimeFormat.window("2026-12-20T15:05:32.063-05:00", ""), "After 03:05:33 PM")
        XCTAssertEqual(EkadashiTimeFormat.window("", ""), "")
    }
}
