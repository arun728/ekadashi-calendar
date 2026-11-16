import Foundation
import StoreKit
import Observation
import os
import EkadashiCore

private let logger = Logger(subsystem: "com.applausestudios.ekadashi-calendar", category: "premium")

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
    private var pendingPurchase: PendingPremiumPurchase?
    private var purchasing = false
    var pending: Bool { pendingPurchase != nil }
    private(set) var busy = false
    /// Translation key of the last store problem (`premium_unavailable`).
    var error: String?

    @ObservationIgnored let snapshot = PremiumSnapshot()
    @ObservationIgnored private var statusUpdates: Task<Void, Never>?
    @ObservationIgnored private var updates: Task<Void, Never>?
    @ObservationIgnored private var recheck: Task<Void, Never>?
    @ObservationIgnored private var refreshAgain = false
    @ObservationIgnored private var inFlight: Task<Void, Never>?
    static let recheckInterval: UInt64 = 5 * 60 * 1_000_000_000

    var isPremium: Bool { state.isPremium }
    var plans: [PremiumPlanID] { PremiumPlanID.allCases.filter { products[$0] != nil } }

    init() {
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    self?.resolvePending(with: transaction)
                    await transaction.finish()
                }
                await self?.refresh()
            }
        }
    }

    func start() async {
        if statusUpdates == nil {
            statusUpdates = Task { [weak self] in
                for await _ in Product.SubscriptionInfo.Status.updates {
                    guard let self else { return }
                    await self.refresh()
                }
            }
        }
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
        // A refresh requested while one runs (a purchase finishing while
        // Transaction.updates or the launch check is reading) used to be
        // dropped, so a new purchase could stay locked until the next check.
        // Now it waits for that read and one more, so the caller sees it.
        if let running = inFlight {
            refreshAgain = true
            await running.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            self.busy = true
            repeat {
                self.refreshAgain = false
                await self.readEntitlements()
            } while self.refreshAgain
            self.busy = false
            self.inFlight = nil
        }
        inFlight = task
        await task.value
    }

    private func readEntitlements() async {
        // On iOS 27 (Xcode StoreKit testing) `Transaction.currentEntitlements`
        // came back empty while the history held a verified, unexpired
        // monthly purchase. Ask for the latest transaction of each product
        // too; both are signed by the App Store and verified the same way.
        var results: [(result: VerificationResult<Transaction>, isCurrent: Bool)] = []
        for await result in Transaction.currentEntitlements { results.append((result, true)) }
        for productId in PremiumProduct.all {
            if let result = await Transaction.latest(for: productId) { results.append((result, false)) }
        }
        var owned: [OwnedProduct] = []
        for (result, isCurrent) in results {
            guard case .verified(let transaction) = result else {
                if case .unverified(let transaction, let failure) = result {
                    logger.error("Premium refresh: ignored unverified \(transaction.productID, privacy: .public): \(String(describing: failure), privacy: .public)")
                }
                continue
            }
            resolvePending(with: transaction)
            guard PremiumProduct.grantsAccess(
                productId: transaction.productID, revoked: transaction.revocationDate != nil,
                upgraded: transaction.isUpgraded, expirationDate: transaction.expirationDate,
                isCurrent: isCurrent, now: Date()
            ),
                  !owned.contains(where: { $0.productId == transaction.productID }) else { continue }
            let renewal = transaction.productType == .autoRenewable ? await renewalRecord(for: transaction) : nil
            #if DEBUG
            if let renewal {
                logger.debug("Premium renewal: current=\(renewal.productID, privacy: .public) willAutoRenew=\(renewal.willRenew, privacy: .public) autoRenewPreference=\(renewal.nextProductID ?? "nil", privacy: .public)")
            }
            #endif
            let purchased = transaction.productType == .autoRenewable ? transaction.originalPurchaseDate : transaction.purchaseDate
            owned.append(OwnedProduct(productId: transaction.productID, purchaseDate: purchased,
                                      willAutoRenew: renewal?.willRenew, expirationDate: transaction.expirationDate,
                                      transactionDate: transaction.purchaseDate, nextProductID: renewal?.nextProductID, renewalDate: renewal?.renewalDate))
        }
        if owned.isEmpty {
            switch await emptyOwnershipStatus() {
            case .ended: state.apply(owned: [])
            case .billingRetry: state.apply(owned: [], billingRetry: true)
            case .unknown: state.storeUnavailable()
            }
        } else {
            state.apply(owned: owned)
        }
        snapshot.set(state)
        logger.info("Premium refresh: owned=\(owned.map(\.productId), privacy: .public) premium=\(self.state.isPremium, privacy: .public) products=\(self.products.count, privacy: .public)")
    }

    private func resolvePending(with transaction: Transaction) {
        if pendingPurchase?.matches(productId: transaction.productID, purchaseDate: transaction.purchaseDate) == true {
            pendingPurchase = nil
        }
    }

    private func renewalRecord(for transaction: Transaction) async -> PremiumRenewalRecord? {
        guard let plan = PremiumPlanID(productId: transaction.productID),
              let statuses = try? await products[plan]?.subscription?.status else { return nil }
        let records: [PremiumRenewalRecord] = statuses.compactMap { status in
            guard status.state == .subscribed || status.state == .inGracePeriod,
                  case .verified(let statusTransaction) = status.transaction,
                  statusTransaction.revocationDate == nil, !statusTransaction.isUpgraded,
                  case .verified(let renewal) = status.renewalInfo,
                  renewal.currentProductID == statusTransaction.productID else { return nil }
            return PremiumRenewalRecord(originalID: statusTransaction.originalID,
                                        productID: renewal.currentProductID,
                                        signedAt: renewal.signedDate, willRenew: renewal.willAutoRenew,
                                        nextProductID: renewal.autoRenewPreference, renewalDate: renewal.renewalDate)
        }
        return PremiumRenewalRecord.resolve(records, originalID: transaction.originalID,
                                            productID: transaction.productID)
    }

    private enum EmptyOwnershipStatus { case ended, billingRetry, unknown }

    private func emptyOwnershipStatus() async -> EmptyOwnershipStatus {
        guard let product = products[.monthly] ?? products[.yearly],
              let statuses = try? await product.subscription?.status else { return .unknown }
        var billingRetry = false
        for status in statuses {
            guard case .verified = status.transaction, case .verified = status.renewalInfo else { return .unknown }
            if status.state == .subscribed || status.state == .inGracePeriod { return .unknown }
            if status.state == .inBillingRetryPeriod { billingRetry = true }
        }
        return billingRetry ? .billingRetry : .ended
    }

    func canBuy(_ plan: PremiumPlanID) -> Bool {
        products[plan] != nil && state.canBuy(plan, pending: pending || purchasing)
    }

    func buy(_ plan: PremiumPlanID) async {
        guard let product = products[plan], canBuy(plan) else { return }
        let startedAt = Date()
        purchasing = true
        defer { purchasing = false }
        do {
            let outcome = try await product.purchase()
            switch outcome {
            case .success(let verification):
                // Never grant an unverified transaction.
                guard case .verified(let transaction) = verification else {
                    if case .unverified(_, let failure) = verification {
                        logger.error("Purchase not verified: \(String(describing: failure), privacy: .public)")
                    }
                    error = "premium_unavailable"
                    return
                }
                await transaction.finish()
                error = nil
                await refresh()
            case .pending:
                pendingPurchase = PendingPremiumPurchase(productId: product.id, startedAt: startedAt)
                // Approval can race the purchase result. Check the latest
                // transactions once, then keep the pending state until approval.
                await refresh()
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            logger.error("Purchase failed: \(String(describing: error), privacy: .public)")
            self.error = "premium_unavailable"
            // The store may already hold this purchase (for example "already
            // subscribed"): re-read entitlements so the screen matches it.
            await refresh()
        }
    }

    /// Restores from the App Store; no account sign-in inside the app.
    func restore() async -> PremiumRestoreResult {
        do {
            try await AppStore.sync()
        } catch {
            return .unavailable
        }
        await refresh()
        return state.restoreResult
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
