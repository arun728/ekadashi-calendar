import Foundation
import XCTest
@testable import EkadashiCore

/// Every city in the world shows in the app language: names the place-name
/// table lacks are written in the language's script by sound.
final class TransliteratorTests: XCTestCase {
    func testWritesNamesBySound() {
        let expected: [(String, String, String)] = [
            ("Toronto", "hi", "टोरोंटो"), ("Boston", "hi", "बोस्टन"), ("Philadelphia", "hi", "फ़िलडेल्फ़िया"),
            ("Ḩattā", "hi", "हटा"), ("Sharjah", "gu", "શર્જા"), ("Ottawa", "te", "ఓటవా"),
            ("Washington", "ta", "வஷிங்க்டன்"), ("Toronto", "ta", "டோரோண்டோ"), ("York", "bn", "ইয়োর্ক"),
            ("Christchurch", "hi", "क्रिस्चुर्च"), ("Brooklyn", "te", "బ్రూక్లీన్"),
        ]
        for (name, language, text) in expected {
            XCTAssertEqual(Transliterator.transliterate(name, language: language), text, "\(language) \(name)")
        }
        XCTAssertEqual(Transliterator.transliterate("Toronto", language: "en"), "Toronto")
        XCTAssertEqual(Transliterator.transliterate("Saint John’s", language: "ta"),
                       Transliterator.transliterate("Saint Johns", language: "ta"))
    }

    /// The place-name table wins; anything else is written by sound.
    func testPlaceNamesFallBackToTransliteration() {
        XCTAssertEqual(PlaceNames.shared.place("Dubai", language: "hi"), "दुबई")
        XCTAssertTrue(PlaceNames.shared.isKnown("Dubai", language: "hi"))
        XCTAssertFalse(PlaceNames.shared.isKnown("Sacramento", language: "hi"))
        XCTAssertEqual(PlaceNames.shared.place("Sacramento", language: "hi"),
                       Transliterator.transliterate("Sacramento", language: "hi"))
        XCTAssertEqual(PlaceNames.shared.place("Sacramento", language: "en"), "Sacramento")
    }

    /// No catalog city, in any language but English, keeps a Latin letter.
    func testEveryCatalogCityIsInEachLanguagesScript() throws {
        var problems: [String] = []
        for city in try PanchangCityCatalog.shared.cities() {
            for language in Localizer.languages where language != "en" {
                let name = PlaceNames.shared.label(city.label, language: language)
                if name.isEmpty || name.range(of: "[A-Za-z]", options: .regularExpression) != nil {
                    problems.append("\(language): \(city.label) → \(name)")
                }
            }
        }
        XCTAssertEqual(problems.count, 0, problems.prefix(10).joined(separator: "\n"))
    }

    /// The Dart transliterator (Android) gives the same text: a sample of the
    /// catalog in every language, shared with test/unit/transliterator_test.dart.
    func testMatchesTheSharedFixture() throws {
        let url = Repo.url("test/fixtures/transliteration.json")
        let all = try PanchangCityCatalog.shared.cities()
        let names = stride(from: 0, to: all.count, by: 97).map { all[$0].label.replacingOccurrences(
            of: #" \([A-Z]{2}\)$"#, with: "", options: .regularExpression) }
        var expected: [String: [String: String]] = [:]
        for name in names {
            expected[name] = Dictionary(uniqueKeysWithValues: ["hi", "ta", "te", "gu", "bn"].map {
                ($0, Transliterator.transliterate(name, language: $0))
            })
        }
        // Every catalog name too, as one FNV-1a hash per language: the Dart
        // port must write the whole catalog identically.
        var hashes: [String: String] = [:]
        for language in ["hi", "ta", "te", "gu", "bn"] {
            var hash: UInt32 = 2_166_136_261
            for city in all {
                let name = city.label.replacingOccurrences(of: #" \([A-Z]{2}\)$"#, with: "", options: .regularExpression)
                for byte in (Transliterator.transliterate(name, language: language) + "\n").utf8 {
                    hash = (hash ^ UInt32(byte)) &* 16_777_619
                }
            }
            hashes[language] = String(hash, radix: 16)
        }
        expected["_catalog_fnv1a32"] = hashes
        if ProcessInfo.processInfo.environment["UPDATE_TRANSLITERATION_FIXTURE"] == "1" {
            let data = try JSONSerialization.data(withJSONObject: expected, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url)
        }
        let fixture = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: [String: String]]
        XCTAssertEqual(fixture, expected)
    }
}
