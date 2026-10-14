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
        XCTAssertTrue(element("home_tradition_menu").exists)
        XCTAssertTrue(element("home_year_menu").exists)
        XCTAssertTrue(element("home_location").exists)
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

    /// The four Home menus line up: location over tradition (same left and
    /// right edges), language over year (same width), all the same height and
    /// inside the screen, in English and in a longer script (Tamil).
    /// Typing a city in Tamil keeps up with the keyboard and finds it (the
    /// search froze typing and deleting outside English, 14 October 2026).
    func testCitySearchKeepsUpWithTypingInTamil() {
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 30))
        element("language_menu").tap()
        XCTAssertTrue(app.buttons["தமிழ்"].waitForExistence(timeout: 5))
        app.buttons["தமிழ்"].tap()
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 10))
        element("home_location").tap()
        let search = app.textFields["ekadashi_location_search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        let start = Date()
        search.typeText("சென")
        search.typeText(XCUIKeyboardKey.delete.rawValue)
        search.typeText("ன")
        XCTAssertLessThan(Date().timeIntervalSince(start), 10, "typing and deleting are not held up")
        XCTAssertTrue(app.buttons["ekadashi_city_geonames-1264527"].waitForExistence(timeout: 10), "Chennai")
        snap("14b-city-search-ta")
        app.buttons.matching(identifier: "Cancel").firstMatch.exists
            ? app.buttons.matching(identifier: "Cancel").firstMatch.tap() : app.swipeDown()
        element("language_menu").tap()
        XCTAssertTrue(app.buttons["English"].waitForExistence(timeout: 5))
        app.buttons["English"].tap()
    }

    func testHomeMenusLineUpInEveryLanguage() {
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 30))
        func check(_ language: String) {
            let location = element("home_location").frame, tradition = element("home_tradition_menu").frame
            let languageMenu = element("language_menu").frame, year = element("home_year_menu").frame
            let screen = app.windows.firstMatch.frame
            XCTAssertEqual(location.minX, tradition.minX, accuracy: 1, language)
            XCTAssertEqual(location.width, tradition.width, accuracy: 1, language)
            XCTAssertEqual(languageMenu.width, year.width, accuracy: 1, language)
            XCTAssertEqual(languageMenu.maxX, year.maxX, accuracy: 1, language)
            XCTAssertEqual(location.height, languageMenu.height, accuracy: 1, language)
            XCTAssertEqual(tradition.height, year.height, accuracy: 1, language)
            XCTAssertEqual(location.height, tradition.height, accuracy: 1, language)
            XCTAssertLessThan(location.maxX, languageMenu.minX, language)
            for frame in [location, tradition, languageMenu, year] {
                XCTAssertTrue(screen.contains(frame), "\(language): \(frame) inside \(screen)")
            }
        }
        check("en")
        snap("18-home-menus-en")
        element("language_menu").tap()
        XCTAssertTrue(app.buttons["தமிழ்"].waitForExistence(timeout: 5))
        app.buttons["தமிழ்"].tap()
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 10))
        check("ta")
        snap("19-home-menus-ta")
        element("language_menu").tap()
        XCTAssertTrue(app.buttons["English"].waitForExistence(timeout: 5))
        app.buttons["English"].tap()
    }

    /// Home: the tradition and year menus, the city search and the free
    /// share card (no paywall).
    func testHomeMenusCitySearchAndShareCard() {
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 30))

        element("home_tradition_menu").tap()
        XCTAssertTrue(app.buttons["Vaishnava"].waitForExistence(timeout: 5))
        app.buttons["Vaishnava"].tap()
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 30))
        snap("12-home-vaishnava")

        element("home_year_menu").tap()
        XCTAssertTrue(app.buttons["2027"].waitForExistence(timeout: 5))
        app.buttons["2027"].tap()
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 10))
        tab(1)
        XCTAssertTrue(element("calendar_ekadashi_source").waitForExistence(timeout: 5))
        // "Smarta • Chennai (IN)" sits under the date title, within the month
        // header row (no extra row, so short screens keep the day in view).
        let source = element("calendar_ekadashi_source").frame
        let title = element("calendar_year_selector").frame
        let next = element("calendar_next_month").frame
        XCTAssertGreaterThanOrEqual(source.minY, title.maxY - 1)
        XCTAssertLessThanOrEqual(source.maxY, next.maxY + 8)
        snap("13-calendar-2027")
        tab(0)

        XCTAssertFalse(element("home_location_name").label.contains("•"), "no time zone beside the city")
        element("home_location").tap()
        let search = app.textFields["ekadashi_location_search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        // Never empty: popular cities before anything is typed.
        XCTAssertTrue(app.buttons["ekadashi_city_geonames-2643743"].waitForExistence(timeout: 5), "London is offered")
        snap("14a-home-city-shortlist")
        search.tap()
        search.typeText("Mumbai")
        let mumbai = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Mumbai'")).firstMatch
        XCTAssertTrue(mumbai.waitForExistence(timeout: 10))
        snap("14-home-city-search")
        mumbai.tap()
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 30))

        app.buttons["home_share_card"].firstMatch.tap()
        XCTAssertTrue(element("share_card_preview").waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["share_card_share"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["premium_close"].exists, "the share card is free")
        snap("15-share-card")
    }

    /// Panchang uses the same city picker as Home on every sub-tab, and every
    /// city shows its time zone (not only India's IST).
    func testPanchangUsesTheHomeCityPickerWithTimeZones() {
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 30))
        tab(3)
        for page in ["keydays", "daily", "ekadashi"] {
            app.buttons["panchang_tab_\(page)"].tap()
            waitSelected("panchang_tab_\(page)")
            app.buttons["panchang_city_selector"].firstMatch.tap()
            XCTAssertTrue(app.textFields["ekadashi_location_search"].waitForExistence(timeout: 5), page)
            let newYork = app.buttons["ekadashi_city_geonames-5128581"]
            XCTAssertTrue(newYork.waitForExistence(timeout: 5), "\(page): popular cities")
            XCTAssertTrue(newYork.label.contains("EDT") || newYork.label.contains("EST"), newYork.label)
            snap("17-panchang-city-picker-\(page)")
            app.buttons["Cancel"].firstMatch.tap()
        }
    }

    /// Every Panchang sub-tab opens the same full calendar to pick a date.
    func testEveryPanchangSubTabOpensTheFullCalendar() {
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 30))
        tab(3)
        for page in ["keydays", "daily", "ekadashi"] {
            app.buttons["panchang_tab_\(page)"].tap()
            waitSelected("panchang_tab_\(page)")
            let picker = page == "daily" ? "panchang_selected_date" : "panchang_selected_month"
            XCTAssertTrue(app.buttons[picker].firstMatch.waitForExistence(timeout: 10), page)
            app.buttons[picker].firstMatch.tap()
            XCTAssertTrue(app.datePickers.firstMatch.waitForExistence(timeout: 5), "\(page) opens the full calendar")
            snap("16-panchang-calendar-\(page)")
            app.buttons["Done"].firstMatch.tap()
        }
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
            // The section chips are pinned above each swipeable page.
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
        // My calendar comes first (then monthly observances, then festivals).
        let choice = element("event_choice_calendar:custom")
        XCTAssertTrue(choice.waitForExistence(timeout: 10), "All custom events")
        choice.tap()
        XCTAssertTrue(element("event_reminder_lead_2").waitForExistence(timeout: 10))
        snap("12-event-reminder-editor")
        element("event_reminder_save").tap()
        XCTAssertTrue(element("event_reminder_row_calendar:custom").waitForExistence(timeout: 10))
        snap("13-notifications")
    }

    /// A notification shown while the app is open must not crash it (the
    /// notification delegate answered off the main thread, 12 Oct 2026).
    func testTestNotificationKeepsTheAppRunning() {
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 20))
        tab(4)
        // Found by its title (the row has no identifier of its own).
        let send = app.staticTexts["Test Notification"].firstMatch
        // The row sits just below the first screen, under the floating tab
        // bar; scroll a third of the screen at a time until it can be tapped.
        for _ in 0..<12 where !(send.exists && send.isHittable) {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)))
        }
        XCTAssertTrue(send.waitForExistence(timeout: 5), "Test notification")
        XCTAssertTrue(send.isHittable, "Test notification is on screen")
        send.tap()
        // It is delivered after one second; give it time to arrive.
        sleep(4)
        XCTAssertEqual(app.state, .runningForeground, "the app survived the notification")
        XCTAssertTrue(send.exists, "Settings is still on screen and responsive")
        snap("14-test-notification")
    }

    /// "No results found for" ends with the query, as on Android (UI parity
    /// review, 12 October 2026).
    func testNoResultsNamesTheQuery() {
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 20))
        app.buttons["open_global_search"].firstMatch.tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
        app.searchFields.firstMatch.tap()
        app.searchFields.firstMatch.typeText("zzqxnomatch\n")
        let title = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "\"zzqxnomatch\"")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10), "No results found for \"zzqxnomatch\"")
        snap("16-no-results")
    }

    /// For a free user a locked festival in the reminder picker opens the
    /// paywall with its reason and is not selected (UI parity review).
    func testLockedReminderEventOpensThePaywall() {
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 20))
        tab(4)
        let add = app.buttons["notifications_add_event"]
        for _ in 0..<8 where !(add.exists && add.isHittable) { app.swipeUp() }
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let choose = element("event_reminder_choose")
        XCTAssertTrue(choose.waitForExistence(timeout: 10), "editor sheet")
        choose.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10), "event picker")
        search.tap()
        search.typeText("deepa")
        let deepavali = element("event_choice_observance:deepavali")
        XCTAssertTrue(deepavali.waitForExistence(timeout: 10))
        deepavali.tap()
        XCTAssertTrue(element("premium_reason").waitForExistence(timeout: 10), "the paywall says why it opened")
        snap("17-locked-reminder-paywall")
        // Closing the paywall without buying keeps the picker, nothing chosen.
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(deepavali.waitForExistence(timeout: 10), "still in the picker")
        XCTAssertFalse(element("event_reminder_save").isHittable)
    }

    /// With notifications off, the Ekadashi switches are off, "Disabled" and
    /// greyed out, as on Android (UI parity review).
    func testEkadashiRemindersFollowTheMasterSwitch() {
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 20))
        tab(4)
        let master = element("notifications_master")
        // Small steps: a full-screen swipe scrolls past the row and the lazy
        // list drops it.
        for _ in 0..<12 where !(master.exists && master.isHittable) {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)))
        }
        XCTAssertTrue(master.waitForExistence(timeout: 5))
        let reminder = element("notify_toggle_notify_2day")
        XCTAssertTrue(reminder.waitForExistence(timeout: 5))
        if (master.value as? String) == "1" { master.switches.firstMatch.exists ? master.switches.firstMatch.tap() : master.tap() }
        let off = expectation(for: NSPredicate(format: "value == '0' AND isEnabled == false"), evaluatedWith: reminder)
        XCTAssertEqual(XCTWaiter.wait(for: [off], timeout: 10), .completed, "off and greyed out")
        snap("18-reminders-off")
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
