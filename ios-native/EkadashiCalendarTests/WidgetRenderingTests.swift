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
    func testPercentageInkHasClearanceFromTheRingInEveryLanguageIncludingOneHundredPercent() throws {
        let events = try CalendarRepository.bundled().ekadashis(timezone: "IST", language: "en")
        let event = try XCTUnwrap(events.first { $0.fastingStart != nil })
        for language in Localizer.languages {
            let snapshot = WidgetSnapshot.build(occurrences: [event], timezone: "IST", locationName: "", language: language, now: event.fastingStart!)
            let item = try XCTUnwrap(snapshot.nextEkadashi)
            for side in [CGFloat(42), 48, 52, 58] {
                for fraction in [0.0, 0.28, 0.99, 1.0] {
                    let now = item.fastingStart.addingTimeInterval(item.paranaStart.timeIntervalSince(item.fastingStart) * fraction)
                    let renderer = ImageRenderer(content: RemainingRing(item: item, snapshot: snapshot, now: now)
                        .frame(width: side, height: side).foregroundStyle(.white).environment(\.colorScheme, .dark))
                    renderer.scale = 3
                    let image = try XCTUnwrap(renderer.uiImage?.cgImage)
                    let pixels = try rgba(image)
                    var textPixels = 0, touching = 0
                    for y in 0..<image.height { for x in 0..<image.width {
                        let i = (y * image.width + x) * 4
                        if pixels[i] > 230 && pixels[i + 1] > 230 && pixels[i + 2] > 230 && pixels[i + 3] > 230 {
                            textPixels += 1
                            if hypot(Double(x) + 0.5 - Double(image.width) / 2, Double(y) + 0.5 - Double(image.height) / 2) > Double(side / 2 - 6) * 3 { touching += 1 }
                        }
                    } }
                    XCTAssertGreaterThan(textPixels, 15)
                    XCTAssertEqual(touching, 0, "Percentage-only ink must stay clear: \(language) \(side) \(item.remainingPercent(at: now))%")
                }
            }
        }
    }

    func testCircularSymbolHasAnEmptyAnnulusBetweenItAndTheProgressRing() throws {
        let events = try CalendarRepository.bundled().ekadashis(timezone: "IST", language: "en")
        let now = try XCTUnwrap(events.first?.fastingStart).addingTimeInterval(3600)
        let snapshot = WidgetSnapshot.build(occurrences: events, timezone: "IST", locationName: "", language: "en", now: now)
        for side in [CGFloat(48), 62, 76] {
            let renderer = ImageRenderer(content: EkadashiWidgetView(snapshot: snapshot, now: now, family: .accessoryCircular)
                .frame(width: side, height: side).environment(\.colorScheme, .dark))
            renderer.scale = 3
            let image = try XCTUnwrap(renderer.uiImage?.cgImage)
            let pixels = try rgba(image)
            let centerX = Double(side / 2) * 3
            let centerY = Double(side * (0.5 - (0.03 + 0.24) / 2)) * 3
            var touching = 0
            for y in 0..<image.height { for x in 0..<image.width {
                let i = (y * image.width + x) * 4
                let radius = hypot(Double(x) + 0.5 - centerX, Double(y) + 0.5 - centerY) / 3
                if radius > Double(side * 0.18) && radius < Double(side * 0.21), pixels[i] > 230 && pixels[i + 1] > 230 && pixels[i + 2] > 230 && pixels[i + 3] > 230 { touching += 1 }
            } }
            XCTAssertEqual(touching, 0, "Reserve space between the symbol and ring at \(side) pt")
        }
    }

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
            let families: [(WidgetFamily, CGFloat, CGFloat)] = [(.systemSmall, 170, 170), (.systemMedium, 350, 165)]
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
            let event = try XCTUnwrap(events.max { $0.name.count < $1.name.count })
            for now in [event.fastingStart!.addingTimeInterval(-86400), event.fastingStart!.addingTimeInterval(3600)] {
                let snapshot = WidgetSnapshot.build(occurrences: events, timezone: "IST", locationName: String(repeating: "நகரம் ", count: 4), language: language, now: now)
                let families: [(WidgetFamily, CGFloat, CGFloat)] = [(.systemSmall, 158, 158), (.systemMedium, 338, 158),
                    (.systemLarge, 338, 354), (.accessoryCircular, 62, 62), (.accessoryRectangular, 150, 62)]
                for (family, width, height) in families {
                    if family != .systemLarge {
                        try assertFits(EkadashiWidgetView(snapshot: snapshot, now: now, family: family), width: width, height: height,
                                       inset: family == .accessoryCircular || family == .accessoryRectangular ? 0 : 16, label: "\(language) \(family) \(now)")
                    }
                    if family == .systemMedium || family == .systemLarge {
                        try assertFits(UpcomingEkadashiWidgetView(snapshot: snapshot, now: now, family: family), width: width, height: height,
                                       inset: 16, label: "upcoming \(language) \(family)")
                    }
                }
            }
        }
    }

    func testLockIconIsBrightWhiteWithoutTheAppIconsOpaqueSquare() throws {
        let renderer = ImageRenderer(content: WidgetBrandIcon().frame(width: 32, height: 32).environment(\.colorScheme, .dark))
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage?.cgImage)
        let pixels = try rgba(image)
        var opaque = 0, white = 0
        for i in stride(from: 0, to: pixels.count, by: 4) where pixels[i + 3] > 240 {
            opaque += 1
            if pixels[i] > 240 && pixels[i + 1] > 240 && pixels[i + 2] > 240 { white += 1 }
        }
        XCTAssertGreaterThan(opaque, 60, "The symbol must be visible")
        XCTAssertGreaterThan(Double(white) / Double(max(opaque, 1)), 0.98, "Use bright monochrome white in both Lock Screen accessories")
        XCTAssertLessThan(opaque, image.width * image.height / 2, "No opaque square app-icon background")
    }

    func testCircularInkStaysInsideTheCircleInEveryLanguageStateAndHostSize() throws {
        let margin: CGFloat = 12
        for language in Localizer.languages {
            let events = try CalendarRepository.bundled().ekadashis(timezone: "IST", language: language)
            let event = try XCTUnwrap(events.first { $0.fastingStart != nil && $0.paranaStart != nil })
            let start = try XCTUnwrap(event.fastingStart)
            for now in [start.addingTimeInterval(-4 * 86400), start.addingTimeInterval(60), start.addingTimeInterval(3600)] {
                let snapshot = WidgetSnapshot.build(occurrences: events, timezone: "IST", locationName: "", language: language, now: now)
                for side in [CGFloat(48), 62, 76] {
                    for textSize in [DynamicTypeSize.large, .xxxLarge] {
                        let renderer = ImageRenderer(content: EkadashiWidgetView(snapshot: snapshot, now: now, family: .accessoryCircular)
                            .frame(width: side, height: side).padding(margin)
                            .environment(\.colorScheme, .dark).environment(\.dynamicTypeSize, textSize))
                        renderer.scale = 2
                        let image = try XCTUnwrap(renderer.uiImage?.cgImage)
                        let pixels = try rgba(image)
                        let center = Double((margin + side / 2) * 2)
                        let radius = Double(side) + 1
                        var escaped = 0, visible = 0
                        for y in 0..<image.height { for x in 0..<image.width {
                            let i = (y * image.width + x) * 4
                            if pixels[i + 3] > 32 {
                                visible += 1
                                if hypot(Double(x) + 0.5 - center, Double(y) + 0.5 - center) > radius { escaped += 1 }
                            }
                        } }
                        XCTAssertGreaterThan(visible, 60)
                        XCTAssertEqual(escaped, 0, "Ink escapes circular slot: \(language) \(side) \(textSize) \(now)")
                        if language == "en" && textSize == .large {
                            let attachment = XCTAttachment(image: try XCTUnwrap(renderer.uiImage))
                            attachment.name = "circle-contained-\(Int(side))-\(now.timeIntervalSince1970)"
                            attachment.lifetime = .keepAlways
                            add(attachment)
                        }
                    }
                }
            }
        }
    }

    func testCompareLockSymbolOptions() throws {
        let options = HStack(spacing: 16) {
            Image("widget_brand_icon").resizable().scaledToFit().frame(width: 30, height: 30)
            Image("widget_brand_icon").resizable().renderingMode(.template).scaledToFit().foregroundStyle(.white).frame(width: 30, height: 30)
            Image(systemName: AppSymbol.tabPanchang).resizable().scaledToFit().foregroundStyle(.white).frame(width: 30, height: 30)
        }.padding(18).background(.black)
        let renderer = ImageRenderer(content: options); renderer.scale = 3
        let attachment = XCTAttachment(image: try XCTUnwrap(renderer.uiImage))
        attachment.name = "lock-icon-options-original-template-panchang"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertFits<V: View>(_ content: V, width: CGFloat, height: CGFloat, inset: CGFloat, label: String) throws {
        let margin = 24
        for textSize in [DynamicTypeSize.large, .xxxLarge] {
            let view = content.padding(inset).frame(width: width, height: height).padding(CGFloat(margin))
                .environment(\.colorScheme, .dark).environment(\.dynamicTypeSize, textSize)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            let image = try XCTUnwrap(renderer.uiImage?.cgImage)
            let pixels = try rgba(image)
            var escaped = 0
            var ink = 0
            for offset in stride(from: 3, to: pixels.count, by: 4) where pixels[offset] > 20 { ink += 1 }
            XCTAssertGreaterThan(ink, 20, "A blank render must not pass the bounds check: \(label)")
            for y in 0..<image.height {
                for x in 0..<image.width where x < margin - 1 || y < margin - 1 || x >= margin + Int(width) + 1 || y >= margin + Int(height) + 1 {
                    if pixels[(y * image.width + x) * 4 + 3] > 20 { escaped += 1 }
                }
            }
            XCTAssertEqual(escaped, 0, "Content escapes widget bounds: \(label) \(textSize)")
        }
    }

    func testMultilingualVisualEvidence() throws {
        for language in Localizer.languages {
            let events = try CalendarRepository.bundled().ekadashis(timezone: "IST", language: language)
            let event = try XCTUnwrap(events.max { $0.name.count < $1.name.count })
            let during = event.fastingStart!.addingTimeInterval(3600)
            let before = during.addingTimeInterval(-86400)
            for scheme in [ColorScheme.dark, .light] {
                let view = VStack(spacing: 16) {
                    ForEach([before, during], id: \.self) { now in
                        let snapshot = WidgetSnapshot.build(occurrences: events, timezone: "IST", locationName: "", language: language, now: now)
                        HStack(spacing: 12) {
                            EkadashiWidgetView(snapshot: snapshot, now: now, family: .systemSmall)
                                .padding(16).frame(width: 158, height: 158).background(WidgetCardBackground())
                            EkadashiWidgetView(snapshot: snapshot, now: now, family: .systemMedium)
                                .padding(16).frame(width: 338, height: 158).background(WidgetCardBackground())
                        }
                        HStack(spacing: 12) {
                            UpcomingEkadashiWidgetView(snapshot: snapshot, now: now, family: .systemMedium)
                                .padding(16).frame(width: 338, height: 158).background(WidgetCardBackground())
                            EkadashiWidgetView(snapshot: snapshot, now: now, family: .accessoryCircular)
                                .frame(width: 62, height: 62)
                            EkadashiWidgetView(snapshot: snapshot, now: now, family: .accessoryRectangular)
                                .frame(width: 150, height: 62)
                        }
                    }
                }
                .padding(20).background(scheme == .dark ? Color.black : Color.white)
                .environment(\.colorScheme, scheme)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                let attachment = XCTAttachment(image: try XCTUnwrap(renderer.uiImage))
                attachment.name = "widgets-\(language)-\(scheme)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    func testRefreshFallbackUsesThePreviewLanguageWithoutASnapshot() throws {
        for language in Localizer.languages {
            let expected = Localizer.shared.translate("open_app_to_refresh", language: language)
            let reference = Text(expected).font(.caption).multilineTextAlignment(.leading)
                .foregroundStyle(.primary).frame(maxWidth: .infinity, maxHeight: .infinity)
            let expectedImage = try renderedPNG(reference, language: language)
            XCTAssertEqual(try renderedPNG(EkadashiWidgetView(snapshot: nil, now: Date()), language: language), expectedImage, language)
            XCTAssertEqual(try renderedPNG(UpcomingEkadashiWidgetView(snapshot: nil, now: Date()), language: language), expectedImage, language)
        }
    }

    private func renderedPNG<V: View>(_ view: V, language: String) throws -> Data {
        let renderer = ImageRenderer(content: view.frame(width: 160, height: 100)
            .environment(\.locale, Localizer.locale(language)).environment(\.colorScheme, .dark))
        renderer.scale = 1
        return try XCTUnwrap(renderer.uiImage?.pngData())
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
