import Foundation
import StoreKit
import Observation
import EkadashiCore

enum RestoreResult { case restored, none, unavailable }

/// The last premium state, readable from any thread (the Google sync rules
/// run off the main actor).
final class PremiumSnapshot: @unchecked Sendable {
    private let lock = NSLock()
    private var value = PremiumState()

    var state: PremiumState { lock.withLock { value } }
    func set(_ state: PremiumState) { lock.withLock { value = state } }
}

/// Premium from the App Store only (Play-only premium rules, adapted):
/// entitlements come from StoreKit 2's cryptographically verified
/// `Transaction.currentEntitlements`, re-read at launch, on foreground,
/// every five minutes while open and after every purchase. Nothing is
/// granted from a stored flag, an unverified or a pending transaction, and
/// completed transactions are finished (Apple's acknowledgement).
@MainActor
@Observable
final class StoreKitPremiumService {
    private(set) var state = PremiumState()
    private(set) var products: [PremiumPlanID: Product] = [:]
    private(set) var pending = false
    private(set) var busy = false
    /// Translation key of the last store problem (`premium_unavailable`).
    var error: String?

    @ObservationIgnored let snapshot = PremiumSnapshot()
    @ObservationIgnored private var updates: Task<Void, Never>?
    @ObservationIgnored private var recheck: Task<Void, Never>?
    static let recheckInterval: UInt64 = 5 * 60 * 1_000_000_000

    var isPremium: Bool { state.isPremium }
    var plans: [PremiumPlanID] { PremiumPlanID.allCases.filter { products[$0] != nil } }

    init() {
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
                await self?.refresh()
            }
        }
    }

    func start() async {
        await loadProducts()
        await refresh()
    }

    func loadProducts() async {
        do {
            let list = try await Product.products(for: PremiumProduct.all)
            var map: [PremiumPlanID: Product] = [:]
            for product in list {
                // Configure no introductory offers in App Store Connect: the
                // paywall shows full prices only, as on Android.
                guard let plan = PremiumPlanID(productId: product.id) else { continue }
                map[plan] = product
            }
            products = map
            error = map.isEmpty ? "premium_unavailable" : nil
        } catch {
            self.error = "premium_unavailable"
        }
    }

    /// Re-reads owned purchases. A lapse is only reported once the App Store
    /// answers that the subscription ended; being offline never counts.
    func refresh() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        var owned: [OwnedProduct] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil,
                  PremiumPlanID(productId: transaction.productID) != nil else { continue }
            if let expiry = transaction.expirationDate, expiry < Date() { continue }
            var renews: Bool?
            if transaction.productType == .autoRenewable {
                renews = await willAutoRenew(transaction.productID)
            }
            let purchased = transaction.productType == .autoRenewable ? transaction.originalPurchaseDate : transaction.purchaseDate
            owned.append(OwnedProduct(productId: transaction.productID, purchaseDate: purchased, willAutoRenew: renews))
        }
        if owned.isEmpty, !(await storeConfirmsNoSubscription()) {
            // The App Store could not confirm: free features stay, but this
            // is not treated as a lapse (no Premium-imported events removed).
            state.storeUnavailable()
        } else {
            state.apply(owned: owned)
        }
        snapshot.set(state)
        pending = false
    }

    private func willAutoRenew(_ productId: String) async -> Bool? {
        guard let plan = PremiumPlanID(productId: productId), let product = products[plan],
              let statuses = try? await product.subscription?.status else { return nil }
        for status in statuses {
            if case .verified(let renewal) = status.renewalInfo, renewal.currentProductID == productId || renewal.autoRenewPreference == productId {
                return renewal.willAutoRenew
            }
        }
        return nil
    }

    /// True when the subscription status request succeeds and shows no
    /// active subscription (expired, revoked or never bought).
    private func storeConfirmsNoSubscription() async -> Bool {
        guard let product = products[.monthly] ?? products[.yearly], let subscription = product.subscription else { return false }
        do {
            let statuses = try await subscription.status
            return !statuses.contains { $0.state == .subscribed || $0.state == .inGracePeriod || $0.state == .inBillingRetryPeriod }
        } catch {
            return false
        }
    }

    func canBuy(_ plan: PremiumPlanID) -> Bool { products[plan] != nil && state.canBuy(plan, pending: pending) }

    func buy(_ plan: PremiumPlanID) async {
        guard let product = products[plan], canBuy(plan) else { return }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                // Never grant an unverified transaction.
                guard case .verified(let transaction) = verification else {
                    error = "premium_unavailable"
                    return
                }
                await transaction.finish()
                error = nil
                await refresh()
            case .pending:
                pending = true
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            self.error = "premium_unavailable"
        }
    }

    /// Restores from the App Store; no account sign-in inside the app.
    func restore() async -> RestoreResult {
        do {
            try await AppStore.sync()
        } catch {
            return .unavailable
        }
        await refresh()
        return state.isPremium ? .restored : .none
    }

    /// Re-checks every five minutes while the app is open.
    func startRecheck() {
        recheck?.cancel()
        recheck = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.recheckInterval)
                await self?.refresh()
            }
        }
    }

    func stopRecheck() {
        recheck?.cancel()
        recheck = nil
    }
}
