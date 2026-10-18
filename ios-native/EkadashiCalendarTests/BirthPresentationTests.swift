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
        let accra = PanchangCity(id: "accra", label: "Accra", latitude: 5.55, longitude: -0.2, timeZoneId: "Africa/Accra")
        XCTAssertEqual(accra.zone.zone(at: date).offsetSeconds, -52)
        XCTAssertTrue(BirthTimeText.offset(date, city: accra, language: "en").contains("−0:00:52"),
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
    func testUnknownTimeResultsRenderForAllLanguagesAndLargeType() throws {
        let input = BirthInput(date: CivilDate(2000, 1, 1), hour: nil, minute: nil, city: .chennai)
        let profile = try BirthProfileStore(store: InMemoryKeyValueStore()).save(input, premium: true)
        let model = AppModel(), originalLanguage = AppModel().language
        defer { model.setLanguage(originalLanguage) }
        for language in Localizer.languages {
            model.setLanguage(language)
            let view = BirthResultsView(profile: profile).frame(width: 360).environment(model).environment(\.dynamicTypeSize, .accessibility1)
            let image = try XCTUnwrap(ImageRenderer(content: view).uiImage)
            XCTAssertGreaterThan(try XCTUnwrap(image.pngData()).count, 1000)
            let shot = XCTAttachment(image: image); shot.name = "birth-results-\(language)-large-type"; shot.lifetime = .keepAlways; add(shot)
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
