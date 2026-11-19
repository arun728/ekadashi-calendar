import XCTest
import StoreKitTest

/// Temporary capture script for App Store screenshots. Not part of the suite.
final class StoreShotsUITests: XCTestCase {
    private var app: XCUIApplication!
    private var outDir: URL {
        URL(fileURLWithPath: ProcessInfo.processInfo.environment["SHOTS_DIR"] ?? NSTemporaryDirectory())
    }

    override func setUp() { continueAfterFailure = true }

    // MARK: helpers
    private func shot(_ name: String, settle: Double = 1.2) {
        Thread.sleep(forTimeInterval: settle)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        try? png.write(to: outDir.appendingPathComponent(name + ".png"))
        print("SHOT \(name)")
    }
    private func el(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
    private func button(_ label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@ OR identifier == %@", label, label)).firstMatch
    }
    @discardableResult private func tap(_ e: XCUIElement, _ what: String, timeout: Double = 8) -> Bool {
        guard e.waitForExistence(timeout: timeout) else { print("MISSING \(what)"); return false }
        if e.isHittable { e.tap() } else { e.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        return true
    }
    @discardableResult private func tap(_ id: String, timeout: Double = 8) -> Bool { tap(el(id), id, timeout: timeout) }
    private func tab(_ i: Int) {
        let b = app.tabBars.buttons.element(boundBy: i)
        for _ in 0..<3 where !(b.waitForExistence(timeout: 2) && b.isHittable) { app.swipeDown(velocity: .fast) }
        if b.isHittable { b.tap() } else { b.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        Thread.sleep(forTimeInterval: 1)
    }
    private func close() {
        for id in ["premium_close", "journey_celebration_close"] where el(id).exists { el(id).tap(); Thread.sleep(forTimeInterval: 1); return }
        for l in ["Cancel", "Done", "Close"] where button(l).exists { button(l).tap(); Thread.sleep(forTimeInterval: 1); return }
        app.swipeDown(velocity: .fast); Thread.sleep(forTimeInterval: 1)
    }
    private func dismissMenu() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap()
        Thread.sleep(forTimeInterval: 0.8)
    }
    private func launch(now: String, premium: String? = nil) {
        app = XCUIApplication()
        if let premium { app.launchEnvironment["SHOTS_PREMIUM"] = premium }
        app.launchArguments = ["-ui-testing"]
        app.launchEnvironment["EKADASHI_UI_TEST_NOW"] = now
        app.launchEnvironment["SHOTS_SEED"] = "1"
        app.launch()
        _ = app.buttons["view_details"].firstMatch.waitForExistence(timeout: 40)
        Thread.sleep(forTimeInterval: 2)
    }
    private func session() throws -> SKTestSession {
        let cfg = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("EkadashiCalendar/Resources/Products.storekit")
        let s = try SKTestSession(contentsOf: cfg)
        s.resetToDefaultState(); s.disableDialogs = true; try s.clearTransactions()
        return s
    }
    private func ids(_ tag: String) {
        let d = app.debugDescription
        let r = try! NSRegularExpression(pattern: "identifier: '([^']+)'")
        let found = r.matches(in: d, range: NSRange(d.startIndex..., in: d)).compactMap { Range($0.range(at: 1), in: d).map { String(d[$0]) } }
        print("IDS \(tag): \(Set(found).sorted().joined(separator: " "))")
    }
    private func panchangPage(_ page: String) {
        let chip = el("panchang_tab_\(page)")
        for _ in 0..<4 where chip.exists && !chip.isHittable {
            let y = chip.frame.midY
            let dir: CGFloat = chip.frame.minX > app.frame.width / 2 ? -1 : 1
            let from = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.width * 0.5, dy: y))
            from.press(forDuration: 0.05, thenDragTo: from.withOffset(CGVector(dx: dir * 160, dy: 0)))
        }
        tap(chip, "panchang_tab_\(page)")
        Thread.sleep(forTimeInterval: 1.5)
    }
    /// A realistic year: mostly observed, a few partial and missed, mixed methods.
    private let plan: [Int: (String, String?)] = [
        1: ("observed", "fullFast"), 2: ("partial", "oneMeal"), 3: ("observed", "fruitsMilk"), 4: ("observed", "fullFast"),
        5: ("observed", "waterOnly"), 6: ("missed", nil), 7: ("observed", "fruitsMilk"), 8: ("observed", "fullFast"),
        9: ("partial", "oneMeal"), 10: ("observed", "fullFast"), 11: ("observed", "fruitsMilk"), 12: ("observed", "waterOnly"),
        14: ("observed", "fullFast"), 15: ("missed", nil), 16: ("observed", "fruitsMilk"), 17: ("partial", "oneMeal"),
        18: ("observed", "fullFast"), 19: ("observed", "fullFast"), 20: ("observed", "fruitsMilk"), 21: ("observed", "fullFast"),
    ]
    private func record(_ n: Int) {
        let row = el(String(format: "journey_row_ekadashi:2026:%02d", n))
        for _ in 0..<6 where row.exists && !row.isHittable { app.swipeUp(velocity: .slow) }
        guard tap(row, "row \(n)") else { return }
        let (status, method) = plan[n] ?? ("observed", "fullFast")
        if status != "observed" { tap("vrat_status_\(status)", timeout: 4); Thread.sleep(forTimeInterval: 0.4) }
        if let method { tap("vrat_method_\(method)", timeout: 3); Thread.sleep(forTimeInterval: 0.3) }
        if tap("vrat_record_save", timeout: 5) {
            Thread.sleep(forTimeInterval: 1.2)
            if el("journey_celebration_close").exists {
                shot(String(format: "prem-celebration-%02d", n), settle: 0.8)
                el("journey_celebration_close").tap(); Thread.sleep(forTimeInterval: 1)
            }
        }
    }

    private func pickCity(_ name: String) {
        tap("home_location"); Thread.sleep(forTimeInterval: 1.5)
        let field = el("ekadashi_location_search")
        guard tap(field, "city field", timeout: 6) else { return }
        field.typeText(name); Thread.sleep(forTimeInterval: 2)
        if button("Continue").exists { button("Continue").tap() }
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        if !tap(row, "city row \(name)", timeout: 5) { close() }
        Thread.sleep(forTimeInterval: 3)
    }

    // MARK: free, 1 Jan 2027
    func test1Free() throws {
        launch(now: "2027-01-01T09:41:00+05:30")
        pickCity("New Delhi")
        shot("free-01-home")
        tap("language_menu"); shot("free-02-language-menu"); dismissMenu()
        Thread.sleep(forTimeInterval: 3)
        tap("home_tradition_menu"); shot("free-03-tradition-menu"); dismissMenu()
        tap("home_location"); Thread.sleep(forTimeInterval: 1.5)
        let field = el("ekadashi_location_search")
        if tap(field, "city field", timeout: 6) { field.typeText("London") }
        Thread.sleep(forTimeInterval: 1.5)
        if button("Continue").exists { button("Continue").tap() }
        app.swipeDown(velocity: .slow)
        shot("free-04-city-search", settle: 1.5)
        close()
        tap("view_details"); shot("free-05-details")
        tap("details_share_card"); shot("free-06-share-card", settle: 2.5); close()
        app.swipeUp(velocity: .slow); shot("free-05b-details-scrolled")
        app.swipeDown(velocity: .fast); app.swipeDown(velocity: .fast)
        if app.navigationBars.buttons.firstMatch.exists { app.navigationBars.buttons.firstMatch.tap() }
        Thread.sleep(forTimeInterval: 1)
        tab(1); shot("free-07-calendar")
        tap(button("Fri, 15 Jan 2027"), "jan 15"); shot("free-07b-calendar-sankranti")
        tap(button("Google"), "google chip"); shot("free-07c-calendar-filter-google")
        tap(button("Custom"), "custom chip"); shot("free-07d-calendar-filter-custom")
        tap(button("All"), "all chip")
        tap(button("Sun, 3 Jan 2027"), "jan 3"); shot("free-07e-calendar-ekadashi-day")
        tap("calendar_next_month"); tap("calendar_next_month")
        tap(button("Mon, 22 Mar 2027"), "holi"); shot("free-07f-calendar-holi")
        for _ in 0..<5 { tap("calendar_next_month"); Thread.sleep(forTimeInterval: 0.4) }
        tap(button("Wed, 25 Aug 2027"), "janmashtami"); shot("free-07g-calendar-aug")
        for _ in 0..<2 { tap("calendar_next_month"); Thread.sleep(forTimeInterval: 0.4) }
        tap(button("Fri, 29 Oct 2027"), "diwali"); shot("free-07h-calendar-diwali")
        tap("calendar_today", timeout: 3)
        tap("calendar_google_menu"); shot("free-08-google-menu")
        dismissMenu()
        tab(3); shot("free-10-panchang-preview")
        if tap(button("Unlock"), "unlock", timeout: 4) { shot("free-11-panchang-paywall", settle: 2); close() }
        tab(0); tap("open_global_search")
        searchWarmup("free-12a-search")
        typeSearch("Nirjala"); shot("free-12-search", settle: 1)
        app.searchFields.firstMatch.buttons.firstMatch.tap(); typeSearch("Diwali"); shot("free-12b-search-diwali", settle: 1)
        tap("global_search_back", timeout: 3)
        tab(4); shot("free-13-settings")
        tap("settings_premium"); shot("free-14-plans", settle: 3)
        tap("premium_plan_lifetime", timeout: 4); shot("free-15-plans-lifetime", settle: 1.5)
        close()
        tap("settings_widget_preview"); shot("free-16-widget-medium")
        tap(button("Small"), "small"); shot("free-17-widget-small")
        tap(button("Lock Screen"), "lock"); shot("free-18-widget-lock")
        tap(button("Upcoming Ekadashis"), "upcoming"); shot("free-19-widget-upcoming-lock")
        tap(button("Medium"), "medium"); shot("free-20-widget-upcoming-medium")
    }

    // MARK: free Journey, 19 Nov 2026 (2026 Ekadashis whose Parana has passed)
    func test2FreeJourney() throws {
        launch(now: "2026-11-19T09:41:00+05:30")
        pickCity("New Delhi")
        tab(2); tap("journey_tab_history")
        if tap("journey_history_year", timeout: 4) { tap(button("2026"), "2026") }
        for n in 1...3 { record(n) }
        tap("journey_tab_overview"); shot("free-21-journey-three")
        tap("journey_tab_history")
        if tap(el("journey_row_ekadashi:2026:04"), "row 4") { tap("vrat_record_save", timeout: 5); shot("free-22-vrat-paywall", settle: 2) }
    }

    // MARK: Yearly subscriber
    func test3Yearly() throws {
        launch(now: "2026-11-19T09:41:00+05:30", premium: "yearly")
        pickCity("New Delhi")
        tab(2); tap("journey_tab_history")
        if tap("journey_history_year", timeout: 4) { tap(button("2026"), "2026") }
        for n in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 15, 16, 17, 18, 19, 20, 21] { record(n) }
        app.swipeDown(velocity: .fast); app.swipeDown(velocity: .fast)
        shot("prem-01-journey-history"); ids("history")
        tap("journey_tab_overview"); shot("prem-02-journey-overview")
        app.swipeUp(velocity: .slow); shot("prem-02b-journey-overview-scrolled")
        app.swipeDown(velocity: .fast)
        tap("journey_tab_statistics"); shot("prem-03-journey-statistics")
        tap("journey_tab_achievements"); shot("prem-04-journey-achievements"); ids("achievements")
        for f in ["consistency", "annual", "milestone"] where el("journey_badge_filter_\(f)").exists {
            el("journey_badge_filter_\(f)").tap(); shot("prem-04-journey-badges-\(f)")
        }
        tap("journey_badge_filter_all", timeout: 3)
        tap("journey_tab_overview"); ids("overview")
        if tap("journey_share_year", timeout: 4) { shot("prem-05-journey-share", settle: 2.5); ids("share"); close() }
        // July 2027 for Panchang, Calendar and Settings.
        app.terminate()
        launch(now: "2027-07-20T09:41:00+05:30", premium: "yearly")
        pickCity("New Delhi")
        tab(3); shot("prem-10-panchang-keydays"); ids("keydays")
        for f in ["Festivals", "Ekadashi", "Amavasya"] where button(f).exists { button(f).tap(); shot("prem-10-panchang-filter-\(f.lowercased())") }
        if button("All").exists { button("All").tap() }
        for (i, p) in ["daily", "muhurta", "ekadashi", "rashi"].enumerated() {
            panchangPage(p); shot("prem-1\(i + 1)-panchang-\(p)")
        }
        panchangPage("daily"); app.swipeUp(velocity: .slow); shot("prem-11b-panchang-daily-scrolled")
        tab(1); shot("prem-20-calendar-july")
        tap(button("Sun, 18 Jul 2027"), "jul 18"); shot("prem-21-calendar-guru-purnima")
        tap("calendar_google_menu"); shot("prem-22-google-menu"); dismissMenu()
        tab(4); shot("prem-30-settings")
        if tap("settings_premium", timeout: 4) { shot("prem-31-plans-yearly-owned", settle: 2); close() }
    }

    // MARK: Monthly subscriber
    func test4Monthly() throws {
        launch(now: "2027-01-01T09:41:00+05:30", premium: "monthly")
        pickCity("New Delhi")
        tab(4); shot("prem-40-settings-monthly")
        if tap("settings_premium", timeout: 4) { shot("prem-41-plans-monthly-owned", settle: 2); close() }
        tab(3); shot("prem-42-panchang-keydays-jan")
        panchangPage("daily"); shot("prem-43-panchang-daily-jan")
    }

    /// Search indexes for a couple of seconds after opening: show the year
    /// menu and the filters first, then type.
    private func searchWarmup(_ prefix: String?, pace: Double = 1.0) {
        Thread.sleep(forTimeInterval: 0.8)
        if tap("search_year_selector", timeout: 4) {
            Thread.sleep(forTimeInterval: pace)
            if let prefix { shot("\(prefix)-year-menu", settle: 0.3) }
            if !tap(button("2027"), "year 2027", timeout: 2) { dismissMenu() }
            Thread.sleep(forTimeInterval: pace * 0.6)
        }
        for (i, id) in ["search_filter_ekadashi", "search_filter_festival"].enumerated() where el(id).exists {
            let f = el(id).frame
            guard !f.isEmpty, f.minX >= 0, f.maxX <= app.frame.width else { continue }
            el(id).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap(); Thread.sleep(forTimeInterval: pace * 0.7)
            if let prefix { shot("\(prefix)-filter-\(i)", settle: 0.3) }
        }
        ids("searchfilters")
        let all = el("search_filter_all")
        if all.exists, !all.frame.isEmpty { all.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        Thread.sleep(forTimeInterval: 0.5)
    }
    private func typeSearch(_ q: String, slow: Bool = false) {
        // Wait for the top-right indexing spinner to finish before typing.
        let spinner = app.activityIndicators.firstMatch
        let gone = NSPredicate(format: "exists == false")
        if spinner.exists { _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: gone, object: spinner)], timeout: 30) }
        Thread.sleep(forTimeInterval: 0.4)
        let sf = app.searchFields.firstMatch
        guard sf.waitForExistence(timeout: 5) else { print("MISSING searchfield"); return }
        sf.tap()
        if slow { for ch in q { sf.typeText(String(ch)); Thread.sleep(forTimeInterval: 0.12) } } else { sf.typeText(q) }
        Thread.sleep(forTimeInterval: 1.5)
    }
    private func openReminders() -> Bool {
        tab(4)
        if el("notifications_add_event").exists { return true }
        for l in ["Notifications", "Reminders"] where button(l).exists { button(l).tap(); Thread.sleep(forTimeInterval: 1) }
        for _ in 0..<8 where !(el("notifications_add_event").exists && el("notifications_add_event").isHittable) { app.swipeUp(velocity: .slow) }
        return el("notifications_add_event").exists
    }
    private func search(_ q: String, _ name: String) {
        tab(0); tap("open_global_search")
        searchWarmup(name)
        typeSearch(q); shot(name, settle: 1); ids(name)
    }
    private func reminders(_ prefix: String, choose: [String]) {
        guard openReminders() else { print("MISSING reminders"); return }
        shot("\(prefix)-reminders")
        for c in choose {
            tap("notifications_add_event"); Thread.sleep(forTimeInterval: 1.2)
            shot("\(prefix)-reminder-editor"); ids("editor")
            tap("event_reminder_choose"); Thread.sleep(forTimeInterval: 1.2)
            shot("\(prefix)-reminder-choices"); ids("choices")
            let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", c)).firstMatch
            for _ in 0..<8 where !(row.exists && row.isHittable) { app.swipeUp(velocity: .slow) }
            tap(row, c); Thread.sleep(forTimeInterval: 1.2)
            shot("\(prefix)-reminder-after-\(c.lowercased())", settle: 1.5)
            if el("premium_close").exists { close() }
            if tap("event_reminder_save", timeout: 3) { Thread.sleep(forTimeInterval: 1) } else { close() }
        }
        shot("\(prefix)-reminders-list")
    }

    func test5FreeExtras() throws {
        launch(now: "2027-01-01T09:41:00+05:30")
        pickCity("New Delhi")
        search("Diwali", "free-30-search-diwali-locked")
        reminders("free-31", choose: ["Diwali"])
    }

    func test6YearlyExtras() throws {
        launch(now: "2027-07-20T09:41:00+05:30", premium: "yearly")
        pickCity("New Delhi")
        search("Diwali", "prem-50-search-diwali")
        reminders("prem-52", choose: ["Diwali", "Janmashtami"])
    }

    // MARK: video clips (screen recorded from outside; MARK lines give cut points)
    private func mark(_ name: String) { print("MARK \(name) \(Date().timeIntervalSince1970)") }
    private func wait(_ s: Double) { Thread.sleep(forTimeInterval: s) }

    func testV1Free() throws {
        launch(now: "2027-01-01T09:41:00+05:30")
        pickCity("New Delhi")
        mark("home"); wait(2.2)
        let next = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'next' OR label == 'Next'")).firstMatch
        app.swipeLeft(velocity: .slow); wait(1.4); app.swipeRight(velocity: .slow); wait(1.0)
        mark("language"); tap("language_menu"); wait(1.2)
        tap(button("हिंदी"), "hindi"); wait(2.4)
        mark("hindi-home"); wait(1.2)
        tap("language_menu"); wait(1.0); tap(button("English"), "english"); wait(3.0)
        mark("tradition"); tap("home_tradition_menu"); wait(1.3); dismissMenu(); wait(0.5)
        mark("city"); tap("home_location"); wait(1.0)
        let field = el("ekadashi_location_search")
        if tap(field, "city field", timeout: 6) { for ch in "London" { field.typeText(String(ch)); wait(0.12) } }
        wait(1.8); close(); wait(0.8)
        mark("details"); tap("view_details"); wait(1.8); app.swipeUp(velocity: .slow); wait(1.4)
        mark("share"); app.swipeDown(velocity: .fast); tap("details_share_card"); wait(2.6); close(); wait(0.6)
        if app.navigationBars.buttons.firstMatch.exists { app.navigationBars.buttons.firstMatch.tap() }; wait(0.8)
        mark("calendar"); tab(1); wait(1.2)
        tap(button("Fri, 15 Jan 2027"), "jan 15"); wait(1.6)
        tap(button("Google"), "google"); wait(1.4); tap(button("All"), "all"); wait(0.6)
        tap("calendar_next_month"); wait(0.8); tap("calendar_next_month"); wait(0.8)
        tap(button("Mon, 22 Mar 2027"), "holi"); wait(1.8)
        mark("panchang-free"); tab(3); wait(1.8)
        mark("search-free"); tab(0); tap("open_global_search")
        searchWarmup(nil, pace: 1.1)
        typeSearch("Diwali", slow: true); wait(1.8); tap("global_search_back", timeout: 3)
        mark("widgets"); tab(4); tap("settings_widget_preview"); wait(1.6)
        tap(button("Small"), "small"); wait(1.2); tap(button("Lock Screen"), "lock"); wait(1.4)
        tap(button("Upcoming Ekadashis"), "upcoming"); wait(1.4)
        close(); app.navigationBars.buttons.firstMatch.tap(); wait(0.6)
        mark("plans"); tab(4); tap("settings_premium"); wait(1.6)
        tap("premium_plan_monthly", timeout: 3); wait(1.0); tap("premium_plan_yearly", timeout: 3); wait(1.8)
        mark("end"); wait(0.5)
    }

    func testV2YearlyJourney() throws {
        launch(now: "2026-11-19T09:41:00+05:30", premium: "yearly")
        pickCity("New Delhi")
        tab(2); tap("journey_tab_history")
        if tap("journey_history_year", timeout: 4) { tap(button("2026"), "2026") }
        for n in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 15, 16, 17, 18] { record(n) }
        tap("journey_tab_overview"); wait(1.0)
        tap("journey_tab_history"); wait(0.8)
        mark("record")
        let row = el("journey_row_ekadashi:2026:19")
        for _ in 0..<6 where row.exists && !row.isHittable { app.swipeUp(velocity: .slow) }
        tap(row, "row19"); wait(1.6); tap("vrat_record_save"); wait(2.6)
        if el("journey_celebration_close").exists { el("journey_celebration_close").tap() }; wait(0.8)
        mark("overview"); tap("journey_tab_overview"); wait(2.4); app.swipeUp(velocity: .slow); wait(1.4); app.swipeDown(velocity: .fast)
        mark("achievements"); tap("journey_tab_achievements"); wait(2.0)
        mark("jshare"); tap("journey_tab_overview"); wait(0.6)
        let share = el("journey_share_year")
        for _ in 0..<8 where !(share.exists && share.isHittable) { app.swipeUp(velocity: .slow); wait(0.3) }
        if tap(share, "journey share", timeout: 4) {
            wait(2.6); shot("prem-05-journey-share", settle: 0.2)
            let toggles = app.switches
            for i in 0..<min(2, toggles.count) where toggles.element(boundBy: i).isHittable { toggles.element(boundBy: i).tap(); wait(0.8) }
            app.swipeDown(velocity: .slow); wait(1.2); shot("prem-05b-journey-share-badges", settle: 0.2)
            close()
        }
        mark("end"); wait(0.5)
    }

    func testV3YearlyPanchang() throws {
        launch(now: "2027-07-20T09:41:00+05:30", premium: "yearly")
        pickCity("New Delhi")
        mark("keydays"); tab(3); wait(1.8)
        if button("Festivals").exists { button("Festivals").tap() }; wait(1.6)
        if button("All").exists { button("All").tap() }; wait(0.4)
        mark("daily"); panchangPage("daily"); wait(1.8); app.swipeUp(velocity: .slow); wait(1.4)
        mark("muhurta"); panchangPage("muhurta"); wait(1.8)
        mark("rashi"); panchangPage("rashi"); wait(1.6)
        mark("calendar"); tab(1); wait(1.0); tap(button("Sun, 18 Jul 2027"), "jul 18"); wait(1.8)
        mark("search"); tab(0); tap("open_global_search")
        searchWarmup(nil, pace: 1.1)
        typeSearch("Diwali", slow: true); wait(1.8); tap("global_search_back", timeout: 3)
        mark("end"); wait(0.5)
    }

    func test7October() throws {
        launch(now: "2027-10-16T09:41:00+05:30", premium: "yearly")
        pickCity("New Delhi")
        shot("prem-60-home-oct")
        tab(3); Thread.sleep(forTimeInterval: 1.5); shot("prem-61-panchang-keydays-oct")
        if button("Festivals").exists { button("Festivals").tap() }; shot("prem-62-panchang-festivals-oct", settle: 1.5)
        tab(1); tap(button("Fri, 29 Oct 2027"), "diwali"); shot("prem-63-calendar-diwali", settle: 1.2)
    }

    func test8Fixups() throws {
        launch(now: "2027-01-01T09:41:00+05:30", premium: "yearly")
        pickCity("New Delhi")
        for _ in 0..<3 {
            tap("home_tradition_menu"); Thread.sleep(forTimeInterval: 1.2)
            if button("Smarta").exists { break }
        }
        shot("free-03-tradition-menu", settle: 0.5)
        dismissMenu()
        reminders("prem-53", choose: ["Deepavali", "Holi", "Maha Shivaratri"])
    }
}
