import XCTest
import SwiftUI
@testable import EkadashiCalendar
import EkadashiCore

@MainActor
final class BirthPresentationTests: XCTestCase {
    func testBirthplaceTimeLabelsUseHistoricalSecondsAndEveryLanguage() throws {
        let date = ISO8601.instant("1900-01-01T06:38:50Z")!
        let city = PanchangCity.chennai
        XCTAssertTrue(BirthTimeText.offset(date, city: city, language: "en").contains("21:10"))
        // Exercise a sub-minute signed offset directly: the bundled slim
        // timezone database merges some pre-1970 regional histories.
        XCTAssertTrue(BirthTimeText.offset(seconds: -52, language: "en").contains("−0:00:52"),
                      "Negative historical offsets shorter than a minute must keep their sign and seconds unit")
        let values = BirthCalculator.values(at: date)
        for language in Localizer.languages {
            for key in ["rashi", "nakshatra", "pada", "tithi"] {
                let text = BirthTimeText.value(values, key: key, language: language)
                XCTAssertFalse(text.isEmpty)
                if language != "en" { XCTAssertNil(text.range(of: "[A-Za-z]", options: .regularExpression), "\(language) \(text)") }
            }
        }
    }
    func testUnknownTimeResultsRenderForAllLanguagesAndLargeType() async throws {
        let input = BirthInput(date: CivilDate(2000, 1, 1), hour: nil, minute: nil, city: .chennai)
        let profile = try BirthProfileStore(store: InMemoryKeyValueStore()).save(input, premium: true)
        let model = AppModel(), originalLanguage = AppModel().language
        defer { model.setLanguage(originalLanguage) }
        for language in Localizer.languages {
            model.setLanguage(language)
            try await captureResults(profile, model: model, prefix: "birth-unknown-\(language)-large-type", large: true)
        }
        model.setLanguage("en")
        try await captureResults(profile, model: model, prefix: "birth-unknown", large: false)
    }
    func testExactResultsRenderAllFourBirthValues() async throws {
        let model = AppModel(), language = AppModel().language
        model.setLanguage("en")
        defer { model.setLanguage(language) }
        let input = BirthInput(date: CivilDate(2000, 1, 1), hour: 12, minute: 0, city: .chennai)
        let profile = try BirthProfileStore(store: InMemoryKeyValueStore()).save(input, premium: true)
        try await captureResults(profile, model: model, prefix: "birth-exact", large: false)
    }
    private func captureResults(_ profile: SavedBirthProfile, model: AppModel, prefix: String, large: Bool) async throws {
        // Material/vibrancy text must be captured from a real window.
        // ImageRenderer omits primary/secondary labels inside glass panels.
        let root = ScrollView { BirthResultsView(profile: profile).padding(16) }
            .background(Color.black).environment(model)
            .environment(\.colorScheme, .dark).environment(\.dynamicTypeSize, large ? .accessibility1 : .large)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = UIHostingController(rootView: root); window.makeKeyAndVisible()
        defer { window.isHidden = true }
        try await Task.sleep(for: .milliseconds(350))
        func scrollView(_ view: UIView) -> UIScrollView? {
            if let scroll = view as? UIScrollView { return scroll }
            return view.subviews.lazy.compactMap { scrollView($0) }.first
        }
        let scroll = try XCTUnwrap(scrollView(window))
        for (name, fraction) in [("top", 0.0), ("middle", 0.5), ("bottom", 1.0)] {
            scroll.setContentOffset(CGPoint(x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height) * fraction), animated: false)
            try await Task.sleep(for: .milliseconds(150))
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
            let pixels = try XCTUnwrap(image.cgImage?.dataProvider?.data) as Data
            XCTAssertGreaterThan(Set(pixels).count, 20)
            let shot = XCTAttachment(image: image); shot.name = "\(prefix)-\(name)"; shot.lifetime = .keepAlways; add(shot)
        }
    }
    func testRepeatedTimeEditorRendersBothHistoricalChoices() async throws {
        let model = AppModel(), language = AppModel().language
        model.setLanguage("en")
        defer { model.setLanguage(language) }
        let input = BirthInput(date: CivilDate(2024, 11, 3), hour: 1, minute: 30, city: .newYork)
        let root = BirthProfileEditor(input: input, repository: BirthProfileStore(store: InMemoryKeyValueStore()), saved: { _ in }).environment(model)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = UIHostingController(rootView: root); window.makeKeyAndVisible()
        defer { window.isHidden = true }
        try await Task.sleep(for: .seconds(1))
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
        let pixels = try XCTUnwrap(image.cgImage?.dataProvider?.data) as Data
        XCTAssertGreaterThan(Set(pixels).count, 20, "The editor screenshot must contain visible UI, not an empty window")
        let shot = XCTAttachment(image: image); shot.name = "birth-repeated-clock-time"; shot.lifetime = .keepAlways; add(shot)
        XCTAssertEqual(try BirthCalculator.candidates(input).count, 2)
    }
}
