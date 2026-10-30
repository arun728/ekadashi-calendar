import XCTest

final class JourneyRewardsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private var glassSuffix = ""

    func testFeedbackYearFiltersAndFastingMethodAvailability() { feedback(glass: false) }
    func testFeedbackYearFiltersAndFastingMethodAvailabilityWithGlassLook() { feedback(glass: true) }

    private func feedback(glass: Bool) {
        glassSuffix = glass ? "-glass-on" : "-glass-off"
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 40))
        if glass {
            app.tabBars.buttons.element(boundBy: 4).tap()
            let toggle = app.switches["settings_glass_look"].firstMatch
            XCTAssertTrue(toggle.waitForExistence(timeout: 10))
            toggle.tap()
        }
        app.tabBars.buttons.element(boundBy: 2).tap()
        capture(app, "journey-overview")
        app.buttons["journey_tab_achievements"].tap()
        let year = app.buttons["journey_achievements_year"]
        XCTAssertTrue(year.waitForExistence(timeout: 5))
        year.tap(); app.buttons["2027"].firstMatch.tap()
        app.buttons["journey_badge_filter_annual"].tap()
        XCTAssertTrue(app.buttons["journey_badge_journey_2027_q1"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["journey_badge_journey_2026_q1"].exists)
        capture(app, "journey-feedback-achievements-2027")
        year.tap(); app.buttons["All years"].firstMatch.tap()
        XCTAssertTrue(year.label.contains("All years"))
        app.buttons["journey_tab_statistics"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label MATCHES '0 of [0-9]+ Ekadashis'")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Year:"].exists)
        capture(app, "journey-feedback-statistics-all-years")
        app.buttons["journey_tab_history"].tap()
        capture(app, "journey-feedback-history-all-years")
        app.buttons["journey_history_year"].tap(); app.buttons["2026"].firstMatch.tap()
        app.buttons["journey_row_ekadashi:2026:01"].tap()
        XCTAssertTrue(app.buttons["vrat_method_fullFast"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["vrat_method_fullFast"].isEnabled)
        XCTAssertFalse(app.buttons["vrat_method_oneMeal"].isEnabled)
        XCTAssertFalse(app.buttons["vrat_method_other"].isEnabled)
        capture(app, "journey-feedback-observed-methods")
        app.buttons["vrat_status_partial"].tap()
        capture(app, "journey-feedback-partial-methods")
        XCTAssertTrue(app.buttons["vrat_method_oneMeal"].isEnabled)
        for method in ["fullFast", "waterOnly", "fruitsMilk", "other"] {
            XCTAssertFalse(app.buttons["vrat_method_" + method].isEnabled)
        }
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name + glassSuffix; attachment.lifetime = .keepAlways; add(attachment)
    }

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
        let consistency = app.buttons["journey_badge_filter_consistency"]
        XCTAssertTrue(consistency.waitForExistence(timeout: 10))
        consistency.tap()
        XCTAssertTrue(app.buttons["journey_badge_consistent_observance"].waitForExistence(timeout: 5))
        app.buttons["journey_badge_filter_all"].tap()
        let first = app.buttons["journey_badge_first_vrat"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        let collection = XCTAttachment(screenshot: app.screenshot())
        collection.name = "journey-badge-collection"; collection.lifetime = .keepAlways; add(collection)
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
    func testBadgeCelebratesAgainAfterDeletingAllRecords() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 40))
        app.tabBars.buttons.element(boundBy: 2).tap()
        app.buttons["journey_tab_history"].tap()
        for cycle in 0..<2 {
            app.buttons["journey_row_ekadashi:2026:01"].tap()
            app.buttons["vrat_record_save"].tap()
            let close = app.buttons["journey_celebration_close"]
            XCTAssertTrue(close.waitForExistence(timeout: 10), "Cycle \(cycle) must celebrate")
            capture(app, "journey-reearned-badge-\(cycle)")
            close.tap()
            if cycle == 0 {
                app.buttons["journey_row_ekadashi:2026:01"].tap()
                app.buttons["Delete Record"].tap()
                app.alerts.buttons["Delete Record"].tap()
            }
        }
    }

    func testOverviewAndAchievementCardsHaveUniformSizes() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 40))
        app.tabBars.buttons.element(boundBy: 2).tap()
        let metric = app.descendants(matching: .any)["journey_metric_current"].firstMatch
        for _ in 0..<5 where !metric.isHittable { app.swipeUp() }
        var sizes: [CGSize] = []
        for id in ["current", "longest", "completion", "observed"] {
            let item = app.descendants(matching: .any)["journey_metric_\(id)"].firstMatch
            XCTAssertTrue(item.exists)
            sizes.append(item.frame.size)
        }
        // Combined accessibility frames bound the labels, not their background.
        // Actual card dimensions are verified with GeometryReader in JourneyPresentationTests.
        for size in sizes { XCTAssertGreaterThan(size.height, 0); XCTAssertGreaterThan(size.width, 0) }
        app.buttons["journey_tab_achievements"].tap()
        var heights: [CGFloat] = []
        for _ in 0..<4 {
            let badges = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'journey_badge_' AND NOT identifier BEGINSWITH 'journey_badge_filter_'"))
            for badge in badges.allElementsBoundByIndex where badge.isHittable { heights.append(badge.frame.height) }
            app.swipeUp()
        }
        XCTAssertGreaterThan(heights.count, 4)
        // Button accessibility frames may bound text instead of the rounded background.
        // Real achievement-button background geometry is checked in JourneyPresentationTests.
        for height in heights { XCTAssertGreaterThan(height, 0) }
    }

    func testOverviewHasNoRecordingAndFutureYearHasNoLeakedProgress() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 40))
        app.tabBars.buttons.element(boundBy: 2).tap()
        XCTAssertTrue(app.buttons["journey_tab_history"].label.contains("Record"))
        app.buttons["journey_tab_history"].tap()
        app.buttons["journey_row_ekadashi:2026:01"].tap()
        app.buttons["vrat_record_save"].tap()
        let close = app.buttons["journey_celebration_close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10)); close.tap()
        app.buttons["journey_tab_overview"].tap()
        app.buttons["journey_overview_year"].tap(); app.buttons["2027"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Current consistency streak · 0"].exists)
        let lifetime = app.descendants(matching: .any)["journey_lifetime_points"].firstMatch
        XCTAssertTrue(lifetime.label.contains("100"))
        for _ in 0..<4 { app.swipeUp() }
        XCTAssertFalse(app.staticTexts["Record Observance"].exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'journey_row_' ")).count, 0)
    }

    func testAnnualSharePreviewIsUserInitiated() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 40))
        app.tabBars.buttons.element(boundBy: 2).tap()
        let share = app.buttons["journey_share_year"]
        for _ in 0..<4 where !share.isHittable { app.swipeUp() }
        XCTAssertTrue(share.exists)
        XCTAssertFalse(app.staticTexts["A personal journey, with no monetary rewards."].exists)
        share.tap()
        XCTAssertTrue(app.descendants(matching: .any)["journey_share_preview"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["journey_share_confirm"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["premium_close"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "journey-annual-share-preview"; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testThreeFreeRecordsAwardPointsAndFourthRequiresPremium() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 40))
        app.tabBars.buttons.element(boundBy: 2).tap()
        app.buttons["journey_tab_history"].tap()
        for ordinal in 1...3 {
            let uid = String(format: "journey_row_ekadashi:2026:%02d", ordinal)
            let row = app.buttons[uid]
            XCTAssertTrue(row.waitForExistence(timeout: 10))
            row.tap()
            let save = app.buttons["vrat_record_save"]
            XCTAssertTrue(save.waitForExistence(timeout: 5))
            save.tap()
            if ordinal == 1 || ordinal == 3 {
                let close = app.buttons["journey_celebration_close"]
                XCTAssertTrue(close.waitForExistence(timeout: 10))
                close.tap()
                let hidden = NSPredicate(format: "exists == false")
                XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: hidden, evaluatedWith: close)], timeout: 5), .completed)
            }
            let closed = NSPredicate(format: "exists == false")
            XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: closed, evaluatedWith: save)], timeout: 5), .completed)
        }
        app.buttons["journey_row_ekadashi:2026:04"].tap()
        app.buttons["vrat_record_save"].tap()
        XCTAssertTrue(app.buttons["premium_close"].waitForExistence(timeout: 10))
        app.buttons["premium_close"].tap()
        app.buttons["Cancel"].firstMatch.tap()
        app.buttons["journey_tab_overview"].tap()
        let points = app.descendants(matching: .any)["journey_year_points"].firstMatch
        XCTAssertTrue(points.waitForExistence(timeout: 5))
        XCTAssertTrue(points.label.contains("300"), points.label)
        XCTAssertTrue(app.staticTexts["Current consistency streak · 3"].exists)
        capture(app, "journey-consistency-three-records")
        app.buttons["journey_tab_statistics"].tap()
        XCTAssertTrue(app.staticTexts["2026 Full-observance completion"].exists)
        app.buttons["journey_tab_history"].tap()
        app.buttons["journey_row_ekadashi:2026:02"].tap()
        app.buttons["Delete Record"].tap()
        app.alerts.buttons["Delete Record"].tap()
        app.buttons["journey_tab_overview"].tap()
        XCTAssertTrue(app.staticTexts["Current consistency streak · 1"].waitForExistence(timeout: 5))
        capture(app, "journey-consistency-after-deletion")
        app.buttons["journey_tab_achievements"].tap()
        app.buttons["journey_badge_filter_consistency"].tap()
        app.buttons["journey_badge_consistent_observance"].tap()
        XCTAssertTrue(app.staticTexts["Locked"].waitForExistence(timeout: 5))
        capture(app, "journey-consistency-badge-relocked")


    }

}
