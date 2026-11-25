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
    /// The one pop-up the buy button can raise. Two chained `.alert`s on
    /// this view left one of them unable to appear on Arun's iPhone.
    @State private var confirmation: PremiumPaywallAction?
    @State private var managing = false
    @State private var toast: ToastMessage?

    static let privacyURL = URL(string: "https://apptinel.com/ekadashi-calendar/privacy-policy/")!
    static let termsURL = URL(string: "https://apptinel.com/ekadashi-calendar/terms-of-service/")!

    private var store: StoreKitPremiumService { model.premium }
    private var state: PremiumState { store.state }
    private var showPlans: Bool { !store.plans.isEmpty }

    /// The tapped plan, kept through store refreshes until it is owned.
    private var plan: PremiumPlanID? {
        selection.plan(state, available: store.plans, pending: store.pending)
    }

    var body: some View {
        // The buy button and links follow the plans (Arun, 25 Nov 2026: a
        // footer pinned to the bottom left a big empty gap above it).
        ScrollView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    status
                    if store.pending { Text(model.t("premium_pending")).font(.subheadline) }
                    if showPlans {
                        HStack(alignment: .top, spacing: 8) {
                            ForEach(store.plans, id: \.self) { tile($0) }
                        }
                        .fixedSize(horizontal: false, vertical: true)
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
                footer
            }
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
        .alert(confirmationTitle, isPresented: Binding(
            get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }), presenting: confirmation) { action in
            Button(model.t("cancel"), role: .cancel) {}
            switch action {
            case .confirmSwitch(let plan):
                Button(model.t("ios_premium_switch_confirm")) { Task { await store.buy(plan) } }
            default:
                Button(model.t("premium_buy_lifetime_anyway")) { Task { await store.buy(.lifetime) } }
            }
        } message: { action in
            if case .confirmSwitch(let plan) = action {
                Text(model.premiumSwitchNote(state, to: plan) ?? "")
            } else {
                Text(model.t("premium_lifetime_confirm_body"))
            }
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
                    statusCard("premium_cancelled_title", "premium_cancelled_body", .orange)
                } else {
                    statusCard("premium_subscriber_title", "premium_subscriber_body", Theme.teal,
                               bodyText: model.premiumRenewalMessage(state),
                               bodyIdentifier: "subscription_renewal_date")
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
                            bodyIdentifier: String? = nil,
                            @ViewBuilder action: () -> some View = { EmptyView() }) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.t(title)).font(.headline)
            Text(bodyText ?? model.t(body)).font(.subheadline)
                .accessibilityIdentifier(bodyIdentifier ?? "")
            action().padding(.top, 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 16, tint: color)
    }

    private func tile(_ id: PremiumPlanID) -> some View {
        let isSelected = id == plan
        let current = (state.lifetime && id == .lifetime) || (state.subscribed && !state.lifetime && id == state.currentPlan)
        let period = id == .monthly ? "premium_per_month" : id == .yearly ? "premium_per_year" : "premium_one_time"
        return Button {
            selection.tap(id)
        } label: {
            VStack(spacing: 6) {
                Group {
                    if id == .yearly {
                        Text(model.t("premium_best_value")).font(.caption2.weight(.semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 2).background(Theme.teal, in: Capsule())
                            .minimumScaleFactor(0.7).lineLimit(1)
                    } else {
                        Color.clear
                    }
                }
                .frame(height: 20)
                Text(model.t("premium_\(id.rawValue)")).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
                Text(store.products[id]?.displayPrice ?? "").font(.title3.bold()).minimumScaleFactor(0.6).lineLimit(1)
                Text(model.t(period)).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                if let badge = model.premiumPlanBadgeText(state, id) {
                    Text(badge)
                        .font(.caption2.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .foregroundStyle(current ? Color.primary : Theme.teal)
                        .background(current ? Color.primary.opacity(0.08) : Theme.teal.opacity(0.12), in: Capsule())
                        .accessibilityIdentifier("premium_\(current ? "current" : "scheduled")_\(id.rawValue)")
                }
                Spacer(minLength: 0)
            }
            .padding(EdgeInsets(top: 10, leading: 8, bottom: 12, trailing: 8))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassPanel(cornerRadius: 16, tint: isSelected ? Theme.teal : nil, interactive: true)
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(isSelected ? Theme.teal : Color.secondary.opacity(0.3),
                                                                     lineWidth: isSelected ? 2 : 1))
            // The whole box answers a tap, edges and corners included, not
            // only its text (on a device the empty glass did not respond).
            .contentShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .contentShape(.rect(cornerRadius: 16))
        .opacity(store.canBuy(id) || current || id == state.scheduledPlan ? 1 : 0.5)
        .accessibilityIdentifier("premium_plan_\(id.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var footer: some View {
        VStack(spacing: 4) {
            if showPlans, !state.lifetime, let plan {
                let price = store.products[plan]?.displayPrice ?? ""
                let reactivating = state.subscriptionCancelled && plan == state.currentPlan
                let title = reactivating ? model.t("premium_reactivate")
                    : "\(model.t("premium_\(plan.rawValue)")) · \(price)"
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
            // Two centred rows with room between the links; a row that does
            // not fit (long translations) stacks its links instead.
            VStack(spacing: 4) {
                linkRow(link("premium_restore") { Task { await restore() } }.disabled(store.busy),
                        link("premium_manage") { managing = true })
                linkRow(link("terms_of_service") { openURL(Self.termsURL) },
                        link("privacy_policy") { openURL(Self.privacyURL) })
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    private func linkRow(_ first: some View, _ second: some View) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { first; second }
            VStack(spacing: 4) { first; second }
        }
    }

    private func link(_ key: String, action: @escaping () -> Void) -> some View {
        Button(model.t(key), action: action).font(.footnote).padding(.horizontal, 8).padding(.vertical, 6).foregroundStyle(Theme.teal)
    }

    /// The App Store cannot cancel a subscription for the app, so a
    /// subscriber is told before buying lifetime to cancel it themselves. A
    /// downgrade first says when each plan applies (Apple keeps the current
    /// plan ticked in its Manage sheet until the renewal).
    private func buy(_ action: PremiumPaywallAction) {
        switch action {
        case .purchase(let plan): Task { await store.buy(plan) }
        case .confirmLifetime, .confirmSwitch: confirmation = action
        case .manage: managing = true
        case .none: break
        }
    }

    private var confirmationTitle: String {
        if case .confirmSwitch = confirmation { return model.t("ios_premium_switch_title") }
        return model.t("premium_lifetime_confirm_title")
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
