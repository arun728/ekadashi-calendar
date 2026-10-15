import XCTest

/// Requires Xcode/iOS simulator; shared formatting is also exercised in the
/// Linux-runnable PanchangPrecisionTests. This checks the actual SwiftUI panel.
final class PanchangPrecisionUITests: XCTestCase {
    func testCalculatedParanaPanelShowsSeconds() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 30))
        app.tabBars.buttons.element(boundBy: 3).tap()
        let tab = app.buttons["panchang_tab_ekadashi"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        // Monthly calculated windows now carry inward-rounded seconds. The
        // previous panel used minute-only PanchangFormat.time for both ends.
        let preciseWindow = app.descendants(matching: .any).matching(
            NSPredicate(format: "label MATCHES %@", ".*[0-9]{2}:[0-9]{2}:[0-9]{2}.* - .*[0-9]{2}:[0-9]{2}:[0-9]{2}.*")
        ).firstMatch
        XCTAssertTrue(preciseWindow.waitForExistence(timeout: 60),
                      "The actual Ekadashi panel must retain precise Parana boundaries")
    }
}
