import Foundation

/// App Store products. Prices are set in App Store Connect (INR 99 monthly,
/// INR 499 yearly, INR 999 lifetime), never in code. Monthly and yearly are
/// one auto-renewable subscription group; lifetime is a non-consumable.
public enum PremiumProduct {
    public static let monthly = "ekadashi_premium_monthly"
    public static let yearly = "ekadashi_premium_yearly"
    public static let lifetime = "ekadashi_premium_lifetime"
    public static let subscriptionGroup = "ekadashi_premium"
    public static let all = [monthly, yearly, lifetime]
}

public enum PremiumPlanID: String, CaseIterable, Sendable {
    case monthly, yearly, lifetime

    public var productId: String {
        switch self {
        case .monthly: return PremiumProduct.monthly
        case .yearly: return PremiumProduct.yearly
        case .lifetime: return PremiumProduct.lifetime
        }
    }

    public init?(productId: String) {
        guard let plan = PremiumPlanID.allCases.first(where: { $0.productId == productId }) else { return nil }
        self = plan
    }
}

/// A product StoreKit reports as currently owned: a verified, unrevoked
/// transaction in `Transaction.currentEntitlements` (an active or
/// grace-period subscription, or the lifetime purchase).
public struct OwnedProduct: Equatable, Sendable {
    public let productId: String
    /// For subscriptions, the original purchase date (renewals keep it).
    public let purchaseDate: Date?
    /// Whether the subscription renews; nil when unknown or not a subscription.
    public let willAutoRenew: Bool?

    public init(productId: String, purchaseDate: Date? = nil, willAutoRenew: Bool? = nil) {
        self.productId = productId
        self.purchaseDate = purchaseDate
        self.willAutoRenew = willAutoRenew
    }
}

/// Premium access, derived only from what the App Store reports as owned on
/// this Apple ID (premium_service.dart). It is never persisted locally and
/// never tied to the Google (Calendar) sign-in.
public struct PremiumState: Equatable, Sendable {
    public private(set) var subscribed = false
    public private(set) var lifetime = false
    public private(set) var subscriptionCancelled = false
    public private(set) var currentPlan: PremiumPlanID?
    /// When the active premium product was bought, as the App Store reports.
    public private(set) var purchasedAt: Date?
    public private(set) var error: String?
    private var confirmedByStore = false

    public init() {}

    public var isPremium: Bool { subscribed || lifetime }

    /// The store answered and reports nothing owned (a subscription ended or
    /// a purchase was refunded). Never true while the store is unreachable.
    public var lapsed: Bool { confirmedByStore && !isPremium }

    /// Applies the complete owned list, revoking anything missing.
    public mutating func apply(owned: [OwnedProduct]) {
        let subscription = owned.first { $0.productId == PremiumProduct.yearly }
            ?? owned.first { $0.productId == PremiumProduct.monthly }
        let lifetimeProduct = owned.first { $0.productId == PremiumProduct.lifetime }
        subscribed = subscription != nil
        lifetime = lifetimeProduct != nil
        currentPlan = subscription.flatMap { PremiumPlanID(productId: $0.productId) }
        subscriptionCancelled = subscription?.willAutoRenew == false
        // The subscription's year governs syncing while it is active.
        purchasedAt = subscription?.purchaseDate ?? lifetimeProduct?.purchaseDate
        confirmedByStore = true
        error = nil
    }

    /// The store could not be read: fail closed, and do not treat it as a lapse.
    public mutating func storeUnavailable() {
        subscribed = false
        lifetime = false
        subscriptionCancelled = false
        currentPlan = nil
        purchasedAt = nil
        confirmedByStore = false
        error = "premium_unavailable"
    }

    /// The 12-month subscription year containing [now], anchored on the month
    /// of [purchasedAt] (a plan bought in November runs November to October).
    public static func subscriptionYear(purchasedAt: Date?, now: Date, calendar: Calendar = .current) -> DateInterval {
        let anchor = calendar.dateComponents([.year, .month], from: purchasedAt ?? now)
        let current = calendar.dateComponents([.year, .month], from: now)
        let months = (current.year! - anchor.year!) * 12 + current.month! - anchor.month!
        let years = months < 0 ? 0 : months / 12
        let start = calendar.date(from: DateComponents(year: anchor.year! + years, month: anchor.month!))!
        let end = calendar.date(from: DateComponents(year: anchor.year! + years + 1, month: anchor.month!))!
        return DateInterval(start: start, end: end)
    }

    /// The Google Calendar range premium may import now, or nil when free.
    /// Lifetime covers every calendar year the app has data for.
    public func syncWindow(now: Date, calendarYears: ClosedRange<Int>?, calendar: Calendar = .current) -> DateInterval? {
        guard isPremium else { return nil }
        if lifetime, let years = calendarYears {
            return DateInterval(start: calendar.date(from: DateComponents(year: years.lowerBound))!,
                                end: calendar.date(from: DateComponents(year: years.upperBound + 1))!)
        }
        return Self.subscriptionYear(purchasedAt: purchasedAt, now: now, calendar: calendar)
    }

    /// Subscribers can switch between monthly and yearly or buy lifetime;
    /// lifetime owners need nothing more; a cancelled subscriber may
    /// reactivate the current plan; nothing while a purchase is pending.
    public func canBuy(_ plan: PremiumPlanID, pending: Bool) -> Bool {
        if pending || lifetime { return false }
        if plan == .lifetime || !subscribed { return true }
        return plan != currentPlan || subscriptionCancelled
    }

    /// Yearly first (best value), then the others that can be bought.
    public func defaultPlan(available: [PremiumPlanID], pending: Bool) -> PremiumPlanID? {
        for plan in [PremiumPlanID.yearly, .monthly, .lifetime] where available.contains(plan) && canBuy(plan, pending: pending) {
            return plan
        }
        return available.first
    }
}
