import XCTest
import SwiftUI
import StoreKit
import StoreKitTest
import EkadashiCore
@testable import EkadashiCalendar

/// App-level checks that need UIKit/StoreKit and so run only in Xcode (the
/// domain rules are covered by the EkadashiCore package tests).
@MainActor
final class AppModelTests: XCTestCase {
    /// Read the StoreKit-resolved metadata, not only the JSON text. Initializing
    /// a session refreshes local test metadata without buying, cancelling,
    /// clearing, or otherwise changing the device's existing transactions.
    func testEveryStoreKitPlanResolvesToTheCustomerFacingPremiumName() async throws {
        let configuration = try XCTUnwrap(Bundle.main.url(forResource: "Products", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: configuration)
        let products = try await Product.products(for: PremiumProduct.all)
        XCTAssertEqual(Set(products.map(\.id)), Set(PremiumProduct.all))
        for product in products {
            XCTAssertEqual(product.displayName, "Ekadashi Premium", product.id)
            if let subscription = product.subscription {
                XCTAssertEqual(subscription.groupDisplayName, "Ekadashi Premium", product.id)
            }
        }
        withExtendedLifetime(session) {}
    }

    func testCurrentOccurrenceAdvancesAtParanaEndWithoutMovingBrowsedCards() async throws {
        let model = AppModel(store: InMemoryKeyValueStore(["has_launched": true, "language_code": "en", AppModel.yearKey: "2026"]))
        model.reload(); await model.waitForLoad()
        let event = try XCTUnwrap(model.ekadashis.first { $0.date == CivilDate(2026, 10, 22) })
        let end = try XCTUnwrap(event.paranaEnd)
        model.selectCurrentOccurrence(now: end.addingTimeInterval(-1))
        XCTAssertEqual(model.homeEkadashis[model.homeIndex].occurrenceUid, event.occurrenceUid)
        model.refreshCurrentOccurrence(previousNow: end.addingTimeInterval(-1), now: end)
        XCTAssertNotEqual(model.homeEkadashis[model.homeIndex].occurrenceUid, event.occurrenceUid)
        let nextUID = model.homeEkadashis[model.homeIndex].occurrenceUid
        model.refreshCurrentOccurrence(previousNow: end.addingTimeInterval(-1), now: end)
        XCTAssertEqual(model.homeEkadashis[model.homeIndex].occurrenceUid, nextUID)
        model.homeIndex = 0
        model.refreshCurrentOccurrence(previousNow: end.addingTimeInterval(-1), now: end)
        XCTAssertEqual(model.homeIndex, 0, "Historical browsing stays put")
    }

    func testCurrentSelectionSurvivesTheYearBoundaryUntilParanaEnds() async throws {
        let model = AppModel(store: InMemoryKeyValueStore(["has_launched": true, "language_code": "en"]))
        model.reload(); await model.waitForLoad()
        for event in model.ekadashis where event.date.year == 2026 {
            let end = try XCTUnwrap(event.paranaEnd)
            model.selectCurrentOccurrence(now: end.addingTimeInterval(-1))
            XCTAssertEqual(model.homeEkadashis[model.homeIndex].occurrenceUid, event.occurrenceUid)
            model.refreshCurrentOccurrence(previousNow: end.addingTimeInterval(-1), now: end)
            if let next = model.ekadashis.first(where: { $0.date > event.date }) {
                XCTAssertEqual(model.homeEkadashis[model.homeIndex].occurrenceUid, next.occurrenceUid)
            }
        }
    }

    #if DEBUG
    func testDebugClockIsPausedOrScaledAndNeverUsesTheProductionSnapshotKey() throws {
        defer { WidgetClock.set(nil) }
        let live = ISO8601.instant("2026-10-23T12:00:00Z")!
        let virtual = ISO8601.instant("2026-10-22T00:30:00Z")!
        WidgetClock.set(virtual, rate: 0, live: live)
        XCTAssertEqual(WidgetClock.date(live.addingTimeInterval(3600)), virtual)
        XCTAssertNotEqual(WidgetClock.snapshotKey, WidgetSnapshot.appGroupKey)
        XCTAssertNil(WidgetClock.realDate(for: virtual.addingTimeInterval(600), liveNow: live))
        WidgetClock.set(virtual, rate: 60, live: live)
        XCTAssertEqual(WidgetClock.date(live.addingTimeInterval(10)), virtual.addingTimeInterval(600))
        XCTAssertEqual(WidgetClock.realDate(for: virtual.addingTimeInterval(600), liveNow: live), live.addingTimeInterval(10))
        WidgetClock.set(nil)
        XCTAssertEqual(WidgetClock.date(live), live)
        XCTAssertEqual(WidgetClock.snapshotKey, WidgetSnapshot.appGroupKey)
    }
    #endif

    #if DEBUG
    func testDebugControlsAreTranslatedWithoutReleaseResources() {
        for language in Localizer.languages {
            for key in DebugClockWords.keys {
                let value = DebugClockWords.text(key, language)
                XCTAssertNotEqual(value, key)
                if language != "en" { XCTAssertNil(value.range(of: "[A-Za-z]", options: .regularExpression), "\(language): \(key)") }
            }
        }
    }

    func testInactiveTimelineHasNoTicksAndActiveFastingUsesMinuteCadence() throws {
        WidgetClock.set(nil)
        let start = ISO8601.instant("2026-10-22T00:30:00Z")!
        let event = EkadashiOccurrence(id: 1, name: "", date: CivilDate(2026, 10, 22),
            fastingStartISO: ISO8601.string(start), paranaStartISO: ISO8601.string(start.addingTimeInterval(86400)),
            paranaEndISO: ISO8601.string(start.addingTimeInterval(93600)))
        let zone = TzDatabase.shared.location("Asia/Kolkata")!
        let inactive = OccurrenceTimelineSchedule(events: [event], zone: zone, active: false)
        XCTAssertEqual(Array(inactive.entries(from: start, mode: .normal)), [start])
        let active = OccurrenceTimelineSchedule(events: [event], zone: zone, active: true)
        XCTAssertEqual(Array(active.entries(from: start, mode: .normal).prefix(3)),
            [start, start.addingTimeInterval(60), start.addingTimeInterval(120)])
        XCTAssertEqual(Array(active.entries(from: start.addingTimeInterval(-2), mode: .normal).prefix(3)),
            [start.addingTimeInterval(-2), start.addingTimeInterval(-1), start])
    }

    #endif

    func testGlassLookIsOffByDefaultAndPersistedIndependentlyOfOtherSettings() {
        for seed: [String: Any] in [[:], [AppModel.glassLookKey: "invalid"]] {
            XCTAssertFalse(AppModel(store: InMemoryKeyValueStore(seed)).isGlassLookEnabled)
        }
        let store = InMemoryKeyValueStore(["language_code": "ta", "is_dark_mode": false,
            AppModel.traditionKey: "smarta", "has_launched": true])
        let model = AppModel(store: store)
        XCTAssertFalse(model.isGlassLookEnabled)
        let city = model.ekadashiCity, year = model.selectedYear
        model.setGlassLook(true)
        XCTAssertTrue(model.isGlassLookEnabled)
        XCTAssertEqual(store.bool(forKey: AppModel.glassLookKey), true)
        XCTAssertTrue(AppModel(store: store).isGlassLookEnabled, "Survives a fresh app model")
        XCTAssertEqual(model.language, "ta")
        XCTAssertFalse(model.isDarkMode)
        XCTAssertEqual(model.tradition, .smarta)
        XCTAssertEqual(model.ekadashiCity, city)
        XCTAssertEqual(model.selectedYear, year)
        model.setDarkMode(true)
        XCTAssertTrue(model.isGlassLookEnabled, "Dark Mode is independent")
        model.setGlassLook(false)
        XCTAssertFalse(AppModel(store: store).isGlassLookEnabled, "Explicit Off survives relaunch too")
        XCTAssertTrue(model.isDarkMode)
    }

    func testGlassLookDefaultsOffInTheEnvironment() {
        XCTAssertFalse(EnvironmentValues().glassLookEnabled)
        XCTAssertFalse(GlassLookPolicy.isActive(preference: false, reduceTransparency: false))
        XCTAssertFalse(GlassLookPolicy.isActive(preference: false, reduceTransparency: true))
        XCTAssertFalse(GlassLookPolicy.isActive(preference: true, reduceTransparency: true))
        XCTAssertTrue(GlassLookPolicy.isActive(preference: true, reduceTransparency: false))
    }

    func testBlockedRecordingExplainsParanaForTodayAndUpcomingInEveryLanguageAndTradition() async throws {
        let model = AppModel()
        let originalLanguage = model.language, originalTradition = model.tradition
        defer { model.setLanguage(originalLanguage); model.setTradition(originalTradition) }
        let now = ISO8601.instant("2026-10-22T07:15:00Z")!
        for language in Localizer.languages {
            model.setLanguage(language)
            for tradition in EkadashiTradition.allCases {
                model.setTradition(tradition)
                await model.waitForLoad()
                for event in model.ekadashis.filter({ $0.date >= CivilDate(2026, 10, 22) }) {
                    model.toast = nil
                    XCTAssertFalse(model.requestVratRecording(event, now: now), "\(language) \(tradition) \(event.date)")
                    XCTAssertEqual(model.toast?.text, model.t("journey_record_after_parana"))
                    model.toast = nil
                    let parana = try XCTUnwrap(event.paranaStart)
                    XCTAssertTrue(model.requestVratRecording(event, now: parana), "Opens at Parana, not earlier")
                    XCTAssertNil(model.toast)
                    XCTAssertFalse(model.requestVratRecording(event, now: parana.addingTimeInterval(-1)))
                }
            }
        }
    }

    func testHomeTraditionOrderIsVaishnavaThenSmarta() {
        XCTAssertEqual(HomeControls.traditions, [.gaudiya, .smarta])
    }

    func testVaishnavaIsTheDefaultForMissingOrInvalidTraditionAndSavedChoicesSurvive() {
        let store = AppModel().store
        let original = store.string(forKey: AppModel.traditionKey)
        defer { if let original { store.set(original, forKey: AppModel.traditionKey) } else { store.remove(AppModel.traditionKey) } }
        store.remove(AppModel.traditionKey)
        XCTAssertEqual(AppModel().tradition, .gaudiya)
        store.set("invalid", forKey: AppModel.traditionKey)
        XCTAssertEqual(AppModel().tradition, .gaudiya)
        for tradition in EkadashiTradition.allCases {
            store.set(tradition.rawValue, forKey: AppModel.traditionKey)
            XCTAssertEqual(AppModel().tradition, tradition)
        }
    }

    func testDisplayClockCanOnlyBePinnedByAnExplicitDebugUITest() {
        let live = ISO8601.instant("2026-10-24T00:00:00Z")!
        let pinned = ISO8601.instant("2026-10-22T07:15:00Z")!
        let environment = ["EKADASHI_UI_TEST_NOW": "2026-10-22T07:15:00Z"]
        XCTAssertEqual(DisplayClock.date(live, arguments: [], environment: environment), live)
        XCTAssertEqual(DisplayClock.date(live, arguments: ["-ui-testing"], environment: [:]), live)
        XCTAssertEqual(DisplayClock.date(live, arguments: ["-ui-testing"], environment: ["EKADASHI_UI_TEST_NOW": "invalid"]), live)
        #if DEBUG
        XCTAssertEqual(DisplayClock.date(live, arguments: ["-ui-testing"], environment: environment), pinned)
        #else
        XCTAssertEqual(DisplayClock.date(live, arguments: ["-ui-testing"], environment: environment), live)
        #endif
    }

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

    func testWidgetDeepLinkSelectsExactHomeCardAcrossYearsWithoutDetailsSheet() async throws {
        let model = AppModel()
        model.reload()
        await model.waitForLoad()
        let originalYear = model.selectedYear
        defer { model.setYear(originalYear) }
        for year in model.enabledYears {
            let events = model.ekadashis.filter { $0.date.year == year }
            for event in [try XCTUnwrap(events.first), try XCTUnwrap(events.last)] {
                model.selectedTab = .settings
                model.open(AppRoute.ekadashiURL(event.occurrenceUid))
                XCTAssertEqual(model.selectedTab, .today)
                XCTAssertEqual(model.selectedYear, year)
                XCTAssertEqual(model.homeEkadashis[model.homeIndex].occurrenceUid, event.occurrenceUid)
            }
        }
        let index = model.homeIndex
        model.open(AppRoute.ekadashiURL("missing-occurrence"))
        XCTAssertEqual(model.homeIndex, index)
    }

    func testColdWidgetLinkWaitsForTheRealSchedule() async throws {
        let model = AppModel()
        model.reload()
        await model.waitForLoad()
        let event = try XCTUnwrap(model.ekadashis.last)
        let cold = AppModel()
        let originalYear = cold.selectedYear
        defer { cold.setYear(originalYear) }
        cold.open(AppRoute.ekadashiURL(event.occurrenceUid))
        cold.reload()
        await cold.waitForLoad()
        XCTAssertEqual(cold.selectedTab, .today)
        XCTAssertEqual(cold.selectedYear, event.date.year)
        XCTAssertEqual(cold.homeEkadashis[cold.homeIndex].occurrenceUid, event.occurrenceUid)
    }

    func testLaunchLocationRefreshPreservesTheWidgetOccurrence() async throws {
        let model = AppModel()
        let originalYear = model.selectedYear
        defer { model.setYear(originalYear) }
        model.reload()
        await model.waitForLoad()
        let event = try XCTUnwrap(model.ekadashis.last)
        model.open(AppRoute.ekadashiURL(event.occurrenceUid))
        await model.handleLocation(atLaunch: true)
        await model.waitForLoad()
        XCTAssertEqual(model.selectedYear, event.date.year)
        XCTAssertEqual(model.homeEkadashis[model.homeIndex].occurrenceUid, event.occurrenceUid)
        model.open(.tab(.today))
        XCTAssertNotEqual(model.homeEkadashis[model.homeIndex].occurrenceUid, event.occurrenceUid,
                          "An explicit Home action can still select the current/next fast")
    }

    /// Home's tradition and year menus drive the Ekadashis everywhere; a city
    /// chosen on Home also becomes the Panchang location.
    func testHomeCityTraditionAndYearApplyAcrossTheApp() async {
        let model = AppModel()
        let city = model.ekadashiCity, manual = model.ekadashiCityIsManual
        let language = model.language
        let tradition = model.tradition, year = model.selectedYear, panchang = model.panchangCity
        defer {
            // The tests share the app's settings; put them back.
            model.setTradition(tradition)
            model.setYear(year)
            if manual { model.chooseEkadashiCity(city) }
            model.savePanchangCity(panchang)
            model.setLanguage(language)
        }
        // These assertions deliberately check English display strings.
        model.setLanguage("en")
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

        model.setYear(2026)
        model.setYear(2027)
        XCTAssertTrue(model.homeEkadashis.allSatisfy { $0.date.year == 2027 })
        XCTAssertEqual(model.calendarFocus?.year, 2027)
        model.calendarShowsYear(2026)
        XCTAssertEqual(model.selectedYear, 2026)
    }
}
