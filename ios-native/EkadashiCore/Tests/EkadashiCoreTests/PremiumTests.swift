import Foundation
import XCTest
@testable import EkadashiCore

/// Ports test/unit/premium_service_test.dart and premium_plan_choice_test.dart
/// to the App Store model: premium comes only from StoreKit's verified current
/// entitlements, never from a stored flag or a pending purchase.
final class PremiumTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        return calendar
    }()

    private func local(_ year: Int, _ month: Int, _ day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func owned(_ id: String, purchased: Date? = nil, renews: Bool? = nil) -> OwnedProduct {
        OwnedProduct(productId: id, purchaseDate: purchased, willAutoRenew: renews)
    }

    func testNothingOwnedMeansTheFreeTier() {
        var state = PremiumState()
        state.apply(owned: [])
        XCTAssertFalse(state.isPremium)
        XCTAssertNil(state.error)
    }

    func testSubscriptionOrLifetimeUnlocksPremium() {
        var state = PremiumState()
        state.apply(owned: [owned(PremiumProduct.monthly)])
        XCTAssertTrue(state.isPremium)
        XCTAssertFalse(state.lifetime)
        XCTAssertEqual(state.currentPlan, .monthly)
        state.apply(owned: [owned(PremiumProduct.lifetime)])
        XCTAssertTrue(state.isPremium)
        XCTAssertTrue(state.lifetime)
        state.apply(owned: [owned(PremiumProduct.yearly)])
        XCTAssertEqual(state.currentPlan, .yearly)
    }

    func testExpiredOrRefundedSubscriptionIsRevoked() {
        var state = PremiumState()
        state.apply(owned: [owned(PremiumProduct.yearly)])
        state.apply(owned: [])
        XCTAssertFalse(state.isPremium)
        XCTAssertTrue(state.lapsed)
    }

    func testStoreFailureFailsClosedAndIsNotALapse() {
        var state = PremiumState()
        state.apply(owned: [owned(PremiumProduct.yearly)])
        state.storeUnavailable()
        XCTAssertFalse(state.isPremium)
        XCTAssertFalse(state.lapsed)
        XCTAssertEqual(state.error, "premium_unavailable")
    }

    func testLapsedOnlyAfterTheStoreAnswers() {
        var state = PremiumState()
        XCTAssertFalse(state.lapsed, "not checked yet")
        state.apply(owned: [])
        XCTAssertTrue(state.lapsed)
    }

    func testUnrelatedProductsNeverUnlockPremium() {
        var state = PremiumState()
        state.apply(owned: [owned("some_other_product")])
        XCTAssertFalse(state.isPremium)
    }

    func testCancelledSubscriptionStaysPremiumUntilItEnds() {
        var state = PremiumState()
        state.apply(owned: [owned(PremiumProduct.monthly, renews: false)])
        XCTAssertTrue(state.subscriptionCancelled)
        XCTAssertTrue(state.isPremium)
        state.apply(owned: [owned(PremiumProduct.monthly, renews: true)])
        XCTAssertFalse(state.subscriptionCancelled)
    }

    func testSubscriptionYearIsAnchoredOnThePurchaseMonth() {
        func year(_ bought: Date?, _ now: Date) -> DateInterval {
            PremiumState.subscriptionYear(purchasedAt: bought, now: now, calendar: calendar)
        }
        XCTAssertEqual(year(local(2026, 11, 20), local(2026, 11, 21)), DateInterval(start: local(2026, 11), end: local(2027, 11)))
        XCTAssertEqual(year(local(2026, 11, 20), local(2027, 9, 30)), DateInterval(start: local(2026, 11), end: local(2027, 11)))
        XCTAssertEqual(year(local(2026, 11, 20), local(2027, 11, 2)), DateInterval(start: local(2027, 11), end: local(2028, 11)))
        XCTAssertEqual(year(nil, local(2026, 10, 5)), DateInterval(start: local(2026, 10), end: local(2027, 10)))
    }

    func testSyncWindowUsesTheStorePurchaseDateAndLifetimeYears() {
        var state = PremiumState()
        state.apply(owned: [owned(PremiumProduct.yearly, purchased: local(2026, 11, 20))])
        XCTAssertEqual(state.purchasedAt, local(2026, 11, 20))
        XCTAssertEqual(state.syncWindow(now: local(2027, 2, 1), calendarYears: nil, calendar: calendar)?.start, local(2026, 11))
        state.apply(owned: [owned(PremiumProduct.lifetime, purchased: local(2026, 11, 20))])
        let window = state.syncWindow(now: local(2026, 11, 21), calendarYears: 2026...2027, calendar: calendar)
        XCTAssertEqual(window, DateInterval(start: local(2026, 1, 1), end: local(2028, 1, 1)))
        var free = PremiumState()
        free.apply(owned: [])
        XCTAssertNil(free.syncWindow(now: local(2026, 10, 5), calendarYears: 2026...2027, calendar: calendar))
    }

    func testSubscriptionDateGovernsSyncWhileBothAreOwned() {
        var state = PremiumState()
        state.apply(owned: [owned(PremiumProduct.lifetime, purchased: local(2025, 3, 1)),
                            owned(PremiumProduct.monthly, purchased: local(2026, 8, 1))])
        XCTAssertEqual(state.purchasedAt, local(2026, 8, 1))
    }

    // MARK: plan choice

    func testAFreeUserCanBuyEveryPlan() {
        var state = PremiumState()
        state.apply(owned: [])
        for plan in PremiumPlanID.allCases { XCTAssertTrue(state.canBuy(plan, pending: false), "\(plan)") }
    }

    func testMonthlySubscriberCanUpgradeButNotRebuyTheSamePlan() {
        var state = PremiumState()
        state.apply(owned: [owned(PremiumProduct.monthly, renews: true)])
        XCTAssertFalse(state.canBuy(.monthly, pending: false))
        XCTAssertTrue(state.canBuy(.yearly, pending: false))
        XCTAssertTrue(state.canBuy(.lifetime, pending: false))
    }

    func testLifetimeOwnersAndPendingPurchasesCannotBuy() {
        var state = PremiumState()
        state.apply(owned: [owned(PremiumProduct.lifetime)])
        for plan in PremiumPlanID.allCases { XCTAssertFalse(state.canBuy(plan, pending: false)) }
        var free = PremiumState()
        free.apply(owned: [])
        XCTAssertFalse(free.canBuy(.monthly, pending: true))
    }

    func testCancelledSubscriptionCanBeReactivatedOnTheSamePlan() {
        var state = PremiumState()
        state.apply(owned: [owned(PremiumProduct.monthly, renews: false)])
        XCTAssertTrue(state.canBuy(.monthly, pending: false))
    }

    func testDefaultPlanPrefersYearlyThenWhatCanBeBought() {
        var state = PremiumState()
        state.apply(owned: [])
        XCTAssertEqual(state.defaultPlan(available: [.monthly, .yearly, .lifetime], pending: false), .yearly)
        state.apply(owned: [owned(PremiumProduct.yearly, renews: true)])
        XCTAssertEqual(state.defaultPlan(available: [.monthly, .yearly, .lifetime], pending: false), .monthly)
        XCTAssertEqual(PremiumPlanID.allCases.map(\.productId),
                       ["ekadashi_premium_monthly", "ekadashi_premium_yearly", "ekadashi_premium_lifetime"])
    }
}
