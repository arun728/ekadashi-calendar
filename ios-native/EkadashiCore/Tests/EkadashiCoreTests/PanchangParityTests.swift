import Foundation
import XCTest
@testable import EkadashiCore

/// Field-by-field parity with the Flutter engine, from
/// test/tool/dump_panchang_parity_test.dart: 112 days in eight cities (polar,
/// DST, date-line and odd-offset zones) over 2026-2030, and 120 days of
/// Smarta and Gaudiya fasts in 2028 in three cities.
final class PanchangParityTests: XCTestCase {
    let engine = PanchangEngine()

    private func fixture() throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(contentsOf: Repo.url(
            "ios-native/EkadashiCore/Tests/EkadashiCoreTests/Fixtures/panchang_parity.json"))) as! [String: Any]
    }

    private func same(_ actual: Date?, _ expected: Any?, _ label: String, _ failures: inout [String]) {
        let wanted = (expected as? String).map { instant($0) }
        if (actual == nil) != (wanted == nil) || secondsBetween(actual, wanted) > 1 && actual != nil {
            failures.append("\(label): \(String(describing: actual)) vs \(String(describing: expected))")
        }
    }

    private func samePeriod(_ actual: PanchangPeriod?, _ expected: Any?, _ label: String, _ failures: inout [String]) {
        let row = expected as? [String: Any]
        if (actual == nil) != (row == nil) {
            failures.append("\(label): presence")
            return
        }
        guard let actual, let row else { return }
        if actual.name != row.string("name") { failures.append("\(label): \(actual.name) vs \(row.string("name") ?? "")") }
        same(actual.start, row["start"], "\(label) start", &failures)
        same(actual.end, row["end"], "\(label) end", &failures)
    }

    private func sameLimb(_ actual: PanchangLimb, _ expected: [String: Any], _ label: String, _ failures: inout [String]) {
        if actual.index != expected.int("index") || actual.name != expected.string("name") || actual.paksha != expected.string("paksha") {
            failures.append("\(label): \(actual.index) \(actual.name) vs \(expected)")
        }
        same(actual.endsAt, expected["end"], "\(label) end", &failures)
    }

    func testEveryPanchangFieldMatchesTheFlutterEngine() throws {
        var failures: [String] = []
        for case let row as [String: Any] in try fixture().array("days")! {
            let c = row.dict("city")!
            let city = PanchangCity(id: c.string("id")!, label: c.string("label")!, latitude: c.double("lat")!,
                                    longitude: c.double("lon")!, timeZoneId: c.string("tz")!)
            let date = CivilDate(iso: row.string("date")!)!
            let day = engine.calculate(date, city: city)
            let key = "\(city.id) \(date)"
            same(day.sunrise, row["sunrise"], "\(key) sunrise", &failures)
            same(day.sunset, row["sunset"], "\(key) sunset", &failures)
            same(day.moonrise, row["moonrise"], "\(key) moonrise", &failures)
            same(day.moonset, row["moonset"], "\(key) moonset", &failures)
            same(day.nextSunrise, row["nextSunrise"], "\(key) nextSunrise", &failures)
            sameLimb(day.tithi, row.dict("tithi")!, "\(key) tithi", &failures)
            sameLimb(day.nakshatra, row.dict("nakshatra")!, "\(key) nakshatra", &failures)
            sameLimb(day.yoga, row.dict("yoga")!, "\(key) yoga", &failures)
            sameLimb(day.karana, row.dict("karana")!, "\(key) karana", &failures)
            let scalars: [(String, String?)] = [
                ("vara", day.vara), ("amanta", day.amantaMonth), ("purnimanta", day.purnimantaMonth), ("ritu", day.ritu),
                ("ayana", day.ayana), ("sunRashi", day.sunRashi), ("moonRashi", day.moonRashi), ("anandadi", day.anandadiYoga),
                ("formattedSunrise", formatPanchangTime(day.sunrise, city: city, date: date)),
            ]
            for (name, value) in scalars where value != row.string(name) {
                failures.append("\(key) \(name): \(value ?? "nil") vs \(row.string(name) ?? "nil")")
            }
            if day.isAdhikaMonth != (row["adhika"] as? Bool) { failures.append("\(key) adhika") }
            if day.nakshatraPada != row.int("pada") || day.shakaYear != row.int("shaka") || day.vikramaYear != row.int("vikrama") {
                failures.append("\(key) pada/shaka/vikrama")
            }
            if abs(day.ayanamsa - row.double("ayanamsa")!) > 1e-9 { failures.append("\(key) ayanamsa") }
            if day.specialYogas != row["specialYogas"] as? [String] { failures.append("\(key) special yogas \(day.specialYogas)") }
            same(day.sunRashiEndsAt, row["sunRashiEnd"], "\(key) sun rashi end", &failures)
            same(day.moonRashiEndsAt, row["moonRashiEnd"], "\(key) moon rashi end", &failures)
            same(day.padaEndsAt, row["padaEnd"], "\(key) pada end", &failures)
            let periods = row.array("periods")!
            for (i, period) in [day.rahukala, day.yamaganda, day.gulika, day.abhijit, day.brahmaMuhurta].enumerated() {
                samePeriod(period, periods[i] is NSNull ? nil : periods[i], "\(key) period \(i)", &failures)
            }
            for (name, list) in [("choghadiya", day.choghadiya), ("hora", day.hora), ("additional", day.additionalPeriods),
                                 ("lagna", day.lagna)] {
                let expected = row.array(name)!
                if list.count != expected.count {
                    failures.append("\(key) \(name) count \(list.count) vs \(expected.count)")
                    continue
                }
                for (i, period) in list.enumerated() { samePeriod(period, expected[i], "\(key) \(name) \(i)", &failures) }
            }
            let timeline = row.dict("timeline")!
            for entry in day.limbTimeline {
                let expected = timeline.array(entry.name)! as! [[String: Any]]
                if entry.limbs.count != expected.count {
                    failures.append("\(key) timeline \(entry.name) count")
                    continue
                }
                for (i, limb) in entry.limbs.enumerated() { sameLimb(limb, expected[i], "\(key) \(entry.name) \(i)", &failures) }
            }
            let observances = row.array("observances")! as! [[String: Any]]
            // Festivals added on iOS first (Phase 3) join the Dart engine with the Android port.
            let actual = day.observances.filter { !PanchangEngine.iosFirstObservanceIds.contains($0.id) }
                .map { "\($0.id)|\($0.name)|\($0.description)|\($0.isMajor)" }
            let wanted = observances.map { "\($0.string("id")!)|\($0.string("name")!)|\($0.string("description")!)|\($0["major"] as! Bool)" }
            if actual != wanted { failures.append("\(key) observances \(actual) vs \(wanted)") }
        }
        XCTAssertEqual(failures, [], failures.prefix(20).joined(separator: "\n"))
    }

    func testCalculatedFastsMatchTheFlutterEngine() throws {
        let rows = try fixture().array("fasts")! as! [[String: Any]]
        let cities = ["new-delhi": PanchangCity.newDelhi, "new-york": .newYork, "sydney": .sydney]
        var failures: [String] = []
        for (id, city) in cities {
            for tradition in EkadashiTradition.allCases {
                let expected = rows.filter { $0.string("city") == id && $0.string("tradition") == tradition.rawValue }
                let actual = try CalculatedEkadashiEngine().calculate(start: CivilDate(2028, 1, 1), count: 120, city: city,
                                                                      tradition: tradition)
                if actual.map(\.date.iso) != expected.map({ $0.string("date")! }) {
                    failures.append("\(id) \(tradition) dates \(actual.map(\.date.iso))")
                    continue
                }
                for (fast, row) in zip(actual, expected) {
                    let key = "\(id) \(tradition) \(fast.date)"
                    if fast.name != row.string("name") || fast.rule != row.string("rule") || fast.paranaReason != row.string("reason")
                        || fast.nearBoundary != (row["nearBoundary"] as? Bool) {
                        failures.append("\(key): \(fast.name) / \(fast.rule) / \(fast.paranaReason)")
                    }
                    same(fast.paranaStart, row["paranaStart"], "\(key) parana start", &failures)
                    same(fast.paranaEnd, row["paranaEnd"], "\(key) parana end", &failures)
                }
            }
        }
        XCTAssertEqual(failures, [], failures.prefix(20).joined(separator: "\n"))
    }
}
