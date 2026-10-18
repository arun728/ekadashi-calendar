import XCTest
import StoreKitTest

final class BirthProfileUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    private func open(_ app: XCUIApplication) {
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["view_details"].firstMatch.waitForExistence(timeout: 40))
        app.tabBars.buttons.element(boundBy: 3).tap()
        let birth = app.buttons["panchang_tab_birth"]
        let chips = app.scrollViews["panchang_tabs_tube"]
        if !birth.isHittable { chips.exists ? chips.swipeLeft() : app.swipeLeft() }
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
    func testPremiumExactUnknownEditAndDeleteWithRealStoreKitEntitlement() async throws {
        let session = try SKTestSession(configurationFileNamed: "Products")
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        try await session.buyProduct(identifier: "ekadashi_premium_lifetime", options: [])
        let app = XCUIApplication(); open(app)
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
        snapshot(app, "birth-06-unknown-results")
        app.swipeUp()
        snapshot(app, "birth-07-transition-timeline")
        let delete = app.buttons["birth_delete"]
        for _ in 0..<5 where !delete.isHittable { app.swipeUp() }
        delete.tap()
        snapshot(app, "birth-08-delete-confirmation")
        app.alerts.buttons["birth_delete_confirm"].tap()
        XCTAssertTrue(app.buttons["birth_create"].waitForExistence(timeout: 10))
    }
}
