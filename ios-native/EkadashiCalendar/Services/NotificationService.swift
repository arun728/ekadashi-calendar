import Foundation
import UserNotifications
import EkadashiCore

/// Local reminders (NotificationScheduler.kt): Ekadashi reminders at instants
/// from the published schedule, and the user's festival, Panchang and
/// calendar reminders (docs/ROADMAP.md Phase 7).
@MainActor
final class NotificationService {
    private let center = UNUserNotificationCenter.current()
    static let prefix = "ekadashi."
    private let assumeAuthorized: Bool

    init(assumeAuthorized: Bool = false) { self.assumeAuthorized = assumeAuthorized }

    func requestAuthorization() async -> Bool {
        if assumeAuthorized { return true }
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func isAuthorized() async -> Bool {
        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        if assumeAuthorized { return .authorized }
        return await center.notificationSettings().authorizationStatus
    }

    /// Replaces this app's pending reminders with [plan] (Ekadashi and
    /// event reminders, docs/ROADMAP.md Phase 7).
    func schedule(_ plan: [PendingNotification]) async {
        await cancelAll()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        for reminder in plan {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            content.userInfo = ["url": reminder.url.absoluteString]
            var parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.fireDate)
            parts.calendar = calendar
            parts.timeZone = calendar.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "\(Self.prefix)\(reminder.id)", content: content, trigger: trigger))
        }
    }

    func cancelAll() async {
        let ids = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func sendTest(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "\(Self.prefix)test", content: content, trigger: trigger))
    }
}
