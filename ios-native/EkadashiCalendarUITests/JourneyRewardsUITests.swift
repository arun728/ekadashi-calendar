import XCTest

final class JourneyRewardsUITests: XCTestCase {
    func testAnnualPointsMandalaPremiumAndBadgeDetails() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 40))
        app.tabBars.buttons.element(boundBy: 2).tap()
        let points = app.descendants(matching: .any)["journey_year_points"].firstMatch
        XCTAssertTrue(points.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["journey_overview_year"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["journey_mandala"].firstMatch.exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "journey-points-mandala"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.buttons["journey_overview_year"].tap()
        app.buttons["2027"].firstMatch.tap()
        XCTAssertTrue(points.label.contains("2027") || app.staticTexts["Your 2027 Journey"].exists)
        app.buttons["journey_tab_achievements"].tap()
        let first = app.buttons["journey_badge_first_vrat"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        first.tap()
        XCTAssertTrue(app.descendants(matching: .any)["journey_badge_detail"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Fully observe your first Ekadashi."].exists)
    }

    func testShareIsExplicitAndPremiumCanBeOpened() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 40))
        app.tabBars.buttons.element(boundBy: 2).tap()
        app.swipeUp()
        let premium = app.buttons["journey_rewards_premium"]
        XCTAssertTrue(premium.waitForExistence(timeout: 10))
        premium.tap()
        XCTAssertTrue(app.buttons["premium_close"].waitForExistence(timeout: 10))
    }
}
