import XCTest
@testable import EkadashiCore

/// Share card, Share app, Rate app and the update prompt: the live v1 Android
/// app, and the iOS app's real App Store page. Apple assigned the id when the
/// app record was created; the page opens once the app is released, so no
/// placeholder link is ever shared (27 Nov 2026, AGENTS.md "Store links").
final class AppLinksTests: XCTestCase {
    private let config = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("Config")

    func testStoreLinks() {
        XCTAssertEqual(AppLinks.playStore, "https://play.google.com/store/apps/details?id=com.applausestudios.ekadashi_calendar")
        XCTAssertEqual(AppLinks.appStoreId, "6825791305")
        XCTAssertEqual(AppLinks.appStore(id: ""), "https://apps.apple.com/app/id6825791305")
        XCTAssertEqual(AppLinks.appStore(id: "123"), "https://apps.apple.com/app/id123")
        XCTAssertEqual(AppLinks.appStoreReview(id: ""), "https://apps.apple.com/app/id6825791305?action=write-review")
    }

    func testAMissingOrEmptyConfiguredIdUsesTheRealId() {
        XCTAssertEqual(AppLinks.appStoreId(configured: nil), "6825791305")
        XCTAssertEqual(AppLinks.appStoreId(configured: ""), "6825791305")
        XCTAssertEqual(AppLinks.appStoreId(configured: " "), "6825791305")
        XCTAssertEqual(AppLinks.appStoreId(configured: "123"), "123")
    }

    func testNoLinkIsAPlaceholder() {
        for link in [AppLinks.appStore(id: ""), AppLinks.appStoreReview(id: ""),
                     AppLinks.shareCardMessage("x", appStoreId: "")] {
            XCTAssertFalse(link.contains("apps.apple.com/app/ekadashi-calendar"), link)
            XCTAssertTrue(link.contains("/id6825791305"), link)
        }
    }

    func testBuildSettingsKeepTheRealId() throws {
        let app = try String(contentsOf: config.appendingPathComponent("App.xcconfig"), encoding: .utf8)
        XCTAssertTrue(app.contains("APP_STORE_ID = \(AppLinks.appStoreId)\n"), "App.xcconfig sets the same id")
        let example = try String(contentsOf: config.appendingPathComponent("Secrets.example.xcconfig"), encoding: .utf8)
        XCTAssertFalse(example.split(separator: "\n").contains { $0.hasPrefix("APP_STORE_ID") },
                       "a Secrets.xcconfig copied from the example must not blank the id")
    }

    func testIosShareMessageHasOnlyTheAppStoreLink() {
        let text = Localizer.shared.translate("share_card_message", language: "ta", args: ["மோகினி ஏகாதசி", "திங்கள், 27 ஏப். 2026"])
        XCTAssertFalse(text.contains("{value"))
        let message = AppLinks.shareCardMessage(text, appStoreId: "")
        XCTAssertTrue(message.hasPrefix(text))
        XCTAssertFalse(message.contains("play.google.com"), "iOS shares only its own store link")
        XCTAssertTrue(message.hasSuffix("https://apps.apple.com/app/id6825791305"))
        XCTAssertTrue(AppLinks.shareCardMessage(text, appStoreId: "123").hasSuffix("https://apps.apple.com/app/id123"))
    }
}
