import XCTest

/// Walks the five tabs, search and the paywall, attaching a screenshot of
/// each (kept with the test results) and checking the main controls exist.
/// Run with the scheme's StoreKit configuration so the paywall shows prices.
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // A clean in-memory store, already launched, in English: no
        // permission prompts and no state left by the unit tests.
        app.launchArguments += ["-ui-testing"]
        app.launch()
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Selects a tab and waits until it is selected; a tap that lands while a
    /// navigation transition is still running can be dropped, so retry once.
    private func tab(_ index: Int) {
        let button = app.tabBars.buttons.element(boundBy: index)
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        let selected = NSPredicate(format: "isSelected == true")
        for _ in 0..<2 {
            button.tap()
            if XCTWaiter.wait(for: [expectation(for: selected, evaluatedWith: button)], timeout: 5) == .completed { return }
        }
        XCTFail("Tab \(index) did not become selected")
    }

    func testTabsSearchAndPaywall() {
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 20))
        XCTAssertTrue(app.descendants(matching: .any)["home_options_tube"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["language_menu"].exists)
        snap("01-today")

        app.buttons["view_details"].firstMatch.tap()
        snap("02-details")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        // Back on Today before switching tabs.
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 10))

        tab(1)
        XCTAssertTrue(app.buttons["calendar_next_month"].waitForExistence(timeout: 5))
        snap("03-calendar")

        tab(2)
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: 5))
        snap("04-vrat")

        tab(3)
        XCTAssertTrue(app.buttons["panchang_next_day"].waitForExistence(timeout: 10))
        snap("05-panchang")
        app.buttons["panchang_tab_ekadashi"].tap()
        snap("06-panchang-ekadashi")

        tab(4)
        snap("07-settings")
        app.buttons["settings_premium"].tap()
        XCTAssertTrue(app.buttons["premium_close"].waitForExistence(timeout: 10))
        snap("08-paywall")
        app.buttons["premium_close"].tap()

        app.buttons["open_global_search"].firstMatch.tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
        app.searchFields.firstMatch.tap()
        app.searchFields.firstMatch.typeText("Mohini\n")
        snap("09-search")
    }
}
