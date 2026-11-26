// Device-only billing harness (kept outside the UI test target; see tool/release/README.md).
// Drives the real paywall against the App Store sandbox. ACTION (via
// TEST_RUNNER_ACTION) picks one step: look, monthly, yearly, lifetime,
// restore, manage. Never types a password: stops and reports instead.
import XCTest

final class DeviceBillingUITests: XCTestCase {
    private var app: XCUIApplication!
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    private var step = 0

    func testDeviceStep() throws {
        continueAfterFailure = true
        let action = ProcessInfo.processInfo.environment["ACTION"] ?? "look"
        print("DEVLOG action \(action)")
        if action == "legal" {
            app = XCUIApplication(); app.launchArguments += ["-ui-testing"]; app.launch()
            _ = app.tabBars.buttons.element(boundBy: 4).waitForExistence(timeout: 30); sleep(3)
            app.tabBars.buttons.element(boundBy: 4).tap(); sleep(3)
            let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
            func check(_ name: String) {
                let done = app.buttons["Done"].firstMatch
                let shown = done.waitForExistence(timeout: 15)
                sleep(3)
                print("DEVLOG \(name): in-app=\(shown) safariForeground=\(safari.state == .runningForeground)")
                snap(name)
                if shown { done.tap(); sleep(2) }
            }
            app.buttons["settings_premium"].firstMatch.tap(); sleep(5)
            app.buttons["Terms of service"].firstMatch.tap(); check("plans-terms")
            app.buttons["Privacy policy"].firstMatch.tap(); check("plans-privacy")
            print("DEVLOG back on plans: \(app.buttons["premium_buy"].exists)")
            app.buttons["premium_close"].firstMatch.tap(); sleep(2)
            for id in ["settings_terms", "settings_privacy"] {
                let row = app.buttons[id].firstMatch
                for _ in 0..<6 where !(row.exists && row.isHittable) { app.swipeUp() }
                row.tap(); check(id)
            }
            print("DEVLOG back in settings: \(app.buttons["settings_contact_support"].exists)")
            return
        }
        if action == "settings" {
            app = XCUIApplication(); app.launchArguments += ["-ui-testing"]; app.launch()
            _ = app.tabBars.buttons.element(boundBy: 4).waitForExistence(timeout: 30); sleep(3)
            app.tabBars.buttons.element(boundBy: 4).tap(); sleep(3)
            snap("settings-top")
            for i in 1...3 { app.swipeUp(); sleep(1); snap("settings-scroll\(i)") }
            for _ in 0..<6 { app.swipeDown() }
            app.buttons["settings_notifications"].firstMatch.tap(); sleep(3)
            snap("notifications-top")
            for i in 1...2 { app.swipeUp(); sleep(1); snap("notifications-scroll\(i)") }
            return
        }
        app = XCUIApplication()
        app.launchArguments += ["-ui-testing"]
        app.launch()
        _ = app.tabBars.buttons.element(boundBy: 4).waitForExistence(timeout: 30)
        sleep(3)
        app.tabBars.buttons.element(boundBy: 4).tap()
        sleep(3)
        snap("settings")
        let entry = app.buttons["settings_premium"].firstMatch
        _ = entry.waitForExistence(timeout: 10)
        entry.tap()
        _ = app.buttons["premium_plan_monthly"].firstMatch.waitForExistence(timeout: 30)
        waitIdle("open")
        snap("plans")
        switch action {
        case "monthly", "yearly", "lifetime":
            let tile = app.buttons["premium_plan_\(action)"].firstMatch
            tile.tap(); sleep(1)
            snap("selected")
            let buy = app.buttons["premium_buy"].firstMatch
            print("DEVLOG buy button '\(buy.label)' enabled=\(buy.isEnabled)")
            buy.tap(); sleep(2)
            let alert = app.alerts.firstMatch
            if alert.exists {
                print("DEVLOG app alert: \(alert.staticTexts.allElementsBoundByIndex.map(\.label)) \(alert.buttons.allElementsBoundByIndex.map(\.label))")
                snap("app-alert")
                alert.buttons.allElementsBoundByIndex.first { $0.label != "Cancel" }?.tap()
            }
            handleAppleSheet()
            waitIdle("after purchase")
            sleep(5)
            snap("after")
        case "lifetime-warn":
            app.buttons["premium_plan_lifetime"].firstMatch.tap(); sleep(1)
            app.buttons["premium_buy"].firstMatch.tap(); sleep(2)
            let alert = app.alerts.firstMatch
            print("DEVLOG lifetime alert exists=\(alert.exists): \(alert.staticTexts.allElementsBoundByIndex.map(\.label)) \(alert.buttons.allElementsBoundByIndex.map(\.label))")
            snap("lifetime-alert")
            alert.buttons["Cancel"].tap(); sleep(2)
            snap("lifetime-cancelled")
        case "manage-cancel":
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Manage subscription'")).firstMatch.tap()
            sleep(8)
            snap("manage-sheet")
            let sheetButtons = springboard.buttons.allElementsBoundByIndex.map(\.label)
            print("DEVLOG manage buttons: \(sheetButtons)")
            let cancelSub = springboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Cancel Subscription'")).firstMatch
            if cancelSub.exists {
                cancelSub.tap(); sleep(3); snap("cancel-confirm")
                print("DEVLOG confirm: \(springboard.staticTexts.allElementsBoundByIndex.map(\.label).prefix(10)) \(springboard.buttons.allElementsBoundByIndex.map(\.label))")
                let confirm = springboard.buttons.matching(NSPredicate(format: "label ==[c] 'Confirm'")).firstMatch
                if confirm.exists { confirm.tap(); print("DEVLOG tapped Confirm") }
                sleep(6); snap("after-cancel")
            }
            let done = springboard.buttons["Done"].firstMatch
            if done.exists { done.tap() }
            sleep(10); snap("back-in-paywall")
        case "manage-resub":
            app.buttons["premium_plan_yearly"].firstMatch.tap(); sleep(2)
            let reactivate = app.buttons["premium_buy"].firstMatch
            print("DEVLOG buy label before reactivate: '\(reactivate.label)'")
            guard reactivate.label == "Reactivate" else { snap("not-reactivate"); break }
            reactivate.tap()
            sleep(8)
            snap("resub-sheet")
            print("DEVLOG resub buttons: \(springboard.buttons.allElementsBoundByIndex.map(\.label))")
            let monthly = springboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Monthly'")).firstMatch
            if monthly.exists { monthly.tap(); sleep(3); snap("resub-picked")
                print("DEVLOG after pick: \(springboard.buttons.allElementsBoundByIndex.map(\.label))") }
            for _ in 0..<20 {
                sleep(3)
                if !springboard.buttons["Done"].exists && app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'See your next renewal'")).firstMatch.exists { break }
            }
            let done = springboard.buttons["Done"].firstMatch
            if done.exists { done.tap() }
            sleep(8); snap("after-resub")
        case "achievements":
            app.buttons["premium_close"].firstMatch.tap(); sleep(1)
            app.tabBars.buttons.element(boundBy: 2).tap(); sleep(2)
            app.descendants(matching: .any).matching(identifier: "journey_tab_achievements").firstMatch.tap(); sleep(3)
            snap("achievements")
        case "restore":
            app.buttons["Restore purchases"].firstMatch.tap()
            handleAppleSheet()
            waitIdle("restore"); sleep(3)
            snap("after-restore")
        case "manage":
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Manage subscription'")).firstMatch.tap()
            sleep(6)
            snap("manage-sheet")
            dumpSpringboard("manage")
        default:
            break
        }
        closeAndSnapSettings()
    }

    private func handleAppleSheet() {
        // The owner confirms Apple's sheet on the phone; we only wait and watch.
        let start = Date()
        let action = ProcessInfo.processInfo.environment["ACTION"] ?? ""
        let tile = app.buttons["premium_plan_\(action)"].firstMatch
        while Date().timeIntervalSince(start) < 150 {
            sleep(3)
            if tile.exists, tile.label.contains("Current plan") || tile.label.contains("Starts") || tile.label.contains("Upcoming") {
                print("DEVLOG plan shown after \(Int(Date().timeIntervalSince(start)))s: \(tile.label)")
                return
            }
            if action == "restore", app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'restored' OR label CONTAINS[c] 'No purchases'")).firstMatch.exists {
                print("DEVLOG restore message after \(Int(Date().timeIntervalSince(start)))s"); return
            }
        }
        print("DEVLOG plan not shown within 150s")
        snap("sheet-timeout")
    }

    private func dumpSpringboard(_ label: String) {
        print("DEVLOG \(label) springboard text: \(springboard.staticTexts.allElementsBoundByIndex.map(\.label).prefix(40))")
        print("DEVLOG \(label) app text: \(app.staticTexts.allElementsBoundByIndex.map(\.label).prefix(60))")
    }

    private func closeAndSnapSettings() {
        let close = app.buttons["premium_close"].firstMatch
        if close.exists { close.tap(); sleep(2) }
        snap("settings-end")
    }

    private func waitIdle(_ label: String) {
        let start = Date()
        let buy = app.buttons["premium_buy"].firstMatch
        var idle = false
        while Date().timeIntervalSince(start) < 120 {
            if !app.activityIndicators["premium_loading"].exists && (!buy.exists || buy.isEnabled) { idle = true; break }
            sleep(1)
        }
        print("DEVLOG idle '\(label)' \(idle) after \(Int(Date().timeIntervalSince(start)))s")
    }

    private func snap(_ name: String) {
        step += 1
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = String(format: "%02d-%@", step, name)
        attachment.lifetime = .keepAlways
        add(attachment)
        let texts = app.staticTexts.allElementsBoundByIndex.map(\.label)
        let buttons = app.buttons.allElementsBoundByIndex.map { "[\($0.identifier)] \($0.label)" }
        print("DEVLOG \(String(format: "%02d", step)) \(name)\n  TEXT: \(texts.joined(separator: " | "))\n  BUTTONS: \(buttons.joined(separator: " | "))")
    }
}
