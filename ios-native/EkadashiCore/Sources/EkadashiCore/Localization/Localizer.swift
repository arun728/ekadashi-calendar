import Foundation

/// The app's UI strings in English, Hindi, Tamil and Telugu, generated from
/// the Flutter ARB files so both apps say the same thing. The language is
/// chosen inside the app (as on Android), not only from the system.
public final class Localizer: @unchecked Sendable {
    public static let shared: Localizer = {
        do {
            return try Localizer(data: CoreResources.data("l10n/strings.json"),
                                 overrides: CoreResources.data("l10n/ios_overrides.json"))
        } catch {
            fatalError("Bundled strings are unreadable: \(error)")
        }
    }()

    /// Language codes in menu order (see `AppLanguage`).
    public static let languages = AppLanguage.all.map(\.code)

    /// The shared Android strings (lib/l10n/app_*.arb).
    private let table: [String: [String: String]]
    /// iOS wording where Android names Google Play or battery settings, and iOS-only keys.
    private let overrides: [String: [String: String]]

    public init(data: Data, overrides: Data? = nil) throws {
        guard let table = try JSONSerialization.jsonObject(with: data) as? [String: [String: String]] else {
            throw CoreError.invalidData("Unreadable strings")
        }
        self.table = table
        var platform: [String: [String: String]] = [:]
        if let overrides, let raw = try JSONSerialization.jsonObject(with: overrides) as? [String: Any] {
            for language in Self.languages { platform[language] = raw[language] as? [String: String] ?? [:] }
        }
        self.overrides = platform
    }

    public func keys(language: String) -> [String] { (table[language] ?? [:]).keys.sorted() }
    public func overrideKeys(language: String) -> [String] { (overrides[language] ?? [:]).keys.sorted() }

    /// The unmodified Android string, for drift checks.
    public func arbValue(_ key: String, language: String) -> String? { table[language]?[key] }

    /// The string for [key]; English for an unsupported language; the key itself when missing.
    public func translate(_ key: String, language: String) -> String {
        let code = Self.languages.contains(language) ? language : "en"
        return overrides[code]?[key] ?? table[code]?[key] ?? overrides["en"]?[key] ?? table["en"]?[key] ?? key
    }

    /// Fills `{value0}`, `{value1}`, ... in order.
    public func translate(_ key: String, language: String, args: [String]) -> String {
        var text = translate(key, language: language)
        for (index, arg) in args.enumerated() {
            text = text.replacingOccurrences(of: "{value\(index)}", with: arg)
        }
        return text
    }

    public static func placeholders(_ text: String) -> [String] {
        var result: [String] = []
        var rest = Substring(text)
        while let open = rest.firstIndex(of: "{"), let close = rest[open...].firstIndex(of: "}") {
            result.append(String(rest[open...close]))
            rest = rest[rest.index(after: close)...]
        }
        return result.sorted()
    }

    public static func displayName(_ language: String) -> String {
        AppLanguage.named(language)?.nativeName ?? "English"
    }

    /// The Foundation locale for dates and numbers in [language].
    public static func locale(_ language: String) -> Locale {
        Locale(identifier: AppLanguage.named(language)?.localeIdentifier ?? "en_US")
    }
}
