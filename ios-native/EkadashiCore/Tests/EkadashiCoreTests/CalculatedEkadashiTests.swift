import Foundation
import XCTest
@testable import EkadashiCore

/// Ports test/unit/calculated_ekadashi_test.dart (rule table),
/// panchang_2027_test.dart (GCAL) and the Ekadashi gates of
/// panchang_accuracy_test.dart.
final class EkadashiRulesTests: XCTestCase {
    private let start = CivilDate(2026, 1, 1)

    private func sample(_ day: Int, _ tithi: Int, arunodaya: Int? = nil, nakshatra: Int = 1,
                        sunsetTithi: Int? = nil) -> EkadashiSample {
        let date = start.adding(days: day)
        return EkadashiSample(date: date,
                              sunrise: date.utcMidnight.addingTimeInterval(6 * 3600),
                              sunset: date.utcMidnight.addingTimeInterval(18 * 3600),
                              tithi: tithi, arunodayaTithi: arunodaya ?? tithi,
                              sunsetTithi: sunsetTithi ?? tithi, nakshatra: nakshatra)
    }

    /// Smarta decisions need sunrises two days before to three days after.
    private func smarta(_ days: [EkadashiSample], _ index: Int) -> String? {
        let first = days.first!.tithi, last = days.last!.tithi
        let padded = [sample(-2, first - 2), sample(-1, first - 1)] + days +
            [sample(days.count, last + 1), sample(days.count + 1, last + 2), sample(days.count + 2, last + 3)]
        return EkadashiRules.select(padded, index + 2, .smarta)
    }

    func testSmartaSunriseVersusGaudiyaDashamiContamination() {
        let days = [sample(0, 10), sample(1, 11, arunodaya: 10), sample(2, 12), sample(3, 13), sample(4, 14)]
        XCTAssertEqual(smarta(days, 1), "Sunrise Ekadashi")
        XCTAssertNil(EkadashiRules.select(days, 1, .gaudiya))
        XCTAssertEqual(EkadashiRules.select(days, 2, .gaudiya), "Viddha / shifted to Dwadashi")
    }

    func testRepeatedEkadashiWithExtendedDwadashiIsTheSecondDay() {
        let days = [sample(0, 10), sample(1, 11), sample(2, 11), sample(3, 12), sample(4, 13)]
        XCTAssertNil(smarta(days, 1))
        XCTAssertNotNil(smarta(days, 2))
        XCTAssertNil(EkadashiRules.select(days, 1, .gaudiya))
        XCTAssertEqual(EkadashiRules.select(days, 2, .gaudiya), "Unmilani")
    }

    func testRepeatedEkadashiWithoutExtendedDwadashiIsTheFirstDay() {
        let days = [sample(0, 10), sample(1, 11), sample(2, 11), sample(3, 13), sample(4, 14)]
        XCTAssertNotNil(smarta(days, 1))
        XCTAssertNil(smarta(days, 2))
    }

    func testSmartaSkippedEkadashiOrDwadashiFastsOnTheDashamiDay() {
        let skippedEkadashi = [sample(0, 9), sample(1, 10), sample(2, 12), sample(3, 13), sample(4, 14)]
        XCTAssertNotNil(smarta(skippedEkadashi, 1))
        XCTAssertNil(smarta(skippedEkadashi, 2))
        let skippedDwadashi = [sample(0, 9), sample(1, 10), sample(2, 11), sample(3, 13), sample(4, 14)]
        XCTAssertNotNil(smarta(skippedDwadashi, 1))
        XCTAssertNil(smarta(skippedDwadashi, 2))
    }

    func testDwadashiKshayaSelectsTrisprishaAndExtendedDwadashiVyanjuli() {
        XCTAssertEqual(EkadashiRules.select([sample(0, 10), sample(1, 11), sample(2, 13), sample(3, 14)], 1, .gaudiya),
                       "Trisprisha")
        let extended = [sample(0, 10), sample(1, 11), sample(2, 12), sample(3, 12), sample(4, 13)]
        XCTAssertNil(EkadashiRules.select(extended, 1, .gaudiya))
        XCTAssertEqual(EkadashiRules.select(extended, 2, .gaudiya), "Vyanjuli")
    }

    func testNakshatraMahadvadashiIsExplicit() {
        let days = [sample(0, 10), sample(1, 11), sample(2, 12, nakshatra: 4), sample(3, 13, nakshatra: 4), sample(4, 14)]
        XCTAssertEqual(EkadashiRules.select(days, 2, .gaudiya), "Jayanti")
        XCTAssertNil(EkadashiRules.select(days, 1, .gaudiya))
    }

    func testMissingSunriseNeverProducesAFast() {
        let days = [sample(0, 10),
                    EkadashiSample(date: start, sunrise: nil, sunset: nil, tithi: 11, arunodayaTithi: 11,
                                   sunsetTithi: 11, nakshatra: 1),
                    sample(2, 12)]
        XCTAssertNil(smarta(days, 1))
    }

    func testPakshavardhiniIsNotBypassed() {
        let days = [sample(0, 10), sample(1, 11), sample(2, 12), sample(3, 13), sample(4, 14),
                    sample(5, 15), sample(6, 15), sample(7, 16)]
        XCTAssertNil(EkadashiRules.select(days, 1, .gaudiya))
        XCTAssertEqual(EkadashiRules.select(days, 2, .gaudiya), "Pakshavardhini")
    }
}

final class CalculatedEkadashiEngineTests: XCTestCase {
    let engine = CalculatedEkadashiEngine()
    let chennai = PanchangCity(id: "chennai", label: "Chennai", latitude: 13.0827, longitude: 80.2707)
    let bengaluru = PanchangCity(id: "bengaluru", label: "Bengaluru", latitude: 12.9716, longitude: 77.5946)

    func testRejectsRangesOutsideOneTo366Days() {
        XCTAssertThrowsError(try engine.calculate(start: CivilDate(2027, 1, 1), count: 0, city: .newDelhi, tradition: .smarta))
        XCTAssertThrowsError(try engine.calculate(start: CivilDate(2027, 1, 1), count: 367, city: .newDelhi, tradition: .smarta))
    }

    func testDelhi2027SmartaFastsAndParanaMatchPublishedDrikData() throws {
        let data = try Repo.json("assets/calendar/2027.json") as! [String: Any]
        let fasts = Dictionary(uniqueKeysWithValues: try engine.calculate(
            start: CivilDate(2027, 1, 1), count: 365, city: .newDelhi, tradition: .smarta).map { ($0.date.iso, $0) })
        var published = Set<String>()
        for case let entry as [String: Any] in data.array("ekadashis")! {
            let timing = entry.dict("timing")!.dict("IST")!
            let date = timing.string("date")!
            published.insert(date)
            let fast = try XCTUnwrap(fasts[date], "\(entry.dict("name")!.string("en")!) \(date)")
            XCTAssertLessThanOrEqual(secondsBetween(fast.paranaStart, instant(timing.string("parana_start")!)), 120, "start \(date)")
            XCTAssertLessThanOrEqual(secondsBetween(fast.paranaEnd, instant(timing.string("parana_end")!)), 120, "end \(date)")
        }
        let last = published.max()!
        XCTAssertEqual(Set(fasts.keys.filter { $0 <= last }), published)
    }

    func testSmartaSkippedAndRepeatedEkadashiFollowDrikInChennai() throws {
        let dates = Set(try engine.calculate(start: CivilDate(2026, 5, 20), count: 200, city: chennai,
                                             tradition: .smarta).map(\.date.iso))
        XCTAssertTrue(dates.contains("2026-05-27"))
        XCTAssertFalse(dates.contains("2026-05-26"))
        XCTAssertTrue(dates.contains("2026-07-10"))
        XCTAssertFalse(dates.contains("2026-07-11"))
        XCTAssertTrue(dates.contains("2026-11-20"))
        XCTAssertFalse(dates.contains("2026-11-21"))
    }

    func testGaudiyaFastsMatchTheIskconBangalorePublishedCalendar() throws {
        // https://www.iskconbangalore.org/ekadashi-calendar/ (March 2026 to March 2027).
        let published: [String: String?] = [
            "2026-03-15": nil, "2026-03-29": nil, "2026-04-13": nil, "2026-04-27": nil,
            "2026-05-13": nil, "2026-05-27": nil, "2026-06-11": nil, "2026-06-25": nil,
            "2026-07-11": "Viddha / shifted to Dwadashi", "2026-07-25": nil, "2026-08-09": nil,
            "2026-08-24": "Vyanjuli", "2026-09-07": nil, "2026-09-22": nil, "2026-10-06": nil,
            "2026-10-22": nil, "2026-11-05": nil, "2026-11-21": "Trisprisha", "2026-12-04": nil,
            "2026-12-20": nil, "2027-01-03": nil, "2027-01-19": "Trisprisha", "2027-02-02": nil,
            "2027-02-17": nil, "2027-03-04": "Unmilani", "2027-03-18": nil,
        ]
        var fasts: [String: String] = [:]
        for (start, count) in [(CivilDate(2026, 3, 10), 300), (CivilDate(2027, 1, 1), 90)] {
            for fast in try engine.calculate(start: start, count: count, city: bengaluru, tradition: .gaudiya) {
                fasts[fast.date.iso] = fast.rule
            }
        }
        let inRange = fasts.filter { $0.key >= "2026-03-15" && $0.key <= "2027-03-18" }
        XCTAssertEqual(Set(inRange.keys), Set(published.keys))
        for (date, rule) in published { if let rule { XCTAssertEqual(inRange[date], rule, date) } }
    }

    func testGaudiya2027FullYearMatchesGcalInFourCities() throws {
        let fixture = try Repo.json("test/fixtures/panchang/gaurabda_raw_2026_2027.json") as! [String: Any]
        for city in [PanchangCity.newDelhi, .newYork, .london, .sydney] {
            let rows = fixture.dict("profiles")!.dict("2027")!.array(city.id)! as! [[String: Any]]
            var expected = Set(rows.map { $0.string("date")! })
            // The raw Python port's EV_NULL sentinel bypasses Pakshavardhini.
            if city == .newDelhi {
                expected.remove("2027-06-14")
                expected.insert("2027-06-15")
            }
            let actual = try engine.calculate(start: CivilDate(2027, 1, 1), count: 365, city: city, tradition: .gaudiya)
            XCTAssertEqual(Set(actual.map(\.date.iso)), expected, city.label)
            for fast in actual {
                let paranaStart = try XCTUnwrap(fast.paranaStart)
                XCTAssertGreaterThan(paranaStart, fast.fastStarts)
                if let end = fast.paranaEnd { XCTAssertGreaterThan(end, paranaStart) }
                guard let row = rows.first(where: { $0.string("date") == fast.date.iso }), !fast.nearBoundary else { continue }
                let parana = row.dict("parana")!
                for (actualTime, key) in [(fast.paranaStart, "startTime"), (fast.paranaEnd, "endTime")] {
                    let hours = parana.double(key)!
                    if hours < 0 {
                        XCTAssertNil(actualTime)
                        continue
                    }
                    let expectedInstant = fast.date.adding(days: 1).utcMidnight
                        .addingTimeInterval((hours - row.double("paranaOffset")!) * 3600)
                    XCTAssertLessThan(secondsBetween(actualTime, expectedInstant), 180, "\(city.label) \(fast.date) \(key)")
                }
            }
        }
    }

    func testEkadashiNamesFollowTheAmantaMonthAndAdhika() throws {
        let fasts = try engine.calculate(start: CivilDate(2026, 5, 1), count: 60, city: .newDelhi, tradition: .smarta)
        let names = fasts.map(\.name)
        XCTAssertTrue(names.contains("Padmini Ekadashi") || names.contains("Parama Ekadashi"), "\(names)")
        XCTAssertEqual(CalculatedEkadashi.ruleVersion, "current-location-v2")
    }
}
