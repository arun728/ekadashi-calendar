import XCTest
@testable import EkadashiCore

/// The city search (Home and every Panchang sub-tab) must keep up with the
/// keyboard in every language. Names in the app language are prepared once
/// per language off the main thread (CitySearchIndex), not for all 34,152
/// cities at every keystroke: a Tamil keystroke took 2-2.5 s and froze the
/// keyboard (14 October 2026). Mirrors city_search_index_test.dart.
final class CitySearchIndexTests: XCTestCase {
    private let chennai = "geonames-1264527"
    private let mumbai = "geonames-1275339"

    func testTheIndexIsBuiltOncePerLanguage() {
        let tamil = PanchangCityCatalog.shared.searchIndex(language: "ta")
        XCTAssertTrue(tamil === PanchangCityCatalog.shared.searchIndex(language: "ta"))
        XCTAssertEqual(tamil.language, "ta")
    }

    func testEveryKeystrokeIsFastOnceTheIndexIsBuilt() {
        var slowest: UInt64 = 0
        for language in ["en", "hi", "ta", "te", "gu", "bn"] {
            let index = PanchangCityCatalog.shared.searchIndex(language: language)
            for query in ["சென", "ஸான்", "zzq", "मुं", "che"] {
                // Search is synchronous. Measure its work on this thread so
                // Simulator and emulator jobs cannot count as search time.
                let start = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)
                _ = index.search(query, limit: 20)
                let elapsed = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID) - start
                XCTAssertLessThan(elapsed, 100_000_000, "\(language) \(query)")
                slowest = max(slowest, elapsed)
            }
        }
        print("City search maximum thread time: \(Double(slowest) / 1_000_000) ms")
    }

    func testCitiesAreFoundByTheirNameInTheAppLanguage() {
        XCTAssertTrue(PanchangCityCatalog.shared.searchIndex(language: "ta").search("சென").map(\.id).contains(chennai))
        // "मुं" is one grapheme but three UTF-16 units: it is a query (as on
        // Android), not ignored.
        XCTAssertTrue(PanchangCityCatalog.shared.searchIndex(language: "hi").search("मुं").map(\.id).contains(mumbai))
        // English names and codes still match in every language.
        XCTAssertTrue(PanchangCityCatalog.shared.searchIndex(language: "ta").search("chenn").map(\.id).contains(chennai))
        XCTAssertTrue(PanchangCityCatalog.shared.search("reykjavik").contains { $0.label.hasPrefix("Reykjav") })
    }

    func testMatchRankingKeepsTheBestPositionInEachName() {
        for (query, name, expected) in [
            ("che", "chennai", 0),
            ("che", "anche chen", 1),
            ("che", "anche-chen", 1),
            ("che", "anche(chen", 1),
            ("che", "anche", 2),
            ("சென", "புது சென்னை", 1),
            ("मुं", "मुंबई", 0),
            ("aba", "aaba", 2),
            ("che", "ch", 3),
            ("", "chennai", 3),
        ] {
            XCTAssertEqual(CitySearchIndex.tier(of: Array(query.utf8), in: Array(name.utf8)),
                           expected, "\(query) in \(name)")
        }
    }

    func testShortQueriesSearchNothing() {
        XCTAssertNil(CitySearchIndex.query(" c "))
        XCTAssertEqual(CitySearchIndex.query(" Che "), "che")
        XCTAssertEqual(CitySearchIndex.query("मुं"), "मुं")
        XCTAssertTrue(PanchangCityCatalog.shared.searchIndex(language: "en").search("c").isEmpty)
    }
}
