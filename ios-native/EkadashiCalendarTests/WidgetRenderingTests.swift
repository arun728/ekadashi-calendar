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
    func testCityRowSurfacesAndDefaultToastRenderAcrossGlassModes() throws {
        for enabled in [false, true] {
            let row = CityPickerRowSurface().frame(width: 300, height: 48)
                .environment(\.glassLookEnabled, enabled)
            XCTAssertNotNil(ImageRenderer(content: row).uiImage)
            let overlay = ToastOverlay(message: .constant(ToastMessage(text: "Feedback")))
            let view = Color.clear.frame(width: 390, height: 400).modifier(overlay)
                .environment(\.glassLookEnabled, enabled)
            XCTAssertNotNil(ImageRenderer(content: view).uiImage)
        }
    }

    func testEditorAndGooglePickerToolbarsRenderInBothGlassModes() async throws {
        let model = AppModel(store: InMemoryKeyValueStore(["has_launched": true, "language_code": "en"]))
        model.reload(); await model.waitForLoad()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.keyWindow
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        defer { window.isHidden = true; previous?.makeKeyAndVisible() }
        let request = GooglePickerRequest(calendars: [GoogleCalendarInfo(id: "test-primary", summary: "Test calendar", primary: true)], saved: [], email: nil)
        let views: [(String, AnyView)] = [
            ("google-picker", AnyView(GoogleCalendarPickerView(request: request))),
            ("entry-editor", AnyView(EntryEditorView(request: EntryEditorRequest(day: CivilDate(2026, 10, 26), existing: nil)))),
            ("reminder-editor", AnyView(NavigationStack { EventReminderEditor(original: nil) }))
        ]
        for enabled in [false, true] {
            for (name, view) in views {
                let host = UIHostingController(rootView: view.environment(model).environment(\.glassLookEnabled, enabled))
                window.rootViewController = host
                window.makeKeyAndVisible()
                host.view.setNeedsLayout(); host.view.layoutIfNeeded()
                try await Task.sleep(for: .milliseconds(250))
                host.view.layoutIfNeeded()
                func navigationBars(_ view: UIView) -> [UINavigationBar] {
                    (view as? UINavigationBar).map { [$0] } ?? view.subviews.flatMap(navigationBars)
                }
                let bar = try XCTUnwrap(navigationBars(host.view).first, "\(name) must have its navigation toolbar")
                XCTAssertGreaterThanOrEqual(bar.frame.height, 44)
                let image = UIGraphicsImageRenderer(bounds: host.view.bounds).image { _ in
                    host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
                }
                let attachment = XCTAttachment(image: image)
                attachment.name = "\(name)-toolbar-glass-\(enabled)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    func testAllLifecycleStatesFitEveryWidgetFamilyAndLargeHomeTextInEveryLanguage() throws {
        let repository = try CalendarRepository.bundled()
        for language in Localizer.languages {
            let events = repository.ekadashis(timezone: "IST", language: language)
            let event = try XCTUnwrap(events.first { $0.fastingStart != nil })
            for now in [event.fastingStart!.addingTimeInterval(-1), event.fastingStart!,
                        event.paranaStart!, event.paranaEnd!.addingTimeInterval(-1)] {
                let snapshot = WidgetSnapshot.build(occurrences: events, timezone: "IST", locationName: "", language: language, now: now)
                for (family, width, height) in [(WidgetFamily.systemSmall, 158.0, 158.0), (.systemMedium, 320.0, 158.0),
                                               (.accessoryCircular, 62.0, 62.0), (.accessoryRectangular, 160.0, 62.0)] {
                    try assertFits(EkadashiWidgetView(snapshot: snapshot, now: now, family: family), width: width, height: height,
                        inset: 0, label: "Lifecycle \(language) \(family) \(now)")
                }
                try assertFits(EkadashiStatusHeader(event: event, timeZone: "Asia/Kolkata", language: language, now: now)
                    .environment(\.dynamicTypeSize, .accessibility3), width: 220, height: 100,
                    inset: 0, label: "Status \(language)")
            }
        }
    }

    func testActionButtonDimensionsAreIdenticalAcrossGlassModes() throws {
        for scheme in [ColorScheme.dark, .light] {
            for size in [DynamicTypeSize.large, .accessibility2] {
                func image(_ enabled: Bool) throws -> UIImage {
                    let view = HStack(spacing: 8) {
                        Button("View Details") {}.primaryActionStyle()
                        Button("Share") {}.secondaryActionStyle()
                    }.padding(24).environment(\.glassLookEnabled, enabled)
                        .environment(\.colorScheme, scheme).environment(\.dynamicTypeSize, size)
                    return try XCTUnwrap(ImageRenderer(content: view).uiImage)
                }
                XCTAssertEqual(try image(false).size, try image(true).size)
            }
        }
    }

    func testGlassOffPreservesTheOriginalPanelAndCapsuleInBothAppearances() throws {
        for scheme in [ColorScheme.dark, .light] {
            let current = glassProbe(scheme: scheme, enabled: false, reduced: false, legacy: false)
            let legacy = glassProbe(scheme: scheme, enabled: false, reduced: false, legacy: true)
            XCTAssertTrue(try glassPixels(current) == glassPixels(legacy), "Off must retain the existing renderer: \(scheme)")
        }
    }

    func testGlassOnChangesTheSurfaceAndRespectsReduceTransparencyInBothAppearances() throws {
        for scheme in [ColorScheme.dark, .light] {
            let off = try glassPixels(glassProbe(scheme: scheme, enabled: false, reduced: false, legacy: false))
            let on = try glassPixels(glassProbe(scheme: scheme, enabled: true, reduced: false, legacy: false))
            XCTAssertTrue(off != on, "Opt-in look has a distinct surface")
            let reduced = try glassPixels(glassProbe(scheme: scheme, enabled: true, reduced: true, legacy: false))
            let systemReduced = try glassPixels(glassProbe(scheme: scheme, enabled: false, reduced: true, legacy: false))
            XCTAssertTrue(reduced == systemReduced, "Never override reduced transparency")
        }
    }

    func testGlassAppearanceEvidenceInEveryLanguageAndBothColorSchemes() throws {
        for language in Localizer.languages {
            for scheme in [ColorScheme.dark, .light] {
                for enabled in [false, true] {
                    let view = VStack(spacing: 18) {
                        Text(Localizer.shared.translate("ios_glass_look", language: language)).font(.title3.bold())
                        Text(Localizer.shared.translate("ios_glass_look_desc", language: language))
                            .font(.body).fixedSize(horizontal: false, vertical: true)
                        Text(Localizer.shared.translate("view_details", language: language)).padding(16).glassCapsule()
                    }.padding(20).frame(width: 320).glassPanel(cornerRadius: 24)
                        .padding(20).background(AppBackground()).environment(\.colorScheme, scheme)
                        .environment(\.glassLookEnabled, enabled)
                    let renderer = ImageRenderer(content: view)
                    renderer.scale = 2
                    let image = try XCTUnwrap(renderer.uiImage)
                    XCTAssertLessThan(image.size.height, 440, "\(language)")
                    let attachment = XCTAttachment(image: image)
                    attachment.name = "glass-surface-\(language)-\(scheme)-\(enabled ? "on" : "off")"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
        }
    }

    private func glassProbe(scheme: ColorScheme, enabled: Bool, reduced: Bool, legacy: Bool) -> some View {
        VStack(spacing: 10) {
            if legacy {
                // Frozen pre-feature rendering contract from Glass.swift.
                if #available(iOS 26.0, *) {
                    Text("Card").padding(20).glassEffect(.regular, in: .rect(cornerRadius: 22))
                    Text("Control").padding(12).glassEffect(.regular.interactive(), in: .capsule)
                } else {
                    Text("Card").padding(20).background(Color.clear.opacity(0.16), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 0.7))
                    Text("Control").padding(12).background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.7))
                        .background(Color.clear.opacity(0.25), in: Capsule())
                }
            } else {
                Text("Card").padding(20).glassPanel()
                Text("Control").padding(12).glassCapsule()
            }
        }.padding(20).frame(width: 250, height: 210).background(AppBackground())
            .environment(\.colorScheme, scheme)
            .environment(\.glassLookEnabled, GlassLookPolicy.isActive(preference: enabled, reduceTransparency: reduced))
    }

    private func glassPixels<V: View>(_ view: V) throws -> [UInt8] {
        let renderer = ImageRenderer(content: view); renderer.scale = 2
        return try rgba(XCTUnwrap(renderer.uiImage?.cgImage))
    }

    func testTodayMediumLocationIsSeparatedFromTimingInkInEveryLanguage() throws {
        for language in Localizer.languages {
            let events = try CalendarRepository.bundled().ekadashis(timezone: "IST", language: language)
            let event = try XCTUnwrap(events.first { $0.fastingStart != nil })
            let now = event.fastingStart!.addingTimeInterval(3600)
            let snapshot = WidgetSnapshot.build(occurrences: [event], timezone: "IST", locationName: "Chennai", language: language, now: now, tradition: "smarta")
            let renderer = ImageRenderer(content: EkadashiWidgetView(snapshot: snapshot, now: now, family: .systemMedium)
                .padding(16).frame(width: 350, height: 170).environment(\.colorScheme, .dark))
            renderer.scale = 3
            let image = try XCTUnwrap(renderer.uiImage?.cgImage)
            let pixels = try rgba(image)
            var bands: [ClosedRange<Int>] = []
            for y in 0..<image.height {
                let ink = (0..<image.width).contains { x in
                    let i = (y * image.width + x) * 4
                    // System secondary text has a slight cool tint; include it
                    // along with primary ink, but exclude the teal ring/labels.
                    return pixels[i + 3] > 90 && abs(Int(pixels[i]) - Int(pixels[i + 1])) < 16 && abs(Int(pixels[i + 1]) - Int(pixels[i + 2])) < 16
                }
                if ink {
                    if let last = bands.last, last.upperBound == y - 1 { bands[bands.count - 1] = last.lowerBound...y }
                    else { bands.append(y...y) }
                }
            }
            XCTAssertGreaterThanOrEqual(bands.count, 2)
            let footer = try XCTUnwrap(bands.last)
            let time = bands[bands.count - 2]
            XCTAssertGreaterThanOrEqual(Double(footer.lowerBound - time.upperBound - 1) / 3, 8, language)
        }
    }

    func testHomeHeaderProgressUsesTheViewedOccurrenceAndHomeCivilDateInEveryLanguage() throws {
        for language in Localizer.languages {
            let event = EkadashiOccurrence(id: 20, occurrenceUid: "ekadashi:2026:20",
                name: "", date: CivilDate(2026, 10, 22), fastingStartISO: "2026-10-22T06:00:00+05:30",
                paranaStartISO: "2026-10-23T06:00:00+05:30", paranaEndISO: "2026-10-23T08:21:00+05:30")
            let cases = [("2026-10-21T17:00:00Z", "Asia/Kolkata", false),
                         ("2026-10-21T23:30:00Z", "Asia/Kolkata", false),
                         ("2026-10-21T23:30:00Z", "UTC", false),
                         ("2026-10-22T07:15:00Z", "Asia/Kolkata", true),
                         ("2026-10-22T19:00:00Z", "Asia/Kolkata", true)]
            for (date, zone, hasProgress) in cases {
                let now = ISO8601.instant(date)!
                let header = EkadashiStatusHeader(event: event, timeZone: zone, language: language, now: now)
                try assertFits(header, width: 220, height: 96, inset: 0, label: "Home status \(language) \(date) \(zone)")
                let renderer = ImageRenderer(content: header.frame(width: 220, height: 96, alignment: .topLeading).environment(\.colorScheme, .dark))
                renderer.scale = 1
                let image = try XCTUnwrap(renderer.uiImage?.cgImage)
                let pixels = try rgba(image)
                var leadingTeal = 0
                for y in 0..<image.height { for x in 0..<52 {
                    let i = (y * image.width + x) * 4
                    if pixels[i] < 5 && abs(Int(pixels[i + 1]) - 161) < 5 && abs(Int(pixels[i + 2]) - 155) < 5 && pixels[i + 3] > 200 { leadingTeal += 1 }
                } }
                XCTAssertEqual(leadingTeal > 20, hasProgress, "Only today's viewed occurrence gets a leading ring: \(language) \(date) \(zone)")
            }
        }
    }

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
            var outside: [(Int, Int)] = []
            var ink = 0
            for offset in stride(from: 3, to: pixels.count, by: 4) where pixels[offset] > 20 { ink += 1 }
            XCTAssertGreaterThan(ink, 20, "A blank render must not pass the bounds check: \(label)")
            for y in 0..<image.height {
                for x in 0..<image.width where x < margin - 1 || y < margin - 1 || x >= margin + Int(width) + 1 || y >= margin + Int(height) + 1 {
                    if pixels[(y * image.width + x) * 4 + 3] > 20 { escaped += 1; outside.append((x, y)) }
                }
            }
            if escaped > 0 {
                let attachment = XCTAttachment(image: UIImage(cgImage: image))
                attachment.name = "overflow-\(label)-\(textSize)"; attachment.lifetime = .keepAlways; add(attachment)
            }
            XCTAssertEqual(escaped, 0, "Content escapes widget bounds: \(label) \(textSize), pixels \(outside.prefix(12))")
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
