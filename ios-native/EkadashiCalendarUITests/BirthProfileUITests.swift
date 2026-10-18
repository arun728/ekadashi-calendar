import XCTest
import StoreKitTest

@MainActor
final class BirthProfileUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    private func open(_ app: XCUIApplication, alreadyLaunched: Bool = false) {
        if !alreadyLaunched {
            app.launchArguments = ["-ui-testing"]
            app.launch()
            XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 40))
        }
        app.tabBars.buttons.element(boundBy: 3).tap()
        let birth = app.buttons["panchang_tab_birth"]
        let chips = app.descendants(matching: .any)["panchang_tabs_tube"].firstMatch
        XCTAssertTrue(chips.waitForExistence(timeout: 10))
        // Drag only within the visible chip strip. The accessibility frame
        // includes offscreen content, so swipeLeft() can start off screen.
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.16))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.16))
        start.press(forDuration: 0.05, thenDragTo: end)
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertTrue(birth.waitForExistence(timeout: 10))
        birth.tap()
        XCTAssertTrue(app.buttons["birth_create"].waitForExistence(timeout: 10))
        snapshot(app, "birth-01-introduction")
        app.buttons["birth_create"].tap()
        XCTAssertTrue(app.buttons["birth_calculate"].waitForExistence(timeout: 10))
        snapshot(app, "birth-02-editor")
    }
    func testFreeProfileCalculationOpensPremiumAndCancelPreservesDraft() throws {
        let session = try SKTestSession(configurationFileNamed: "Products")
        session.clearTransactions()
        let app = XCUIApplication(); open(app)
        app.buttons["birth_calculate"].tap()
        XCTAssertTrue(app.buttons["premium_close"].waitForExistence(timeout: 10))
        snapshot(app, "birth-03-premium")
        app.buttons["premium_close"].tap()
        XCTAssertTrue(app.buttons["birth_calculate"].waitForExistence(timeout: 5))
    }
    func testOfflineBirthplaceSearchDoesNotChangeHome() {
        let app = XCUIApplication(); open(app)
        app.buttons["birth_place"].tap()
        let search = app.textFields["birth_city_search"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap(); search.typeText("New York")
        let city = app.buttons["birth_city_geonames-5128581"]
        XCTAssertTrue(city.waitForExistence(timeout: 15))
        snapshot(app, "birth-09-offline-place-search")
        city.tap()
        XCTAssertTrue(app.buttons["birth_place"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["birth_place"].label.contains("New York City"))
        snapshot(app, "birth-10-selected-birthplace")
        app.buttons["Cancel"].firstMatch.tap()
        app.tabBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["home_location"].label.contains("Chennai"))
    }
    func testManualBirthplaceRejectsInvalidZoneAndSavesValidPlace() {
        let app = XCUIApplication(); open(app)
        app.buttons["birth_place"].tap()
        let zone = app.textFields["birth_manual_timezone"]
        for _ in 0..<5 where !zone.isHittable { app.swipeUp() }
        XCTAssertTrue(zone.waitForExistence(timeout: 10))
        zone.tap()
        zone.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Asia/Kolkata".count) + "Invalid/Zone")
        let save = app.buttons["birth_manual_save"]
        XCTAssertFalse(save.isEnabled)
        zone.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Invalid/Zone".count) + "Asia/Kathmandu")
        XCTAssertTrue(save.isEnabled)
        snapshot(app, "birth-11-manual-birthplace")
        save.tap()
        XCTAssertTrue(app.buttons["birth_calculate"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Asia/Kathmandu")).firstMatch.exists)
    }
    func testPremiumExactUnknownEditAndDeleteWithRealStoreKitEntitlement() async throws {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        if os.majorVersion == 26 && os.minorVersion == 5 {
            throw XCTSkip("Apple FB22237318 / FB23721564: StoreKitTest configuration mutations fail on the iOS 26.5 CLI runtime. Run this test on iOS 18.6 or a fixed runtime.")
        }
        let session = try SKTestSession(configurationFileNamed: "Products")
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]; app.launch()
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 40))
        app.tabBars.buttons.element(boundBy: 4).tap()
        app.buttons["settings_premium"].tap()
        let lifetime = app.buttons["premium_plan_lifetime"]
        XCTAssertTrue(lifetime.waitForExistence(timeout: 10))
        lifetime.tap()
        let buy = app.buttons["premium_buy"]
        for _ in 0..<4 where !buy.isHittable { app.swipeUp() }
        XCTAssertTrue(buy.waitForExistence(timeout: 10)); buy.tap()
        guard app.descendants(matching: .any)["premium_lifetime_thanks"].firstMatch.waitForExistence(timeout: 30) else {
            snapshot(app, "birth-purchase-verification-failure")
            XCTFail("The app must verify the test purchase before exercising paid calculations")
            return
        }
        app.buttons["premium_close"].tap()
        open(app, alreadyLaunched: true)
        app.buttons["birth_calculate"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["birth_results"].firstMatch.waitForExistence(timeout: 15))
        snapshot(app, "birth-04-exact-results")
        let edit = app.buttons["birth_edit"]
        for _ in 0..<4 where !edit.isHittable { app.swipeUp() }
        edit.tap()
        let known = app.switches["birth_known_time"]
        XCTAssertTrue(known.waitForExistence(timeout: 10))
        known.tap()
        snapshot(app, "birth-05-unknown-editor")
        app.buttons["birth_calculate"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["birth_unknown_summary"].firstMatch.waitForExistence(timeout: 15))
        app.swipeDown(velocity: .fast)
        app.swipeDown(velocity: .fast)
        snapshot(app, "birth-06-unknown-results")
        let timeline = app.staticTexts["Possible results during this date"]
        for _ in 0..<6 where !timeline.isHittable { app.swipeUp() }
        snapshot(app, "birth-07-transition-timeline")
        let delete = app.buttons["birth_delete"]
        for _ in 0..<5 where !delete.isHittable { app.swipeUp() }
        delete.tap()
        snapshot(app, "birth-08-delete-confirmation")
        app.alerts.buttons["birth_delete_confirm"].tap()
        XCTAssertTrue(app.buttons["birth_create"].waitForExistence(timeout: 10))
    }
}
