import XCTest
@testable import EkadashiCore

final class JourneyPlatformTests: XCTestCase {
    func testCompanyIosIdentityAndSharedContainerStayConsistent() throws {
        let spec = try String(contentsOf: Repo.url("ios-native/project.yml"), encoding: .utf8)
        let config = try String(contentsOf: Repo.url("ios-native/Config/App.xcconfig"), encoding: .utf8)
        XCTAssertTrue(spec.contains("PRODUCT_BUNDLE_IDENTIFIER: com.apptinel.ekadashi-calendar\n"))
        XCTAssertTrue(spec.contains("PRODUCT_BUNDLE_IDENTIFIER: com.apptinel.ekadashi-calendar.widgets\n"))
        XCTAssertTrue(config.contains("APP_GROUP = group.com.apptinel.ekadashi-calendar"))
        XCTAssertTrue(config.contains("DEVELOPMENT_TEAM = 65HTQTRP96"))
        XCTAssertEqual(spec.components(separatedBy: "application-groups: [$(APP_GROUP)]").count - 1, 2)
        for target in ["EkadashiCalendar", "EkadashiWidgets"] {
            let xml = try String(contentsOf: Repo.url("ios-native/\(target)/\(target).entitlements"), encoding: .utf8)
            XCTAssertTrue(xml.contains("<string>$(APP_GROUP)</string>"))
        }
    }

    func testAndroidKeepsTheLiveV1IdentityAndBundledWidgets() throws {
        let gradle = try String(contentsOf: Repo.url("android/app/build.gradle.kts"), encoding: .utf8)
        XCTAssertTrue(gradle.contains("else \"com.applausestudios.ekadashi_calendar\""))
        XCTAssertFalse(gradle.contains("com.apptinel"))
        let manifest = try String(contentsOf: Repo.url("android/app/src/main/AndroidManifest.xml"), encoding: .utf8)
        for provider in ["NextEkadashiWidgetReceiver", "EkadashiTodayWidgetReceiver", "UpcomingEkadashisWidgetReceiver"] {
            XCTAssertTrue(manifest.contains(provider))
        }
    }

    func testJourneyStringsMatchTheApprovedCrossPlatformCopy() throws {
        let table = try Repo.json("test/fixtures/journey_translations.json") as! [String: [String: String]]
        for language in Localizer.languages {
            let strings = try XCTUnwrap(table[language])
            XCTAssertEqual(strings.count, 63)
            for (key, value) in strings {
                XCTAssertEqual(Localizer.shared.translate(key, language: language), value, "\(language) \(key)")
            }
        }
    }
}
