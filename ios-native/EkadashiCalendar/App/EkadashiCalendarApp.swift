import SwiftUI
import UserNotifications
import GoogleSignIn

/// Notification taps open their `ekadashi://` link, like the Android
/// notification payloads.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let model = AppModel()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions { [.banner, .sound, .list] }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let link = response.notification.request.content.userInfo["url"] as? String, let url = URL(string: link) else { return }
        await MainActor.run { model.open(url) }
    }
}

@main
struct EkadashiCalendarApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(delegate.model)
                .preferredColorScheme(delegate.model.isDarkMode ? .dark : .light)
                .environment(\.locale, delegate.model.locale)
                .onOpenURL { url in
                    if GIDSignIn.sharedInstance.handle(url) { return }
                    delegate.model.open(url)
                }
                .task { await delegate.model.start() }
                // Festival and Panchang reminders follow Premium.
                .onChange(of: delegate.model.premium.isPremium) { _, _ in
                    Task { await delegate.model.scheduleReminders() }
                }
        }
        .onChange(of: scenePhase) { _, phase in delegate.model.scenePhaseChanged(phase) }
        .backgroundTask(.appRefresh(AppModel.refreshTaskId)) {
            await delegate.model.backgroundRefresh()
        }
    }
}
