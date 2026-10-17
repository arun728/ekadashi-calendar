import XCTest
import EkadashiCore
@testable import EkadashiCalendar

/// App-level checks that need UIKit/StoreKit and so run only in Xcode (the
/// domain rules are covered by the EkadashiCore package tests).
@MainActor
final class AppModelTests: XCTestCase {
    func testBundledScheduleLoadsInEveryLanguage() async {
        let model = AppModel()
        let original = model.language
        model.reload()
        await model.waitForLoad()
        XCTAssertFalse(model.ekadashis.isEmpty, original)
        for language in Localizer.languages where language != original {
            model.setLanguage(language)
            await model.waitForLoad()
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

    func testScreensOpenedFromSearchGoBackToIt() {
        let model = AppModel()
        model.reload()
        let session = SearchSession(query: "settings", category: nil, year: nil)
        model.open(.search)
        model.open(.tab(.settings), from: session)
        XCTAssertFalse(model.showSearch)
        XCTAssertEqual(model.selectedTab, .settings)
        XCTAssertTrue(model.searchReturn.showsBack(on: .settings))
        model.returnToSearch()
        XCTAssertTrue(model.showSearch)
        XCTAssertEqual(model.restoredSearch, session)
        XCTAssertFalse(model.searchReturn.showsBack(on: .settings))

        model.open(.calendar(CivilDate(2027, 1, 14)), from: session)
        XCTAssertTrue(model.searchReturn.showsBack(on: .calendar))
        model.select(.today)
        XCTAssertFalse(model.searchReturn.showsBack(on: .calendar), "another tab forgets the way back")
        // A deep link is not a search result.
        model.open(.tab(.settings), from: session)
        model.open(URL(string: "ekadashi://vrat")!)
        XCTAssertFalse(AppTab.allCases.contains { model.searchReturn.showsBack(on: $0) })
    }

    func testPremiumIsNeverGrantedFromStoredFlags() {
        UserDefaults.standard.set(true, forKey: "is_premium")
        UserDefaults.standard.set(true, forKey: "premium_lifetime")
        let model = AppModel()
        XCTAssertFalse(model.premium.isPremium, "premium comes only from verified StoreKit entitlements")
    }

    func testWidgetSnapshotReflectsTheSchedule() async {
        let model = AppModel()
        model.reload()
        await model.waitForLoad()
        let snapshot = WidgetSnapshot.build(occurrences: model.ekadashis, timezone: model.ekadashiCity.timeZoneId,
                                            locationName: "Test", language: "en", now: Date())
        XCTAssertEqual(snapshot.timeZone, model.ekadashiCity.timeZoneId)
        XCTAssertFalse(snapshot.strings.isEmpty)
    }

    func testWidgetDeepLinkOpensTheExactOccurrenceInsteadOfTodaysHomeCard() async throws {
        let model = AppModel()
        model.reload()
        await model.waitForLoad()
        let event = try XCTUnwrap(model.ekadashis.first)
        model.open(AppRoute.ekadashiURL(event.occurrenceUid))
        XCTAssertEqual(model.widgetEvent?.occurrenceUid, event.occurrenceUid)
        XCTAssertEqual(model.widgetEvent?.date, event.date)
        XCTAssertEqual(model.widgetEvent?.fastingStart, event.fastingStart)
        model.widgetEvent = nil
        model.open(AppRoute.ekadashiURL("missing-occurrence"))
        XCTAssertNil(model.widgetEvent)
    }

    func testColdWidgetLinkWaitsForTheRealSchedule() async throws {
        let model = AppModel()
        model.reload()
        await model.waitForLoad()
        let event = try XCTUnwrap(model.ekadashis.last)
        let cold = AppModel()
        cold.open(AppRoute.ekadashiURL(event.occurrenceUid))
        cold.reload()
        await cold.waitForLoad()
        XCTAssertEqual(cold.widgetEvent?.occurrenceUid, event.occurrenceUid)
    }

    /// Home's tradition and year menus drive the Ekadashis everywhere; a city
    /// chosen on Home also becomes the Panchang location.
    func testHomeCityTraditionAndYearApplyAcrossTheApp() async {
        let model = AppModel()
        let city = model.ekadashiCity, manual = model.ekadashiCityIsManual
        let tradition = model.tradition, year = model.selectedYear, panchang = model.panchangCity
        defer {
            // The tests share the app's settings; put them back.
            model.setTradition(tradition)
            model.setYear(year)
            if manual { model.chooseEkadashiCity(city) }
            model.savePanchangCity(panchang)
        }
        XCTAssertEqual(model.enabledYears, [2026, 2027])
        XCTAssertEqual(AppModel.defaultCity.label, "Chennai (IN)")

        model.chooseEkadashiCity(AppModel.defaultCity)
        await model.waitForLoad()
        XCTAssertTrue(model.ekadashiCityIsManual)
        XCTAssertEqual(model.panchangCity, AppModel.defaultCity)

        model.setTradition(.smarta)
        await model.waitForLoad()
        XCTAssertTrue(model.ekadashis.contains { $0.date == CivilDate(2026, 7, 10) })
        model.setTradition(.gaudiya)
        await model.waitForLoad()
        XCTAssertTrue(model.ekadashis.contains { $0.date == CivilDate(2026, 7, 11) }, "Vaishnava Yogini is a day later")

        // Switching tradition stays on the Ekadashi on screen, both ways.
        model.homeIndex = min(5, model.homeEkadashis.count - 1)
        let shown = model.homeEkadashis[model.homeIndex].occurrenceUid
        model.setTradition(.smarta)
        await model.waitForLoad()
        XCTAssertEqual(model.homeEkadashis[model.homeIndex].occurrenceUid, shown)
        model.setTradition(.gaudiya)
        await model.waitForLoad()
        XCTAssertEqual(model.homeEkadashis[model.homeIndex].occurrenceUid, shown)
        XCTAssertEqual(model.traditionName(.gaudiya), "Vaishnava")

        // A city chosen on Home is offered first next time and moves Panchang.
        let revision = model.panchangCityRevision
        model.chooseEkadashiCity(AppModel.defaultCity)
        XCTAssertGreaterThan(model.panchangCityRevision, revision)
        XCTAssertEqual(RecentCities(store: model.store).all().first, AppModel.defaultCity)
        XCTAssertEqual(model.ekadashiCityName, "Chennai (IN)", "city and country code, no time zone")

        model.setYear(2027)
        XCTAssertTrue(model.homeEkadashis.allSatisfy { $0.date.year == 2027 })
        XCTAssertEqual(model.calendarFocus?.year, 2027)
        model.calendarShowsYear(2026)
        XCTAssertEqual(model.selectedYear, 2026)
    }
}
