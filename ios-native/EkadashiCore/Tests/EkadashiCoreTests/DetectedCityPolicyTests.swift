import XCTest
@testable import EkadashiCore

/// Home's city at launch (EkadashiSettings.useDetected on Android) and the
/// Calendar's month slide, shared by both apps.
final class DetectedCityPolicyTests: XCTestCase {
    private let sanJose = PanchangCity(id: "geonames-5392171", label: "San Jose (US)", latitude: 37.33939,
                                       longitude: -121.89496, timeZoneId: "America/Los_Angeles")
    private let chennai = PanchangCity(id: "detected", label: "Chennai (IN)", latitude: 13.08, longitude: 80.27,
                                       timeZoneId: "Asia/Kolkata")
    private let london = PanchangCity(id: "geonames-2643743", label: "London (GB)", latitude: 51.50853,
                                      longitude: -0.12574, timeZoneId: "Europe/London")

    func testALaunchDetectsThePlaceEvenAfterACityWasPicked() {
        XCTAssertTrue(DetectedCityPolicy.replaces(manual: true, atLaunch: true))
        XCTAssertFalse(DetectedCityPolicy.replaces(manual: true, atLaunch: false), "back in the app: a pick stays")
        XCTAssertTrue(DetectedCityPolicy.replaces(manual: false, atLaunch: false))
    }

    func testPanchangFollowsHomeOnlyWhenItShowedHomesCity() {
        XCTAssertTrue(DetectedCityPolicy.panchangFollows(panchang: nil, previousHome: sanJose, detected: chennai,
                                                         atLaunch: false), "the first place starts Panchang")
        XCTAssertTrue(DetectedCityPolicy.panchangFollows(panchang: sanJose, previousHome: sanJose, detected: chennai,
                                                         atLaunch: true))
        XCTAssertFalse(DetectedCityPolicy.panchangFollows(panchang: london, previousHome: sanJose, detected: chennai,
                                                          atLaunch: true), "a city set on Panchang stays")
        XCTAssertFalse(DetectedCityPolicy.panchangFollows(panchang: sanJose, previousHome: sanJose, detected: chennai,
                                                          atLaunch: false))
        XCTAssertFalse(DetectedCityPolicy.panchangFollows(panchang: chennai, previousHome: chennai, detected: chennai,
                                                          atLaunch: true), "nothing moved")
    }

    func testMonthsSlideInAQuarterSecond() {
        XCTAssertEqual(CalendarMotion.monthSlideSeconds, 0.25)
    }
}
