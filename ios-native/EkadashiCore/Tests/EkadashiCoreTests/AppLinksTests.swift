import XCTest
@testable import EkadashiCore

/// Share card links: the live v1 Android app, and the App Store page once
/// the iOS app has a listing (a placeholder until v2; see AGENTS.md).
final class AppLinksTests: XCTestCase {
    func testStoreLinks() {
        XCTAssertEqual(AppLinks.playStore, "https://play.google.com/store/apps/details?id=com.applausestudios.ekadashi_calendar")
        XCTAssertEqual(AppLinks.appStore(id: ""), "https://apps.apple.com/app/ekadashi-calendar")
        XCTAssertEqual(AppLinks.appStore(id: "123"), "https://apps.apple.com/app/id123")
    }

    func testIosShareMessageHasOnlyTheAppStoreLink() {
        let text = Localizer.shared.translate("share_card_message", language: "ta", args: ["மோகினி ஏகாதசி", "திங்கள், 27 ஏப். 2026"])
        XCTAssertFalse(text.contains("{value"))
        let message = AppLinks.shareCardMessage(text, appStoreId: "")
        XCTAssertTrue(message.hasPrefix(text))
        XCTAssertFalse(message.contains("play.google.com"), "iOS shares only its own store link")
        XCTAssertTrue(message.hasSuffix(AppLinks.appStorePlaceholder))
        XCTAssertTrue(AppLinks.shareCardMessage(text, appStoreId: "123").hasSuffix("https://apps.apple.com/app/id123"))
    }
}
