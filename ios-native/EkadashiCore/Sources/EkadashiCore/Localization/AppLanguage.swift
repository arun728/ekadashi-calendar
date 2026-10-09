import Foundation

/// The languages the app speaks, in menu order. New languages are appended
/// at the end, never inserted earlier, and need
/// their strings in every table (the tests check).
public struct AppLanguage: Hashable, Sendable {
    public let code: String
    /// The language's own name, as the language menu shows it.
    public let nativeName: String
    public let localeIdentifier: String

    public static let all: [AppLanguage] = [
        AppLanguage(code: "en", nativeName: "English", localeIdentifier: "en_US"),
        AppLanguage(code: "hi", nativeName: "हिंदी", localeIdentifier: "hi_IN"),
        AppLanguage(code: "ta", nativeName: "தமிழ்", localeIdentifier: "ta_IN"),
        AppLanguage(code: "te", nativeName: "తెలుగు", localeIdentifier: "te_IN"),
        AppLanguage(code: "gu", nativeName: "ગુજરાતી", localeIdentifier: "gu_IN"),
        AppLanguage(code: "bn", nativeName: "বাংলা", localeIdentifier: "bn_IN"),
    ]

    public static func named(_ code: String) -> AppLanguage? { all.first { $0.code == code } }
}
