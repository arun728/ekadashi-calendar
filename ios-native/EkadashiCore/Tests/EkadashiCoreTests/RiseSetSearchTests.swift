import Foundation
import XCTest
@testable import EkadashiCore

/// Sunrise, sunset, moonrise and moonset skip ahead where the body is far
/// from the horizon (altitude changes by at most 0.3° a minute), instead of
/// scanning every 5 minutes: the same instants, faster (rise_set_search_test.dart).
final class RiseSetSearchTests: XCTestCase {
    let engine = PanchangEngine()

    /// The 5-minute scan the engine used before October 2026, as the reference.
    private func scan(_ start: Date, _ end: Date, _ city: PanchangCity, moon: Bool, rising: Bool) -> Date? {
        func difference(_ instant: Date) -> Double {
            let altitude = AstronomyCalculator.altitudeDegrees(instant: instant, latitude: city.latitude,
                                                               longitude: city.longitude, moon: moon)
            return moon ? altitude
                : altitude + AstronomyCalculator.horizonRefraction + AstronomyCalculator.semidiameterDegrees(instant, moon: false)
        }
        var low = start, lowValue = difference(low), high = start.adding(300)
        while low < end {
            if high > end { high = end }
            let highValue = difference(high)
            if rising ? lowValue <= 0 && highValue > 0 : lowValue >= 0 && highValue < 0 {
                var left = low, right = high
                for _ in 0..<20 {
                    let middle = left.adding(truncatedMicroseconds(right.timeIntervalSince(left), dividedBy: 2))
                    let value = difference(middle)
                    if rising ? value > 0 : value < 0 { right = middle } else { left = middle }
                }
                return right
            }
            low = high
            lowValue = highValue
            high = high.adding(300)
        }
        return nil
    }

    private let cities: [PanchangCity] = [
        .newDelhi, .chennai, .london, .newYork, .sydney,
        PanchangCity(id: "tromso", label: "Tromso", latitude: 69.6492, longitude: 18.9553, timeZoneId: "Europe/Oslo"),
        PanchangCity(id: "reykjavik", label: "Reykjavik", latitude: 64.1466, longitude: -21.9426, timeZoneId: "Atlantic/Reykjavik"),
    ]

    private var days: [CivilDate] {
        [CivilDate(1900, 3, 1), CivilDate(2026, 1, 15), CivilDate(2026, 6, 21), CivilDate(2026, 10, 30),
         CivilDate(2027, 3, 20), CivilDate(2027, 12, 21), CivilDate(2100, 6, 21)]
    }

    func testCrossingsMatchTheScan() {
        for city in cities {
            for day in days {
                let start = city.midnight(day), end = city.midnight(day, dayOffset: 1)
                for moon in [false, true] {
                    for rising in [true, false] {
                        let expected = scan(start, end, city, moon: moon, rising: rising)
                        let actual = engine.findCrossing(start, end, city, moon: moon, rising: rising)
                        if expected == nil || actual == nil {
                            XCTAssertEqual(actual == nil, expected == nil, "\(city.id) \(day) moon \(moon) rising \(rising)")
                        } else {
                            XCTAssertLessThan(secondsBetween(actual, expected), 0.001, "\(city.id) \(day) moon \(moon) rising \(rising)")
                        }
                    }
                }
            }
        }
    }

    func testCrossingsAreFasterThanTheScan() {
        func time(_ body: () -> Void) -> TimeInterval {
            let started = Date()
            body()
            return Date().timeIntervalSince(started)
        }
        func each(_ search: (Date, Date, PanchangCity, Bool, Bool) -> Date?) {
            for city in cities {
                for day in days {
                    for moon in [false, true] {
                        for rising in [true, false] {
                            _ = search(city.midnight(day), city.midnight(day, dayOffset: 1), city, moon, rising)
                        }
                    }
                }
            }
        }
        let old = time { each { scan($0, $1, $2, moon: $3, rising: $4) } }
        let new = time { each { engine.findCrossing($0, $1, $2, moon: $3, rising: $4) } }
        XCTAssertLessThan(new, old * 0.6, "new \(new) s, scan \(old) s")
    }
}
