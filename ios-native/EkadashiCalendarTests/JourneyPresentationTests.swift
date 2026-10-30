import XCTest
import SwiftUI
import EkadashiCore
@testable import EkadashiCalendar

@MainActor
final class JourneyPresentationTests: XCTestCase {
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
        func render(_ scheme: ColorScheme) throws -> Data {
            let view = JourneyAnnualShareCard(progress: progress, badges: [badge]).frame(width: 360)
                .environment(model).environment(\.colorScheme, scheme)
            return try XCTUnwrap(ImageRenderer(content: view).uiImage?.pngData())
        }
        XCTAssertEqual(try render(.light), try render(.dark))
    }

    func testSharedImageHasOpaqueGreenCornersWithRoundedInnerCard() throws {
        let model = AppModel()
        let progress = JourneyRewards.calculate(occurrences: [], history: [], completeYears: []).year(2026)
        let image = try XCTUnwrap(ImageRenderer(content:
            JourneyAnnualShareCard(progress: progress, badges: []).frame(width: 360).environment(model)).uiImage?.cgImage)
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8,
            bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        XCTAssertEqual(pixel[3], 255, "Exported corners must be opaque, including after JPEG conversion")
        XCTAssertGreaterThan(pixel[1], pixel[0], "Corner matte must be green, not white")
        XCTAssertLessThan(pixel[0], 40)
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
