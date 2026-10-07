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
    @State private var selected: PremiumPlanID?
    @State private var confirmLifetime = false
    @State private var managing = false
    @State private var toast: ToastMessage?

    static let privacyURL = URL(string: "https://arun728.github.io/ekadashi-calendar/privacy-policy")!
    static let termsURL = URL(string: "https://arun728.github.io/ekadashi-calendar/terms-of-service")!

    private var store: StoreKitPremiumService { model.premium }
    private var state: PremiumState { store.state }
    private var showPlans: Bool { !state.lifetime && !store.plans.isEmpty }

    /// The tapped plan, else yearly (best value), monthly, lifetime among
    /// those that can be bought, else the first.
    private var plan: PremiumPlanID? {
        let plans = store.plans
        if let selected, plans.contains(selected) { return selected }
        for id in [PremiumPlanID.yearly, .monthly, .lifetime] where plans.contains(id) && store.canBuy(id) { return id }
        return plans.first
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    status
                    if store.busy { ProgressView().tint(Theme.teal).frame(maxWidth: .infinity) }
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
            }
            footer
        }
        .background(AppBackground())
        .navigationTitle(model.t("premium_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .accessibilityLabel(model.t("premium_continue_free"))
                    .accessibilityIdentifier("premium_close")
            }
        }
        .manageSubscriptionsSheet(isPresented: $managing)
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
                    Image(systemName: "info.circle").foregroundStyle(Theme.teal)
                }
                .accessibilityIdentifier("premium_reason")
            }
            feature("arrow.triangle.2.circlepath", "premium_feature_calendar")
            feature("figure.mind.and.body", "premium_feature_vrat")
            feature("sunrise", "premium_feature_panchang")
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
        } else if state.subscribed {
            Group {
                if state.subscriptionCancelled {
                    statusCard("premium_cancelled_title", "premium_cancelled_body", .orange)
                } else {
                    statusCard("premium_subscriber_title", "premium_subscriber_body", Theme.teal)
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

    private func statusCard(_ title: String, _ body: String, _ color: Color,
                            @ViewBuilder action: () -> some View = { EmptyView() }) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.t(title)).font(.headline)
            Text(model.t(body)).font(.subheadline)
            action().padding(.top, 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 16, tint: color)
    }

    private func tile(_ id: PremiumPlanID) -> some View {
        let isSelected = id == plan
        let current = state.subscribed && !state.lifetime && id == state.currentPlan
        let period = id == .monthly ? "premium_per_month" : id == .yearly ? "premium_per_year" : "premium_one_time"
        return Button {
            selected = id
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
                if current {
                    Text(model.t("premium_current_plan")).font(.caption).foregroundStyle(Theme.teal)
                        .accessibilityIdentifier("premium_current_\(id.rawValue)")
                }
                Spacer(minLength: 0)
            }
            .padding(EdgeInsets(top: 10, leading: 8, bottom: 12, trailing: 8))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassPanel(cornerRadius: 16, tint: isSelected ? Theme.teal : nil, interactive: true)
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(isSelected ? Theme.teal : Color.secondary.opacity(0.3),
                                                                     lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .opacity(store.canBuy(id) || current ? 1 : 0.5)
        .accessibilityIdentifier("premium_plan_\(id.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var footer: some View {
        VStack(spacing: 4) {
            if showPlans, let plan {
                let price = store.products[plan]?.displayPrice ?? ""
                let title = state.subscriptionCancelled && plan == state.currentPlan
                    ? "\(model.t("premium_reactivate")) · \(price)" : "\(model.t("premium_\(plan.rawValue)")) · \(price)"
                Button {
                    buy(plan)
                } label: {
                    Text(title).font(.headline).multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .primaryActionStyle()
                .disabled(!store.canBuy(plan))
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
    /// subscriber is told before buying lifetime to cancel it themselves.
    private func buy(_ plan: PremiumPlanID) {
        if plan == .lifetime && state.subscribed {
            confirmLifetime = true
        } else {
            Task { await store.buy(plan) }
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
