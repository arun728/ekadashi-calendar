import Foundation

/// The Panchang in the app language (docs/ROADMAP.md Phase 2). The engine
/// works in English terms; this table (assets/panchang/terms.json) gives
/// each term in Hindi, Tamil and Telugu. Observance names come from the
/// search catalogue. Unknown terms stay in English.
public final class PanchangTerms: @unchecked Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        case tithi, paksha, nakshatra, yoga, karana, month, vara, rashi, ritu, ayana, period, choghadiya, hora, anandadi
        case specialYoga = "special_yoga"
        case observance
        case ekadashiName = "ekadashi_name"
        case ekadashiRule = "ekadashi_rule"
    }

    public static let shared: PanchangTerms = {
        do {
            return try PanchangTerms(data: CoreResources.data("panchang/terms.json"))
        } catch {
            assertionFailure("Unreadable Panchang terms: \(error)")
            return PanchangTerms(table: [:], catalog: .bundled)
        }
    }()

    /// kind → English term → language → text.
    private let table: [String: [String: [String: String]]]
    private let catalog: SearchCatalog

    private init(table: [String: [String: [String: String]]], catalog: SearchCatalog) {
        self.table = table
        self.catalog = catalog
    }

    public convenience init(data: Data, catalog: SearchCatalog = .bundled) throws {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let kinds = root["kinds"] as? [String: [String: [String: String]]] else {
            throw CoreError.invalidData("Panchang terms")
        }
        self.init(table: kinds, catalog: catalog)
    }

    /// [term] in [language]; English (and anything unknown) unchanged.
    public func translate(_ term: String, _ kind: Kind, language: String) -> String {
        guard language != "en" else { return term }
        return table[kind.rawValue]?[term]?[language] ?? term
    }

    /// "Shukla Pratipada", "Krishna Ekadashi"; Purnima and Amavasya stand alone.
    public func tithi(paksha: String?, name: String, language: String) -> String {
        let tithi = translate(name, .tithi, language: language)
        guard let paksha, !paksha.isEmpty, name != "Purnima", name != "Amavasya" else { return tithi }
        return "\(translate(paksha, .paksha, language: language)) \(tithi)"
    }

    /// "Kartika" or "Adhika Shravana".
    public func month(_ name: String, language: String) -> String {
        let prefix = "Adhika "
        guard name.hasPrefix(prefix) else { return translate(name, .month, language: language) }
        let base = String(name.dropFirst(prefix.count))
        return "\(translate("Adhika", .month, language: language)) \(translate(base, .month, language: language))"
    }

    /// The engine's "Day · Udveg" and "Night · Amrit".
    public func choghadiya(_ name: String, language: String) -> String {
        let parts = name.components(separatedBy: " · ")
        guard parts.count == 2 else { return translate(name, .choghadiya, language: language) }
        let half = Localizer.shared.translate(parts[0] == "Night" ? "panchang_night" : "panchang_day", language: language)
        return "\(half) · \(translate(parts[1], .choghadiya, language: language))"
    }

    /// An observance's name: the catalogue's name, the table's, or English.
    public func observanceName(_ observance: PanchangObservance, language: String) -> String {
        if let entry = catalog.observance(engineId: observance.id, name: observance.name) { return entry.name(language) }
        return translate(observance.name, .observance, language: language)
    }

    /// A calculated fast's rule or Parana reason; "Jaya: nakshatra end, ..."
    /// is translated through its "{rule}: ..." template.
    public func ekadashiNote(_ text: String, language: String) -> String {
        // Reasons are built from a base plus suffixes; translate each part.
        for suffix in Self.noteSuffixes where text.hasSuffix(suffix) && text != suffix {
            let base = String(text.dropLast(suffix.count))
            return ekadashiNote(base, language: language) + translate(suffix, .ekadashiRule, language: language)
        }
        let direct = translate(text, .ekadashiRule, language: language)
        if direct != text || language == "en" { return direct }
        guard let colon = text.range(of: ": ") else { return text }
        let rule = String(text[..<colon.lowerBound])
        let template = "{rule}: " + text[colon.upperBound...]
        let translated = translate(template, .ekadashiRule, language: language)
        guard translated != template else { return text }
        return translated.replacingOccurrences(of: "{rule}", with: translate(rule, .ekadashiRule, language: language))
    }

    static let noteSuffixes = [". No bounded window; shown as after-only.", ". No bounded morning window; shown as after-only.",
                               ", before Dwadashi ends"]

    /// A period name (Rahu Kalam ...), choghadiya, hora planet or lagna rashi.
    public func period(_ name: String, language: String) -> String {
        if name.contains(" · ") { return choghadiya(name, language: language) }
        for kind in [Kind.period, .hora, .rashi] {
            let text = translate(name, kind, language: language)
            if text != name { return text }
        }
        return name
    }
}
