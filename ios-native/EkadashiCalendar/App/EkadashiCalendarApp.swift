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

    // The completion-handler forms, answered on the main thread. The async
    // forms are resumed on a background thread, and UIKit then asserts
    // "Call must be made on main thread": a notification arriving while the
    // app is open crashed it, and a tapped one (lock screen or banner) never
    // opened its event.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        DispatchQueue.main.async { completionHandler([.banner, .sound, .list]) }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let link = response.notification.request.content.userInfo["url"] as? String
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                // Opens the reminder's day in Panchang or Calendar (or Home for
                // Ekadashi reminders); a cold launch queues it until loaded.
                if let link, let url = URL(string: link) { self.model.open(url) }
            }
            completionHandler()
        }
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
                .environment(\.glassLookEnabled, delegate.model.isGlassLookEnabled)
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
