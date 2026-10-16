import XCTest
@testable import EkadashiCore

/// Every city shows a short time zone like India's "IST": the zone's own
/// abbreviation in English (EDT, GMT, AEST…), "UTC+4" where the zone has no
/// letters, and the UTC offset in the language's script elsewhere.
final class TimeZoneLabelTests: XCTestCase {
    private func city(_ zone: String) -> PanchangCity {
        PanchangCity(id: "t", label: "T", latitude: 0, longitude: 0, timeZoneId: zone)
    }

    func testEnglishAbbreviationsWorldwide() {
        let summer = utc(2026, 7, 1, 12), winter = utc(2026, 1, 15, 12)
        XCTAssertEqual(city("Asia/Kolkata").timeZoneLabel(language: "en", now: summer), "IST")
        XCTAssertEqual(city("America/New_York").timeZoneLabel(language: "en", now: summer), "EDT")
        XCTAssertEqual(city("America/New_York").timeZoneLabel(language: "en", now: winter), "EST")
        XCTAssertEqual(city("America/Los_Angeles").timeZoneLabel(language: "en", now: winter), "PST")
        XCTAssertEqual(city("America/Chicago").timeZoneLabel(language: "en", now: summer), "CDT")
        XCTAssertEqual(city("Europe/London").timeZoneLabel(language: "en", now: summer), "BST")
        XCTAssertEqual(city("Europe/London").timeZoneLabel(language: "en", now: winter), "GMT")
        XCTAssertEqual(city("Europe/Berlin").timeZoneLabel(language: "en", now: winter), "CET")
        XCTAssertEqual(city("Australia/Sydney").timeZoneLabel(language: "en", now: winter), "AEDT")
        XCTAssertEqual(city("Asia/Dubai").timeZoneLabel(language: "en", now: summer), "UTC+4")
        XCTAssertEqual(city("Asia/Kathmandu").timeZoneLabel(language: "en", now: summer), "UTC+5:45")
        XCTAssertEqual(city("Asia/Singapore").timeZoneLabel(language: "en", now: summer), "UTC+8")
    }

    func testOtherLanguagesUseTheirScript() {
        let now = utc(2026, 7, 1, 12)
        for language in Localizer.languages where language != "en" {
            let india = city("Asia/Kolkata").timeZoneLabel(language: language, now: now)
            XCTAssertEqual(india, Localizer.shared.timeZoneName("IST", language: language))
            let york = city("America/New_York").timeZoneLabel(language: language, now: now)
            XCTAssertNil(york.range(of: "[A-Za-z]", options: .regularExpression), "\(language): \(york)")
            XCTAssertFalse(york.isEmpty)
        }
    }
}
