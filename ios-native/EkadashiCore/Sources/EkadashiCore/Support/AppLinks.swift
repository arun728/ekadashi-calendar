import Foundation

/// Store links for sharing (share card, Share app), Rate app and the update prompt.
public enum AppLinks {
    /// The live v1 Android app.
    public static let playStore = "https://play.google.com/store/apps/details?id=com.applausestudios.ekadashi_calendar"

    /// The id Apple assigned to the iOS app in App Store Connect (also
    /// APP_STORE_ID in Config/App.xcconfig). Its page opens once the app is
    /// released, so builds made before the launch already share the real link.
    public static let appStoreId = "6825791305"

    /// The build's configured id (Info.plist EkadashiAppStoreId), else the real id.
    public static func appStoreId(configured: String?) -> String {
        let id = configured?.trimmingCharacters(in: .whitespaces) ?? ""
        return id.isEmpty ? appStoreId : id
    }

    /// The App Store page.
    public static func appStore(id: String = appStoreId) -> String {
        "https://apps.apple.com/app/id\(appStoreId(configured: id))"
    }

    /// The App Store page's "Write a Review" sheet (Rate app).
    public static func appStoreReview(id: String = appStoreId) -> String {
        appStore(id: id) + "?action=write-review"
    }

    /// The text shared with a share card on iOS: the translated message,
    /// then the App Store link only (Android shares its Play Store link).
    public static func shareCardMessage(_ message: String, appStoreId: String) -> String {
        "\(message)\n\n\(appStore(id: appStoreId))"
    }
}
