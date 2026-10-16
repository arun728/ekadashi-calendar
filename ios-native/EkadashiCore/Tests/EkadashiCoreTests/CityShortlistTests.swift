import XCTest
@testable import EkadashiCore

/// The Home city search is never empty: recent picks on top, then popular
/// cities around the world.
final class CityShortlistTests: XCTestCase {
    func testEveryPopularCityIsInTheCatalog() {
        let popular = PanchangCityCatalog.shared.popular()
        XCTAssertEqual(popular.count, PanchangCityCatalog.popularIds.count)
        XCTAssertEqual(popular.first?.label, "Chennai (IN)")
        let zones = Set(popular.map(\.timeZoneId))
        for zone in ["Asia/Kolkata", "America/New_York", "America/Los_Angeles", "Europe/London", "Australia/Sydney", "Asia/Dubai"] {
            XCTAssertTrue(zones.contains(zone), zone)
        }
    }

    /// Popular cities are written in each language's own script.
    func testEveryPopularCityHasItsNameInEveryLanguage() {
        for city in PanchangCityCatalog.shared.popular() {
            for language in Localizer.languages where language != "en" {
                let name = PlaceNames.shared.label(city.label, language: language)
                XCTAssertNil(name.range(of: "[A-Za-z]", options: .regularExpression), "\(language): \(name)")
            }
        }
    }

    func testRecentPicksComeFirstNewestFirstWithoutDuplicates() throws {
        let store = InMemoryKeyValueStore()
        let recents = RecentCities(store: store)
        XCTAssertTrue(recents.all().isEmpty)
        XCTAssertFalse(recents.shortlist().popular.isEmpty, "never empty, even before any pick")
        let popular = PanchangCityCatalog.shared.popular()
        let london = popular.first { $0.label.hasPrefix("London") }!
        let sydney = popular.first { $0.label.hasPrefix("Sydney") }!
        recents.add(london)
        recents.add(sydney)
        recents.add(london)
        XCTAssertEqual(recents.all().map(\.label), [london.label, sydney.label])
        let shortlist = recents.shortlist()
        XCTAssertEqual(shortlist.recent.map(\.id), [london.id, sydney.id])
        XCTAssertFalse(shortlist.popular.contains { $0.id == london.id || $0.id == sydney.id })
        for city in popular.prefix(12) { recents.add(city) }
        XCTAssertEqual(recents.all().count, RecentCities.limit)
    }

    /// Back in the app, a newly detected place recalculates the Ekadashis
    /// only when the place moved (coordinates or time zone), not when only
    /// its name changed (lib/main.dart `_placeKey` on Android).
    func testSamePlaceIgnoresTheNameButNotTheCoordinatesOrZone() {
        let chennai = PanchangCity(id: "detected", label: "Chennai (IN)", latitude: 13.08, longitude: 80.27,
                                   timeZoneId: "Asia/Kolkata")
        let renamed = PanchangCity(id: "geonames-1264527", label: "Madras (IN)", latitude: 13.08, longitude: 80.27,
                                   timeZoneId: "Asia/Kolkata")
        XCTAssertTrue(chennai.isSamePlace(as: renamed))
        let moved = PanchangCity(id: "detected", label: "Chennai (IN)", latitude: 13.09, longitude: 80.27,
                                 timeZoneId: "Asia/Kolkata")
        XCTAssertFalse(chennai.isSamePlace(as: moved))
        let otherZone = PanchangCity(id: "detected", label: "Chennai (IN)", latitude: 13.08, longitude: 80.27,
                                     timeZoneId: "Asia/Colombo")
        XCTAssertFalse(chennai.isSamePlace(as: otherZone))
    }
}
