import SwiftUI
import StoreKit
import UserNotifications
import EkadashiCore

/// Settings (settings_screen.dart): Premium, widget preview, dark mode,
/// reminders, permissions and about.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL
    @State private var authorization: UNAuthorizationStatus = .notDetermined
    @State private var backgroundRefresh: UIBackgroundRefreshStatus = .available
    @State private var showGuide = false

    private var hasPermission: Bool { authorization == .authorized || authorization == .provisional || authorization == .ephemeral }
    private var settings: ReminderSettings { model.reminderSettings }
    private var togglesEnabled: Bool { hasPermission && settings.enabled }

    var body: some View {
        List {
            Section {
                SettingsPremiumCard()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section(model.t("appearance")) {
                NavigationLink {
                    WidgetPreviewView()
                } label: {
                    row("square.grid.2x2", model.t("widget_preview"), model.t("widget_preview_desc"))
                }
                Toggle(isOn: Binding(get: { model.isDarkMode }, set: { model.setDarkMode($0) })) {
                    Label(model.t("dark_mode"), systemImage: "moon.fill")
                }
                .tint(Theme.teal)
            }
            .accessibilityIdentifier("settings_appearance_tube")

            Section(model.t("notifications")) {
                Toggle(isOn: Binding(get: { settings.enabled && hasPermission }, set: { on in Task { await toggleNotifications(on) } })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.t("enable_notifications"))
                        if !hasPermission {
                            Text(model.t("notifications_off")).font(.caption).foregroundStyle(.orange)
                        } else if settings.enabled {
                            Text(model.t("reminders_active", String(settings.activeCount))).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                reminder("notify_2day", \.twoDaysBefore)
                reminder("notify_1day", \.oneDayBefore)
                reminder("notify_start", \.onFastingStart)
                reminder("notify_parana", \.onParana)
                if togglesEnabled {
                    Button {
                        Task {
                            await model.notifications.sendTest(title: model.t("test_notif_title"), body: model.t("test_notif_body"))
                            model.show("notif_sent_msg")
                        }
                    } label: {
                        row("bell.badge", model.t("test_notification"), model.t("test_notification_desc"))
                    }
                    .buttonStyle(.plain)
                }
            }
            .tint(Theme.teal)
            .accessibilityIdentifier("settings_notifications_tube")

            Section(model.t("permissions")) {
                Button { openSettings() } label: {
                    row("gearshape", model.t("app_settings"), model.t("app_settings_desc"))
                }
                .buttonStyle(.plain)
                HStack {
                    row("arrow.clockwise.circle", model.t("ios_background_refresh"), model.t("ios_background_refresh_desc"))
                    Spacer()
                    StatusPill(text: model.t(backgroundRefresh == .available ? "status_active" : "status_disabled"),
                               color: backgroundRefresh == .available ? Theme.observed : .orange)
                }
                Button { showGuide = true } label: {
                    row("info.circle", model.t("perm_guide_title"), nil)
                }
                .buttonStyle(.plain)
            }

            Section(model.t("about")) {
                Button { rate() } label: { row("star.fill", model.t("rate_app"), model.t("rate_app_desc")) }
                    .buttonStyle(.plain)
                ShareLink(item: model.t("ios_share_message", appStoreLink)) {
                    row("square.and.arrow.up", model.t("share_app"), model.t("share_app_desc"))
                }
                .buttonStyle(.plain)
                HStack {
                    Text(model.t("version"))
                    Spacer()
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "").foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("settings_about_tube")
        }
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 80, for: .scrollContent)
        .alert(model.t("perm_guide_title"), isPresented: $showGuide) {
            Button(model.t("settings_button")) { openSettings() }
            Button(model.t("info_close"), role: .cancel) {}
        } message: {
            Text(model.t("perm_guide_desc"))
        }
        .task { await refreshStatus() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await refreshStatus() }
        }
    }

    /// Titles in the primary colour (white in dark mode), details in grey;
    /// teal only for icons and switches (docs/ROADMAP.md Phase 5).
    private func row(_ symbol: String, _ title: String, _ subtitle: String?) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.primary)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
        } icon: {
            Image(systemName: symbol).foregroundStyle(Theme.teal)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func reminder(_ key: String, _ path: WritableKeyPath<ReminderSettings, Bool>) -> some View {
        Toggle(isOn: Binding(get: { settings[keyPath: path] }, set: { on in
            var updated = settings
            updated[keyPath: path] = on
            model.updateReminders(updated)
        })) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.t(key))
                Text(model.t(settings[keyPath: path] ? "status_active" : "status_disabled")).font(.caption).foregroundStyle(.secondary)
            }
        }
        .disabled(!togglesEnabled)
    }

    /// Turning reminders on asks for permission once; after a denial iOS only
    /// allows changing it in Settings.
    private func toggleNotifications(_ on: Bool) async {
        if on && !hasPermission {
            if authorization == .notDetermined {
                guard await model.notifications.requestAuthorization() else {
                    await refreshStatus()
                    return
                }
            } else {
                openSettings()
                return
            }
        }
        var updated = settings
        updated.enabled = on
        model.updateReminders(updated)
        await refreshStatus()
    }

    private func refreshStatus() async {
        authorization = await model.notifications.authorizationStatus()
        backgroundRefresh = UIApplication.shared.backgroundRefreshStatus
        if hasPermission && settings.enabled { await model.scheduleReminders() }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }

    private var appStoreId: String { Bundle.main.object(forInfoDictionaryKey: "EkadashiAppStoreId") as? String ?? "" }

    private var appStoreLink: String {
        appStoreId.isEmpty ? "https://apps.apple.com/app/ekadashi-calendar" : "https://apps.apple.com/app/id\(appStoreId)"
    }

    /// The App Store review page when the app has a listing, else the system prompt.
    private func rate() {
        if !appStoreId.isEmpty, let url = URL(string: "https://apps.apple.com/app/id\(appStoreId)?action=write-review") {
            openURL(url)
        } else {
            requestReview()
        }
    }
}

/// Premium at the top of Settings: what it unlocks and the store prices
/// for free users; the plan, its state and Manage for members.
struct SettingsPremiumCard: View {
    @Environment(AppModel.self) private var model
    @State private var managing = false

    private var state: PremiumState { model.premium.state }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "crown.fill")
                    .font(.title2)
                    .foregroundStyle(LinearGradient(colors: [Theme.amber, .orange], startPoint: .top, endPoint: .bottom))
                    .frame(width: 52, height: 52)
                    .background(Theme.amber.opacity(0.18), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.t("premium_title")).font(.title3.weight(.bold)).foregroundStyle(.primary)
                    Text(model.t(subtitleKey)).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if model.premium.isPremium { member } else { offer }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Theme.teal.opacity(0.45), Theme.teal.opacity(0.12)], startPoint: .topLeading,
                           endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .glassPanel(cornerRadius: 24)
        .manageSubscriptionsSheet(isPresented: $managing)
    }

    private var subtitleKey: String {
        if state.lifetime { return "premium_lifetime_thanks_title" }
        if state.subscribed { return state.subscriptionCancelled ? "premium_cancelled_title" : "premium_subscriber_title" }
        return "settings_premium_subtitle"
    }

    private var offer: some View {
        VStack(alignment: .leading, spacing: 10) {
            benefit("calendar.badge.clock", "premium_feature_calendar")
            benefit("leaf.fill", "premium_feature_vrat")
            benefit("sparkles", "premium_feature_panchang_v2")
            if let monthly = model.premium.products[.monthly]?.displayPrice,
               let lifetime = model.premium.products[.lifetime]?.displayPrice {
                Text(model.t("settings_premium_from", monthly, lifetime)).font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary).padding(.top, 2)
            }
            Button { model.openPaywall() } label: {
                Text(model.t("settings_premium_cta")).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .primaryActionStyle()
            .accessibilityIdentifier("settings_premium")
        }
    }

    private var member: some View {
        VStack(alignment: .leading, spacing: 10) {
            if state.lifetime {
                Text(model.t("premium_lifetime_thanks_body")).font(.subheadline).foregroundStyle(.primary)
            } else if let plan = state.currentPlan {
                Text(model.t("settings_premium_plan", model.t("premium_\(plan.rawValue)"))).font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(model.t(state.subscriptionCancelled ? "premium_cancelled_body" : "premium_subscriber_body"))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                if state.subscribed {
                    Button { managing = true } label: {
                        Text(model.t("settings_premium_manage")).frame(maxWidth: .infinity).padding(.vertical, 4)
                    }
                    .secondaryActionStyle()
                }
                if !state.lifetime {
                    Button { model.openPaywall() } label: {
                        Text(model.t("settings_premium_plans")).frame(maxWidth: .infinity).padding(.vertical, 4)
                    }
                    .primaryActionStyle()
                    .accessibilityIdentifier("settings_premium")
                }
            }
        }
    }

    private func benefit(_ symbol: String, _ key: String) -> some View {
        Label {
            Text(model.t(key)).font(.subheadline).foregroundStyle(.primary)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Theme.teal)
        }
    }
}

/// Live previews of the two widgets, now and during the next Ekadashi
/// (widget_preview_screen.dart).
struct WidgetPreviewView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let snapshot = WidgetSnapshot.build(occurrences: model.ekadashis, timezone: model.timezone.rawValue,
                                            locationName: model.locationName, language: model.language, now: Date())
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let during = snapshot.nextEkadashi.map {
                $0.fastingStart.addingTimeInterval($0.paranaStart.timeIntervalSince($0.fastingStart) * 0.6)
            }
            ScrollView {
                VStack(spacing: 16) {
                    caption("widget_name_ekadashi")
                    HStack(spacing: 16) {
                        preview(width: 170, height: 170) { EkadashiWidgetView(snapshot: snapshot, now: context.date, family: .systemSmall) }
                            .accessibilityIdentifier("card_next_ekadashi")
                        if let during {
                            preview(width: 170, height: 170) { EkadashiWidgetView(snapshot: snapshot, now: during, family: .systemSmall) }
                                .accessibilityIdentifier("card_today_ekadashi")
                        }
                    }
                    if during != nil {
                        Text(model.t("widget_preview_during")).font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    preview(width: 360, height: 170) { EkadashiWidgetView(snapshot: snapshot, now: context.date, family: .systemMedium) }
                    caption("upcoming_ekadashis")
                    preview(width: 360, height: 170) {
                        UpcomingEkadashiWidgetView(snapshot: snapshot, now: context.date, family: .systemMedium)
                    }
                    preview(width: 360, height: 380) {
                        UpcomingEkadashiWidgetView(snapshot: snapshot, now: context.date, family: .systemLarge)
                    }
                    .accessibilityIdentifier("card_upcoming_ekadashi")
                }
                .padding(16)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(model.t("widget_preview"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func caption(_ key: String) -> some View {
        Text(model.t(key)).font(.footnote.weight(.semibold)).foregroundStyle(WidgetStyle.cyan).frame(maxWidth: .infinity, alignment: .leading)
    }

    private func preview(width: CGFloat, height: CGFloat, @ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: width, minHeight: height, maxHeight: height)
            .background(WidgetCardBackground())
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .environment(\.colorScheme, .dark)
    }
}
