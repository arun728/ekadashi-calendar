import Foundation

/// Store links for sharing (share card, Share App).
public enum AppLinks {
    /// The live v1 Android app.
    public static let playStore = "https://play.google.com/store/apps/details?id=com.applausestudios.ekadashi_calendar"
    /// Placeholder: the iOS app has no App Store listing yet (it launches
    /// with v2 at the end of 2026). Replace it, or set APP_STORE_ID, then
    /// (AGENTS.md "Store links").
    public static let appStorePlaceholder = "https://apps.apple.com/app/ekadashi-calendar"

    /// The App Store page for the configured id, else the placeholder.
    public static func appStore(id: String) -> String {
        id.isEmpty ? appStorePlaceholder : "https://apps.apple.com/app/id\(id)"
    }

    /// The text shared with a share card on iOS: the translated message,
    /// then the App Store link only (Android shares its Play Store link).
    public static func shareCardMessage(_ message: String, appStoreId: String) -> String {
        "\(message)\n\n\(appStore(id: appStoreId))"
    }
}
