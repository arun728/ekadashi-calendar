import XCTest
@testable import EkadashiCore

/// Arun's iPhone (16 Nov 2026): with Yearly in use and Monthly scheduled,
/// tapping Lifetime did nothing even after several taps, and with Yearly
/// cancelled Monthly did nothing either. Every App Store refresh cleared the
/// tapped plan, and the buy button relied on two separate pop-ups.
final class PremiumPaywallTests: XCTestCase {
    private let end = Date(timeIntervalSince1970: 1_810_000_000)
    private let all: [PremiumPlanID] = [.monthly, .yearly, .lifetime]

    private func yearlyWithMonthlyNext() -> PremiumState {
        var state = PremiumState()
        state.apply(owned: [OwnedProduct(productId: PremiumProduct.yearly, willAutoRenew: true, expirationDate: end,
                                         nextProductID: PremiumProduct.monthly, renewalDate: end)])
        return state
    }

    private func cancelledYearly() -> PremiumState {
        var state = PremiumState()
        state.apply(owned: [OwnedProduct(productId: PremiumProduct.yearly, willAutoRenew: false, expirationDate: end)])
        return state
    }

    func testATappedPlanSurvivesStoreRefreshes() {
        var selection = PremiumPaywallSelection()
        var state = yearlyWithMonthlyNext()
        XCTAssertEqual(selection.plan(state, available: all, pending: false), .yearly, "The plan in use is ticked")
        selection.tap(.lifetime)
        XCTAssertEqual(selection.plan(state, available: all, pending: false), .lifetime)
        // A refresh that briefly loses the renewal record, then finds it again.
        state.apply(owned: [OwnedProduct(productId: PremiumProduct.yearly, willAutoRenew: nil, expirationDate: end)])
        selection.storeChanged(state)
        XCTAssertEqual(selection.plan(state, available: all, pending: false), .lifetime)
        state = yearlyWithMonthlyNext()
        selection.storeChanged(state)
        XCTAssertEqual(selection.plan(state, available: all, pending: false), .lifetime, "Lifetime must stay selected")

        var cancelled = PremiumPaywallSelection()
        cancelled.tap(.monthly)
        cancelled.storeChanged(cancelledYearly())
        XCTAssertEqual(cancelled.plan(cancelledYearly(), available: all, pending: false), .monthly)
    }

    func testTheSelectionMovesOnOnceTheTappedPlanIsOwned() {
        var selection = PremiumPaywallSelection()
        selection.tap(.lifetime)
        var state = PremiumState()
        state.apply(owned: [OwnedProduct(productId: PremiumProduct.lifetime)])
        selection.storeChanged(state)
        XCTAssertNil(selection.selected)
        XCTAssertEqual(selection.plan(state, available: all, pending: false), .lifetime)

        var yearly = PremiumPaywallSelection()
        yearly.tap(.yearly)
        state = PremiumState()
        state.apply(owned: [OwnedProduct(productId: PremiumProduct.yearly, willAutoRenew: true, expirationDate: end)])
        yearly.storeChanged(state)
        XCTAssertNil(yearly.selected, "A bought, renewing plan is no longer a choice")
        XCTAssertEqual(yearly.plan(state, available: all, pending: false), .yearly, "The bought plan is ticked")
    }

    /// As in Apple's Available Plans sheet (Arun, 16 Nov 2026): the plan in
    /// use is ticked, even with another plan scheduled next; a free user
    /// starts on the suggested plan.
    func testTheCurrentPlanIsTickedLikeApplesPlanList() {
        let selection = PremiumPaywallSelection()
        XCTAssertEqual(selection.plan(yearlyWithMonthlyNext(), available: all, pending: false), .yearly)
        XCTAssertEqual(selection.plan(cancelledYearly(), available: all, pending: false), .yearly)
        var free = PremiumState()
        free.apply(owned: [])
        XCTAssertEqual(selection.plan(free, available: all, pending: false), .yearly)
    }

    /// The button appears only once another plan is ticked; a downgrade is
    /// bought straight away and Apple's own sheet says when it starts.
    func testTheBuyButtonOnlyActsOnADifferentPlan() {
        let scheduled = yearlyWithMonthlyNext()
        XCTAssertEqual(scheduled.paywallAction(for: .yearly, canBuy: false), .none, "No button on the plan in use")
        XCTAssertEqual(scheduled.paywallAction(for: .lifetime, canBuy: true), .confirmLifetime)
        XCTAssertEqual(scheduled.paywallAction(for: .monthly, canBuy: false), .manage, "Monthly is already scheduled")

        let cancelled = cancelledYearly()
        XCTAssertEqual(cancelled.paywallAction(for: .monthly, canBuy: true), .purchase(.monthly))
        XCTAssertEqual(cancelled.paywallAction(for: .yearly, canBuy: true), .manage, "Reactivating is in Apple's sheet")
        XCTAssertEqual(cancelled.paywallAction(for: .lifetime, canBuy: true), .confirmLifetime)

        var free = PremiumState()
        free.apply(owned: [])
        XCTAssertEqual(free.paywallAction(for: .lifetime, canBuy: true), .purchase(.lifetime))
        XCTAssertEqual(free.paywallAction(for: .monthly, canBuy: true), .purchase(.monthly))
        XCTAssertEqual(free.paywallAction(for: .monthly, canBuy: false), .none)

        var monthly = PremiumState()
        monthly.apply(owned: [OwnedProduct(productId: PremiumProduct.monthly, willAutoRenew: true, expirationDate: end)])
        XCTAssertEqual(monthly.paywallAction(for: .monthly, canBuy: false), .none)
        XCTAssertEqual(monthly.paywallAction(for: .yearly, canBuy: true), .purchase(.yearly), "Upgrades start now")
    }

    func testTheButtonSaysChangePlanOnlyForASubscriptionSwitch() {
        XCTAssertTrue(cancelledYearly().paywallIsPlanChange(to: .monthly))
        XCTAssertTrue(yearlyWithMonthlyNext().paywallIsPlanChange(to: .monthly))
        XCTAssertFalse(cancelledYearly().paywallIsPlanChange(to: .lifetime))
        XCTAssertFalse(cancelledYearly().paywallIsPlanChange(to: .yearly))
        var free = PremiumState()
        free.apply(owned: [])
        XCTAssertFalse(free.paywallIsPlanChange(to: .monthly))
    }
}
