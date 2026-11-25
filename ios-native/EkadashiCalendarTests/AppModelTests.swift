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
    func testPremiumLegalLinksUseApptinelPages() {
        XCTAssertEqual(PremiumView.privacyURL.absoluteString,
                       "https://apptinel.com/ekadashi-calendar/privacy-policy/")
        XCTAssertEqual(PremiumView.termsURL.absoluteString,
                       "https://apptinel.com/ekadashi-calendar/terms-of-service/")
    }

    /// Read the StoreKit-resolved metadata, not only the JSON text. Initializing
    /// a session refreshes local test metadata without buying, cancelling,
    /// clearing, or otherwise changing the device's existing transactions.
    func testEveryStoreKitPlanResolvesToTheCustomerFacingPremiumName() async throws {
        let configuration = try XCTUnwrap(Bundle.main.url(forResource: "Products", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: configuration)
        let products = try await Product.products(for: PremiumProduct.all)
        if #available(iOS 26.0, *), products.isEmpty {
            throw XCTSkip("This command-line iOS 26 runner did not provision its local StoreKit catalog; run this catalog integration check on iOS 18.6")
        }
        XCTAssertEqual(Set(products.map(\.id)), Set(PremiumProduct.all))
        let displayNames = [
            PremiumProduct.monthly: "Ekadashi Premium - Monthly",
            PremiumProduct.yearly: "Ekadashi Premium - Yearly",
            PremiumProduct.lifetime: "Ekadashi Premium",
        ]
        for product in products {
            XCTAssertEqual(product.displayName, displayNames[product.id], product.id)
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

    func testHomeScopeAndCivilYearRollOverAcrossCitiesTraditionsAndLanguages() async throws {
        let places: [(String, Double, Double, String)] = [
            ("Chennai (IN)", 13.08784, 80.27847, "Asia/Kolkata"),
            ("Kathmandu (NP)", 27.70169, 85.3206, "Asia/Kathmandu"),
            ("London (GB)", 51.50853, -0.12574, "Europe/London"),
            ("New York City (US)", 40.71427, -74.00597, "America/New_York"),
            ("Los Angeles (US)", 34.05223, -118.24368, "America/Los_Angeles"),
            ("Sydney (AU)", -33.86785, 151.20732, "Australia/Sydney"),
        ]
        for (label, latitude, longitude, zone) in places {
            let city = PanchangCity(id: zone, label: label, latitude: latitude, longitude: longitude, timeZoneId: zone)
            let cityJSON = String(decoding: try JSONEncoder().encode(city), as: UTF8.self)
            for tradition in EkadashiTradition.allCases {
                for language in Localizer.languages {
                    let scenario = "\(zone) \(tradition) \(language)"
                    let model = AppModel(store: InMemoryKeyValueStore([
                        "has_launched": true, "language_code": language, AppModel.cityKey: cityJSON,
                        AppModel.traditionKey: tradition.rawValue,
                    ]))
                    model.reload()
                    await model.waitForLoad()
                    let last = try XCTUnwrap(model.ekadashis.last { $0.date.year == 2026 }, scenario)
                    let first = try XCTUnwrap(model.ekadashis.first { $0.date.year == 2027 }, scenario)
                    let end = try XCTUnwrap(last.paranaEnd, scenario)
                    let before = end.addingTimeInterval(-1)
                    model.selectCurrentOccurrence(now: before)
                    XCTAssertEqual(model.selectedYear, 2026, scenario)
                    XCTAssertEqual(model.homeEkadashis[model.homeIndex].occurrenceUid, last.occurrenceUid, scenario)
                    model.refreshCurrentOccurrence(previousNow: before, now: end)
                    XCTAssertEqual(model.selectedYear, 2027, scenario)
                    XCTAssertEqual(model.currentYear, 2026, scenario)
                    XCTAssertEqual(model.homeEkadashis[model.homeIndex].occurrenceUid, first.occurrenceUid, scenario)

                    model.selectCurrentOccurrence(now: before)
                    model.showAllYearsOnHome()
                    XCTAssertEqual(model.homeEkadashis.count, model.ekadashis.count, scenario)
                    model.refreshCurrentOccurrence(previousNow: before, now: end)
                    XCTAssertTrue(model.homeShowsAllYears, scenario)
                    XCTAssertEqual(model.homeEkadashis[model.homeIndex].occurrenceUid, first.occurrenceUid, scenario)

                    let midnight = city.zone.utc(CivilDate(2027, 1, 1))
                    model.refreshCurrentOccurrence(previousNow: midnight.addingTimeInterval(-1), now: midnight)
                    XCTAssertEqual(model.currentYear, 2027, scenario)
                }
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

/// The plans page felt slow and sometimes needed two taps on PR #42
/// (16 Nov 2026): an idle subscriber must not keep the service refreshing.
@MainActor
final class PremiumRefreshChurnTests: XCTestCase {
    func testStoreKitSwitchesToMonthlyAtTheYearlyRenewal() async throws {
        #if targetEnvironment(simulator)
        let configuration = try XCTUnwrap(Bundle.main.url(forResource: "Products", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: configuration)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.timeRate = .realTime
        session.clearTransactions()
        defer { session.clearTransactions() }

        print("STOREKIT RENEWAL: cleared isolated transaction history")
        let service = StoreKitPremiumService()
        await service.loadProducts()
        XCTAssertEqual(service.products.count, 3)
        print("STOREKIT RENEWAL: buying Monthly")
        _ = try await session.buyProduct(identifier: PremiumProduct.monthly)
        await service.refresh()
        XCTAssertEqual(service.state.currentPlan, .monthly)
        print("STOREKIT RENEWAL: buying Yearly")
        _ = try await session.buyProduct(identifier: PremiumProduct.yearly)
        await service.refresh()
        XCTAssertEqual(service.state.currentPlan, .yearly)

        print("STOREKIT RENEWAL: scheduling Monthly")
        _ = try await session.buyProduct(identifier: PremiumProduct.monthly)
        await service.refresh()
        XCTAssertEqual(service.state.currentPlan, .yearly)
        XCTAssertEqual(service.state.scheduledPlan, .monthly)
        XCTAssertNotNil(service.state.nextRenewalDate)

        print("STOREKIT RENEWAL: forcing the Yearly renewal")
        try session.forceRenewalOfSubscription(productIdentifier: PremiumProduct.yearly)
        await service.refresh()
        XCTAssertEqual(service.state.currentPlan, .monthly)
        XCTAssertNil(service.state.scheduledPlan)
        XCTAssertTrue(service.state.isPremium)
        #else
        throw XCTSkip("Uses Xcode's isolated StoreKit test catalog")
        #endif
    }

    func testStoreKitPricesFollowTheStorefrontCurrency() async throws {
        #if targetEnvironment(simulator)
        let configuration = try XCTUnwrap(Bundle.main.url(forResource: "Products", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: configuration)
        session.resetToDefaultState()
        defer { session.resetToDefaultState() }
        for (storefront, language, currency) in [
            ("IND", "en_IN", "INR"), ("USA", "en_US", "USD"),
            ("GBR", "en_GB", "GBP"), ("JPN", "ja_JP", "JPY"),
        ] {
            session.storefront = storefront
            session.locale = Locale(identifier: language)
            let service = StoreKitPremiumService()
            await service.loadProducts()
            let product = try XCTUnwrap(service.products[.yearly], storefront)
            XCTAssertEqual(product.priceFormatStyle.currencyCode, currency, storefront)
            XCTAssertFalse(product.displayPrice.isEmpty, storefront)
        }
        #else
        throw XCTSkip("Uses Xcode's isolated StoreKit storefront")
        #endif
    }

    func testIdleSubscriberDoesNotKeepRefreshing() async throws {
        let configuration = try XCTUnwrap(Bundle.main.url(forResource: "Products", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: configuration)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        defer { session.clearTransactions() }
        let service = StoreKitPremiumService()
        await service.start()
        if service.products.isEmpty {
            throw XCTSkip("This runner did not provision the local StoreKit catalog; run on the iOS 18.6 simulator")
        }
        _ = try await session.buyProduct(identifier: PremiumProduct.monthly)
        await service.refresh()
        try await Task.sleep(nanoseconds: 2_000_000_000)
        let settled = service.refreshCount
        try await Task.sleep(nanoseconds: 6_000_000_000)
        XCTAssertLessThanOrEqual(service.refreshCount - settled, 1,
                                 "An idle subscriber triggered \(service.refreshCount - settled) refreshes in 6 s")
        XCTAssertFalse(service.busy)
    }
}

/// The paywall's plan-change wording (PR #42 review, 16 Nov 2026).
@MainActor
final class PremiumPlanChangeWordingTests: XCTestCase {
    private let end = CivilDate(2027, 11, 16).utcMidnight.addingTimeInterval(12 * 3600)

    /// No billing copy shows a date (Arun, 25 Nov 2026): the App Store shows
    /// renewal dates in its own time zone, so ours disagreed (25 Nov in IST
    /// against Apple's 24 November). Users are sent to Manage instead.
    func testBillingStatusNeverShowsADateInAnyLanguage() {
        for language in Localizer.languages {
            let model = AppModel(store: InMemoryKeyValueStore(["has_launched": true, "language_code": language]))
            var state = PremiumState()
            state.apply(owned: [OwnedProduct(productId: PremiumProduct.yearly, willAutoRenew: true, expirationDate: end,
                                             renewalDate: end)])
            XCTAssertEqual(model.premiumRenewalMessage(state), model.t("premium_renewal_in_play"), language)
            XCTAssertEqual(model.premiumSettingsMessage(state), model.t("premium_subscriber_body"), language)
            state.apply(owned: [OwnedProduct(productId: PremiumProduct.yearly, willAutoRenew: true, expirationDate: end,
                                             nextProductID: PremiumProduct.monthly, renewalDate: end)])
            XCTAssertEqual(model.premiumRenewalMessage(state), model.t("premium_monthly_switch_scheduled"), language)
            XCTAssertEqual(model.premiumSettingsMessage(state), model.t("premium_monthly_switch_scheduled"), language)
            state.apply(owned: [OwnedProduct(productId: PremiumProduct.yearly, willAutoRenew: false, expirationDate: end)])
            XCTAssertEqual(model.premiumSettingsMessage(state), model.t("premium_cancelled_body"), language)
            XCTAssertEqual(model.premiumSwitchNote(state, to: .monthly), model.t("premium_switch_at_renewal_body"), language)
            let date = model.fullDate(CivilDate.today(now: end))
            for text in [model.premiumRenewalMessage(state), model.premiumSettingsMessage(state),
                         model.premiumSwitchNote(state, to: .monthly) ?? ""] {
                XCTAssertFalse(text.contains(date), "\(language): \(text)")
            }
        }
    }

    func testUnknownRenewalStatusSendsUsersToTheAppStore() {
        let model = AppModel(store: InMemoryKeyValueStore(["has_launched": true, "language_code": "en"]))
        var state = PremiumState()
        state.apply(owned: [OwnedProduct(productId: PremiumProduct.monthly, willAutoRenew: nil)])
        XCTAssertEqual(model.premiumRenewalMessage(state), "See your next renewal and any scheduled change in the App Store.")
        XCTAssertEqual(model.premiumSettingsMessage(state), "Switch plans or go lifetime anytime.")
    }

    func testTilesShowShortStatusBadgesInEveryLanguage() {
        for language in ["en", "hi", "ta", "te", "gu", "bn"] {
            let model = AppModel(store: InMemoryKeyValueStore(["has_launched": true, "language_code": language]))
            var state = PremiumState()
            state.apply(owned: [OwnedProduct(productId: PremiumProduct.yearly, willAutoRenew: true, expirationDate: end,
                                             nextProductID: PremiumProduct.monthly, renewalDate: end)])
            let upcoming = model.premiumPlanBadgeText(state, .monthly)
            let current = model.premiumPlanBadgeText(state, .yearly)
            XCTAssertEqual(upcoming, model.t("premium_upcoming_plan"), language)
            XCTAssertEqual(current, model.t("premium_current_plan"), language)
            XCTAssertNil(model.premiumPlanBadgeText(state, .lifetime))
            if language == "en" {
                XCTAssertEqual(upcoming, "Upcoming plan")
                XCTAssertEqual(current, "Current plan")
            } else {
                for text in [upcoming, current] { XCTAssertNil(text?.range(of: "[A-Za-z]", options: .regularExpression), language) }
            }
        }
    }

    func testADowngradeExplainsWhenEachPlanAppliesBeforeCheckout() {
        let model = AppModel(store: InMemoryKeyValueStore(["has_launched": true, "language_code": "en"]))
        var state = PremiumState()
        state.apply(owned: [OwnedProduct(productId: PremiumProduct.yearly, willAutoRenew: true, expirationDate: end)])
        let downgrade = model.premiumSwitchNote(state, to: .monthly)
        XCTAssertEqual(downgrade, "Yearly stays active until your next renewal. The App Store then starts Monthly and charges for it.")
        XCTAssertNil(model.premiumSwitchNote(state, to: .lifetime), "Lifetime starts now")
        state.apply(owned: [OwnedProduct(productId: PremiumProduct.monthly, willAutoRenew: true, expirationDate: end)])
        XCTAssertEqual(model.premiumSwitchNote(state, to: .yearly),
                       "Yearly starts and is charged today. Apple refunds the unused portion of Monthly to your original payment method.")
    }
}

/// Arun (25 Nov 2026): Google Calendar reminders are Premium. A free user who
/// used the one free sync may use them during that month only.
@MainActor
final class GoogleReminderLockTests: XCTestCase {
    private func model(freeMonth: String?) -> AppModel {
        var seed: [String: Any] = ["has_launched": true, "language_code": "en"]
        if let freeMonth { seed[GoogleSyncCoordinator.freeSyncMonthKey] = freeMonth }
        return AppModel(store: InMemoryKeyValueStore(seed))
    }

    func testAFreeUserGetsGoogleRemindersOnlyDuringTheFreeSyncMonth() {
        let thisMonth = String(CivilDate.today().iso.prefix(7))
        XCTAssertTrue(model(freeMonth: nil).reminderLocked(.calendar(.google)))
        XCTAssertFalse(model(freeMonth: nil).reminderLocked(.calendar(.custom)), "custom entries stay free")
        XCTAssertFalse(model(freeMonth: thisMonth).reminderLocked(.calendar(.google)))
        XCTAssertTrue(model(freeMonth: thisMonth).reminderLocked(.observance("holi")))
        XCTAssertTrue(model(freeMonth: "2020-01").reminderLocked(.calendar(.google)), "locked again after the month")
    }
}
