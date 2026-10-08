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
