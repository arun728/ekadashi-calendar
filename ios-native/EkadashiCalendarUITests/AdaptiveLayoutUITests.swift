import XCTest

/// Wide screens (the iPhone Duo's inner screen) put two panes side by side;
/// phones and the Duo's outer screen keep one column (docs/FOLDABLES.md).
/// CI also runs these on the iPhone Duo simulator when Xcode has one.
final class AdaptiveLayoutUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-ui-testing"]
        app.launch()
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    /// The shared rule switches at 560 points of content; the window can
    /// be a little wider than the content (side safe areas), so widths near
    /// the rule are not asserted either way.
    private enum Expectation { case sideBySide, stacked, either }

    private var expectation: Expectation {
        let width = app.windows.firstMatch.frame.width
        if width >= 640 { return .sideBySide }
        if width <= 500 { return .stacked }
        return .either
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tab(_ index: Int) {
        let button = app.tabBars.buttons.element(boundBy: index)
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
    }

    /// [first] is left of [second] on a wide screen, above it otherwise.
    private func assertPanes(_ first: String, _ second: String, file: StaticString = #filePath, line: UInt = #line) {
        let leading = element(first), trailing = element(second)
        XCTAssertTrue(leading.waitForExistence(timeout: 20), first, file: file, line: line)
        switch expectation {
        case .sideBySide:
            XCTAssertTrue(trailing.waitForExistence(timeout: 5), second, file: file, line: line)
            XCTAssertLessThanOrEqual(leading.frame.maxX, trailing.frame.minX + 1, "\(first) is left of \(second)", file: file, line: line)
            XCTAssertEqual(leading.frame.minY, trailing.frame.minY, accuracy: 60, "\(first) and \(second) start together",
                           file: file, line: line)
        case .stacked:
            // The second pane may be below the fold: it only must not be beside.
            if trailing.exists {
                XCTAssertLessThanOrEqual(leading.frame.maxY, trailing.frame.minY + 1, "\(second) is below \(first)",
                                         file: file, line: line)
            }
        case .either:
            break
        }
    }

    func testCalendarShowsTheMonthBesideTheSelectedDay() {
        tab(1)
        XCTAssertTrue(app.buttons["calendar_next_month"].waitForExistence(timeout: 10))
        assertPanes("calendar_grid_pane", "calendar_day_pane")
        snap("duo-calendar")
    }

    /// Home lists the year's Ekadashis beside the card only on wide screens;
    /// tapping one opens its card.
    func testHomeListsTheYearBesideTheCard() {
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 30))
        switch expectation {
        case .sideBySide:
            assertPanes("home_card_pane", "home_list_pane")
            let indicator = element("home_page_indicator")
            let before = indicator.label
            let rows = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "home_list_row_"))
            XCTAssertGreaterThan(rows.count, 2)
            let other = rows.allElementsBoundByIndex.first { !$0.isSelected && $0.isHittable }
            XCTAssertNotNil(other)
            other?.tap()
            XCTAssertNotEqual(indicator.label, before, "The tapped Ekadashi's card is shown")
        case .stacked:
            XCTAssertFalse(element("home_list_pane").exists, "Phones keep one card at a time")
        case .either:
            break
        }
        snap("duo-home")
    }

    func testJourneyOverviewSplitsMetricsAndRecording() {
        tab(2)
        XCTAssertTrue(element("vrat_tabs_tube").waitForExistence(timeout: 10))
        assertPanes("journey_overview_metrics_pane", "journey_overview_record_pane")
        snap("duo-journey")
    }

    func testPanchangDailySplitsIntoTwoColumns() {
        tab(3)
        let daily = app.buttons["panchang_tab_daily"]
        XCTAssertTrue(daily.waitForExistence(timeout: 10))
        daily.tap()
        XCTAssertTrue(app.buttons["panchang_next_day"].waitForExistence(timeout: 10))
        assertPanes("panchang_daily_leading_pane", "panchang_daily_trailing_pane")
        snap("duo-panchang-daily")
    }

    /// Settings keeps a readable width instead of stretching across the screen.
    func testSettingsKeepsAReadableWidth() {
        tab(4)
        let premium = app.buttons["settings_premium"]
        XCTAssertTrue(premium.waitForExistence(timeout: 10))
        XCTAssertLessThanOrEqual(premium.frame.width, 720 + 1)
        snap("duo-settings")
    }

    /// Unfolding or rotating resizes the app; the selected day and month stay.
    func testResizingKeepsTheSelectedDay() {
        tab(1)
        let next = app.buttons["calendar_next_month"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        let title = app.buttons["calendar_year_selector"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let before = title.label
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, before)
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, before)
    }
}
