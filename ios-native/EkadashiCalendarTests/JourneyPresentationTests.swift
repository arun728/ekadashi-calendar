import XCTest
import SwiftUI
import EkadashiCore
@testable import EkadashiCalendar

@MainActor
final class JourneyPresentationTests: XCTestCase {
    func testShareSelectsEveryEarnedBadgeAndAllowsDeselection() async throws {
        let model = AppModel()
        let badges = Array(JourneyBadgeCatalog.all(years: []).prefix(5))
        let progress = JourneyRewards.calculate(occurrences: [], history: [], completeYears: []).year(2026)
        let host = UIHostingController(rootView: JourneyShareSheet(progress: progress, badges: badges).environment(model))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 430, height: 2000))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        try await Task.sleep(for: .milliseconds(600))
        host.view.layoutIfNeeded()
        func switches(_ view: UIView) -> [UISwitch] {
            (view as? UISwitch).map { [$0] } ?? view.subviews.flatMap { switches($0) }
        }
        let controls = switches(host.view)
        XCTAssertEqual(controls.count, 5)
        XCTAssertEqual(controls.filter(\.isOn).count, 5, "Every earned badge should be selected, including the fourth and fifth")
        let control = try XCTUnwrap(controls.first)
        control.setOn(false, animated: false)
        control.sendActions(for: .valueChanged)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(switches(host.view).filter(\.isOn).count, 4)
    }

    func testJourneyMetricTitlesWrapInsteadOfTruncating() throws {
        func height(_ title: String) throws -> CGFloat {
            let view = MetricCard(title: title, value: "3", subtitle: "Ekadashis", symbol: AppSymbol.journeyStreak, color: .orange).frame(width: 150)
            return try XCTUnwrap(ImageRenderer(content: view).uiImage).size.height
        }
        XCTAssertGreaterThan(try height("Current consistency streak"), try height("Short"))
    }

    func testUniformGridFitsTallContentAndMakesEveryCellTheSameSize() async throws {
        for width: CGFloat in [320, 430] {
            for large in [false, true] {
                var frames: [Int: CGRect] = [:]
                let titles = ["Current consistency streak", "Longest consistency streak", "2026 Full-observance completion", "Total Observed"]
                let content = ScrollView {
                    JourneyUniformGrid(columns: 2) {
                        ForEach(0..<titles.count, id: \.self) { i in
                            MetricCard(title: titles[i], value: "20", subtitle: "Ekadashis", symbol: AppSymbol.journeyStreak, color: .orange)
                                .background(GeometryReader { proxy in Color.clear.preference(key: JourneyCellFrames.self, value: [i: proxy.frame(in: .global)]) })
                        }
                    }
                    .onPreferenceChange(JourneyCellFrames.self) { frames = $0 }
                }.environment(\.dynamicTypeSize, large ? .accessibility3 : .large)
                let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 1200))
                let host = UIHostingController(rootView: content)
                window.rootViewController = host; window.makeKeyAndVisible()
                host.view.layoutIfNeeded()
                try await Task.sleep(for: .milliseconds(150))
                XCTAssertEqual(frames.count, 4)
                let first = try XCTUnwrap(frames[0])
                for frame in frames.values {
                    XCTAssertEqual(frame.width, first.width, accuracy: 0.5)
                    XCTAssertEqual(frame.height, first.height, accuracy: 0.5)
                }
                let tallest = try XCTUnwrap(ImageRenderer(content: MetricCard(title: titles[2], value: "20", subtitle: "Ekadashis", symbol: AppSymbol.journeyStreak, color: .orange).frame(width: first.width).environment(\.dynamicTypeSize, large ? .accessibility3 : .large)).uiImage)
                XCTAssertGreaterThanOrEqual(first.height + 0.5, tallest.size.height)
                window.isHidden = true
            }
        }
    }

    func testEveryBadgeVectorRendersAtSmallAndLargeSizes() throws {
        for badge in JourneyBadgeCatalog.all(years: [2026, 2027]) {
            for size: CGFloat in [48, 160] {
                let renderer = ImageRenderer(content: JourneyBadgeArt(definition: badge).frame(width: size, height: size))
                let image = try XCTUnwrap(renderer.uiImage, badge.id)
                XCTAssertEqual(image.size.width, size)
                XCTAssertGreaterThan(try XCTUnwrap(image.pngData()).count, 300, badge.id)
            }
        }
    }

    func testEngineAnnualTargetsAndBothMandalaSizes() async throws {
        let model = AppModel()
        model.reload(); await model.waitForLoad()
        let events = model.ekadashis
        XCTAssertEqual(events.filter { $0.date.year == 2026 }.count, 24)
        XCTAssertEqual(events.filter { $0.date.year == 2027 }.count, 25)
        let history = events.enumerated().map { index, event in
            VratRecord(id: event.occurrenceUid, ekadashiOccurrenceId: event.id, occurrenceUid: event.occurrenceUid,
                       ekadashiDate: event.date.iso, ekadashiName: event.name,
                       status: index % 4 == 0 ? .partial : index % 7 == 0 ? .missed : .observed,
                       recordedAtUTC: "2028-01-01T00:00:00Z", updatedAtUTC: "2028-01-01T00:00:00Z")
        }
        let summary = JourneyRewards.calculate(occurrences: events, history: history, completeYears: [2026, 2027],
                                              now: ISO8601.instant("2028-01-02T00:00:00Z")!, zone: model.scheduleZone)
        for year in [2026, 2027] {
            let renderer = ImageRenderer(content: JourneyMandala(progress: summary.year(year)).frame(width: 300, height: 300).environment(model))
            let image = try XCTUnwrap(renderer.uiImage)
            XCTAssertGreaterThan(try XCTUnwrap(image.pngData()).count, 3000)
            let attachment = XCTAttachment(image: image)
            attachment.name = "journey-mandala-\(year)-mixed-status"; attachment.lifetime = .keepAlways; add(attachment)
        }
    }

    func testAnnualShareCardRendersConsistentlyInLightAndDarkMode() throws {
        let model = AppModel()
        let progress = JourneyRewards.calculate(occurrences: [], history: [], completeYears: []).year(2027)
        let badge = try XCTUnwrap(JourneyBadgeCatalog.definition("first_vrat"))
        func render(_ scheme: ColorScheme, glass: Bool = false) throws -> Data {
            let view = JourneyAnnualShareCard(progress: progress, badges: [badge]).frame(width: 360)
                .environment(model).environment(\.colorScheme, scheme).environment(\.glassLookEnabled, glass)
            return try XCTUnwrap(ImageRenderer(content: view).uiImage?.pngData())
        }
        XCTAssertEqual(try render(.light), try render(.dark))
        XCTAssertEqual(try render(.light), try render(.dark, glass: true))
    }

    func testSharedImageHasOpaqueGreenCornersWithRoundedInnerCard() throws {
        let model = AppModel()
        let progress = JourneyRewards.calculate(occurrences: [], history: [], completeYears: []).year(2026)
        let image = try XCTUnwrap(ImageRenderer(content:
            JourneyAnnualShareCard(progress: progress, badges: []).frame(width: 360).environment(model)).uiImage?.cgImage)
        for point in [CGPoint(x: 0, y: 0), CGPoint(x: image.width - 1, y: 0),
                      CGPoint(x: 0, y: image.height - 1), CGPoint(x: image.width - 1, y: image.height - 1)] {
            let pixel = try pixel(image, at: point)
            XCTAssertEqual(pixel[3], 255, "All exported corners must remain opaque after JPEG conversion")
            XCTAssertGreaterThan(pixel[1], pixel[0], "Corner matte must be green, not white")
            XCTAssertLessThan(pixel[0], 40)
        }
        let attachment = XCTAttachment(image: UIImage(cgImage: image))
        attachment.name = "journey-feedback-opaque-export"; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testOverviewUsesTheDarkSharePalette() throws {
        let model = AppModel()
        let summary = JourneyRewards.calculate(occurrences: [], history: [], completeYears: [])
        let image = try XCTUnwrap(ImageRenderer(content:
            JourneyOverviewPanel(summary: summary, year: 2026).frame(width: 360).environment(model)).uiImage?.cgImage)
        let color = try pixel(image, at: CGPoint(x: 12, y: 80))
        XCTAssertEqual(color[3], 255)
        XCTAssertGreaterThan(color[1], color[0])
        XCTAssertLessThan(color[1], 65, "Use the share gradient rather than the washed-out glass tint")
    }

    private func pixel(_ image: CGImage, at point: CGPoint) throws -> [UInt8] {
        let crop = try XCTUnwrap(image.cropping(to: CGRect(origin: point, size: CGSize(width: 1, height: 1))))
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8,
            bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return bytes
    }

    func testGroupedAnnouncementsAreDeduplicated() {
        let model = AppModel()
        let badges = Array(JourneyBadgeCatalog.all(years: [2026]).prefix(3).map(\.achievement))
        model.announce(badges)
        model.announce(badges)
        XCTAssertEqual(model.unlockQueue.map(\.id), badges.map(\.id))
        XCTAssertEqual(JourneyUnlockGroup(achievements: model.unlockQueue).achievements.count, 3)
    }

    func testHapticPreferenceCanBeDisabledAndRestored() {
        let model = AppModel(), original = model.badgeHaptics
        defer { model.setBadgeHaptics(original) }
        model.setBadgeHaptics(false)
        XCTAssertFalse(model.badgeHaptics)
        XCTAssertFalse(AppModel().badgeHaptics)
    }
}

private struct JourneyCellFrames: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) { value.merge(nextValue(), uniquingKeysWith: { _, new in new }) }
}
