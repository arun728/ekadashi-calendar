import XCTest
@testable import EkadashiCore

final class JourneyFeedbackTests: XCTestCase {
    func testMethodAvailabilityAndStatusTransitions() {
        XCTAssertEqual(FastingMethod.allowed(for: .observed), [.fullFast, .waterOnly, .fruitsMilk])
        XCTAssertEqual(FastingMethod.allowed(for: .partial), [.oneMeal])
        XCTAssertEqual(FastingMethod.allowed(for: .missed), [])
        XCTAssertEqual(FastingMethod.normalized(.waterOnly, for: .observed), .waterOnly)
        XCTAssertEqual(FastingMethod.normalized(.oneMeal, for: .observed), .fullFast)
        XCTAssertEqual(FastingMethod.normalized(.fruitsMilk, for: .partial), .oneMeal)
        XCTAssertNil(FastingMethod.normalized(.fullFast, for: .missed))
    }

    func testYearFilterKeepsLifetimeBadgesAndOnlySelectedAnnualCollection() {
        let badges = JourneyBadgeCatalog.all(years: [2026, 2027])
        let selected = badges.filter { $0.isVisible(inYear: 2026) }
        XCTAssertTrue(selected.contains { $0.id == "first_vrat" })
        XCTAssertTrue(selected.contains { $0.year == 2026 })
        XCTAssertFalse(selected.contains { $0.year == 2027 })
        XCTAssertEqual(badges.filter { $0.isVisible(inYear: nil) }.count, badges.count)
    }
}
