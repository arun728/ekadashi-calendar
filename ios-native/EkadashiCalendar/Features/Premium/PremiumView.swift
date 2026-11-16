import SwiftUI
import StoreKit
import EkadashiCore

/// The paywall (premium_screen.dart). Premium is bought and restored
/// through the App Store only; no Google sign-in or account is involved.
/// Prices come from StoreKit (set in App Store Connect), never hard-coded.
struct PremiumView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let reason: String?
    @State private var selection = PremiumPaywallSelection()
    /// The one pop-up the buy button can raise (Lifetime for a subscriber).
    @State private var confirmLifetime = false
    @State private var managing = false
    @State private var toast: ToastMessage?

    static let privacyURL = URL(string: "https://arun728.github.io/ekadashi-calendar/privacy-policy")!
    static let termsURL = URL(string: "https://arun728.github.io/ekadashi-calendar/terms-of-service")!

    private var store: StoreKitPremiumService { model.premium }
    private var state: PremiumState { store.state }
    private var showPlans: Bool { !store.plans.isEmpty }

    /// The tapped plan, kept through store refreshes until it is owned.
    private var plan: PremiumPlanID? {
        selection.plan(state, available: store.plans, pending: store.pending)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    status
                    if store.pending { Text(model.t("premium_pending")).font(.subheadline) }
                    if showPlans {
                        // Full-width rows, top to bottom, as in Apple's
                        // Available Plans sheet.
                        VStack(spacing: 12) {
                            ForEach(store.plans, id: \.self) { tile($0) }
                        }
                    }
                    if showPlans, let plan {
                        Text(model.t("premium_\(plan.rawValue)_terms")).font(.caption).foregroundStyle(.secondary)
                    }
                    if let error = store.error, !state.isPremium {
                        Text(model.t(error)).font(.subheadline).accessibilityIdentifier("premium_status_message")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            footer
        }
        .background(AppBackground())
        .navigationTitle(model.t("premium_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            AppToolbarItem(placement: .cancellationAction, compact: true) {
                Button { dismiss() } label: { Image(systemName: AppSymbol.close) }
                    .accessibilityLabel(model.t("premium_continue_free"))
                    .accessibilityIdentifier("premium_close")
            }
            // In the navigation bar, never in the page: a spinner above the
            // plans moved them on every refresh and swallowed taps.
            ToolbarItem(placement: .topBarTrailing) {
                if store.busy { ProgressView().tint(Theme.teal).accessibilityIdentifier("premium_loading") }
            }
        }
        .onChange(of: state) { _, newState in selection.storeChanged(newState) }
        .manageSubscriptionsSheet(isPresented: $managing)
        .onChange(of: managing) { _, isPresented in
            if !isPresented { Task { await model.premium.refresh() } }
        }
        .alert(model.t("premium_lifetime_confirm_title"), isPresented: $confirmLifetime) {
            Button(model.t("cancel"), role: .cancel) {}
            Button(model.t("premium_buy_lifetime_anyway")) { Task { await store.buy(.lifetime) } }
        } message: {
            Text(model.t("premium_lifetime_confirm_body"))
        }
        .toast($toast)
        .task {
            if store.products.isEmpty { await store.loadProducts() }
            await store.refresh()
        }
    }

    @ViewBuilder
    private var header: some View {
        if !state.isPremium {
            if let reason {
                Label {
                    Text(model.t(reason)).fontWeight(.semibold)
                } icon: {
                    Image(systemName: AppSymbol.info).foregroundStyle(Theme.teal)
                }
                .accessibilityIdentifier("premium_reason")
            }
            feature(AppSymbol.premiumCalendar, "premium_feature_calendar")
            feature(AppSymbol.premiumVrat, "premium_feature_vrat")
            feature(AppSymbol.premiumPanchang, "premium_feature_panchang_v2")
                .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var status: some View {
        if state.lifetime {
            statusCard("premium_lifetime_thanks_title", "premium_lifetime_thanks_body", Theme.teal)
                .accessibilityIdentifier("premium_lifetime_thanks")
            if state.subscribed {
                statusCard("premium_active", "premium_cancel_subscription_note", .orange) {
                    Button(model.t("premium_cancel_subscription_action")) { managing = true }
                        .secondaryActionStyle()
                        .accessibilityIdentifier("premium_cancel_subscription")
                }
            }
        } else if state.isInBillingRetry {
            statusCard("ios_premium_billing_retry_title", "ios_premium_billing_retry_body", .orange) {
                Button(model.t("premium_manage")) { managing = true }
                    .secondaryActionStyle()
            }
        } else if state.subscribed {
            Group {
                if state.subscriptionCancelled {
                    statusCard("premium_cancelled_title", "premium_cancelled_body", .orange,
                               bodyText: model.premiumCancellationMessage(state))
                } else {
                    statusCard("premium_subscriber_title", "premium_subscriber_body", Theme.teal,
                               bodyText: model.premiumRenewalMessage(state))
                }
            }
            .accessibilityIdentifier("premium_active")
        }
    }

    private func feature(_ symbol: String, _ key: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Theme.teal).frame(width: 26)
            Text(model.t(key))
        }
        .padding(.vertical, 4)
    }

    private func statusCard(_ title: String, _ body: String, _ color: Color, bodyText: String? = nil,
                            @ViewBuilder action: () -> some View = { EmptyView() }) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.t(title)).font(.headline)
            Text(bodyText ?? model.t(body)).font(.subheadline)
            action().padding(.top, 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 16, tint: color)
    }

    /// One plan row: name, price, its state, and a tick circle on the right
    /// (Apple's Available Plans sheet). The whole row answers a tap.
    private func tile(_ id: PremiumPlanID) -> some View {
        let isSelected = id == plan
        let current = (state.lifetime && id == .lifetime) || (state.subscribed && !state.lifetime && id == state.currentPlan)
        let period = id == .monthly ? "premium_per_month" : id == .yearly ? "premium_per_year" : "premium_one_time"
        let price = store.products[id]?.displayPrice ?? ""
        return Button {
            selection.tap(id)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(model.t("premium_\(id.rawValue)")).font(.headline)
                        if id == .yearly {
                            Text(model.t("premium_best_value")).font(.caption2.weight(.semibold)).foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 2).background(Theme.teal, in: Capsule())
                                .lineLimit(1)
                        }
                    }
                    Text("\(price) \(model.t(period))").font(.subheadline).foregroundStyle(.secondary)
                    if current {
                        Text(model.t("premium_current_plan")).font(.caption).foregroundStyle(Theme.teal)
                            .accessibilityIdentifier("premium_current_\(id.rawValue)")
                    }
                    if id == state.scheduledPlan {
                        Text(model.premiumPlanBadgeText(state, id) ?? model.t("ios_premium_next_plan"))
                            .font(.caption).foregroundStyle(Theme.teal)
                            .accessibilityIdentifier("premium_scheduled_\(id.rawValue)")
                    } else if current, let until = model.premiumPlanBadgeText(state, id) {
                        Text(until).font(.caption).foregroundStyle(.secondary)
                            .accessibilityIdentifier("premium_current_until_\(id.rawValue)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: isSelected ? AppSymbol.premiumPlanSelected : AppSymbol.premiumPlanUnselected)
                    .font(.title2)
                    .foregroundStyle(isSelected ? Theme.teal : Color.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel(cornerRadius: 20, tint: isSelected ? Theme.teal : nil, interactive: true)
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(isSelected ? Theme.teal : Color.secondary.opacity(0.3),
                                                                     lineWidth: isSelected ? 2 : 1))
            // The whole row answers a tap, edges and corners included, not
            // only its text (on a device the empty glass did not respond).
            .contentShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .contentShape(.rect(cornerRadius: 20))
        .opacity(store.canBuy(id) || current || id == state.scheduledPlan ? 1 : 0.5)
        .accessibilityIdentifier("premium_plan_\(id.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var footer: some View {
        VStack(spacing: 4) {
            // No button while the plan in use is ticked, as in Apple's list.
            if showPlans, !state.lifetime, let plan,
               !(state.subscribed && plan == state.currentPlan && !state.subscriptionCancelled) {
                let price = store.products[plan]?.displayPrice ?? ""
                let reactivating = state.subscriptionCancelled && plan == state.currentPlan
                let name = state.paywallIsPlanChange(to: plan) ? model.t("ios_premium_switch_confirm")
                    : model.t("premium_\(plan.rawValue)")
                let title = reactivating ? model.t("premium_reactivate") : "\(name) · \(price)"
                let action = state.paywallAction(for: plan, canBuy: store.canBuy(plan))
                Button {
                    buy(action)
                } label: {
                    Text(plan == state.scheduledPlan ? model.t("premium_manage") : title).font(.headline).multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .primaryActionStyle()
                .disabled(action == .none)
                .accessibilityIdentifier("premium_buy")
            }
            FlowLayout(spacing: 4) {
                link("premium_restore") { Task { await restore() } }.disabled(store.busy)
                link("premium_manage") { managing = true }
                link("terms_of_service") { openURL(Self.termsURL) }
                link("privacy_policy") { openURL(Self.privacyURL) }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func link(_ key: String, action: @escaping () -> Void) -> some View {
        Button(model.t(key), action: action).font(.footnote).padding(.horizontal, 8).padding(.vertical, 6).foregroundStyle(Theme.teal)
    }

    /// The App Store cannot cancel a subscription for the app, so a
    /// subscriber is told before buying lifetime to cancel it themselves. A
    /// downgrade goes straight to Apple's sheet, which says when it starts.
    private func buy(_ action: PremiumPaywallAction) {
        switch action {
        case .purchase(let plan): Task { await store.buy(plan) }
        case .confirmLifetime: confirmLifetime = true
        case .manage: managing = true
        case .none: break
        }
    }

    private func restore() async {
        let key: String
        switch await store.restore() {
        case .restored: key = "premium_restored"
        case .none: key = "premium_restore_none"
        case .unavailable: key = "premium_unavailable"
        }
        toast = ToastMessage(text: model.t(key))
    }
}
