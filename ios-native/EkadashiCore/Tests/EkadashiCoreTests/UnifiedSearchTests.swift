import Foundation
import XCTest
@testable import EkadashiCore

/// Phase 1 search (docs/ROADMAP.md): one index over Ekadashis, Panchang
/// observances, calendar entries and app screens.
final class SearchCatalogTests: XCTestCase {
    func testBundledCatalogIsByteIdenticalToTheSharedAsset() throws {
        XCTAssertEqual(try CoreResources.data("search/search_catalog.json"), try Repo.data("assets/search/search_catalog.json"))
    }

    func testEveryObservanceHasANameInEveryLanguageAndKnownCategories() {
        let catalog = SearchCatalog.bundled
        XCTAssertGreaterThan(catalog.observances.count, 30)
        XCTAssertEqual(Set(catalog.observances.map(\.key)).count, catalog.observances.count, "duplicate keys")
        for observance in catalog.observances {
            XCTAssertFalse(observance.categories.isEmpty, observance.key)
            XCTAssertFalse(observance.categories.contains(.screen), observance.key)
            for language in Localizer.languages {
                let name = observance.names[language] ?? ""
                XCTAssertFalse(name.trimmingCharacters(in: .whitespaces).isEmpty, "\(observance.key) \(language)")
                if language != "en" { XCTAssertNotEqual(name, observance.names["en"], "\(observance.key) \(language)") }
            }
        }
        for category in SearchCategory.filters where category != .myCalendar {
            XCTAssertFalse(catalog.keywords(category).isEmpty, category.rawValue)
        }
    }

    /// A new engine observance must be added to the catalog (or excluded on
    /// purpose), so search never silently misses it.
    func testEveryMajorEngineObservanceIsCataloguedOrExcluded() {
        let catalog = SearchCatalog.bundled
        let engine = PanchangEngine()
        var unknown: Set<String> = []
        for city in [PanchangCity.newDelhi, .chennai] {
            for (_, observance) in engine.observanceCalendar(year: 2026, city: city)
            where catalog.observance(engineId: observance.id, name: observance.name) == nil
                && !catalog.excludedEngineIds.contains(observance.id) {
                unknown.insert("\(observance.id) \(observance.name)")
            }
        }
        XCTAssertEqual(unknown.sorted(), [])
    }

    func testScreenTitlesAreTranslatedInEveryLanguage() {
        for screen in SearchCatalog.bundled.screens {
            for language in Localizer.languages {
                let title = Localizer.shared.translate(screen.titleKey, language: language)
                XCTAssertNotEqual(title, screen.titleKey, "\(screen.key) \(language)")
            }
        }
    }

    func testEveryFilterHasALabelInEveryLanguage() {
        for category in SearchCategory.allCases {
            for language in Localizer.languages {
                XCTAssertNotEqual(Localizer.shared.translate(category.localizationKey, language: language),
                                  category.localizationKey, "\(category.rawValue) \(language)")
            }
        }
    }
}

final class ObservanceCalendarTests: XCTestCase {
    /// The fast observances-only path matches the full day calculation.
    func testObservancesOnlyPathMatchesTheFullCalculation() {
        let engine = PanchangEngine()
        let cities = [PanchangCity.newDelhi, .chennai, PanchangCity(id: "london", label: "London", latitude: 51.5074,
                                                                     longitude: -0.1278, timeZoneId: "Europe/London")]
        for city in cities {
            var date = CivilDate(2026, 1, 1)
            while date.year == 2026 {
                XCTAssertEqual(engine.observances(on: date, city: city), engine.calculate(date, city: city).observances,
                               "\(city.id) \(date)")
                date = date.adding(days: 11)
            }
        }
    }

    func testObservanceCalendarCoversTheWholeYearInDateOrder() {
        let calendar = PanchangEngine().observanceCalendar(year: 2026, city: .newDelhi)
        XCTAssertEqual(calendar.first?.date.year, 2026)
        XCTAssertEqual(calendar.last?.date.year, 2026)
        XCTAssertEqual(calendar.map(\.date), calendar.map(\.date).sorted())
        XCTAssertTrue(calendar.contains { $0.date == CivilDate(2026, 11, 8) && $0.observance.id == "deepavali" })
        XCTAssertEqual(calendar.filter { $0.observance.id == "amavasya" }.count, 12)
    }
}

final class SearchQueryParserTests: XCTestCase {
    private let catalog = SearchCatalog.bundled

    func testYearsBecomeTheYearFilter() {
        let parsed = SearchQueryParser.parse("Diwali 2027", catalog: catalog)
        XCTAssertEqual(parsed.year, 2027)
        XCTAssertEqual(parsed.tokens, ["diwali"])
        XCTAssertFalse(parsed.isListing)
    }

    func testATypeWordAloneListsThatType() {
        for (query, category) in [("amavasai", SearchCategory.amavasya), ("अमावस्या", .amavasya), ("Festivals", .festival),
                                  ("shivratri", .shivaratri), ("ekadasi", .ekadashi), ("పౌర్ణమి", .purnima)] {
            let parsed = SearchQueryParser.parse(query, catalog: catalog)
            XCTAssertEqual(parsed.category, category, query)
            XCTAssertTrue(parsed.isListing, query)
        }
    }

    func testTypeWordsWithOtherWordsFilterAndStillMatch() {
        let parsed = SearchQueryParser.parse("maha shivratri", catalog: catalog)
        XCTAssertEqual(parsed.category, .shivaratri)
        XCTAssertEqual(parsed.tokens, ["maha", "shivratri"])
        XCTAssertFalse(parsed.isListing)
    }

    func testShortFragmentsAreNotTypeWordsAndChipsWin() {
        XCTAssertNil(SearchQueryParser.parse("ama", catalog: catalog).category)
        XCTAssertNil(SearchQueryParser.parse("e", catalog: catalog).category)
        let chip = SearchQueryParser.parse("amavasya 2026", catalog: catalog, category: .festival, year: 2027)
        XCTAssertEqual(chip.category, .festival)
        XCTAssertEqual(chip.year, 2027)
        XCTAssertEqual(chip.tokens, ["amavasya"])
    }

    func testNumbersThatAreNotYearsStayText() {
        let parsed = SearchQueryParser.parse("108 names", catalog: catalog)
        XCTAssertNil(parsed.year)
        XCTAssertEqual(parsed.tokens, ["108", "names"])
    }
}

final class SearchMatchingTests: XCTestCase {
    private let today = CivilDate(2026, 10, 8)

    private func item(_ id: String, _ title: String, words: String = "", date: CivilDate? = nil,
                      categories: [SearchCategory] = [.festival]) -> SearchItem {
        SearchItem(id: id, target: .tab(.panchang), categories: categories, title: title, titleEnglish: title,
                   names: [title], text: words, date: date, requiresPremium: false)
    }

    func testRankingTiersExactThenPrefixThenTypoThenBodyThenInOrderLetters() {
        let search = UnifiedSearch(items: [
            item("letters", "Kartika Purnima"),
            item("body", "Unrelated", words: "vaikuntha"),
            item("typo", "Vaikunta Darshan"),
            item("prefix", "Vaikuntha Ekadashi"),
            item("exact", "Vaikuntha"),
        ])
        XCTAssertEqual(search.search("vaikuntha", today: today).map(\.id), ["exact", "prefix", "typo", "body"])
        XCTAssertEqual(search.search("krtka", today: today).map(\.id), ["letters"])
    }

    func testInOrderLettersNeedThreeLettersAndTheSameFirstLetter() {
        let search = UnifiedSearch(items: [item("a", "Ekadashi")])
        XCTAssertTrue(search.search("ek", today: today).map(\.id) == ["a"], "a prefix still matches")
        XCTAssertTrue(search.search("kds", today: today).isEmpty)
        XCTAssertEqual(search.search("ekdsh", today: today).map(\.id), ["a"])
    }

    func testEveryWordMustMatchSomething() {
        let search = UnifiedSearch(items: [item("a", "Vaikuntha Ekadashi")])
        XCTAssertTrue(search.search("vaikuntha unrelatedword", today: today).isEmpty)
        XCTAssertTrue(search.search("!!!", today: today).isEmpty)
    }

    func testEqualScoresShowUpcomingFirstThenRecentPast() {
        let search = UnifiedSearch(items: [
            item("past-old", "Holi", date: CivilDate(2025, 3, 14)),
            item("past", "Holi", date: CivilDate(2026, 3, 3)),
            item("later", "Holi", date: CivilDate(2028, 3, 11)),
            item("next", "Holi", date: CivilDate(2027, 3, 22)),
        ])
        XCTAssertEqual(search.search("holi", today: today).map(\.id), ["next", "later", "past", "past-old"])
    }

    func testFiltersAndListing() {
        let search = UnifiedSearch(items: [
            item("a26", "Amavasya", date: CivilDate(2026, 11, 9), categories: [.amavasya]),
            item("a27", "Amavasya", date: CivilDate(2027, 1, 7), categories: [.amavasya]),
            item("f27", "Holi", date: CivilDate(2027, 3, 22)),
            SearchItem(id: "screen", target: .paywall, categories: [.screen], title: "Premium", titleEnglish: "Premium",
                       names: ["Premium"], text: "", date: nil, requiresPremium: false),
        ])
        XCTAssertEqual(search.search("", category: .amavasya, today: today).map(\.id), ["a26", "a27"])
        XCTAssertEqual(search.search("", year: 2027, today: today).map(\.id), ["a27", "f27"])
        XCTAssertTrue(search.search("", today: today).isEmpty, "no text and no filter is the start screen")
        XCTAssertEqual(search.search("premium", today: today).map(\.id), ["screen"])
        XCTAssertTrue(search.search("premium", year: 2026, today: today).isEmpty, "screens have no year")
    }
}

/// The shared golden cases in test/fixtures/search/search_golden.json.
final class SearchGoldenTests: XCTestCase {
    func testGoldenCases() throws {
        let fixture = try Repo.json("test/fixtures/search/search_golden.json") as! [String: Any]
        let today = CivilDate(iso: fixture.string("today")!)!
        let zone = TimeZone(identifier: fixture.string("timezone")!)!
        let city = PanchangCity.newDelhi
        XCTAssertEqual(fixture.string("city"), city.id)
        let years = (fixture.array("years") as! [Int])
        let repository = try CalendarRepository.bundled()
        let engine = PanchangEngine()
        let observances = years.flatMap { engine.observanceCalendar(year: $0, city: city) }
        let entries = (fixture.array("entries") as! [[String: Any]]).map { row -> CalendarEntry in
            let date = CivilDate(iso: row.string("date")!)!
            let start = zone.date(at: date, hour: 9)
            return CalendarEntry(id: row.string("id")!, title: row.string("title")!, notes: row.string("notes"),
                                 start: start, end: start.addingTimeInterval(3600),
                                 source: row.string("source") == "google" ? .google : .custom,
                                 calendarName: row.string("calendar"), updatedAt: start)
        }
        var searches: [String: UnifiedSearch] = [:]
        func search(_ language: String) -> UnifiedSearch {
            if let built = searches[language] { return built }
            let built = UnifiedSearch(items: SearchCorpus.build(
                ekadashis: { repository.ekadashis(timezone: "IST", language: $0) }, observances: observances,
                entries: entries, timeZone: zone, language: language))
            searches[language] = built
            return built
        }
        var english: [String: String] = [:]
        for item in search("en").items { english[item.id] = item.titleEnglish }

        for case let row as [String: Any] in fixture.array("cases")! {
            let query = row.string("query")!
            let language = row.string("language") ?? "en"
            let label = "\(language) '\(query)' \(row.string("category") ?? "") \(row.int("year_filter").map(String.init) ?? "")"
            let results = search(language).search(query, category: row.string("category").flatMap(SearchCategory.init(rawValue:)),
                                                   year: row.int("year_filter"), today: today)
            if let count = row.int("count") { XCTAssertEqual(results.count, count, label) }
            if let top = row.string("top") { XCTAssertEqual(results.first?.id, top, label) }
            if let prefix = row.string("top_prefix") { XCTAssertTrue(results.first?.id.hasPrefix(prefix) == true, label) }
            if let title = row.string("top_title") { XCTAssertEqual(results.first?.title, title, label) }
            if let title = row.string("top_title_en") { XCTAssertEqual(results.first.flatMap { english[$0.id] }, title, label) }
            if let raw = row.string("all_categories"), let category = SearchCategory(rawValue: raw) {
                XCTAssertFalse(results.isEmpty, label)
                XCTAssertTrue(results.allSatisfy { $0.categories.contains(category) }, label)
            }
            if let year = row.int("all_in_year") {
                XCTAssertFalse(results.isEmpty, label)
                XCTAssertTrue(results.allSatisfy { $0.date?.year == year }, label)
            }
        }
    }

    func testOnlyPanchangObservancesNeedPremium() throws {
        let repository = try CalendarRepository.bundled()
        let items = SearchCorpus.build(
            ekadashis: { repository.ekadashis(timezone: "IST", language: $0) },
            observances: PanchangEngine().observanceCalendar(year: 2026, city: .newDelhi),
            entries: [], timeZone: TimeZone(identifier: "Asia/Kolkata")!, language: "en")
        XCTAssertTrue(items.contains { $0.categories.contains(.ekadashi) })
        for item in items {
            if case .observance = item.target { XCTAssertTrue(item.requiresPremium, item.id) }
            else { XCTAssertFalse(item.requiresPremium, item.id) }
        }
    }

    func testTitlesFollowTheAppLanguage() throws {
        let repository = try CalendarRepository.bundled()
        let observances = PanchangEngine().observanceCalendar(year: 2026, city: .newDelhi)
        for (language, expected) in [("en", "Deepavali (Lakshmi Puja)"), ("hi", "दीपावली (लक्ष्मी पूजा)"),
                                     ("ta", "தீபாவளி"), ("te", "దీపావళి")] {
            let items = SearchCorpus.build(ekadashis: { repository.ekadashis(timezone: "IST", language: $0) },
                                           observances: observances, entries: [],
                                           timeZone: TimeZone(identifier: "Asia/Kolkata")!, language: language)
            XCTAssertEqual(items.first { $0.id == "observance:deepavali:2026-11-08" }?.title, expected, language)
            let screen = items.first { $0.id == "screen:notifications" }
            XCTAssertEqual(screen?.title, Localizer.shared.translate("notifications", language: language))
        }
    }
}

private extension TimeZone {
    /// [hour]:00 local time on [date] in this zone.
    func date(at date: CivilDate, hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = self
        return calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day, hour: hour))!
    }
}
