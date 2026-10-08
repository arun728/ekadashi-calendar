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
        // iOS 26 minimizes the tab bar after scrolling down; bring it back.
        for _ in 0..<3 where !button.waitForExistence(timeout: 2) {
            app.swipeDown(velocity: .fast)
            if !button.exists, app.tabBars.buttons.firstMatch.exists { app.tabBars.buttons.firstMatch.tap() }
        }
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
        // Journey's sections are glass chips, as in Panchang.
        XCTAssertTrue(element("vrat_tabs_tube").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["journey_tab_overview"].isSelected)
        snap("04-vrat")

        tab(3)
        XCTAssertTrue(app.buttons["panchang_next_month"].waitForExistence(timeout: 10))
        XCTAssertTrue(result("panchang_key_day_ekadashi:").waitForExistence(timeout: 60), "Key days list the month")
        snap("05-panchang-key-days")
        app.buttons["panchang_tab_daily"].tap()
        XCTAssertTrue(app.buttons["panchang_next_day"].waitForExistence(timeout: 10))
        waitSelected("panchang_tab_daily")
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

    /// Sub-sections change with a horizontal swipe as well as their chips,
    /// and the chip bar follows (Panchang, Journey and Search).
    func testSwipingChangesSubSections() {
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 20))
        tab(3)
        waitSelected("panchang_tab_keydays")
        swipe(.left)
        waitSelected("panchang_tab_daily")
        XCTAssertTrue(app.buttons["panchang_next_day"].waitForExistence(timeout: 10), "the day stepper")
        swipe(.left)
        waitSelected("panchang_tab_muhurta")
        swipe(.right)
        swipe(.right)
        waitSelected("panchang_tab_keydays")
        XCTAssertTrue(app.buttons["panchang_next_month"].waitForExistence(timeout: 10), "the month stepper")

        tab(2)
        waitSelected("journey_tab_overview")
        swipe(.left)
        waitSelected("journey_tab_history")
        XCTAssertTrue(element("vrat_history_filters_tube").waitForExistence(timeout: 10))
        swipe(.left)
        waitSelected("journey_tab_statistics")
        app.buttons["journey_tab_achievements"].tap()
        waitSelected("journey_tab_achievements")
        snap("14-journey-achievements")
        swipe(.right)
        waitSelected("journey_tab_statistics")

        app.buttons["open_global_search"].firstMatch.tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
        app.searchFields.firstMatch.tap()
        app.searchFields.firstMatch.typeText("ekadashi\n")
        waitSelected("search_filter_all")
        XCTAssertNotNil(visible("search_result_ekadashi:"))
        swipe(.left)
        waitSelected("search_filter_\(firstFilter)")
        swipe(.right)
        waitSelected("search_filter_all")
    }

    /// A result that opens a tab leaves the search; that screen's top bar
    /// goes back to the same results.
    func testScreenResultsGoBackToTheSearch() {
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 20))
        app.buttons["open_global_search"].firstMatch.tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
        app.searchFields.firstMatch.tap()
        app.searchFields.firstMatch.typeText("settings\n")
        let settings = visible("search_result_screen:settings")
        XCTAssertNotNil(settings)
        settings?.tap()
        XCTAssertTrue(app.buttons["settings_premium"].waitForExistence(timeout: 10), "the Settings tab")
        let back = app.buttons["search_return"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        snap("15-search-return")
        back.tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.searchFields.firstMatch.value as? String, "settings", "the query is kept")
        XCTAssertNotNil(visible("search_result_screen:settings"), "and its results")
        // Leaving search from its own close button forgets the return.
        app.buttons["global_search_back"].tap()
        XCTAssertFalse(app.buttons["search_return"].waitForExistence(timeout: 2))
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
            // Scrolling down minimizes the tab bar; scroll back to bring it back.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)))
        }
    }

    /// Notifications has Ekadashi and Festivals and events sub-sections; a
    /// free reminder for the user's own entries is added from a picker
    /// (docs/ROADMAP.md Phase 7).
    func testEventReminderIsAddedFromSettings() {
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 20))
        tab(4)
        // The Ekadashi switches come first, then Festivals and events.
        let parana = app.descendants(matching: .any)["notify_toggle_notify_parana"].firstMatch
        for _ in 0..<6 where !(parana.exists && parana.isHittable) { app.swipeUp() }
        XCTAssertTrue(parana.exists, "Ekadashi reminders")
        let add = app.buttons["notifications_add_event"]
        for _ in 0..<6 where !(add.exists && add.isHittable) { app.swipeUp() }
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        XCTAssertTrue(add.isEnabled, "UI tests run with notifications allowed")
        add.tap()
        // Form rows and links are not always exposed as buttons; find them by id.
        let choose = element("event_reminder_choose")
        XCTAssertTrue(choose.waitForExistence(timeout: 10), "editor sheet")
        choose.tap()
        // My calendar is last in a long list whose off-screen rows are not in
        // the accessibility tree; search narrows it to the entry.
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10), "event picker")
        search.tap()
        search.typeText("my entries")
        let choice = element("event_choice_calendar:custom")
        XCTAssertTrue(choice.waitForExistence(timeout: 10), "All my entries")
        choice.tap()
        XCTAssertTrue(element("event_reminder_lead_2").waitForExistence(timeout: 10))
        snap("12-event-reminder-editor")
        element("event_reminder_save").tap()
        XCTAssertTrue(element("event_reminder_row_calendar:custom").waitForExistence(timeout: 10))
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

    /// The first search type after All (SearchCategory.filters).
    private let firstFilter = "ekadashi"

    /// Swipes across the middle of the screen, below the chip bars.
    private func swipe(_ direction: Direction) {
        let y = 0.6
        let (from, to) = direction == .left ? (0.85, 0.15) : (0.15, 0.85)
        app.coordinate(withNormalizedOffset: CGVector(dx: from, dy: y))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: to, dy: y)))
    }

    private enum Direction { case left, right }

    private func waitSelected(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let chip = app.buttons[identifier]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), identifier, file: file, line: line)
        let selected = expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: chip)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 10), .completed, "\(identifier) selected", file: file, line: line)
    }

    /// The first on-screen element whose identifier starts with the prefix;
    /// the pages beside the visible one may also be in the accessibility tree.
    private func visible(_ prefix: String, timeout: TimeInterval = 10) -> XCUIElement? {
        let query = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
        let end = Date().addingTimeInterval(timeout)
        repeat {
            if let match = query.allElementsBoundByIndex.first(where: { $0.exists && $0.isHittable }) { return match }
            _ = query.firstMatch.waitForExistence(timeout: 0.5)
        } while Date() < end
        return nil
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func result(_ prefix: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
    }
}
