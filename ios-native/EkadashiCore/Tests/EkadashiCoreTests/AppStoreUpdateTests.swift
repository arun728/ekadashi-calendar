import Foundation
import XCTest
@testable import EkadashiCore

final class AppStoreUpdateTests: XCTestCase {
    func testStorefrontDeterminesLookupCountry() throws {
        for (storefront, country) in [("IND", "in"), ("GBR", "gb"), ("USA", "us"), ("AUS", "au")] {
            let url = try XCTUnwrap(AppStoreUpdate.lookupURL(appID: "123", storefrontCode: storefront))
            XCTAssertEqual(url.host, "itunes.apple.com")
            XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
                [URLQueryItem(name: "id", value: "123"), URLQueryItem(name: "country", value: country)])
        }
        XCTAssertNil(AppStoreUpdate.lookupURL(appID: "invalid", storefrontCode: "IND"))
        XCTAssertNil(AppStoreUpdate.lookupURL(appID: "123", storefrontCode: "ZZZ"))
    }

    func testOnlyNewerCompatibleVersionsOfTheExpectedAppAreOffered() throws {
        func offered(_ version: String, os: String = "17.0", bundleID: String = "app.bundle", appID: Int = 123) throws -> String? {
            let data = try JSONSerialization.data(withJSONObject: ["results": [
                ["version": version, "minimumOsVersion": os, "bundleId": bundleID, "trackId": appID]
            ]])
            return AppStoreUpdate.availableVersion(in: data, appID: "123", bundleID: "app.bundle",
                installedVersion: "2.9.0", systemVersion: "18.6")
        }
        XCTAssertEqual(try offered("2.10"), "2.10")
        XCTAssertNil(try offered("2.9"))
        XCTAssertNil(try offered("2.8.99"))
        XCTAssertNil(try offered("2.99", os: "26.0"))
        XCTAssertNil(try offered("2.99", bundleID: "other.app"))
        XCTAssertNil(try offered("2.99", appID: 456))
        XCTAssertNil(try offered("not a version"))
        XCTAssertNil(AppStoreUpdate.availableVersion(in: Data(#"{"results":[]}"#.utf8), appID: "123",
            bundleID: "app.bundle", installedVersion: "2.9", systemVersion: "18.6"))
    }
}
