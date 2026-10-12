import Foundation

/// One important day in the Panchang's Key days list.
public struct KeyDay: Identifiable, Hashable, Sendable {
    /// `<occurrence uid>` for published Ekadashis, else `<catalogue key>:<date>`.
    public let id: String
    /// The catalogue key (nil for published Ekadashis).
    public let key: String?
    public let date: CivilDate
    public let title: String
    public let categories: [SearchCategory]
    /// Panchang observances are Premium; published Ekadashis are free.
    public let requiresPremium: Bool
}

/// The month's Ekadashis (published schedule, authoritative) and catalogued
/// Panchang observances (Amavasya, Purnima, Shivaratri, festivals, ...).
public enum PanchangKeyDays {
    public static func month(_ month: CivilDate, observances: [DatedObservance], ekadashis: [EkadashiOccurrence],
                             language: String, catalog: SearchCatalog = .bundled) -> [KeyDay] {
        func inMonth(_ date: CivilDate) -> Bool { date.year == month.year && date.month == month.month }
        var days = ekadashis.filter { inMonth($0.date) }.map {
            KeyDay(id: $0.occurrenceUid, key: nil, date: $0.date, title: $0.name, categories: [.ekadashi], requiresPremium: false)
        }
        var seen: Set<String> = []
        for dated in observances where inMonth(dated.date) && !catalog.excludedEngineIds.contains(dated.observance.id) {
            guard let entry = catalog.observance(engineId: dated.observance.id, name: dated.observance.name),
                  seen.insert("\(entry.key):\(dated.date.iso)").inserted else { continue }
            days.append(KeyDay(id: "\(entry.key):\(dated.date.iso)", key: entry.key, date: dated.date, title: entry.name(language),
                               categories: entry.categories, requiresPremium: true))
        }
        return days.enumerated().sorted { a, b in
            if a.element.date != b.element.date { return a.element.date < b.element.date }
            let rank = { (day: KeyDay) in day.categories.contains(.ekadashi) ? 0 : day.categories.contains(.festival) ? 1 : 2 }
            if rank(a.element) != rank(b.element) { return rank(a.element) < rank(b.element) }
            return a.offset < b.offset
        }.map(\.element)
    }

    public static func filter(_ days: [KeyDay], category: SearchCategory?) -> [KeyDay] {
        guard let category else { return days }
        return days.filter { $0.categories.contains(category) }
    }
}
