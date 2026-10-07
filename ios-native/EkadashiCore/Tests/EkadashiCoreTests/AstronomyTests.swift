import Foundation
import XCTest
@testable import EkadashiCore

/// Ports test/unit/panchang_engine_test.dart (astronomy), panchang_ephemeris_test
/// and the position gate of panchang_accuracy_test against the same fixtures.
final class AstronomyTests: XCTestCase {
    private func arcseconds(_ a: Double, _ b: Double) -> Double {
        abs(AstronomyCalculator.signedAngle(a - b)) * 3600
    }

    func testMeeusLunarLongitudeExample() {
        // Meeus, Astronomical Algorithms, 2nd ed., Example 47.a (1992-04-12).
        XCTAssertEqual(AstronomyCalculator.moonLongitude(utc(1992, 4, 12)), 133.162655, accuracy: 0.03)
    }

    func testSunMoonAndLahiriAgreeWithSwissEphemerisToAnArcsecond() throws {
        let fixture = try Repo.json("test/fixtures/panchang/swiss_ephemeris_positions.json") as! [String: Any]
        for case let row as [String: Any] in fixture.array("samples")! {
            let date = instant(row.string("utc")!)
            XCTAssertLessThan(arcseconds(AstronomyCalculator.sunLongitude(date), row.double("sun")!), 0.5, "Sun \(date)")
            XCTAssertLessThan(arcseconds(AstronomyCalculator.moonLongitude(date), row.double("moon")!), 1.0, "Moon \(date)")
            XCTAssertLessThan(arcseconds(AstronomyCalculator.apparentLahiriAyanamsa(date), row.double("lahiri")!), 0.1, "Lahiri \(date)")
        }
    }

    func testLongitudesAgreeWithIndependent2026And2027Fixtures() throws {
        let fixture = try Repo.json("test/fixtures/panchang/ephemeris_2026_2027.json") as! [String: Any]
        var rows = fixture.array("samples")! as! [[String: Any]]
        for row in rows {
            let date = instant(row.string("utc")!)
            XCTAssertLessThan(abs(AstronomyCalculator.signedAngle(AstronomyCalculator.sunLongitude(date) - row.double("sun")!)), 0.01)
            XCTAssertLessThan(abs(AstronomyCalculator.signedAngle(AstronomyCalculator.moonLongitude(date) - row.double("moon")!)), 0.003)
        }
        rows.append(fixture.dict("boundary_sample")!)
        for row in rows {
            let date = instant(row.string("utc")!)
            let sidereal = AstronomyCalculator.normalize(
                AstronomyCalculator.moonLongitude(date) - AstronomyCalculator.apparentLahiriAyanamsa(date))
            XCTAssertLessThan(abs(AstronomyCalculator.signedAngle(sidereal - row.double("siderealMoon")!)), 0.003)
        }
    }

    func testAscendantAgreesWithIndependentHouseAngles() throws {
        let rows = try Repo.json("test/fixtures/panchang/ascendant_2027.json") as! [[String: Any]]
        for row in rows {
            let value = AstronomyCalculator.ascendantLongitude(
                instant(row.string("utc")!), latitude: row.double("latitude")!, longitude: row.double("longitude")!)
            XCTAssertLessThan(abs(AstronomyCalculator.signedAngle(value - row.double("ascendant")!)), 0.02)
        }
    }

    func testDeltaTFollowsTheTableAndItsTrend() {
        XCTAssertEqual(AstronomyCalculator.deltaTSeconds(2000), 63.83, accuracy: 1e-9)
        XCTAssertEqual(AstronomyCalculator.deltaTSeconds(2026.5), (68.90 + 68.80) / 2, accuracy: 1e-9)
        XCTAssertEqual(AstronomyCalculator.deltaTSeconds(2101), 93.18 + (93.18 - 92.72), accuracy: 1e-9)
    }

    func testJulianDayRoundTripsToTheMillisecond() {
        let date = instant("2026-10-04T00:51:12.345Z")
        let jd = AstronomyCalculator.julianDay(date)
        XCTAssertEqual(AstronomyCalculator.fromJulianDay(jd).timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
    }

    func testDartStyleModuloIsNeverNegative() {
        XCTAssertEqual(dartMod(-1.5, 1.0), 0.5)
        XCTAssertEqual(dartMod(-361.0, 360.0), 359.0)
        XCTAssertEqual(dartMod(-5, 30), 25)
        XCTAssertEqual(dartMod(31, 30), 1)
    }
}

/// The bundled IANA database must behave exactly like the Android app's.
final class TimeZoneDatabaseTests: XCTestCase {
    func testBundlesTheSameIanaReleaseAsAndroid() throws {
        let dart = try String(contentsOf: Repo.url("lib/services/time_zone_data.dart"), encoding: .utf8)
        XCTAssertTrue(dart.contains("timeZoneDataRelease = '\(TzDatabase.shared.release)'"))
        XCTAssertEqual(TzDatabase.shared.release, "2026b")
        XCTAssertGreaterThan(TzDatabase.shared.locationNames.count, 400)
    }

    func testBritishColumbiaStaysOnUtcMinusSevenFromNovember2026() throws {
        let vancouver = try XCTUnwrap(TzDatabase.shared.location("America/Vancouver"))
        XCTAssertEqual(vancouver.zone(at: utc(2026, 12, 1, 12)).offsetSeconds, -7 * 3600)
        XCTAssertEqual(vancouver.zone(at: utc(2026, 7, 1, 12)).offsetSeconds, -7 * 3600)
    }

    func testKolkataAndNewYorkOffsetsAndAbbreviations() throws {
        let kolkata = try XCTUnwrap(TzDatabase.shared.location("Asia/Kolkata"))
        let zone = kolkata.zone(at: utc(2026, 1, 1))
        XCTAssertEqual(zone.offsetSeconds, 19800)
        XCTAssertEqual(zone.abbreviation, "IST")
        let newYork = try XCTUnwrap(TzDatabase.shared.location("America/New_York"))
        XCTAssertEqual(newYork.zone(at: utc(2026, 1, 15)).abbreviation, "EST")
        XCTAssertEqual(newYork.zone(at: utc(2026, 7, 15)).abbreviation, "EDT")
        XCTAssertTrue(newYork.zone(at: utc(2026, 7, 15)).isDst)
    }

    func testLocalTimeInADaylightSavingGapMovesForwardLikeDart() throws {
        // 2026-03-08 02:30 does not exist in New York; package:timezone
        // returns 03:30 EDT (07:30 UTC).
        let newYork = try XCTUnwrap(TzDatabase.shared.location("America/New_York"))
        XCTAssertEqual(newYork.utc(year: 2026, month: 3, day: 8, hour: 2, minute: 30), utc(2026, 3, 8, 7, 30))
        // Midnight on an ordinary day.
        XCTAssertEqual(newYork.utc(year: 2026, month: 1, day: 5), utc(2026, 1, 5, 5))
        // Repeated hour on 1 November: the first (EDT) occurrence.
        XCTAssertEqual(newYork.utc(year: 2026, month: 11, day: 1, hour: 1, minute: 30), utc(2026, 11, 1, 5, 30))
    }

    func testHalfHourDaylightSavingAtLordHowe() throws {
        let lordHowe = try XCTUnwrap(TzDatabase.shared.location("Australia/Lord_Howe"))
        XCTAssertEqual(lordHowe.zone(at: utc(2026, 1, 15)).offsetSeconds, 11 * 3600)
        XCTAssertEqual(lordHowe.zone(at: utc(2026, 7, 15)).offsetSeconds, 10 * 3600 + 1800)
    }

    func testWallClockFieldsAndCivilDate() throws {
        let sydney = try XCTUnwrap(TzDatabase.shared.location("Australia/Sydney"))
        let clock = sydney.wallClock(utc(2026, 12, 31, 14))
        XCTAssertEqual(clock.date, CivilDate(2027, 1, 1))
        XCTAssertEqual(clock.hour, 1)
        XCTAssertEqual(clock.offsetSeconds, 11 * 3600)
        XCTAssertNil(TzDatabase.shared.location("Mars/Olympus_Mons"))
    }
}
