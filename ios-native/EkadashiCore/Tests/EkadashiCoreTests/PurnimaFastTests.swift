import Foundation
import XCTest
@testable import EkadashiCore

/// Purnima is listed once, on its fast (Upavasa) day, as Drik Panchang,
/// Prokerala and AstroSage list it: the day Purnima begins if it has begun
/// by the end of that day's Madhyahna (three fifths of daylight), else the
/// next day (test/fixtures/panchang/purnima_fasts.json, purnima_fast_test.dart).
final class PurnimaFastTests: XCTestCase {
    let engine = PanchangEngine()

    private func fixture() throws -> [String: Any] {
        try Repo.json("test/fixtures/panchang/purnima_fasts.json") as! [String: Any]
    }

    private func delhi() throws -> PanchangCity {
        let c = try fixture().dict("city")!
        return PanchangCity(id: c.string("id")!, label: c.string("label")!, latitude: c.double("lat")!,
                            longitude: c.double("lon")!, timeZoneId: c.string("tz")!)
    }

    private func isPurnima(_ date: CivilDate, _ city: PanchangCity) -> Bool {
        engine.calculate(date, city: city).observances.contains { $0.id == "purnima" }
    }

    func testPurnimaIsListedOnItsFastDayOnly() throws {
        let city = try delhi()
        var failures: [String] = []
        for case let row as [String: Any] in try fixture().array("fasts")! {
            let date = CivilDate(iso: row.string("date")!)!
            if !isPurnima(date, city) { failures.append("\(date): not Purnima") }
            for other in [date.adding(days: -1), date.adding(days: 1)] where isPurnima(other, city) {
                failures.append("\(date): Purnima also on \(other)")
            }
        }
        XCTAssertEqual(failures, [])
    }

    func testSharadPurnima2026IsTheFastDayNotTheNextDay() throws {
        let city = try delhi()
        XCTAssertTrue(isPurnima(CivilDate(2026, 10, 25), city))
        XCTAssertFalse(isPurnima(CivilDate(2026, 10, 26), city))
    }

    func testPurnimaIsListedOncePerLunarMonth() throws {
        let city = try delhi()
        for (year, count) in [(2026, 13), (2027, 12)] {
            var found = 0
            var day = CivilDate(year, 1, 1)
            while day.year == year {
                if isPurnima(day, city) { found += 1 }
                day = day.adding(days: 1)
            }
            XCTAssertEqual(found, count, "\(year)")
        }
    }
}
