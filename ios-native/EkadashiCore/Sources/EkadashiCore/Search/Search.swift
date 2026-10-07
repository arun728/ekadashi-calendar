import Foundation

public enum SearchContentType: String, CaseIterable, Codable, Sendable {
    case all, ekadashi, katha, mantra, food, vratInfo, festival, temple, event

    public var localizationKey: String { "category_\(self == .vratInfo ? "vrat" : rawValue)" }

    /// SF Symbols matching the Android icons.
    public var symbol: String {
        switch self {
        case .all: return "sparkles"
        case .ekadashi: return "calendar"
        case .katha: return "book.fill"
        case .mantra: return "waveform"
        case .food: return "fork.knife"
        case .vratInfo: return "list.bullet.rectangle"
        case .festival: return "party.popper"
        case .temple: return "building.columns"
        case .event: return "calendar.badge.clock"
        }
    }

    /// RGB hex of the Android badge colour.
    public var colorHex: UInt32 {
        switch self {
        case .all, .ekadashi: return 0x00A19B
        case .katha: return 0x8B5CF6
        case .mantra: return 0xF59E0B
        case .food: return 0x10B981
        case .vratInfo: return 0xEC4899
        case .festival: return 0xF97316
        case .temple: return 0x0284C7
        case .event: return 0x6366F1
        }
    }
}

public struct SearchIndexEntry: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let contentType: SearchContentType
    public let title: String
    public let normalizedTitle: String
    public let description: String
    public let normalizedText: String
    public let keywords: [String]
    public let language: String
    public let date: String?
    public let tags: [String]
    public let sourceId: String
    public var isDownloaded: Bool?
    public var isOnlineOnly: Bool
    public let navigationTarget: String
    public let metadata: [String: SearchValue]

    public func metadataString(_ key: String) -> String? {
        if case .string(let value)? = metadata[key] { return value }
        return nil
    }

    public func metadataInt(_ key: String) -> Int? {
        if case .number(let value)? = metadata[key] { return Int(value) }
        return nil
    }
}

/// A JSON value in search metadata (curated items carry lists of steps or rules).
public enum SearchValue: Codable, Equatable, Sendable {
    case string(String), number(Double), bool(Bool), list([SearchValue]), null

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null } else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) } else { self = .list(try c.decode([SearchValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n): try c.encode(n)
        case .bool(let b): try c.encode(b)
        case .list(let l): try c.encode(l)
        case .null: try c.encodeNil()
        }
    }

    /// Display text: lists become one item per line.
    public var text: String? {
        switch self {
        case .string(let s): return s
        case .number(let n): return n == n.rounded() ? String(Int(n)) : String(n)
        case .list(let l): return l.compactMap(\.text).map { "• \($0)" }.joined(separator: "\n")
        default: return nil
        }
    }
}

public struct SearchResult: Equatable, Sendable, Identifiable {
    public let entry: SearchIndexEntry
    public let score: Double
    public let snippet: String
    public var id: String { entry.id }
    public var title: String { entry.title }
}

public enum SearchText {
    /// Keeps Indic letters and combining marks; punctuation is a token boundary.
    public static func normalize(_ text: String) -> String {
        var out = ""
        var lastWasSpace = true
        for scalar in text.lowercased().unicodeScalars {
            let v = scalar.value
            // Dart's \w is ASCII [A-Za-z0-9_]; Devanagari, Tamil and Telugu are kept.
            let keep = (0x61...0x7A).contains(v) || (0x30...0x39).contains(v) || v == 0x5F
                || (0x0900...0x097F).contains(v) || (0x0B80...0x0BFF).contains(v) || (0x0C00...0x0C7F).contains(v)
            if keep {
                out.unicodeScalars.append(scalar)
                lastWasSpace = false
            } else if !lastWasSpace {
                out.append(" ")
                lastWasSpace = true
            }
        }
        return out.trimmingCharacters(in: .whitespaces)
    }

    /// Optimal-string-alignment Damerau–Levenshtein over displayed characters.
    /// Numeric and short queries stay strict; longer words allow two edits.
    public static func tokenDistance(_ query: String, _ candidate: String) -> Int? {
        if query == candidate || candidate.hasPrefix(query) { return 0 }
        let a = Array(query), b = Array(candidate)
        let maxEdits = a.count < 4 || query.allSatisfy(\.isNumber) ? 0 : (a.count < 8 ? 1 : 2)
        if maxEdits == 0 || abs(a.count - b.count) > maxEdits { return nil }
        var d = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { d[i][0] = i }
        for j in 0...b.count { d[0][j] = j }
        for i in 1...max(1, a.count) where i <= a.count {
            for j in 1...max(1, b.count) where j <= b.count {
                var value = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
                if i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1] { value = min(value, d[i - 2][j - 2] + 1) }
                d[i][j] = value
            }
        }
        let distance = d[a.count][b.count]
        return distance <= maxEdits ? distance : nil
    }
}

/// On-device search across Ekadashis, kathas, Vrat rules and the curated
/// catalog (search_index_manager.dart and content_catalog_service.dart).
public final class SearchIndex: @unchecked Sendable {
    private var entries: [SearchIndexEntry] = []
    private var downloaded: Set<String>
    private let lock = NSLock()
    public private(set) var language = "en"
    public static let catalog: [SearchIndexEntry] = {
        do {
            return try JSONDecoder().decode([SearchIndexEntry].self, from: CoreResources.data("search/catalog.json"))
        } catch {
            assertionFailure("Unreadable search catalog: \(error)")
            return []
        }
    }()

    public init(downloaded: Set<String> = []) { self.downloaded = downloaded }

    public func build(ekadashis: [EkadashiOccurrence], language: String, localizer: Localizer = .shared) {
        let katha = localizer.translate("category_katha", language: language)
        let rules = localizer.translate("fasting_rules", language: language)
        var built: [SearchIndexEntry] = []
        for e in ekadashis {
            let date = e.date.iso
            func meta(_ extra: [String: SearchValue]) -> [String: SearchValue] {
                extra.merging(["ekadashi_id": .number(Double(e.id)), "occurrence_uid": .string(e.occurrenceUid),
                               "year": .number(Double(e.date.year)), "name": .string(e.name)]) { a, _ in a }
            }
            built.append(SearchIndexEntry(
                id: "ekadashi_\(e.id)", contentType: .ekadashi, title: e.name, normalizedTitle: SearchText.normalize(e.name),
                description: e.description,
                normalizedText: SearchText.normalize("\(e.name) \(e.description) \(e.paksha) \(e.month) \(e.benefits)"),
                keywords: ["ekadashi", "vrat", "fasting", e.name.lowercased(), e.paksha.lowercased(), e.month.lowercased(), "parana"],
                language: language, date: date, tags: [e.paksha, e.month, "Ekadashi", "Vrat"], sourceId: "\(e.id)",
                isDownloaded: true, isOnlineOnly: false, navigationTarget: "ekadashi_detail",
                metadata: meta(["date": .string(date), "paksha": .string(e.paksha), "month": .string(e.month),
                                "fastStartTime": .string(e.fastStartTime), "fastBreakTime": .string(e.fastBreakTime),
                                "benefits": .string(e.benefits)])))
            if !e.story.isEmpty {
                built.append(SearchIndexEntry(
                    id: "katha_\(e.id)", contentType: .katha, title: "\(e.name) \(katha)",
                    normalizedTitle: SearchText.normalize("\(e.name) \(katha) Story"), description: Self.excerpt(e.story),
                    normalizedText: SearchText.normalize("\(e.name) \(katha) Story \(e.story)"),
                    keywords: ["katha", "story", "history", "significance", e.name.lowercased()], language: language, date: date,
                    tags: ["Katha", "Story", e.name], sourceId: "\(e.id)", isDownloaded: true, isOnlineOnly: false,
                    navigationTarget: "katha_detail",
                    metadata: meta(["title": .string("\(e.name) \(katha)"), "full_story": .string(e.story), "date": .string(date)])))
            }
            if !e.fastingRules.isEmpty {
                built.append(SearchIndexEntry(
                    id: "vrat_info_\(e.id)", contentType: .vratInfo, title: "\(e.name) \(rules)",
                    normalizedTitle: SearchText.normalize("\(e.name) \(rules) Fasting Guidelines"),
                    description: Self.excerpt(e.fastingRules),
                    normalizedText: SearchText.normalize("\(e.name) \(rules) Fasting \(e.fastingRules)"),
                    keywords: ["vrat", "rules", "fasting rules", "guidelines", "parana", e.name.lowercased()], language: language,
                    date: date, tags: ["Vrat Info", "Rules", "Fasting"], sourceId: "\(e.id)", isDownloaded: true,
                    isOnlineOnly: false, navigationTarget: "vrat_detail",
                    metadata: meta(["title": .string("\(e.name) \(rules)"), "rules": .string(e.fastingRules)])))
            }
        }
        built.append(contentsOf: Self.catalog)
        lock.lock()
        entries = built
        self.language = language
        lock.unlock()
    }

    static func excerpt(_ text: String) -> String { text.count > 180 ? String(text.prefix(180)) + "..." : text }

    public func markDownloaded(_ id: String) {
        lock.lock()
        downloaded.insert(id)
        lock.unlock()
    }

    public func isDownloaded(_ entry: SearchIndexEntry) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return downloaded.contains(entry.id) || (entry.isDownloaded ?? !entry.isOnlineOnly)
    }

    /// Every query token must match a word; ranked by title match, then edits.
    public func search(_ query: String, filter: SearchContentType = .all, languageCode: String? = nil, year: Int? = nil,
                       offline: Bool = false) -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let normalized = SearchText.normalize(trimmed)
        let tokens = normalized.split(separator: " ").map(String.init)
        guard !trimmed.isEmpty, !tokens.isEmpty else { return [] }
        lock.lock()
        let snapshot = entries
        lock.unlock()
        var results: [SearchResult] = []
        for entry in snapshot {
            if let languageCode, entry.language != languageCode { continue }
            if let year, let date = entry.date, !date.hasPrefix("\(year)-") { continue }
            if filter != .all && entry.contentType != filter { continue }
            let available = isDownloaded(entry)
            if offline && !available { continue }
            let score = relevance(entry, normalized, tokens, available: available)
            if score > 0 { results.append(SearchResult(entry: entry, score: score, snippet: snippet(entry, trimmed))) }
        }
        return results.sorted { $0.score != $1.score ? $0.score > $1.score : $0.id < $1.id }
    }

    func relevance(_ entry: SearchIndexEntry, _ query: String, _ tokens: [String], available: Bool) -> Double {
        let title = SearchText.normalize(entry.title)
        let titleTokens = title.split(separator: " ").map(String.init)
        let words = Set(SearchText.normalize("\(entry.title) \(entry.normalizedText) \(entry.keywords.joined(separator: " ")) \(entry.tags.joined(separator: " "))")
            .split(separator: " ").map(String.init))
        var edits = 0
        for token in tokens {
            let distances = words.compactMap { SearchText.tokenDistance(token, $0) }
            guard let best = distances.min() else { return 0 }
            edits += best
        }
        var score: Double
        if title == query { score = 1000 }
        else if title.hasPrefix(query + " ") { score = 900 }
        else if title.hasPrefix(query) { score = 800 }
        else if title.contains(query) { score = 600 }
        else if tokens.allSatisfy({ q in titleTokens.contains { SearchText.tokenDistance(q, $0) == 0 } }) { score = 450 }
        else if tokens.allSatisfy({ q in titleTokens.contains { SearchText.tokenDistance(q, $0) != nil } }) { score = 300 - Double(edits) * 10 }
        else if edits == 0 { score = 200 }
        else { score = 100 - Double(edits) * 10 }
        if entry.contentType == .ekadashi { score += 5 }
        if available && !entry.isOnlineOnly { score += 2 }
        return score
    }

    func snippet(_ entry: SearchIndexEntry, _ raw: String) -> String {
        let description = entry.description
        if let range = description.lowercased().range(of: raw.lowercased()) {
            let lower = description.lowercased()
            let index = lower.distance(from: lower.startIndex, to: range.lowerBound)
            let start = max(0, index - 30), end = min(description.count, index + raw.count + 50)
            let text = String(Array(description)[start..<end]).trimmingCharacters(in: .whitespaces)
            return (start > 0 ? "..." : "") + text + (end < description.count ? "..." : "")
        }
        return description.count > 90 ? String(description.prefix(90)) + "..." : description
    }

    /// Live suggestions: title prefixes, titles containing the text, keywords.
    public func suggestions(_ query: String, limit: Int = 5) -> [String] {
        let normalized = SearchText.normalize(query)
        guard !normalized.isEmpty else { return [] }
        lock.lock()
        let snapshot = entries.filter { $0.language == language }
        lock.unlock()
        var result: [String] = []
        func add(_ value: String) { if !result.contains(value) && result.count < limit { result.append(value) } }
        for entry in snapshot where entry.normalizedTitle.hasPrefix(normalized) { add(entry.title) }
        for entry in snapshot where entry.normalizedTitle.contains(normalized) { add(entry.title) }
        for entry in snapshot {
            for keyword in entry.keywords where SearchText.normalize(keyword).hasPrefix(normalized) {
                add(keyword.prefix(1).uppercased() + keyword.dropFirst())
            }
        }
        return result
    }
}

/// Private, on-device recent searches (recent_search_repository.dart).
public final class RecentSearches {
    public static let key = "ec2_recent_searches_list"
    public static let maxCount = 10
    let store: KeyValueStore
    public init(store: KeyValueStore) { self.store = store }

    public func all() -> [String] { Self.sanitize(store.stringArray(forKey: Self.key) ?? []) }

    /// Drops short typing prefixes (three letters or fewer) of longer entries and duplicates.
    public static func sanitize(_ list: [String]) -> [String] {
        var result: [String] = []
        for (i, raw) in list.enumerated() {
            let current = raw.trimmingCharacters(in: .whitespaces)
            if current.isEmpty { continue }
            let prefix = list.enumerated().contains { j, other in
                let o = other.trimmingCharacters(in: .whitespaces)
                return i != j && o.lowercased().hasPrefix(current.lowercased()) && current.count <= 3 && o.count > current.count
            }
            if !prefix && !result.contains(where: { $0.lowercased() == current.lowercased() }) { result.append(current) }
        }
        return result
    }

    public func add(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var list = store.stringArray(forKey: Self.key) ?? []
        list.removeAll { $0.lowercased() == trimmed.lowercased() }
        list.removeAll { item in
            let lower = item.lowercased(), query = trimmed.lowercased()
            return query.hasPrefix(lower) && lower.count <= 3 && lower.count < query.count
        }
        list.insert(trimmed, at: 0)
        store.set(Array(list.prefix(Self.maxCount)), forKey: Self.key)
    }

    public func remove(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        store.set((store.stringArray(forKey: Self.key) ?? []).filter { $0.lowercased() != trimmed }, forKey: Self.key)
    }

    public func clear() { store.remove(Self.key) }
}
