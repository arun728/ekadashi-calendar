import Foundation

/// What a search result is; also the filter chips (all but `screen`).
public enum SearchCategory: String, CaseIterable, Codable, Sendable {
    case ekadashi, festival, amavasya, purnima, shivaratri, chaturthi, pradosham, navaratri, sankranti, jayanti
    case myCalendar = "my_calendar"
    case screen

    /// The filter chips, in display order after "All".
    public static let filters: [SearchCategory] = allCases.filter { $0 != .screen }

    public var localizationKey: String { "search_filter_\(rawValue)" }

    public var symbol: String {
        switch self {
        case .ekadashi: return "leaf"
        case .festival: return "sparkles"
        case .amavasya: return "moon"
        case .purnima: return "moon.fill"
        case .shivaratri: return "moon.stars"
        case .chaturthi: return "seal"
        case .pradosham: return "sunset"
        case .navaratri: return "flame"
        case .sankranti: return "sun.max"
        case .jayanti: return "star"
        case .myCalendar: return "calendar"
        case .screen: return "arrow.up.forward.app"
        }
    }

    /// RGB hex of the badge colour.
    public var colorHex: UInt32 {
        switch self {
        case .ekadashi: return 0x00A19B
        case .festival: return 0xF97316
        case .amavasya: return 0x6366F1
        case .purnima: return 0xEAB308
        case .shivaratri: return 0x8B5CF6
        case .chaturthi: return 0xEC4899
        case .pradosham: return 0xF59E0B
        case .navaratri: return 0xEF4444
        case .sankranti: return 0xF59E0B
        case .jayanti: return 0x0EA5E9
        case .myCalendar: return 0x10B981
        case .screen: return 0x64748B
        }
    }
}

/// Where a search result leads.
public enum SearchTarget: Hashable, Sendable {
    case ekadashi(occurrenceUid: String)
    case observance(key: String, date: CivilDate)
    case entry(id: String, date: CivilDate)
    case tab(AppTab)
    case paywall
    case widgetPreview
}

/// The shared search catalog (assets/search/search_catalog.json): Panchang
/// observances with names in every language and aliases, the words that act
/// as type filters, and app screens.
public struct SearchCatalog: Sendable {
    public struct Observance: Sendable {
        public let key: String
        public let engineId: String
        /// Set when one engine id carries several observances (the Bhadrapada
        /// Vinayaka Chaturthi is Ganesh Chaturthi).
        public let engineName: String?
        public let categories: [SearchCategory]
        public let names: [String: String]
        public let aliases: [String]

        public func name(_ language: String) -> String { names[language] ?? names["en"] ?? key }
    }

    public struct Screen: Sendable {
        public let key: String
        public let titleKey: String
        public let target: SearchTarget
        public let aliases: [String]
    }

    public let observances: [Observance]
    public let screens: [Screen]
    public let excludedEngineIds: Set<String>
    private let keywordTable: [SearchCategory: [String]]

    public static let bundled: SearchCatalog = {
        do {
            return try SearchCatalog(data: CoreResources.data("search/search_catalog.json"))
        } catch {
            assertionFailure("Unreadable search catalog: \(error)")
            return SearchCatalog(observances: [], screens: [], excludedEngineIds: [], keywordTable: [:])
        }
    }()

    private init(observances: [Observance], screens: [Screen], excludedEngineIds: Set<String>,
                 keywordTable: [SearchCategory: [String]]) {
        self.observances = observances
        self.screens = screens
        self.excludedEngineIds = excludedEngineIds
        self.keywordTable = keywordTable
    }

    public init(data: Data) throws {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CoreError.invalidArgument("search catalog")
        }
        var table: [SearchCategory: [String]] = [:]
        for (raw, words) in root["categories"] as? [String: [String]] ?? [:] {
            guard let category = SearchCategory(rawValue: raw) else { throw CoreError.invalidArgument("category \(raw)") }
            table[category] = words.map(SearchText.normalize)
        }
        var observances: [Observance] = []
        for row in root["observances"] as? [[String: Any]] ?? [] {
            let engine = row["engine"] as? [String: String] ?? [:]
            let categories = try (row["categories"] as? [String] ?? []).map { raw -> SearchCategory in
                guard let category = SearchCategory(rawValue: raw) else { throw CoreError.invalidArgument("category \(raw)") }
                return category
            }
            observances.append(Observance(key: row["key"] as? String ?? "", engineId: engine["id"] ?? "",
                                          engineName: engine["name"], categories: categories,
                                          names: row["names"] as? [String: String] ?? [:],
                                          aliases: row["aliases"] as? [String] ?? []))
        }
        var screens: [Screen] = []
        for row in root["screens"] as? [[String: Any]] ?? [] {
            let raw = row["target"] as? String ?? ""
            guard let target = Self.target(raw) else { throw CoreError.invalidArgument("screen target \(raw)") }
            screens.append(Screen(key: row["key"] as? String ?? "", titleKey: row["titleKey"] as? String ?? "",
                                  target: target, aliases: row["aliases"] as? [String] ?? []))
        }
        self.init(observances: observances, screens: screens,
                  excludedEngineIds: Set(root["excludedEngineIds"] as? [String] ?? []), keywordTable: table)
    }

    static func target(_ raw: String) -> SearchTarget? {
        switch raw {
        case "paywall": return .paywall
        case "widget_preview": return .widgetPreview
        case "tab:today": return .tab(.today)
        case "tab:calendar": return .tab(.calendar)
        case "tab:vrat": return .tab(.vrat)
        case "tab:panchang": return .tab(.panchang)
        case "tab:settings": return .tab(.settings)
        default: return nil
        }
    }

    /// Normalized words that name [category] in any language.
    public func keywords(_ category: SearchCategory) -> [String] { keywordTable[category] ?? [] }

    /// The catalogue entry for an engine observance, preferring one that also
    /// matches the engine's name.
    public func observance(engineId: String, name: String) -> Observance? {
        observances.first { $0.engineId == engineId && $0.engineName == name }
            ?? observances.first { $0.engineId == engineId && $0.engineName == nil }
    }

    /// The category one query word names, if any: an exact type word, or the
    /// start of one (four letters or more), or a type word with a typo.
    public func category(named word: String) -> SearchCategory? {
        for category in SearchCategory.filters {
            if keywords(category).contains(word) { return category }
        }
        guard word.count >= 4 else { return nil }
        for category in SearchCategory.filters {
            if keywords(category).contains(where: { SearchText.tokenDistance(word, $0) != nil }) { return category }
        }
        return nil
    }
}
