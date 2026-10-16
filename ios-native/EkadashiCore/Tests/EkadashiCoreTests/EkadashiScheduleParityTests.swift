import Foundation
import XCTest
@testable import EkadashiCore

/// Home's Ekadashi schedule is the same on iOS and Android: every field of
/// every fast (identity, notification id, content, date, fasting start,
/// Parana window, paksha, month, rule) for ten cities on four continents,
/// both traditions, 2026-2028, compared with the Dart port's output in
/// test/tool/dump_ekadashi_schedule_parity_test.dart.
final class EkadashiScheduleParityTests: XCTestCase {
    func testEverySwiftFastMatchesTheDartSchedule() throws {
        let data = try Data(contentsOf: Repo.url(
            "ios-native/EkadashiCore/Tests/EkadashiCoreTests/Fixtures/ekadashi_schedule_parity.json"))
        let entries = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        XCTAssertEqual(entries.count, 60, "10 cities × 2 traditions × 3 years")
        let schedule = EkadashiSchedule(repository: try CalendarRepository.bundled())
        var failures: [String] = []
        var compared = 0
        for entry in entries {
            let c = entry["city"] as! [String: Any]
            let city = PanchangCity(id: c["id"] as! String, label: c["label"] as! String,
                                    latitude: c["latitude"] as! Double, longitude: c["longitude"] as! Double,
                                    timeZoneId: c["timeZoneId"] as! String)
            let tradition = EkadashiTradition(rawValue: entry["tradition"] as! String)!
            let year = entry["year"] as! Int
            let label = "\(city.label) \(tradition.rawValue) \(year)"
            let expected = entry["fasts"] as! [[String: Any]]
            let actual = try schedule.scheduled(EkadashiScheduleKey(city: city, tradition: tradition, year: year))
            guard actual.count == expected.count else {
                failures.append("\(label): \(actual.count) fasts vs \(expected.count)")
                continue
            }
            for (fast, row) in zip(actual, expected) {
                let fields: [(String, Any?, Any?)] = [
                    ("occurrenceUid", fast.occurrenceUid, row["occurrenceUid"]),
                    ("notificationId", fast.notificationId, row["notificationId"]),
                    ("legacyId", fast.legacyId, row["legacyId"]),
                    ("contentId", fast.contentId, row["contentId"]),
                    ("publishedUid", fast.publishedUid, row["publishedUid"] is NSNull ? nil : row["publishedUid"]),
                    ("date", fast.date, row["date"]),
                    ("paksha", fast.paksha, row["paksha"]),
                    ("month", fast.month, row["month"]),
                    ("rule", fast.rule, row["rule"]),
                ]
                for (name, mine, theirs) in fields where "\(mine ?? "nil")" != "\(theirs ?? "nil")" {
                    failures.append("\(label) \(fast.date) \(name): \(mine ?? "nil") vs \(theirs ?? "nil")")
                }
                // Independent floating-point roots may straddle a millisecond.
                // Compare instants within 2 ms, preserving offset and null-end semantics.
                for (name, mine) in [("fastingStart", Optional(fast.fastingStart)),
                                     ("paranaStart", Optional(fast.paranaStart)),
                                     ("paranaEnd", Optional(fast.paranaEnd)),
                                     ("contextExpiresAt", fast.contextExpiresAt)] {
                    let theirs = row[name] as? String
                    if let mine, let theirs, !mine.isEmpty, !theirs.isEmpty,
                       let a = ISO8601.instant(mine), let b = ISO8601.instant(theirs) {
                        if abs(a.timeIntervalSince(b)) > 0.0021 || mine.suffix(6) != theirs.suffix(6) {
                            failures.append("\(label) \(fast.date) \(name): \(mine) vs \(theirs)")
                        }
                    } else if (mine ?? "") != (theirs ?? "") {
                        failures.append("\(label) \(fast.date) \(name): missing boundary")
                    }
                }
                compared += 1
            }
        }
        XCTAssertGreaterThan(compared, 1400)
        XCTAssertTrue(failures.isEmpty, "\(failures.count) differences:\n" + failures.prefix(20).joined(separator: "\n"))
    }
}
