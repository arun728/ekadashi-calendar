import XCTest
import SwiftUI
import WidgetKit
import UIKit
import EkadashiCore
@testable import EkadashiCalendar

/// Native rendering checks require Xcode. The Linux package tests exercise
/// the shared selection, percentage, formatter, timeline and link behaviour.
@MainActor
final class WidgetRenderingTests: XCTestCase {
    func testEveryHomeFamilyUsesAppTealAndItsApprovedBackgroundInBothStates() throws {
        let events = try CalendarRepository.bundled().ekadashis(timezone: "IST", language: "en")
        let event = try XCTUnwrap(events.first { $0.fastingStart != nil && $0.paranaStart != nil })
        let start = try XCTUnwrap(event.fastingStart)
        let parana = try XCTUnwrap(event.paranaStart)
        let before = start.addingTimeInterval(-86400)
        let during = start.addingTimeInterval(parana.timeIntervalSince(start) * 0.625)
        for now in [before, during] {
            let snapshot = WidgetSnapshot.build(occurrences: events, timezone: "IST", locationName: "Chennai",
                                                language: "en", now: now, tradition: "smarta")
            let families: [(WidgetFamily, CGFloat, CGFloat)] = [(.systemSmall, 170, 170), (.systemMedium, 350, 165), (.systemLarge, 350, 368)]
            for (family, width, height) in families {
                for scheme in [ColorScheme.dark, .light] {
                    let view = EkadashiWidgetView(snapshot: snapshot, now: now, family: family)
                        .padding(16).frame(width: width, height: height)
                        .background(WidgetCardBackground()).environment(\.colorScheme, scheme)
                    let renderer = ImageRenderer(content: view)
                    renderer.scale = 1
                    let image = try XCTUnwrap(renderer.uiImage?.cgImage)
                    let pixels = try rgba(image)
                    XCTAssertTrue(contains(WidgetPalette.teal, in: pixels), "\(family) \(scheme): brand teal")
                    XCTAssertTrue(contains(scheme == .dark ? WidgetPalette.charcoal : WidgetPalette.ivory, in: pixels),
                                  "\(family) \(scheme): approved background")
                }
            }
        }
    }

    func testUpcomingRendersBothSupportedSizesInEveryLanguageAndAppearance() throws {
        for language in Localizer.languages {
            let events = try CalendarRepository.bundled().ekadashis(timezone: "IST", language: language)
            let now = ISO8601.instant("2026-10-17T12:00:00Z")!
            let snapshot = WidgetSnapshot.build(occurrences: events, timezone: "IST", locationName: "", language: language, now: now)
            for (family, height) in [(WidgetFamily.systemMedium, CGFloat(170)), (.systemLarge, 368)] {
                for scheme in [ColorScheme.dark, .light] {
                    let view = UpcomingEkadashiWidgetView(snapshot: snapshot, now: now, family: family)
                        .padding(16).frame(width: 350, height: height).background(WidgetCardBackground())
                        .environment(\.colorScheme, scheme)
                    let renderer = ImageRenderer(content: view)
                    renderer.scale = 1
                    let image = try XCTUnwrap(renderer.uiImage?.cgImage)
                    XCTAssertTrue(contains(WidgetPalette.teal, in: try rgba(image)))
                }
            }
        }
    }

    /// Render into a transparent safety margin: ink outside the widget's bounds
    /// exposes overflow even when a real WidgetKit host would clip it away.
    func testLongTranslationsStayInsideEveryWidgetFamilyInBothStates() throws {
        for language in Localizer.languages {
            let events = try CalendarRepository.bundled().ekadashis(timezone: "IST", language: language)
            let event = try XCTUnwrap(events.first { $0.fastingStart != nil })
            for now in [event.fastingStart!.addingTimeInterval(-86400), event.fastingStart!.addingTimeInterval(3600)] {
                let snapshot = WidgetSnapshot.build(occurrences: events, timezone: "IST", locationName: String(repeating: "நகரம் ", count: 4), language: language, now: now)
                let families: [(WidgetFamily, CGFloat, CGFloat)] = [(.systemSmall, 158, 158), (.systemMedium, 338, 158),
                    (.systemLarge, 338, 354), (.accessoryCircular, 62, 62), (.accessoryRectangular, 150, 62)]
                for (family, width, height) in families {
                    try assertFits(EkadashiWidgetView(snapshot: snapshot, now: now, family: family), width: width, height: height,
                                   inset: family == .accessoryCircular || family == .accessoryRectangular ? 0 : 16, label: "\(language) \(family) \(now)")
                    if family == .systemMedium || family == .systemLarge {
                        try assertFits(UpcomingEkadashiWidgetView(snapshot: snapshot, now: now, family: family), width: width, height: height,
                                       inset: 16, label: "upcoming \(language) \(family)")
                    }
                }
            }
        }
    }

    private func assertFits<V: View>(_ content: V, width: CGFloat, height: CGFloat, inset: CGFloat, label: String) throws {
        let margin = 24
        let view = content.padding(inset).frame(width: width, height: height).padding(CGFloat(margin))
            .environment(\.colorScheme, .dark).environment(\.dynamicTypeSize, .large)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.uiImage?.cgImage)
        let pixels = try rgba(image)
        var escaped = 0
        for y in 0..<image.height {
            for x in 0..<image.width where x < margin - 1 || y < margin - 1 || x >= margin + Int(width) + 1 || y >= margin + Int(height) + 1 {
                if pixels[(y * image.width + x) * 4 + 3] > 20 { escaped += 1 }
            }
        }
        XCTAssertEqual(escaped, 0, "Content escapes widget bounds: \(label)")
    }

    private func rgba(_ image: CGImage) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: space,
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))
        }
        return pixels
    }

    private func contains(_ hex: UInt32, in pixels: [UInt8]) -> Bool {
        let expected = [Int(hex >> 16 & 255), Int(hex >> 8 & 255), Int(hex & 255)]
        var matches = 0
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            if (0..<3).allSatisfy({ abs(Int(pixels[offset + $0]) - expected[$0]) <= 3 }) { matches += 1 }
            if matches >= 20 { return true }
        }
        return false
    }
}
