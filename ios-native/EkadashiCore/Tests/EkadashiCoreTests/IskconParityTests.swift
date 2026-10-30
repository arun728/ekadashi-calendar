import Foundation
import XCTest
@testable import EkadashiCore

/// Vaishnava (ISKCON) fasts and Parana match GCal 11, the GBC Calendar
/// Committee's program that ISKCON calendars are made with, as published by
/// vaisnavacalendar.info for 67 cities worldwide in 2026 and 2027
/// (test/fixtures/panchang/gcal11_ekadashi_2026_2027.json,
/// iskcon_parity_test.dart). GCal shows times cut to the minute in local time.
final class IskconParityTests: XCTestCase {
    private func fixture() throws -> [[String: Any]] {
        (try Repo.json("test/fixtures/panchang/gcal11_ekadashi_2026_2027.json") as! [String: Any]).array("cities") as! [[String: Any]]
    }

    private func city(_ row: [String: Any]) -> PanchangCity {
        PanchangCity(id: row.string("name")!, label: row.string("name")!, latitude: row.double("lat")!,
                     longitude: row.double("lon")!, timeZoneId: row.string("tz")!)
    }

    /// Both tests read the same 134 city-years, calculated once.
    nonisolated(unsafe) private static var cache: [String: [String: CalculatedEkadashi]] = [:]

    private func fasts(_ city: PanchangCity, _ year: Int) throws -> [String: CalculatedEkadashi] {
        if let cached = Self.cache["\(city.id)|\(year)"] { return cached }
        let found = try calculate(city, year)
        Self.cache["\(city.id)|\(year)"] = found
        return found
    }

    private func calculate(_ city: PanchangCity, _ year: Int) throws -> [String: CalculatedEkadashi] {
        let start = CivilDate(year, 1, 1)
        let count = CivilDate(year + 1, 1, 1).daysSinceEpoch - start.daysSinceEpoch
        return Dictionary(try CalculatedEkadashiEngine().calculate(start: start, count: count, city: city, tradition: .gaudiya)
            .map { ($0.date.iso, $0) }, uniquingKeysWith: { a, _ in a })
    }

    private func shown(_ instant: Date?, _ city: PanchangCity) -> String? {
        guard let instant else { return nil }
        let wall = city.displayClock(instant)
        return "\(pad2(wall.hour)):\(pad2(wall.minute))"
    }

    func testFastDaysMatchGcal11In67Cities() throws {
        var failures: [String] = []
        var total = 0
        for row in try fixture() {
            let place = city(row)
            for (year, list) in row.dict("years")! {
                let expected = Set((list as! [[String: Any]]).map { $0.string("date")! })
                let found = Set(try fasts(place, Int(year)!).keys)
                total += expected.count
                if found != expected {
                    failures.append("\(place.id) \(year): engine only \(found.subtracting(expected).sorted()), GCal only \(expected.subtracting(found).sorted())")
                }
            }
        }
        XCTAssertGreaterThan(total, 3000)
        XCTAssertEqual(failures, [])
    }

    func testParanaMatchesGcal11ToTheMinute() throws {
        var matched = 0, total = 0
        var far: [String] = []
        for row in try fixture() {
            let place = city(row)
            for (year, list) in row.dict("years")! {
                let found = try fasts(place, Int(year)!)
                for gcal in list as! [[String: Any]] {
                    guard let fast = found[gcal.string("date")!] else { continue }
                    XCTAssertEqual(fast.paranaDate.iso, gcal.string("paranaDate"), "\(place.id) \(fast.date)")
                    for (want, actual) in [(gcal.string("paranaStart"), fast.paranaStart), (gcal.string("paranaEnd"), fast.paranaEnd)] {
                        guard let want else { continue }
                        total += 1
                        let got = shown(actual, place)
                        if got == want { matched += 1; continue }
                        // Only a GCal build difference of seconds may remain.
                        let minutes = { (s: String?) -> Int in
                            guard let s else { return -9999 }
                            return Int(s.prefix(2))! * 60 + Int(s.suffix(2))!
                        }
                        if abs(minutes(got) - minutes(want)) > 1 { far.append("\(place.id) \(fast.date): \(got ?? "none") vs \(want)") }
                    }
                }
            }
        }
        XCTAssertGreaterThan(total, 6000)
        XCTAssertEqual(far, [])
        XCTAssertGreaterThanOrEqual(Double(matched) / Double(total), 0.99, "\(matched)/\(total)")
    }
}
