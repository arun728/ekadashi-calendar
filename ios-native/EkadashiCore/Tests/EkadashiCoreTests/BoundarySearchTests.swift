import Foundation
import XCTest
@testable import EkadashiCore

/// Tithi, nakshatra, yoga, karana and rashi ends come from a bracketed
/// root search on the (always increasing) angle instead of a 10-minute scan:
/// the same instants to well under a millisecond, with far fewer Sun and
/// Moon evaluations (boundary_search_test.dart). Near a boundary the angles
/// change in steps of about a millisecond (the floating-point resolution of
/// the Julian date), so both searches agree to 10 ms, not exactly.
final class BoundarySearchTests: XCTestCase {
    let engine = PanchangEngine()

    /// The scan the engine used before October 2026, kept as the reference.
    private func scanNext(_ start: Date, _ startAngle: Double, _ width: Double, _ angleAt: (Date) -> Double) -> Date? {
        let distance = width - (startAngle - floor(startAngle / width) * width)
        let limit = start.adding(Double(width >= 30 ? 35 * 24 : 40) * 3600)
        var low = start, high: Date?, probe = start.adding(600)
        while probe <= limit {
            if AstronomyCalculator.normalize(angleAt(probe) - startAngle) >= distance { high = probe; break }
            low = probe
            probe = probe.adding(600)
        }
        guard var right = high else { return nil }
        for _ in 0..<22 {
            let middle = low.adding(truncatedMicroseconds(right.timeIntervalSince(low), dividedBy: 2))
            if AstronomyCalculator.normalize(angleAt(middle) - startAngle) >= distance { right = middle } else { low = middle }
        }
        return right
    }

    private func scanPrevious(_ instant: Date, _ width: Double, _ angleAt: (Date) -> Double) -> Date {
        let index = Int(floor(angleAt(instant) / width))
        var right = instant
        for i in 1...48 {
            var left = instant.adding(-Double(i) * 3600)
            if Int(floor(angleAt(left) / width)) == index { continue }
            for _ in 0..<24 {
                let middle = left.adding(truncatedMicroseconds(right.timeIntervalSince(left), dividedBy: 2))
                if Int(floor(angleAt(middle) / width)) == index { right = middle } else { left = middle }
            }
            return right
        }
        return instant.adding(-48 * 3600)
    }

    private var angles: [(String, Double, (Date) -> Double)] {
        [("tithi", 12, engine.elongation), ("karana", 6, engine.elongation), ("nakshatra", 40.0 / 3, engine.siderealMoon),
         ("yoga", 40.0 / 3, engine.yogaAngle), ("sun sign", 30, engine.siderealSun), ("moon sign", 30, engine.siderealMoon)]
    }

    private var samples: [Date] {
        var result: [Date] = []
        for year in [1900, 1950, 2026, 2027, 2100] {
            for k in 0..<12 { result.append(utc(year, 1 + k, 1 + (k * 7) % 27, (k * 5) % 24, k * 4)) }
        }
        return result
    }

    func testNextBoundaryMatchesTheScan() {
        for (name, width, angleAt) in angles {
            for start in samples where name != "sun sign" || start < utc(2100, 6, 1) {
                let angle = angleAt(start)
                let expected = scanNext(start, angle, width, angleAt)
                let actual = engine.nextBoundary(start, angle, width, angleAt)
                XCTAssertLessThan(secondsBetween(actual, expected), 0.01, "\(name) \(start)")
            }
        }
    }

    func testPreviousBoundaryMatchesTheScan() {
        for (name, width, angleAt) in angles where width < 30 {
            for instant in samples {
                XCTAssertLessThan(secondsBetween(engine.previousBoundary(instant, width, angleAt),
                                                 scanPrevious(instant, width, angleAt)), 0.01, "\(name) \(instant)")
            }
        }
    }

    func testBoundariesNeedFewEvaluations() {
        var calls = 0
        let counted: (Date) -> Double = { calls += 1; return self.engine.elongation($0) }
        var total = 0
        for start in samples {
            calls = 0
            _ = engine.nextBoundary(start, counted(start), 12, counted)
            total += calls
            calls = 0
            _ = engine.previousBoundary(start, 12, counted)
            total += calls
        }
        // The 10-minute scan took about 150 evaluations a boundary.
        XCTAssertLessThanOrEqual(Double(total) / Double(2 * samples.count), 16)
    }
}
