import XCTest
import EkadashiCore
@testable import EkadashiCalendar

/// App-level checks that need UIKit/StoreKit and so run only in Xcode (the
/// domain rules are covered by the EkadashiCore package tests).
@MainActor
final class AppModelTests: XCTestCase {
    func testBundledScheduleLoadsInEveryLanguage() {
        let model = AppModel()
        let original = model.language
        model.reload()
        XCTAssertFalse(model.ekadashis.isEmpty, original)
        for language in Localizer.languages where language != original {
            model.setLanguage(language)
            XCTAssertEqual(model.language, language)
            XCTAssertFalse(model.ekadashis.isEmpty, language)
            XCTAssertNil(model.loadError)
        }
        // The tests share the app's settings; leave the language as it was.
        model.setLanguage(original)
    }

    func testDeepLinksSelectTabsAndSearch() {
        let model = AppModel()
        model.reload()
        model.open(URL(string: "ekadashi://panchang")!)
        XCTAssertEqual(model.selectedTab, .panchang)
        model.open(URL(string: "ekadashi://more")!)
        XCTAssertEqual(model.selectedTab, .panchang)
        model.open(URL(string: "ekadashi://vrat")!)
        XCTAssertEqual(model.selectedTab, .vrat)
        model.open(URL(string: "ekadashi://calendar?date=2027-01-14")!)
        XCTAssertEqual(model.selectedTab, .calendar)
        XCTAssertEqual(model.calendarFocus, CivilDate(2027, 1, 14))
        model.open(URL(string: "ekadashi://search")!)
        XCTAssertTrue(model.showSearch)
    }

    func testPremiumIsNeverGrantedFromStoredFlags() {
        UserDefaults.standard.set(true, forKey: "is_premium")
        UserDefaults.standard.set(true, forKey: "premium_lifetime")
        let model = AppModel()
        XCTAssertFalse(model.premium.isPremium, "premium comes only from verified StoreKit entitlements")
    }

    func testWidgetSnapshotReflectsTheSchedule() {
        let model = AppModel()
        model.reload()
        let snapshot = WidgetSnapshot.build(occurrences: model.ekadashis, timezone: model.timezone.rawValue,
                                            locationName: "Test", language: "en", now: Date())
        XCTAssertEqual(snapshot.timeZone, model.timezone.ianaIdentifier)
        XCTAssertFalse(snapshot.strings.isEmpty)
    }
}
