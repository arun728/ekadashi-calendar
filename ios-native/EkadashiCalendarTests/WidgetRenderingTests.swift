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
