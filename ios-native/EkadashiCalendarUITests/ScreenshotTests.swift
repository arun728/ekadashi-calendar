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
        XCTAssertTrue(app.buttons["panchang_next_month"].waitForExistence(timeout: 10))
        XCTAssertTrue(result("panchang_key_day_ekadashi:").waitForExistence(timeout: 60), "Key days list the month")
        snap("05-panchang-key-days")
        app.buttons["panchang_tab_daily"].tap()
        XCTAssertTrue(app.buttons["panchang_next_day"].waitForExistence(timeout: 10))
        snap("05b-panchang-daily")
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
        XCTAssertTrue(result("search_result_ekadashi:").waitForExistence(timeout: 10))
        snap("09-search")

        // Festivals are calculated in the background, then show locked for free users.
        replaceSearch(with: "Diwali")
        XCTAssertTrue(result("search_result_observance:deepavali:").waitForExistence(timeout: 60))
        snap("10-search-festival")

        replaceSearch(with: "amavasai")
        XCTAssertTrue(result("search_result_observance:amavasya:").waitForExistence(timeout: 10))
        snap("11-search-type-word")
    }

    /// Long screens scroll when dragged from the top half, not only from
    /// their lowest card (the Android Calendar bug, docs/ROADMAP.md Phase 4).
    func testLongScreensScrollFromTheTopHalf() {
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 20))
        let screens: [(Int, XCUIElement)] = [
            // The segmented control is pinned above the scroll view.
            (2, app.descendants(matching: .any)["journey_overview_streaks"].firstMatch),
            (3, app.descendants(matching: .any)["panchang_key_day_filters"].firstMatch),
            (4, app.descendants(matching: .any)["settings_premium"].firstMatch),
        ]
        for (index, anchor) in screens {
            tab(index)
            XCTAssertTrue(anchor.waitForExistence(timeout: 60), "tab \(index)")
            // Key days fills in once the month's festivals are calculated.
            if index == 3 { XCTAssertTrue(result("panchang_key_day_ekadashi:").waitForExistence(timeout: 60), "key days") }
            let before = anchor.frame.minY
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
            start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)))
            XCTAssertLessThan(anchor.frame.minY, before, "tab \(index) scrolls when dragged from the middle")
        }
    }

    /// Notifications has Ekadashi and Festivals and events sub-sections; a
    /// free reminder for the user's own entries is added from a picker
    /// (docs/ROADMAP.md Phase 7).
    func testEventReminderIsAddedFromSettings() {
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 20))
        tab(4)
        let add = app.buttons["notifications_add_event"]
        for _ in 0..<6 where !(add.exists && add.isHittable) { app.swipeUp() }
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["notify_toggle_notify_parana"].exists, "Ekadashi reminders sit above")
        XCTAssertTrue(add.isEnabled, "UI tests run with notifications allowed")
        add.tap()
        app.buttons["event_reminder_choose"].tap()
        let choice = app.buttons["event_choice_calendar:custom"]
        for _ in 0..<12 where !(choice.exists && choice.isHittable) { app.swipeUp() }
        choice.tap()
        XCTAssertTrue(app.buttons["event_reminder_lead_2"].waitForExistence(timeout: 5))
        snap("12-event-reminder-editor")
        app.buttons["event_reminder_save"].tap()
        XCTAssertTrue(app.buttons["event_reminder_row_calendar:custom"].waitForExistence(timeout: 5))
        snap("13-notifications")
    }

    /// Return ends editing, so focus the field again before replacing its text.
    private func replaceSearch(with text: String) {
        let field = app.searchFields.firstMatch
        field.tap()
        let value = field.value as? String ?? ""
        let count = value == field.placeholderValue ? 0 : value.count
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: count) + text)
    }

    private func result(_ prefix: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
    }
}
