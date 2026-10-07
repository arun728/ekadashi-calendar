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
                Button { model.openPaywall() } label: {
                    row("crown.fill", model.t("premium_title"), model.premium.isPremium ? model.t("premium_active") : model.t("premium_free_achievements"))
                }
                .accessibilityIdentifier("settings_premium")
            }
            .listRowBackground(Rectangle().fill(.clear).glassPanel(cornerRadius: 16, tint: Theme.teal))

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
                }
            }
            .tint(Theme.teal)
            .accessibilityIdentifier("settings_notifications_tube")

            Section(model.t("permissions")) {
                Button { openSettings() } label: {
                    row("gearshape", model.t("app_settings"), model.t("app_settings_desc"))
                }
                HStack {
                    row("arrow.clockwise.circle", model.t("ios_background_refresh"), model.t("ios_background_refresh_desc"))
                    Spacer()
                    StatusPill(text: model.t(backgroundRefresh == .available ? "status_active" : "status_disabled"),
                               color: backgroundRefresh == .available ? Theme.observed : .orange)
                }
                Button { showGuide = true } label: {
                    row("info.circle", model.t("perm_guide_title"), nil)
                }
            }

            Section(model.t("about")) {
                Button { rate() } label: { row("star.fill", model.t("rate_app"), model.t("rate_app_desc")) }
                ShareLink(item: model.t("ios_share_message", appStoreLink)) {
                    row("square.and.arrow.up", model.t("share_app"), model.t("share_app_desc"))
                }
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

    private func row(_ symbol: String, _ title: String, _ subtitle: String?) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.primary)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
        } icon: {
            Image(systemName: symbol).foregroundStyle(Theme.teal)
        }
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

/// Live previews of the three widgets with tap-through (widget_preview_screen.dart).
struct WidgetPreviewView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let snapshot = WidgetSnapshot.build(occurrences: model.ekadashis, timezone: model.timezone.rawValue,
                                            locationName: model.locationName, language: model.language, now: Date())
        TimelineView(.periodic(from: .now, by: 60)) { context in
            ScrollView {
                VStack(spacing: 16) {
                    caption("ios_widget_small")
                    preview(width: 170, height: 170) { NextEkadashiWidgetView(snapshot: snapshot, now: context.date) }
                        .accessibilityIdentifier("card_next_ekadashi")
                    caption("ios_widget_medium")
                    preview(width: 360, height: 170) { TodayEkadashiWidgetView(snapshot: snapshot, now: context.date) }
                        .accessibilityIdentifier("card_today_ekadashi")
                    caption("ios_widget_large")
                    preview(width: 360, height: 380) { UpcomingEkadashiWidgetView(snapshot: snapshot, now: context.date) }
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
