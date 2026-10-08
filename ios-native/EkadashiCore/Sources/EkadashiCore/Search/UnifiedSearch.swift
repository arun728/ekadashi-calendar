import Foundation

/// One searchable thing: an Ekadashi, a Panchang observance on a date, a
/// calendar entry or an app screen.
public struct SearchItem: Identifiable, Equatable, Sendable {
    /// `<occurrence uid>`, `observance:<key>:<date>`, `entry:<id>` or `screen:<key>`.
    public let id: String
    public let target: SearchTarget
    public let categories: [SearchCategory]
    /// The title in the app language.
    public let title: String
    public let titleEnglish: String
    /// Every name that counts as a title match: all languages and aliases.
    public let names: [String]
    /// Other searchable text (descriptions, notes, calendar names).
    public let text: String
    public let date: CivilDate?
    /// Panchang observances belong to the Premium festival finder.
    public let requiresPremium: Bool

    public init(id: String, target: SearchTarget, categories: [SearchCategory], title: String, titleEnglish: String,
                names: [String], text: String, date: CivilDate?, requiresPremium: Bool) {
        self.id = id
        self.target = target
        self.categories = categories
        self.title = title
        self.titleEnglish = titleEnglish
        self.names = names
        self.text = text
        self.date = date
        self.requiresPremium = requiresPremium
    }
}

/// A query split into words, with a year and a type taken out of it.
public struct ParsedSearchQuery: Equatable, Sendable {
    public let tokens: [String]
    public let year: Int?
    public let category: SearchCategory?

    /// Nothing left to match: list everything the filters allow.
    public var isListing: Bool { tokens.isEmpty }
}

public enum SearchQueryParser {
    /// A four-digit year becomes the year filter and a type word ("amavasai",
    /// "festivals", "शिवरात्रि") the type filter. A chip the user chose wins
    /// over a word in the query. A type word alone lists that type; with other
    /// words it filters and still has to match.
    public static func parse(_ raw: String, catalog: SearchCatalog = .bundled, category chip: SearchCategory? = nil,
                             year chipYear: Int? = nil) -> ParsedSearchQuery {
        var year = chipYear
        var words: [String] = []
        for token in SearchText.normalize(raw).split(separator: " ").map(String.init) {
            if token.count == 4, token.allSatisfy({ $0.isASCII && $0.isNumber }), let value = Int(token), (1900...2200).contains(value) {
                if chipYear == nil { year = value }
                continue
            }
            words.append(token)
        }
        guard chip == nil else { return ParsedSearchQuery(tokens: words, year: year, category: chip) }
        var category: SearchCategory?
        var typeWords = 0
        for word in words {
            if let named = catalog.category(named: word) {
                category = category ?? named
                typeWords += 1
            }
        }
        let onlyTypeWords = category != nil && typeWords == words.count
        return ParsedSearchQuery(tokens: onlyTypeWords ? [] : words, year: year, category: category)
    }
}

/// On-device search over the whole app. Every query word must match a word
/// of the item (exactly, as a prefix, with a typo, or as in-order letters),
/// then results rank by how well a name matches:
///
/// 1000 exact name · 900 name starts with the query and a space · 800 name
/// prefix · 600 name contains the query · 450 every word starts a name word
/// · 300 − 10 per typo when every word matches a name word · 200 body words
/// · 100 − 10 per typo in body words · 50 in-order letters ("ekdsh").
///
/// Equal scores show upcoming dates first (soonest first), then undated
/// screens, then past dates (most recent first).
public final class UnifiedSearch: @unchecked Sendable {
    private struct Prepared {
        let item: SearchItem
        let names: [String]
        let nameTokens: [[String]]
        let words: [String]
    }

    public let items: [SearchItem]
    private let prepared: [Prepared]
    private let catalog: SearchCatalog

    public init(items: [SearchItem], catalog: SearchCatalog = .bundled) {
        self.items = items
        self.catalog = catalog
        prepared = items.map { item in
            let names = item.names.map(SearchText.normalize).filter { !$0.isEmpty }
            var words: [String] = []
            var seen: Set<String> = []
            let typeWords = item.categories.flatMap { catalog.keywords($0) }
            for word in (names + [SearchText.normalize(item.text)] + typeWords).joined(separator: " ").split(separator: " ")
            where seen.insert(String(word)).inserted {
                words.append(String(word))
            }
            return Prepared(item: item, names: names, nameTokens: names.map { $0.split(separator: " ").map(String.init) },
                            words: words)
        }
    }

    /// The data years, for the year filter.
    public var years: [Int] { Array(Set(items.compactMap { $0.date?.year })).sorted() }

    public func search(_ raw: String, category chip: SearchCategory? = nil, year chipYear: Int? = nil,
                       today: CivilDate, limit: Int = 300) -> [SearchItem] {
        let query = SearchQueryParser.parse(raw, catalog: catalog, category: chip, year: chipYear)
        func allowed(_ item: SearchItem) -> Bool {
            if let year = query.year, item.date?.year != year { return false }
            if let category = query.category, !item.categories.contains(category) { return false }
            return true
        }
        if query.isListing {
            guard query.year != nil || query.category != nil else { return [] }
            let listed = prepared.map(\.item).filter { allowed($0) && !$0.categories.contains(.screen) }
            return Array(listed.sorted { before($0, $1, today) }.prefix(limit))
        }
        let phrase = query.tokens.joined(separator: " ")
        var scored: [(SearchItem, Double)] = []
        for entry in prepared where allowed(entry.item) {
            if let score = score(entry, phrase, query.tokens) { scored.append((entry.item, score)) }
        }
        scored.sort { a, b in a.1 != b.1 ? a.1 > b.1 : before(a.0, b.0, today) }
        return Array(scored.prefix(limit).map(\.0))
    }

    /// Titles starting with (then containing) the typed text, in the app language.
    public func suggestions(_ raw: String, limit: Int = 5) -> [String] {
        let typed = SearchText.normalize(raw)
        guard !typed.isEmpty else { return [] }
        var result: [String] = []
        for pass in 0..<2 {
            for entry in prepared {
                let title = SearchText.normalize(entry.item.title)
                let hit = pass == 0 ? entry.names.contains { $0.hasPrefix(typed) } : title.contains(typed)
                if hit, !result.contains(entry.item.title) { result.append(entry.item.title) }
                if result.count == limit { return result }
            }
        }
        return result
    }

    private func score(_ entry: Prepared, _ phrase: String, _ tokens: [String]) -> Double? {
        var edits = 0
        var looseLetters = false
        for token in tokens {
            if let best = entry.words.compactMap({ SearchText.tokenDistance(token, $0) }).min() {
                edits += best
            } else if token.count >= 3,
                      entry.words.contains(where: { $0.first == token.first && SearchText.isSubsequence(token, of: $0) }) {
                looseLetters = true
            } else {
                return nil
            }
        }
        if looseLetters { return 50 }
        var best = 0.0
        for (name, nameTokens) in zip(entry.names, entry.nameTokens) {
            let value: Double
            if name == phrase { value = 1000 }
            else if name.hasPrefix(phrase + " ") { value = 900 }
            else if name.hasPrefix(phrase) { value = 800 }
            else if name.contains(phrase) { value = 600 }
            else if tokens.allSatisfy({ q in nameTokens.contains { SearchText.tokenDistance(q, $0) == 0 } }) { value = 450 }
            else if tokens.allSatisfy({ q in nameTokens.contains { SearchText.tokenDistance(q, $0) != nil } }) {
                value = 300 - Double(edits) * 10
            } else { value = 0 }
            best = max(best, value)
        }
        if best == 0 { best = edits == 0 ? 200 : 100 - Double(edits) * 10 }
        return best
    }

    /// Upcoming first (soonest first), then undated, then past (latest first).
    private func before(_ a: SearchItem, _ b: SearchItem, _ today: CivilDate) -> Bool {
        func bucket(_ date: CivilDate?) -> Int { date.map { $0 >= today ? 0 : 2 } ?? 1 }
        let (ba, bb) = (bucket(a.date), bucket(b.date))
        if ba != bb { return ba < bb }
        if let da = a.date, let db = b.date, da != db { return ba == 0 ? da < db : da > db }
        return a.id < b.id
    }
}
