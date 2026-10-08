import Foundation

/// Builds the search items for the whole app (docs/ROADMAP.md Phase 1).
/// Titles follow the app language; every language's name stays searchable.
public enum SearchCorpus {
    public static func build(ekadashis: (String) -> [EkadashiOccurrence], observances: [DatedObservance],
                             entries: [CalendarEntry], timeZone: TimeZone, language: String,
                             catalog: SearchCatalog = .bundled, localizer: Localizer = .shared) -> [SearchItem] {
        ekadashiItems(ekadashis, language: language)
            + observanceItems(observances, language: language, catalog: catalog)
            + entryItems(entries, timeZone: timeZone)
            + screenItems(language: language, catalog: catalog, localizer: localizer)
    }

    /// Published Ekadashis (free). [ekadashis] returns the schedule in a language.
    public static func ekadashiItems(_ ekadashis: (String) -> [EkadashiOccurrence], language: String) -> [SearchItem] {
        var namesByUid: [String: [String]] = [:]
        var english: [String: String] = [:]
        for code in Localizer.languages {
            for event in ekadashis(code) {
                namesByUid[event.occurrenceUid, default: []].append(event.name)
                if code == "en" { english[event.occurrenceUid] = event.name }
            }
        }
        return ekadashis(language).map { event in
            SearchItem(id: event.occurrenceUid, target: .ekadashi(occurrenceUid: event.occurrenceUid), categories: [.ekadashi],
                       title: event.name, titleEnglish: english[event.occurrenceUid] ?? event.name,
                       names: namesByUid[event.occurrenceUid] ?? [event.name],
                       text: "\(event.description) \(event.paksha) \(event.month)", date: event.date, requiresPremium: false)
        }
    }

    /// Calculated Panchang observances that the catalogue knows (Premium).
    public static func observanceItems(_ observances: [DatedObservance], language: String,
                                       catalog: SearchCatalog = .bundled) -> [SearchItem] {
        var seen: Set<String> = []
        var items: [SearchItem] = []
        for dated in observances where !catalog.excludedEngineIds.contains(dated.observance.id) {
            guard let entry = catalog.observance(engineId: dated.observance.id, name: dated.observance.name) else { continue }
            let id = "observance:\(entry.key):\(dated.date.iso)"
            guard seen.insert(id).inserted else { continue }
            items.append(SearchItem(id: id, target: .observance(key: entry.key, date: dated.date), categories: entry.categories,
                                    title: entry.name(language), titleEnglish: entry.name("en"),
                                    names: Localizer.languages.map(entry.name) + entry.aliases, text: "",
                                    date: dated.date, requiresPremium: true))
        }
        return items
    }

    /// Custom entries and imported Google events, on the day they start.
    public static func entryItems(_ entries: [CalendarEntry], timeZone: TimeZone) -> [SearchItem] {
        entries.map { entry in
            let day = entry.allDayStart ?? CivilDate.today(in: timeZone, now: entry.start)
            let source = entry.source == .google ? "google" : "custom"
            return SearchItem(id: "entry:\(entry.id)", target: .entry(id: entry.id, date: day), categories: [.myCalendar],
                              title: entry.title, titleEnglish: entry.title, names: [entry.title],
                              text: [entry.notes, entry.calendarName, source].compactMap { $0 }.joined(separator: " "),
                              date: day, requiresPremium: false)
        }
    }

    /// App screens and settings.
    public static func screenItems(language: String, catalog: SearchCatalog = .bundled,
                                   localizer: Localizer = .shared) -> [SearchItem] {
        catalog.screens.map { screen in
            let titles = Localizer.languages.map { localizer.translate(screen.titleKey, language: $0) }
            return SearchItem(id: "screen:\(screen.key)", target: screen.target, categories: [.screen],
                              title: localizer.translate(screen.titleKey, language: language),
                              titleEnglish: localizer.translate(screen.titleKey, language: "en"),
                              names: titles + screen.aliases, text: "", date: nil, requiresPremium: false)
        }
    }
}
