import Foundation
import XCTest
@testable import EkadashiCore

/// Both apps show the same icon in every place (docs/ICONS.md): each role in
/// test/fixtures/app_icons.json names the SF Symbol iOS shows (AppSymbol) and
/// its CupertinoIcons twin on Android (AppIcons, app_icons_parity_test.dart).
final class AppSymbolTests: XCTestCase {
    private struct Fixture: Decodable {
        let roles: [String: String]
        let symbols: [String: String]
    }

    private let fixture = try! JSONDecoder().decode(Fixture.self,
                                                    from: Data(contentsOf: Repo.url("test/fixtures/app_icons.json")))

    func testEveryRoleIsTheSymbolInTheSharedTable() {
        XCTAssertEqual(AppSymbol.all, fixture.roles)
        for (role, symbol) in fixture.roles {
            XCTAssertNotNil(fixture.symbols[symbol], "\(role): \(symbol) has an Android twin")
        }
    }

    func testGlassLookUsesTheAppleStyleOverlappingGlassShapes() {
        XCTAssertEqual(AppSymbol.all["glass_look"], "square.on.circle")
    }

    func testTheTabBar() {
        XCTAssertEqual([AppSymbol.tabHome, AppSymbol.tabCalendar, AppSymbol.tabJourney, AppSymbol.tabPanchang,
                        AppSymbol.tabSettings], ["house.fill", "calendar", "rosette", "sparkles", "gearshape.fill"])
    }

    func testCategoriesAndAchievementsUseTheTable() {
        for category in SearchCategory.allCases {
            XCTAssertNotNil(fixture.symbols[category.symbol], "\(category)")
        }
        for achievement in AchievementEvaluator.all {
            XCTAssertNotNil(fixture.symbols[achievement.symbol], achievement.id)
        }
    }

    /// No screen names an SF Symbol itself: every icon comes from AppSymbol.
    func testScreensTakeEveryIconFromAppSymbol() throws {
        let known = Set(fixture.symbols.keys).union(["square.grid.2x2", "sparkle", "circle.circle", "medal",
                                                      "fork.knife", "g.circle", "crown.fill"])
        let api = try NSRegularExpression(pattern: #"(systemName|systemImage|symbol):\s*"[^"]*""#)
        let literal = try NSRegularExpression(pattern: #""([a-z0-9]+(\.[a-z0-9]+)+)""#)
        // A one-word symbol handed to a helper ("sparkles", ...) or chosen by a ternary.
        let argument = try NSRegularExpression(pattern: #"(?:\w\(|\? |: )"([a-z]+)"(?:,| :|\))"#)
        var offenders: [String] = []
        for folder in ["ios-native/EkadashiCalendar", "ios-native/EkadashiCore/Sources/EkadashiCore"] {
            let root = Repo.url(folder)
            let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)!
            for case let url as URL in files where url.pathExtension == "swift" && url.lastPathComponent != "AppSymbol.swift" {
                let lines = try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
                for (index, line) in lines.enumerated() where !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                    let range = NSRange(line.startIndex..., in: line)
                    let found = api.matches(in: line, range: range).map { (line as NSString).substring(with: $0.range) }
                        + literal.matches(in: line, range: range)
                            .map { (line as NSString).substring(with: $0.range(at: 1)) }
                            .filter { known.contains($0) }
                        + argument.matches(in: line, range: range)
                            .map { (line as NSString).substring(with: $0.range(at: 1)) }
                            .filter { known.contains($0) && !line.contains("model.t(\"\($0)\")") }
                    offenders += found.map { "\(url.lastPathComponent):\(index + 1) \($0)" }
                }
            }
        }
        XCTAssertEqual(offenders, [])
    }
}
