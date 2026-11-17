import XCTest

final class YearAndUpdateUITests: XCTestCase {
    private func launch(at instant: String, newerVersion: String? = nil) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing"]
        app.launchEnvironment["EKADASHI_UI_TEST_NOW"] = instant
        app.launchEnvironment["EKADASHI_UI_TEST_STORE_VERSION"] = newerVersion
        app.launch()
        return app
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testHomeStartsInCurrentYearAndAllYearsIncludesBothCalendars() {
        let app = launch(at: "2026-12-20T12:00:00+05:30")
        let year = app.buttons["home_year_menu"]
        XCTAssertTrue(year.waitForExistence(timeout: 30))
        XCTAssertTrue(year.label.contains("2026"))
        year.tap()
        let all = app.buttons["All years"].firstMatch
        XCTAssertTrue(all.waitForExistence(timeout: 4))
        all.tap()
        XCTAssertTrue(year.label.contains("All years"))
        let indicator = app.staticTexts["home_page_indicator"]
        XCTAssertGreaterThan(Int(indicator.label.split(separator: "/").last?.trimmingCharacters(in: .whitespaces) ?? "") ?? 0, 40)
        capture(app, name: "ios-home-all-years")
    }

    func testJanuaryDefaultAppliesToHomeCalendarSearchAndJourney() {
        let app = launch(at: "2027-01-01T12:00:00+05:30")
        let year = app.buttons["home_year_menu"]
        XCTAssertTrue(year.waitForExistence(timeout: 30))
        XCTAssertTrue(year.label.contains("2027"))
        XCTAssertTrue(app.staticTexts["home_page_indicator"].label.hasPrefix("1 / "))

        app.tabBars.buttons["Calendar"].tap()
        let calendar = app.buttons["calendar_year_selector"]
        XCTAssertTrue(calendar.waitForExistence(timeout: 5))
        XCTAssertTrue(calendar.label.contains("1 Jan 2027"))
        capture(app, name: "ios-calendar-january-default")

        app.tabBars.buttons["Journey"].tap()
        let journey = app.buttons["journey_overview_year"]
        XCTAssertTrue(journey.waitForExistence(timeout: 5))
        XCTAssertTrue(journey.label.contains("2027"))

        app.buttons["open_global_search"].firstMatch.tap()
        let search = app.buttons["search_year_selector"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertTrue(search.label.contains("2027"))
        search.tap()
        app.buttons["All years"].firstMatch.tap()
        XCTAssertTrue(search.label.contains("All years"))
    }

    func testNewerCompatiblePublicVersionPromptsAndCanBeDismissed() {
        let app = launch(at: "2026-11-17T12:00:00+05:30", newerVersion: "99.0")
        let prompt = app.alerts.firstMatch
        XCTAssertTrue(prompt.waitForExistence(timeout: 20))
        XCTAssertTrue(prompt.staticTexts["Update available"].exists)
        XCTAssertTrue(prompt.buttons["Update"].exists)
        capture(app, name: "ios-update-available")
        prompt.buttons["Later"].tap()
        XCTAssertFalse(prompt.exists)
        XCTAssertTrue(app.buttons["home_year_menu"].waitForExistence(timeout: 15))
    }
}
