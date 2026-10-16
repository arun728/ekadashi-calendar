import Foundation

/// City and country names in the app language (Resources/panchang/
/// place_names.json, generated from assets/ and shared with Android).
/// Names not in the table are written in the language's script by sound
/// (Transliterator), so a city never shows in Latin letters outside English.
public final class PlaceNames: @unchecked Sendable {
    public static let shared: PlaceNames = {
        (try? PlaceNames(data: CoreResources.data("panchang/place_names.json"))) ?? PlaceNames()
    }()

    private let places: [String: [String: String]]
    private let countries: [String: [String: String]]

    init() {
        places = [:]
        countries = [:]
    }

    public init(data: Data) throws {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let places = root["places"] as? [String: [String: String]],
              let countries = root["countries"] as? [String: [String: String]] else {
            throw CoreError.invalidData("Unreadable place names")
        }
        self.places = places
        self.countries = countries
    }

    /// [name] in [language]: the table's translation, else [name] written in
    /// the language's script by sound.
    public func place(_ name: String, language: String) -> String {
        guard language != "en", !name.isEmpty else { return name }
        return translation(name, language: language) ?? Transliterator.transliterate(name, language: language)
    }

    /// Whether the table has [name] in [language] (else it is transliterated).
    public func isKnown(_ name: String, language: String) -> Bool {
        language == "en" || translation(name, language: language) != nil
    }

    func translation(_ name: String, language: String) -> String? {
        places[name]?[language] ?? places[name.trimmingCharacters(in: .whitespaces)]?[language]
    }

    /// The country with ISO code [code] in [language]; the code in English.
    public func country(_ code: String, language: String) -> String {
        language == "en" ? code : countries[code]?[language] ?? code
    }

    /// A Panchang city label: "Chennai" or "Chennai (IN)" from the worldwide
    /// list, with the country spelled out in other languages.
    public func label(_ label: String, language: String) -> String {
        guard language != "en" else { return label }
        guard let match = label.range(of: #" \(([A-Z]{2})\)$"#, options: .regularExpression) else {
            return place(label, language: language)
        }
        let code = String(label[match].dropFirst(2).dropLast())
        return "\(place(String(label[..<match.lowerBound]), language: language)) (\(country(code, language: language)))"
    }
}
