import Foundation

public enum SearchText {
    /// Keeps Indic letters and combining marks; punctuation is a token boundary.
    public static func normalize(_ text: String) -> String {
        var out = ""
        var lastWasSpace = true
        for scalar in text.lowercased().unicodeScalars {
            let v = scalar.value
            // Dart's \w is ASCII [A-Za-z0-9_]; Devanagari, Bengali, Gujarati,
            // Tamil and Telugu are kept.
            let keep = (0x61...0x7A).contains(v) || (0x30...0x39).contains(v) || v == 0x5F
                || (0x0900...0x097F).contains(v) || (0x0980...0x09FF).contains(v) || (0x0A80...0x0AFF).contains(v)
                || (0x0B80...0x0BFF).contains(v) || (0x0C00...0x0C7F).contains(v)
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

extension SearchText {
    /// True when every letter of [needle] appears in [hay] in order, as in
    /// "ekdsh" and "ekadashi" (vault-hub's Fuzzy.isSubsequence).
    public static func isSubsequence(_ needle: String, of hay: String) -> Bool {
        var index = needle.startIndex
        for character in hay where index != needle.endIndex {
            if character == needle[index] { index = needle.index(after: index) }
        }
        return index == needle.endIndex
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
