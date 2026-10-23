import Foundation
import XCTest
@testable import EkadashiCore

/// Wide screens (the iPhone Duo's inner screen, Android foldables) show two
/// panes side by side (docs/FOLDABLES.md). Both apps take the rule from
/// test/fixtures/adaptive_layout.json (adaptive_layout_test.dart on Android).
final class AdaptiveLayoutTests: XCTestCase {
    private struct Fixture: Decodable {
        struct Case: Decodable {
            let name: String
            let width: Double
            let panes: Int
            let readableWidth: Double
        }

        let twoPaneMinWidth: Double
        let readableMaxWidth: Double
        let paneSpacing: Double
        let cases: [Case]
    }

    private let fixture = try! JSONDecoder().decode(Fixture.self,
                                                    from: Data(contentsOf: Repo.url("test/fixtures/adaptive_layout.json")))

    func testTheRuleIsTheSharedTable() {
        XCTAssertEqual(AdaptiveLayout.twoPaneMinWidth, fixture.twoPaneMinWidth)
        XCTAssertEqual(AdaptiveLayout.readableMaxWidth, fixture.readableMaxWidth)
        XCTAssertEqual(AdaptiveLayout.paneSpacing, fixture.paneSpacing)
    }

    func testEveryWidthGetsTheSharedPanesAndReadableWidth() {
        for item in fixture.cases {
            XCTAssertEqual(AdaptiveLayout.panes(forWidth: item.width).columns, item.panes, item.name)
            XCTAssertEqual(AdaptiveLayout.readableWidth(forWidth: item.width), item.readableWidth, item.name)
        }
    }

    func testPhonesKeepOnePaneAndTheDuoInnerScreenGetsTwo() {
        XCTAssertEqual(AdaptiveLayout.panes(forWidth: 440), .single)
        XCTAssertEqual(AdaptiveLayout.panes(forWidth: 466), .single, "iPhone Duo outer screen")
        XCTAssertEqual(AdaptiveLayout.panes(forWidth: 669), .double, "iPhone Duo inner screen")
        XCTAssertEqual(AdaptiveLayout.panes(forWidth: 951), .double, "iPhone Duo inner screen, landscape")
        XCTAssertTrue(AdaptiveLayout.panes(forWidth: 669).isSideBySide)
        XCTAssertFalse(AdaptiveLayout.panes(forWidth: 402).isSideBySide)
    }

    /// An unmeasured or nonsense width falls back to the phone layout.
    func testInvalidWidthsKeepOnePane() {
        for width in [-1, 0, .nan, -.infinity] as [Double] {
            XCTAssertEqual(AdaptiveLayout.panes(forWidth: width), .single, "\(width)")
            XCTAssertEqual(AdaptiveLayout.readableWidth(forWidth: width), 0, "\(width)")
        }
        XCTAssertEqual(AdaptiveLayout.panes(forWidth: .infinity), .double)
        XCTAssertEqual(AdaptiveLayout.readableWidth(forWidth: .infinity), AdaptiveLayout.readableMaxWidth)
    }

    /// The side margin that centres readable content (Settings, details).
    func testSideMarginCentresTheReadableWidth() {
        XCTAssertEqual(AdaptiveLayout.sideMargin(forWidth: 402), 0)
        XCTAssertEqual(AdaptiveLayout.sideMargin(forWidth: 720), 0)
        XCTAssertEqual(AdaptiveLayout.sideMargin(forWidth: 951), 115.5)
        XCTAssertEqual(AdaptiveLayout.sideMargin(forWidth: .nan), 0)
    }
}

/// The app follows Apple's iPhone Duo guidance (developer.apple.com/iphone-duo):
/// layout comes from the space a screen is given, never from the device,
/// its orientation or the main screen, and every tab adapts to wide screens.
final class AdaptiveSourceTests: XCTestCase {
    private func source(_ path: String) throws -> String {
        try String(contentsOf: Repo.url("ios-native/\(path)"), encoding: .utf8)
    }

    private func appSources() throws -> [(String, String)] {
        var files: [(String, String)] = []
        for folder in ["EkadashiCalendar", "Shared", "EkadashiWidgets"] {
            let root = Repo.url("ios-native/\(folder)")
            let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
            while let url = walker?.nextObject() as? URL {
                guard url.pathExtension == "swift" else { continue }
                files.append((url.lastPathComponent, try String(contentsOf: url, encoding: .utf8)))
            }
        }
        XCTAssertGreaterThan(files.count, 20)
        return files
    }

    func testNoScreenSizesItselfFromTheDeviceOrMainScreen() throws {
        let banned = ["UIScreen.main", "userInterfaceIdiom", "UIDevice.current.orientation", "interfaceOrientation",
                      "statusBarOrientation", "UIRequiresFullScreen"]
        for (name, text) in try appSources() {
            for word in banned { XCTAssertFalse(text.contains(word), "\(name) uses \(word)") }
        }
        XCTAssertFalse(try source("project.yml").contains("UIRequiresFullScreen"))
    }

    /// Every tab measures its width once (RootView) and the screens split
    /// into panes or keep a readable width from that one rule.
    func testEveryTabAdaptsToWideScreens() throws {
        XCTAssertTrue(try source("EkadashiCalendar/App/RootView.swift").contains(".measuresPaneLayout()"))
        for screen in ["Features/Today/TodayView.swift", "Features/Calendar/CalendarView.swift",
                       "Features/Vrat/VratView.swift", "Features/Panchang/PanchangPages.swift"] {
            XCTAssertTrue(try source("EkadashiCalendar/\(screen)").contains("AdaptivePanes"), screen)
        }
        for screen in ["Features/Settings/SettingsView.swift", "Features/Today/EkadashiDetailsView.swift",
                       "Features/Premium/PremiumView.swift", "Features/Panchang/PanchangView.swift"] {
            XCTAssertTrue(try source("EkadashiCalendar/\(screen)").contains("readable"), screen)
        }
    }

    /// The panes the UI tests look for on the iPhone Duo.
    func testPanesHaveTheIdentifiersTheUITestsUse() throws {
        let expected = [
            "Features/Calendar/CalendarView.swift": ["calendar_grid_pane", "calendar_day_pane"],
            "Features/Today/TodayView.swift": ["home_card_pane", "home_list_pane"],
            "Features/Vrat/VratView.swift": ["journey_overview_metrics_pane", "journey_overview_record_pane"],
            "Features/Panchang/PanchangPages.swift": ["panchang_daily_leading_pane", "panchang_daily_trailing_pane"],
        ]
        let uiTests = try source("EkadashiCalendarUITests/AdaptiveLayoutUITests.swift")
        for (screen, identifiers) in expected {
            let text = try source("EkadashiCalendar/\(screen)")
            for identifier in identifiers {
                XCTAssertTrue(text.contains("\"\(identifier)\""), "\(screen): \(identifier)")
                XCTAssertTrue(uiTests.contains("\"\(identifier)\""), "UI tests: \(identifier)")
            }
        }
    }

    /// Xcode 27.1 (iOS 27.1 SDK) lets the app fill the Duo's screens edge to edge.
    func testBuildsWithTheIPhoneDuoSDK() throws {
        XCTAssertTrue(try source("project.yml").contains("Xcode 27.1"))
        let workflow = try String(contentsOf: Repo.url(".github/workflows/android-tests.yml"), encoding: .utf8)
        XCTAssertTrue(workflow.contains("Xcode_27"), "CI prefers Xcode 27.1")
        XCTAssertTrue(workflow.contains("AdaptiveLayoutUITests"), "CI runs the wide-screen UI tests on the iPhone Duo simulator")
    }
}
