import Foundation
import XCTest
@testable import EkadashiCore

/// Phase 2 (docs/ROADMAP.md): one app language for every tab, including
/// Panchang, in a fixed order where new languages are only ever appended.
final class AppLanguageTests: XCTestCase {
    func testLanguagesKeepTheirOrderAndNewOnesAreAppended() {
        // Never reorder: add Bengali, Gujarati, ... after Telugu.
        XCTAssertEqual(Array(AppLanguage.all.map(\.code).prefix(4)), ["en", "hi", "ta", "te"])
        XCTAssertEqual(Localizer.languages, AppLanguage.all.map(\.code))
        XCTAssertEqual(Set(Localizer.languages).count, Localizer.languages.count)
    }

    func testEveryLanguageHasANativeNameAndALocale() {
        for language in AppLanguage.all {
            XCTAssertFalse(language.nativeName.isEmpty, language.code)
            XCTAssertEqual(Localizer.displayName(language.code), language.nativeName)
            XCTAssertTrue(Localizer.locale(language.code).identifier.hasPrefix(language.code), language.code)
        }
        XCTAssertEqual(Localizer.displayName("xx"), "English")
    }

    /// Every language in the registry ships every string the iOS app uses,
    /// so adding a language without its strings fails here.
    func testEveryRegisteredLanguageHasEveryEnglishKey() {
        let english = Set(Localizer.shared.keys(language: "en")).union(Localizer.shared.overrideKeys(language: "en"))
        for language in Localizer.languages where language != "en" {
            let known = Set(Localizer.shared.keys(language: language)).union(Localizer.shared.overrideKeys(language: language))
            XCTAssertEqual(english.subtracting(known).sorted(), [], language)
        }
    }
}

final class PanchangTermsTests: XCTestCase {
    func testBundledTermsAreByteIdenticalToTheSharedAsset() throws {
        XCTAssertEqual(try CoreResources.data("panchang/terms.json"), try Repo.data("assets/panchang/terms.json"))
    }

    /// Every word the engine can show has a translation in every language.
    func testEveryEngineTermIsTranslatedInEveryLanguage() {
        typealias E = PanchangEngine
        let vocabulary: [(PanchangTerms.Kind, [String])] = [
            (.tithi, E.tithis + ["Amavasya"]), (.paksha, ["Shukla", "Krishna"]), (.nakshatra, E.nakshatras),
            (.yoga, E.yogas), (.karana, E.karanaChara + E.karanaFixed), (.month, E.lunarMonths), (.vara, E.varaNames),
            (.rashi, E.signs), (.ritu, E.ritus), (.ayana, E.ayanas), (.period, E.periodNames),
            (.choghadiya, E.choghadiyaNames), (.hora, E.horaPlanets), (.anandadi, E.anandadiNames),
            (.specialYoga, E.specialYogaNames),
        ]
        var missing: [String] = []
        for (kind, words) in vocabulary {
            for word in words {
                for language in Localizer.languages where language != "en" {
                    let text = PanchangTerms.shared.translate(word, kind, language: language)
                    if text == word { missing.append("\(language) \(kind.rawValue) \(word)") }
                }
                XCTAssertEqual(PanchangTerms.shared.translate(word, kind, language: "en"), word)
            }
        }
        XCTAssertEqual(missing, [])
    }

    func testCompoundTermsAreTranslatedPartByPart() {
        let terms = PanchangTerms.shared
        XCTAssertEqual(terms.tithi(paksha: "Shukla", name: "Pratipada", language: "hi"), "शुक्ल प्रतिपदा")
        XCTAssertEqual(terms.tithi(paksha: "Krishna", name: "Amavasya", language: "te"), "అమావాస్య", "Amavasya has no paksha label")
        XCTAssertEqual(terms.tithi(paksha: "Shukla", name: "Purnima", language: "ta"), "பௌர்ணமி")
        XCTAssertEqual(terms.tithi(paksha: "Krishna", name: "Ekadashi", language: "en"), "Krishna Ekadashi")
        XCTAssertEqual(terms.month("Adhika Shravana", language: "hi"), "अधिक श्रावण")
        XCTAssertEqual(terms.month("Kartika", language: "te"), "కార్తీకం")
        XCTAssertEqual(terms.choghadiya("Night · Amrit", language: "hi"), "रात · अमृत")
        XCTAssertEqual(terms.choghadiya("Day · Rog", language: "en"), "Day · Rog")
    }

    /// Every observance the engine reports has a name in every language.
    func testEveryEngineObservanceHasALocalizedName() {
        var missing: Set<String> = []
        for dated in PanchangEngine().observanceCalendar(year: 2026, city: .newDelhi) {
            for language in Localizer.languages where language != "en" {
                let name = PanchangTerms.shared.observanceName(dated.observance, language: language)
                if name == dated.observance.name { missing.insert("\(language) \(dated.observance.id) \(dated.observance.name)") }
            }
        }
        XCTAssertEqual(missing.sorted(), [])
    }
}

final class PanchangLocalizationTests: XCTestCase {
    /// Calculated fasts (both traditions) read fully in every language.
    func testCalculatedEkadashiNamesRulesAndReasonsAreTranslated() throws {
        var missing: Set<String> = []
        for tradition in EkadashiTradition.allCases {
            let fasts = try CalculatedEkadashiEngine().calculate(start: CivilDate(2026, 1, 1), count: 365, city: .newDelhi,
                                                                tradition: tradition)
            XCTAssertGreaterThan(fasts.count, 20)
            for fast in fasts {
                for language in Localizer.languages where language != "en" {
                    let terms = PanchangTerms.shared
                    if terms.translate(fast.name, .ekadashiName, language: language) == fast.name { missing.insert("\(language) \(fast.name)") }
                    if terms.ekadashiNote(fast.rule, language: language) == fast.rule { missing.insert("\(language) \(fast.rule)") }
                    if terms.ekadashiNote(fast.paranaReason, language: language) == fast.paranaReason {
                        missing.insert("\(language) \(fast.paranaReason)")
                    }
                }
            }
        }
        XCTAssertEqual(missing.sorted(), [])
        XCTAssertEqual(PanchangTerms.shared.ekadashiNote("Jaya: nakshatra end, Dwadashi end and morning limit evaluated together",
                                                         language: "hi"),
                       "जया: नक्षत्र समाप्ति, द्वादशी समाप्ति और प्रातः सीमा साथ में")
    }

    func testTimesAndDatesFollowTheLanguage() {
        let city = PanchangCity.newDelhi
        let date = CivilDate(2026, 10, 8)
        let evening = city.dateAtHour(date, 18).addingTimeInterval(24 * 60)
        XCTAssertEqual(PanchangFormat.time(evening, city: city, date: date, language: "en"), "6:24 PM")
        XCTAssertEqual(PanchangFormat.time(evening.addingTimeInterval(86400), city: city, date: date, language: "en"),
                       "6:24 PM (next day)")
        XCTAssertEqual(PanchangFormat.time(nil, city: city, date: date, language: "en"), "—")
        let hindi = PanchangFormat.time(evening, city: city, date: date, language: "hi")
        XCTAssertTrue(hindi.contains("6:24"), hindi)
        XCTAssertNotEqual(hindi, "6:24 PM")
        XCTAssertEqual(PanchangFormat.date(date, language: "en"), "Thu, 8 Oct 2026")
        XCTAssertNotEqual(PanchangFormat.date(date, language: "ta"), "Thu, 8 Oct 2026")
        XCTAssertEqual(PanchangFormat.monthTitle(date, language: "en"), "October 2026")
    }
}

final class KeyDaysTests: XCTestCase {
    private func ekadashis() throws -> [EkadashiOccurrence] {
        try CalendarRepository.bundled().ekadashis(timezone: "IST", language: "en")
    }

    func testAMonthListsPublishedEkadashisAndCataloguedObservancesInDateOrder() throws {
        let month = CivilDate(2026, 11, 1)
        let days = PanchangKeyDays.month(month, observances: PanchangEngine().observanceCalendar(year: 2026, city: .newDelhi),
                                         ekadashis: try ekadashis(), language: "en")
        XCTAssertTrue(days.allSatisfy { $0.date.year == 2026 && $0.date.month == 11 })
        XCTAssertEqual(days.map(\.date), days.map(\.date).sorted())
        let ekadashiDays = days.filter { $0.categories.contains(.ekadashi) }
        XCTAssertEqual(ekadashiDays.count, 2)
        XCTAssertTrue(ekadashiDays.allSatisfy { !$0.requiresPremium }, "published Ekadashis are free")
        XCTAssertTrue(days.contains { $0.key == "deepavali" && $0.date == CivilDate(2026, 11, 8) && $0.requiresPremium })
        XCTAssertFalse(days.contains { $0.key == "ekadashi" }, "the engine's Smarta Ekadashi defers to the published data")
        XCTAssertFalse(days.contains { $0.key == nil && !$0.categories.contains(.ekadashi) })
    }

    func testTitlesFollowTheLanguageAndFiltersWork() throws {
        let month = CivilDate(2026, 11, 1)
        let observances = PanchangEngine().observanceCalendar(year: 2026, city: .newDelhi)
        let hindi = PanchangKeyDays.month(month, observances: observances,
                                          ekadashis: try CalendarRepository.bundled().ekadashis(timezone: "IST", language: "hi"),
                                          language: "hi")
        XCTAssertEqual(hindi.first { $0.key == "deepavali" }?.title, "दीपावली (लक्ष्मी पूजा)")
        let festivals = PanchangKeyDays.filter(hindi, category: .festival)
        XCTAssertFalse(festivals.isEmpty)
        XCTAssertTrue(festivals.allSatisfy { $0.categories.contains(.festival) })
        XCTAssertEqual(PanchangKeyDays.filter(hindi, category: nil).count, hindi.count)
    }
}

final class EnglishFallbackTests: XCTestCase {
    /// Words that stay the same in every language (brand names).
    static let sameEverywhere: Set<String> = ["filter_google"]

    /// No string is left in English in another language by mistake; a new
    /// language that copies English strings fails here too.
    func testNoStringIsAccidentallyEnglish() {
        let english = Set(Localizer.shared.keys(language: "en")).union(Localizer.shared.overrideKeys(language: "en"))
        var same: [String] = []
        for language in Localizer.languages where language != "en" {
            for key in english.sorted() where !Self.sameEverywhere.contains(key) {
                let source = Localizer.shared.translate(key, language: "en")
                guard source.contains(where: \.isLetter) else { continue }
                if Localizer.shared.translate(key, language: language) == source { same.append("\(language) \(key)") }
            }
        }
        XCTAssertEqual(same, [])
    }

    /// No English word in another language: brand names are written in the
    /// language's script too. Only placeholders, links and time zone ids a
    /// user types stay in Latin letters.
    func testNoEnglishIsLeftInOtherLanguages() {
        let allowed = #"\{[^{}]+\}|https?://\S+|Asia/Kolkata|America/New_York"#
        var problems: [String] = []
        for language in Localizer.languages where language != "en" {
            let keys = Set(Localizer.shared.keys(language: language)).union(Localizer.shared.overrideKeys(language: language))
            for key in keys {
                let text = Localizer.shared.translate(key, language: language)
                    .replacingOccurrences(of: allowed, with: "", options: .regularExpression)
                if text.range(of: "[A-Za-z]", options: .regularExpression) != nil { problems.append("\(language) \(key)") }
            }
        }
        XCTAssertEqual(problems.sorted(), [])
    }

    func testClockTimesUseTheLanguagesOwnWords() {
        XCTAssertEqual(Localizer.shared.clock(hour: 18, minute: 5, language: "en"), "6:05 PM")
        XCTAssertEqual(Localizer.shared.clock(hour: 6, minute: 30, language: "hi"), "6:30 पूर्वाह्न")
        XCTAssertEqual(Localizer.shared.localizeClock("06:00 AM - 08:21 AM", language: "bn"), "06:00 পূর্বাহ্ণ - 08:21 পূর্বাহ্ণ")
        XCTAssertEqual(Localizer.shared.timeZoneName("IST", language: "gu"), "ભારતીય સમય")
        XCTAssertEqual(Localizer.shared.timeZoneName("IST", language: "en"), "IST")
    }

    func testPlacesAndCountriesAreNamedInEachLanguage() {
        XCTAssertEqual(PlaceNames.shared.place("Chennai", language: "hi"), "चेन्नई")
        XCTAssertEqual(PlaceNames.shared.place("Chennai", language: "en"), "Chennai")
        XCTAssertEqual(PlaceNames.shared.place("Nowhere", language: "ta"), "Nowhere")
        XCTAssertEqual(PlaceNames.shared.label("London (GB)", language: "gu"), "લંડન (યુનાઇટેડ કિંગડમ)")
        XCTAssertEqual(PlaceNames.shared.country("IN", language: "te"), "భారతదేశం")
    }

    /// Every Indian city in the worldwide Panchang list, as the list spells
    /// it, is written in each language's own script.
    func testEveryIndianPanchangCityIsNamedInEachLanguage() throws {
        let rows = try XCTUnwrap(JSONSerialization.jsonObject(with: Repo.data("assets/panchang/cities.json")) as? [[Any]])
        let latin = try NSRegularExpression(pattern: "[A-Za-z]")
        var missing: [String] = []
        for row in rows where row[3] as? String == "IN" {
            let label = "\(row[1]) (IN)"
            for language in ["hi", "ta", "te", "gu", "bn"] {
                let shown = PlaceNames.shared.label(label, language: language)
                if latin.firstMatch(in: shown, range: NSRange(shown.startIndex..., in: shown)) != nil {
                    missing.append("\(language): \(label)")
                }
            }
        }
        XCTAssertEqual(Array(missing.prefix(20)), [], "\(missing.count) missing")
    }
}
