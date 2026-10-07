import Foundation
import XCTest
@testable import EkadashiCore

/// Ports test/unit/panchang_engine_test.dart, panchang_details_test.dart and
/// the engine gates of panchang_accuracy_test.dart, using the same fixtures.
final class PanchangEngineTests: XCTestCase {
    let engine = PanchangEngine()

    private func names(_ day: PanchangDay) -> [String] { day.observances.map(\.name) }
    private func ids(_ day: PanchangDay) -> [String] { day.observances.map(\.id) }

    // MARK: panchang_engine_test.dart

    func testPanchangDayUsesLocalSunriseAndCityCoordinates() throws {
        let delhi = engine.calculate(CivilDate(2026, 10, 4))
        let mumbai = engine.calculate(CivilDate(2026, 10, 4), city: .mumbai)
        XCTAssertEqual(delhi.city, .newDelhi)
        let sunrise = try XCTUnwrap(delhi.sunrise)
        let sunset = try XCTUnwrap(delhi.sunset)
        let rise = PanchangCity.newDelhi.wallClock(sunrise)
        let set = PanchangCity.newDelhi.wallClock(sunset)
        // USNO RSTT (2026-10-04, 28.6139 N, 77.2090 E): sunrise 06:16, sunset 18:04.
        XCTAssertLessThan(abs(rise.hour * 60 + rise.minute - (6 * 60 + 16)), 6)
        XCTAssertLessThan(abs(set.hour * 60 + set.minute - (18 * 60 + 4)), 6)
        XCTAssertEqual(delhi.tithi.name, "Navami")
        XCTAssertEqual(delhi.tithi.paksha, "Krishna")
        XCTAssertGreaterThan(secondsBetween(delhi.sunrise, mumbai.sunrise), 5 * 60)
    }

    func testLimbsAreSampledAtSunriseAndExposeTheirNextTransition() throws {
        let day = engine.calculate(CivilDate(2026, 10, 4))
        let sunrise = try XCTUnwrap(day.sunrise)
        for limb in [day.tithi, day.nakshatra, day.yoga, day.karana] {
            XCTAssertGreaterThan(limb.index, 0)
            XCTAssertFalse(limb.name.isEmpty)
            let end = try XCTUnwrap(limb.endsAt)
            XCTAssertGreaterThan(end, sunrise)
            XCTAssertLessThan(end.timeIntervalSince(sunrise), 48 * 3600)
        }
        XCTAssertTrue(["Shukla", "Krishna"].contains(day.tithi.paksha ?? ""))
    }

    func testMonthlyObservancesAreCalculatedLocally() {
        let day = engine.calculate(CivilDate(2026, 2, 15))
        XCTAssertTrue(names(day).contains("Maha Shivaratri"))
        XCTAssertTrue(day.observances.allSatisfy { $0.ruleSource == "calculated" })
    }

    func testSolarIngressIsIncludedOnTheIstCivilDate() {
        XCTAssertTrue(names(engine.calculate(CivilDate(2026, 1, 14))).contains("Makar Sankranti"))
    }

    func testAnnualObservancesUseTheirKalaRules() {
        let expectations: [(CivilDate, String)] = [
            (CivilDate(2026, 1, 23), "Vasant Panchami"),
            (CivilDate(2026, 3, 2), "Holika Dahan"),
            (CivilDate(2026, 3, 3), "Holi"),
            (CivilDate(2026, 4, 19), "Akshaya Tritiya"),
            (CivilDate(2026, 7, 29), "Guru Purnima"),
            (CivilDate(2026, 9, 14), "Ganesh Chaturthi"),
            (CivilDate(2026, 10, 20), "Vijayadashami"),
            (CivilDate(2026, 11, 8), "Deepavali"),
        ]
        for (date, name) in expectations {
            XCTAssertTrue(names(engine.calculate(date)).contains(name), "\(name) on \(date)")
        }
    }

    func testFullMoonBoundaryAgreesWithUsnoPhase() throws {
        // USNO 2026 full moon: March 3 at 11:38 UTC = 17:08 IST.
        let day = engine.calculate(CivilDate(2026, 3, 3))
        XCTAssertEqual(day.tithi.index, 15)
        let end = PanchangCity.newDelhi.wallClock(try XCTUnwrap(day.tithi.endsAt))
        XCTAssertLessThanOrEqual(abs(end.hour * 60 + end.minute - (17 * 60 + 8)), 2)
    }

    // MARK: panchang_details_test.dart

    func testHoraFollowsWeekdayRulerAndIsContiguous() {
        let day = engine.calculate(CivilDate(2026, 10, 4))
        XCTAssertEqual(day.hora.count, 24)
        XCTAssertEqual(day.hora.first?.name, "Sun")
        XCTAssertEqual(day.hora[1].name, "Venus")
        XCTAssertEqual(day.hora.first?.start, day.sunrise)
        XCTAssertEqual(day.hora[12].start, day.sunset)
        XCTAssertEqual(day.hora.last?.end, day.nextSunrise)
        for i in 1..<24 { XCTAssertEqual(day.hora[i].start, day.hora[i - 1].end) }
    }

    func testWednesdayExcludesAbhijitAndIncludesEighthDurMuhurta() throws {
        let day = engine.calculate(CivilDate(2026, 10, 7))
        XCTAssertNil(day.abhijit)
        let dur = day.additionalPeriods.filter { $0.name == "Dur Muhurta" }
        XCTAssertEqual(dur.count, 1)
        let length = try XCTUnwrap(day.sunset).timeIntervalSince(try XCTUnwrap(day.sunrise))
        XCTAssertEqual(dur[0].start.timeIntervalSince(day.sunrise!), length * 7 / 15, accuracy: 1)
    }

    func testIntercalaryJyeshtha2026IsIdentified() {
        let day = engine.calculate(CivilDate(2026, 5, 25))
        XCTAssertTrue(day.isAdhikaMonth)
        XCTAssertTrue(day.amantaMonth.contains("Adhika"))
        XCTAssertTrue((1...4).contains(day.nakshatraPada))
        XCTAssertTrue((24.0...25.0).contains(day.ayanamsa))
    }

    func testSundayNightFollowsItsOwnChoghadiyaOrder() {
        let day = engine.calculate(CivilDate(2027, 1, 3))
        XCTAssertEqual(day.choghadiya.dropFirst(8).map(\.name), [
            "Night · Shubh", "Night · Amrit", "Night · Chal", "Night · Rog",
            "Night · Kaal", "Night · Labh", "Night · Udveg", "Night · Shubh",
        ])
        XCTAssertFalse(day.lagna.isEmpty)
        XCTAssertEqual(day.lagna.first?.start, day.sunrise)
        XCTAssertEqual(day.lagna.last?.end, day.nextSunrise)
    }

    func testAdhikaMonthKeepsTheSameNameInBothConventions() {
        let day = engine.calculate(CivilDate(2026, 6, 11))
        XCTAssertEqual(day.amantaMonth, "Adhika Jyeshtha")
        XCTAssertEqual(day.purnimantaMonth, "Adhika Jyeshtha")
    }

    func testLimbTimelineKeepsTheFourLimbsInOrder() {
        let day = engine.calculate(CivilDate(2026, 10, 4))
        XCTAssertEqual(day.limbTimeline.map(\.name), ["Tithi", "Nakshatra", "Yoga", "Karana"])
        XCTAssertTrue(day.limbTimeline.allSatisfy { !$0.limbs.isEmpty && $0.limbs.count <= 8 })
    }

    func testFormatsTimesWithZoneAndDayMarker() throws {
        let day = engine.calculate(CivilDate(2026, 10, 4))
        let text = formatPanchangTime(day.sunrise, city: .newDelhi, date: day.date)
        XCTAssertTrue(text.hasSuffix("AM IST (UTC+05:30)"), text)
        XCTAssertEqual(formatPanchangTime(nil, city: .newDelhi, date: day.date), "—")
        let nextDay = formatPanchangTime(day.nextSunrise, city: .newDelhi, date: day.date)
        XCTAssertTrue(nextDay.hasSuffix("(+1 day)"), nextDay)
    }

    // MARK: panchang_accuracy_test.dart

    func testSunAndMoonRiseSetAgreeWithSwissEphemerisWithinASecond() throws {
        let fixture = try Repo.json("test/fixtures/panchang/swiss_rise_set_2027.json") as! [String: Any]
        let zones = ["new-delhi": "Asia/Kolkata", "london": "Europe/London",
                     "sydney": "Australia/Sydney", "new-york": "America/New_York"]
        for case let row as [String: Any] in fixture.array("events")! {
            let id = row.string("city")!
            let city = PanchangCity(id: id, label: id, latitude: row.double("lat")!,
                                    longitude: row.double("lon")!, timeZoneId: zones[id]!)
            let expected = instant(row.string("utc")!)
            let day = engine.calculate(city.wallClock(expected).date, city: city)
            let actual: Date?
            switch "\(row.string("body")!) \(row.string("event")!)" {
            case "sun rise": actual = day.sunrise
            case "sun set": actual = day.sunset
            case "moon rise": actual = day.moonrise
            default: actual = day.moonset
            }
            XCTAssertLessThan(secondsBetween(actual, expected), 1, "\(row)")
        }
    }

    func testPolarDateLineOddOffsetAndDstLocationsMatchSwissEphemeris() throws {
        let fixture = try Repo.json("test/fixtures/panchang/swiss_world_edges_2026.json") as! [String: Any]
        var failures: [String] = []
        for case let row as [String: Any] in fixture.array("cases")! {
            let city = PanchangCity(id: row.string("id")!, label: row.string("id")!,
                                    latitude: row.double("lat")!, longitude: row.double("lon")!,
                                    timeZoneId: row.string("tz")!)
            let date = CivilDate(iso: row.string("date")!)!
            let day = engine.calculate(date, city: city)
            func compare(_ key: String, _ actual: Date?) {
                let expected = row.string(key).map { instant($0) }
                if expected == nil || actual == nil {
                    if (expected == nil) != (actual == nil) { failures.append("\(city.id) \(date) \(key)") }
                    return
                }
                if secondsBetween(actual, expected) > 1 { failures.append("\(city.id) \(date) \(key)") }
            }
            compare("sunrise", day.sunrise)
            compare("moonrise", day.moonrise)
            compare("moonset", day.moonset)
            if let rise = row.string("sunrise"), let set = row.string("sunset"), set > rise {
                compare("sunset", day.sunset)
            }
            if let tithi = row.int("tithi"), day.tithi.index != tithi {
                failures.append("\(city.id) \(date) tithi \(day.tithi.index) vs \(tithi)")
            }
        }
        XCTAssertEqual(failures, [])
    }

    func testFestivalDatesMatchPublicIndianLists() throws {
        let fixture = try Repo.json("test/fixtures/panchang/festivals_india_2026_2027.json") as! [String: Any]
        func key(_ id: String, _ name: String) -> String? {
            switch id {
            case "vinayaka-chaturthi": return name == "Ganesh Chaturthi" ? "ganesh-chaturthi" : nil
            case "sankranti-9": return "makar-sankranti"
            case "sankranti-0": return "mesha-sankranti"
            default: return id
            }
        }
        var cache: [CivilDate: [String]] = [:]
        func keys(on date: CivilDate) -> [String] {
            if let hit = cache[date] { return hit }
            let value = engine.calculate(date).observances.compactMap { key($0.id, $0.name) }
            cache[date] = value
            return value
        }
        var failures: [String] = []
        for (festival, accepted) in fixture.dict("festivals")! {
            let dates = accepted as! [String]
            for year in Set(dates.map { String($0.prefix(4)) }) {
                let want = Set(dates.filter { $0.hasPrefix(year) })
                let first = CivilDate(iso: want.min()!)!
                let found = (-3...4).map { first.adding(days: $0) }.filter { keys(on: $0).contains(festival) }.map(\.iso)
                if found.count != 1 || !want.contains(found[0]) {
                    failures.append("\(festival) \(year): found \(found), accepted \(want.sorted())")
                }
            }
        }
        XCTAssertEqual(failures, [])
    }

    func testMakarSankrantiAfterSunsetIsObservedTheNextDay() {
        XCTAssertFalse(names(engine.calculate(CivilDate(2027, 1, 14))).contains("Makar Sankranti"))
        XCTAssertTrue(names(engine.calculate(CivilDate(2027, 1, 15))).contains("Makar Sankranti"))
    }

    func testSunsetJustAfterLocalMidnightBelongsToTheSolarDay() throws {
        let reykjavik = PanchangCity(id: "reykjavik", label: "Reykjavik", latitude: 64.1466,
                                     longitude: -21.9426, timeZoneId: "Atlantic/Reykjavik")
        let day = engine.calculate(CivilDate(2026, 6, 16), city: reykjavik)
        XCTAssertLessThanOrEqual(secondsBetween(day.sunset, utc(2026, 6, 17, 0, 0, 52)), 1)
        XCTAssertNotNil(day.rahukala)
    }

    func testSankrantiIsShownOnPolarDaysWithoutSunriseOrSunset() {
        let longyearbyen = PanchangCity(id: "longyearbyen", label: "Longyearbyen", latitude: 78.2232,
                                        longitude: 15.6267, timeZoneId: "Arctic/Longyearbyen")
        let winter = engine.calculate(CivilDate(2026, 12, 16), city: longyearbyen)
        XCTAssertNil(winter.sunrise)
        XCTAssertTrue(ids(winter).contains("sankranti-8"))
        let summer = engine.calculate(CivilDate(2026, 6, 15), city: longyearbyen)
        XCTAssertNil(summer.sunset)
        XCTAssertTrue(ids(summer).contains("sankranti-2"))
    }

    func testVancouverSunriseUsesTheUtcMinusSevenCivilDay() throws {
        let vancouver = PanchangCity(id: "vancouver", label: "Vancouver", latitude: 49.2827,
                                     longitude: -123.1207, timeZoneId: "America/Vancouver")
        XCTAssertEqual(vancouver.wallClock(utc(2026, 12, 1, 12)).offsetSeconds, -7 * 3600)
        let day = engine.calculate(CivilDate(2026, 12, 1), city: vancouver)
        XCTAssertEqual(vancouver.wallClock(try XCTUnwrap(day.sunrise)).hour, 8)
    }

    func testNewYorkMeshaSankrantiFallsOnItsLocalCivilDate() {
        XCTAssertFalse(ids(engine.calculate(CivilDate(2026, 4, 13), city: .newYork)).contains("sankranti-0"))
        XCTAssertTrue(ids(engine.calculate(CivilDate(2026, 4, 14), city: .newYork)).contains("sankranti-0"))
    }

    func testInvalidCoordinatesAndZonesAreRejected() {
        XCTAssertThrowsError(try PanchangCity(id: "x", label: "X", latitude: 91, longitude: 0).validate())
        XCTAssertThrowsError(try PanchangCity(id: "x", label: "X", latitude: 0, longitude: 0,
                                              timeZoneId: "Nowhere/Land").validate())
        XCTAssertThrowsError(try PanchangCity(id: "x", label: " ", latitude: 0, longitude: 0).validate())
        XCTAssertNoThrow(try PanchangCity.sydney.validate())
    }

    func testWorldwideCatalogLoadsAndSearches() throws {
        let cities = try PanchangCityCatalog.shared.cities()
        XCTAssertEqual(cities.count, 34152)
        let results = PanchangCityCatalog.shared.search("reykjavik")
        XCTAssertTrue(results.contains { $0.label.hasPrefix("Reykjav") && $0.timeZoneId == "Atlantic/Reykjavik" })
        XCTAssertTrue(PanchangCityCatalog.shared.search("").isEmpty)
    }
}
