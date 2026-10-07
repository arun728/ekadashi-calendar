import Foundation

/// The app's UI strings in English, Tamil, Hindi and Telugu, generated from
/// the Flutter ARB files so both apps say the same thing. The language is
/// chosen inside the app (as on Android), not only from the system.
public final class Localizer: @unchecked Sendable {
    public static let shared: Localizer = {
        do {
            return try Localizer(data: CoreResources.data("l10n/strings.json"))
        } catch {
            fatalError("Bundled strings are unreadable: \(error)")
        }
    }()

    public static let languages = ["en", "ta", "hi", "te"]

    private let table: [String: [String: String]]

    public init(data: Data) throws {
        guard let table = try JSONSerialization.jsonObject(with: data) as? [String: [String: String]] else {
            throw CoreError.invalidData("Unreadable strings")
        }
        self.table = table
    }

    public func keys(language: String) -> [String] { (table[language] ?? [:]).keys.sorted() }

    /// The string for [key]; English for an unsupported language; the key itself when missing.
    public func translate(_ key: String, language: String) -> String {
        table[Self.languages.contains(language) ? language : "en"]?[key] ?? table["en"]?[key] ?? key
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
        ["en": "English", "ta": "தமிழ்", "hi": "हिंदी", "te": "తెలుగు"][language] ?? "English"
    }

    /// The Foundation locale for dates and numbers in [language].
    public static func locale(_ language: String) -> Locale {
        Locale(identifier: ["ta": "ta_IN", "hi": "hi_IN", "te": "te_IN"][language] ?? "en_US")
    }
}
