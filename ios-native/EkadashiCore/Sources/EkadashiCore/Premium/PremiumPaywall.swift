import Foundation

/// What the paywall's buy button does for the highlighted plan.
public enum PremiumPaywallAction: Equatable, Sendable {
    /// Buy it straight away.
    case purchase(PremiumPlanID)
    /// A subscriber buying Lifetime is first told to cancel the subscription.
    case confirmLifetime
    /// A downgrade first says when each plan applies (at the renewal).
    case confirmSwitch(PremiumPlanID)
    /// Reactivating or a plan already scheduled: Apple's Manage sheet.
    case manage
    /// Nothing can be bought right now (a purchase is pending).
    case none
}

extension PremiumState {
    public func paywallAction(for plan: PremiumPlanID, canBuy: Bool) -> PremiumPaywallAction {
        if lifetime { return .none }
        if plan == scheduledPlan || (subscriptionCancelled && plan == currentPlan) { return .manage }
        guard canBuy else { return .none }
        if case .atRenewal = switchTiming(to: plan) { return .confirmSwitch(plan) }
        if plan == .lifetime && subscribed { return .confirmLifetime }
        return .purchase(plan)
    }
}

/// The plan tapped on the paywall. A tap is kept through App Store
/// refreshes (on a device they come often and can briefly lose the renewal
/// record); it is dropped only once that plan is owned and nothing is left
/// to buy, so the page then highlights the next sensible plan.
public struct PremiumPaywallSelection: Equatable, Sendable {
    public private(set) var selected: PremiumPlanID?

    public init() {}

    public mutating func tap(_ plan: PremiumPlanID) { selected = plan }

    public mutating func storeChanged(_ state: PremiumState) {
        guard let selected else { return }
        let owned = state.lifetime
            || (state.subscribed && selected == state.currentPlan && !state.subscriptionCancelled)
        if owned { self.selected = nil }
    }

    public func plan(_ state: PremiumState, available: [PremiumPlanID], pending: Bool) -> PremiumPlanID? {
        if state.lifetime { return available.contains(.lifetime) ? .lifetime : nil }
        if let selected, available.contains(selected) { return selected }
        if let scheduled = state.scheduledPlan, available.contains(scheduled) { return scheduled }
        return state.defaultPlan(available: available, pending: pending)
    }
}
