import Foundation
import XCTest
@testable import EkadashiCore

/// Ports test/unit/calendar_data_test.dart and localization_completeness_test.dart.
final class CalendarDataTests: XCTestCase {
    var repository: CalendarRepository!
    var raw: [[String: Any]] = []

    override func setUpWithError() throws {
        repository = try CalendarRepository.bundled()
        raw = try [2026, 2027].flatMap { year -> [[String: Any]] in
            let pack = try Repo.json("assets/calendar/\(year).json") as! [String: Any]
            return pack.array("ekadashis")! as! [[String: Any]]
        }
    }

    func testAvailableYearsComeFromTheManifest() {
        XCTAssertEqual(repository.availableYears, [2026, 2027])
    }

    func testEveryTimezoneIsCompleteOrderedUniqueAndUtcConsistent() throws {
        for zone in AppTimezone.allCases {
            let events = repository.ekadashis(timezone: zone.rawValue, language: "en")
            XCTAssertEqual(events.count, raw.count, zone.rawValue)
            XCTAssertEqual(Set(events.map(\.id)).count, events.count)
            let location = try XCTUnwrap(TzDatabase.shared.location(zone.ianaIdentifier))
            for (i, event) in events.enumerated() {
                XCTAssertGreaterThan(event.id, 0)
                XCTAssertFalse(event.name.isEmpty)
                XCTAssertFalse(event.description.isEmpty)
                XCTAssertFalse(event.story.isEmpty)
                if i > 0 { XCTAssertGreaterThan(event.date, events[i - 1].date) }
                let start = try XCTUnwrap(event.fastingStart)
                let parana = try XCTUnwrap(event.paranaStart)
                let end = try XCTUnwrap(event.paranaEnd)
                XCTAssertLessThan(start, parana)
                XCTAssertLessThan(parana, end)
                for iso in [event.fastingStartISO, event.paranaStartISO, event.paranaEndISO] {
                    let clock = location.wallClock(ISO8601.instant(iso)!)
                    let stored = iso.dropFirst(11).prefix(5)
                    XCTAssertEqual(String(format: "%02d:%02d", clock.hour, clock.minute), String(stored), iso)
                }
                XCTAssertEqual(location.wallClock(start).date, event.date)
                XCTAssertNotNil(event.fastStartTime.range(of: #"^\d{2}:\d{2} (AM|PM)$"#, options: .regularExpression))
                XCTAssertNotNil(event.fastBreakTime.range(of: #"^\d{2}:\d{2} (AM|PM) - \d{2}:\d{2} (AM|PM)$"#,
                                                          options: .regularExpression))
            }
        }
    }

    func testTranslatedContentKeepsOccurrenceIdentity() {
        for zone in AppTimezone.allCases {
            for language in Localizer.languages {
                for event in repository.ekadashis(timezone: zone.rawValue, language: language) {
                    let row = raw.first { $0.string("occurrence_uid") == event.occurrenceUid }!
                    func text(_ key: String) -> String {
                        let map = row.dict(key)!
                        return map.string(language) ?? map.string("en")!
                    }
                    XCTAssertEqual(event.name, text("name"))
                    XCTAssertEqual(event.story, text("story"))
                    XCTAssertEqual(event.fastingRules, text("fasting_rules"))
                    XCTAssertEqual(event.paksha, Localizer.shared.translate("paksha_\(row.string("paksha")!)", language: language))
                }
            }
        }
    }

    func testUnknownLanguageFallsBackToEnglish() {
        let fallback = repository.ekadashis(timezone: "IST", language: "xx")
        let english = repository.ekadashis(timezone: "IST", language: "en")
        XCTAssertEqual(fallback.map(\.name), english.map(\.name))
        XCTAssertEqual(fallback.map(\.story), english.map(\.story))
        XCTAssertTrue(fallback.allSatisfy(\.usesContentFallback))
    }

    func testTimezonesStayIsolated() {
        let india = repository.ekadashis(timezone: "IST", language: "en")
        let west = repository.ekadashis(timezone: "PST", language: "ta")
        XCTAssertNotEqual(west.first?.date, india.first?.date)
        XCTAssertNotEqual(west.first?.name, india.first?.name)
        XCTAssertTrue(repository.ekadashis(timezone: "UNSUPPORTED", language: "en").isEmpty)
        XCTAssertEqual(repository.ekadashis(timezone: "IST", language: "en", year: 2027).count, 24)
    }

    func testInvalidPacksAreRejectedBeforePublishing() throws {
        let manifestPack = try Repo.data("assets/calendar/2026.json")
        XCTAssertThrowsError(try CalendarRepository(packs: [manifestPack, manifestPack]))
        var broken = try Repo.json("assets/calendar/2026.json") as! [String: Any]
        var rows = broken.array("ekadashis")! as! [[String: Any]]
        rows[0]["occurrence_uid"] = "ekadashi:1999:01"
        broken["ekadashis"] = rows
        XCTAssertThrowsError(try CalendarRepository(packs: [JSONSerialization.data(withJSONObject: broken)]))
    }

    func testDisplayTimesAreReadFromTheStoredWallClock() {
        XCTAssertEqual(EkadashiTimeFormat.displayTime("2026-01-14T06:35:00+05:30"), "06:35 AM")
        XCTAssertEqual(EkadashiTimeFormat.displayTime("2026-01-13T13:16:00-08:00"), "01:16 PM")
        XCTAssertEqual(EkadashiTimeFormat.displayTime("2026-01-13T00:05:00-05:00"), "12:05 AM")
        XCTAssertEqual(EkadashiTimeFormat.displayTime(""), "")
        XCTAssertEqual(EkadashiTimeFormat.window("2026-01-15T06:35:00+05:30", "2026-01-15T08:52:00+05:30"),
                       "06:35 AM - 08:52 AM")
    }

    func testDeviceTimezoneMapsToTheNearestPublishedSchedule() {
        XCTAssertEqual(AppTimezone.matching(deviceIdentifier: "Asia/Calcutta"), .ist)
        XCTAssertEqual(AppTimezone.matching(deviceIdentifier: "America/Toronto"), .est)
        XCTAssertEqual(AppTimezone.matching(deviceIdentifier: "America/Indiana/Knox"), .est)
        XCTAssertEqual(AppTimezone.matching(deviceIdentifier: "America/Mexico_City"), .cst)
        XCTAssertEqual(AppTimezone.matching(deviceIdentifier: "America/Phoenix"), .mst)
        XCTAssertEqual(AppTimezone.matching(deviceIdentifier: "America/Vancouver"), .pst)
        XCTAssertEqual(AppTimezone.matching(deviceIdentifier: "Asia/Dubai"), .ist)
        XCTAssertEqual(AppTimezone.matching(deviceIdentifier: "Europe/London"), .ist)
        XCTAssertEqual(AppTimezone.ist.ianaIdentifier, "Asia/Kolkata")
    }

    func testLocationFixMapsToAScheduleLikeAndroid() {
        XCTAssertEqual(AppTimezone.detect(latitude: 13.08, longitude: 80.27), .ist)
        XCTAssertEqual(AppTimezone.detect(latitude: 40.71, longitude: -74.0), .est)
        XCTAssertEqual(AppTimezone.detect(latitude: 41.88, longitude: -87.63), .cst)
        XCTAssertEqual(AppTimezone.detect(latitude: 39.74, longitude: -104.99), .mst)
        XCTAssertEqual(AppTimezone.detect(latitude: 34.05, longitude: -118.24), .pst)
        XCTAssertEqual(AppTimezone.detect(latitude: 51.5, longitude: -0.12), .ist)
        let nearest = PanchangCityCatalog.shared.nearest(latitude: 13.0827, longitude: 80.2707)
        XCTAssertEqual(nearest?.label, "Chennai (IN)")
    }

    func testCitySelectionRoundTripsCountryAndTimezone() {
        let groups = AppTimezone.citiesByCountry
        XCTAssertTrue(groups.keys.contains("India"))
        XCTAssertTrue(groups.keys.contains("United States"))
        for city in groups.values.flatMap({ $0 }) {
            XCTAssertEqual(AppTimezone.city(id: city.id)?.name, city.name)
            XCTAssertEqual(AppTimezone.timezone(forCity: city.id), city.timezone)
        }
        XCTAssertNil(AppTimezone.city(id: "no-such-city"))
    }

    func testHomeOpensTheNextEkadashiOrAnActiveParana() {
        let events = repository.ekadashis(timezone: "IST", language: "en")
        let zone = TzDatabase.shared.location("Asia/Kolkata")!
        let first = events[0]
        // Before the first fast: the first card.
        XCTAssertEqual(HomeSelection.index(of: events, now: utc(2026, 1, 1), zone: zone, includeParana: true), 0)
        // During Parana of the first fast the passed card stays selected...
        let duringParana = first.paranaStart!.addingTimeInterval(60)
        XCTAssertEqual(HomeSelection.index(of: events, now: duringParana, zone: zone, includeParana: true), 0)
        // ...unless the user taps Home again, which skips to the next one.
        XCTAssertEqual(HomeSelection.index(of: events, now: duringParana, zone: zone, includeParana: false), 1)
        // After every fast: the last card.
        XCTAssertEqual(HomeSelection.index(of: events, now: utc(2030, 1, 1), zone: zone, includeParana: true),
                       events.count - 1)
        XCTAssertEqual(HomeSelection.daysUntil(first.date, now: utc(2026, 1, 13, 20), zone: zone), 0)
    }
}

final class LocalizationTests: XCTestCase {
    func testEveryLanguageHasEveryKeyNativeScriptAndPlaceholders() {
        let scripts = ["ta": "\u{0B80}"..."\u{0BFF}", "hi": "\u{0900}"..."\u{097F}", "te": "\u{0C00}"..."\u{0C7F}"]
        let english = Localizer.shared.keys(language: "en")
        XCTAssertEqual(english.count, 325)
        var problems: [String] = []
        for language in ["ta", "hi", "te"] {
            for key in english {
                let value = Localizer.shared.translate(key, language: language)
                if value == key || value.trimmingCharacters(in: .whitespaces).isEmpty {
                    problems.append("\(language) \(key): missing")
                    continue
                }
                if key != "filter_google" && !value.unicodeScalars.contains(where: { scripts[language]!.contains(String($0)) }) {
                    problems.append("\(language) \(key): untranslated")
                }
                if Localizer.placeholders(Localizer.shared.translate(key, language: "en")) != Localizer.placeholders(value) {
                    problems.append("\(language) \(key): placeholder mismatch")
                }
            }
        }
        XCTAssertEqual(problems, [])
    }

    func testTranslateWithArgumentsFillsPlaceholdersInOrder() {
        XCTAssertEqual(Localizer.shared.translate("in_days", language: "en", args: ["3"]), "in 3 days")
        XCTAssertEqual(Localizer.shared.translate("no_such_key", language: "en"), "no_such_key")
        XCTAssertEqual(Localizer.shared.translate("home", language: "xx"), Localizer.shared.translate("home", language: "en"))
        XCTAssertEqual(Localizer.languages, ["en", "hi", "ta", "te", "gu", "bn"])
        XCTAssertEqual(Localizer.displayName("te"), "తెలుగు")
    }

    func testIosNeverNamesGooglePlayOrAndroidBattery() {
        let android = ["Google Play", "Play Store", "Battery", "கூகுள் பிளே", "பிளே ஸ்டோர்", "பேட்டரி", "गूगल प्ले",
                       "प्ले स्टोर", "बैटरी", "గూగుల్ ప్లే", "ప్లే స్టోర్", "బ్యాటరీ"]
        let shownOnIos = ["rate_app_desc", "app_settings_desc", "perm_guide_desc", "premium_monthly_terms", "premium_yearly_terms",
                          "premium_manage", "premium_restore_none", "premium_cancel_subscription_note",
                          "premium_cancel_subscription_action", "premium_lifetime_confirm_body", "premium_unavailable"]
        for language in Localizer.languages {
            for key in shownOnIos {
                let value = Localizer.shared.translate(key, language: language)
                XCTAssertFalse(android.contains { value.contains($0) }, "\(language) \(key): \(value)")
            }
        }
        XCTAssertEqual(Localizer.shared.translate("premium_manage", language: "en"), "Manage subscription in the App Store")
        XCTAssertEqual(Localizer.shared.translate("ios_share_message", language: "en", args: ["https://example.org"]).suffix(19),
                       "https://example.org")
    }

    func testOverridesOnlyReplacePlatformWordingInEveryLanguage() throws {
        let english = try Repo.json("lib/l10n/app_en.arb") as! [String: Any]
        let keys = Set(Localizer.shared.overrideKeys(language: "en"))
        for language in Localizer.languages {
            XCTAssertEqual(Set(Localizer.shared.overrideKeys(language: language)), keys, language)
        }
        for key in keys {
            // ios_ keys are iOS-only; other keys missing from the ARB files are
            // iOS-first additions (docs/ROADMAP.md) that move to the ARB files
            // when the feature is ported to Android. Keys present in the ARB
            // files may only replace platform wording.
            if key.hasPrefix("ios_") || english[key] == nil {
                XCTAssertNil(english[key], key)
            } else {
                let source = english[key] as? String ?? ""
                XCTAssertTrue(["Play", "Battery", "battery"].contains { source.contains($0) }, key)
            }
            for language in Localizer.languages {
                XCTAssertEqual(Localizer.placeholders(Localizer.shared.translate(key, language: language)),
                               Localizer.placeholders(Localizer.shared.translate(key, language: "en")), "\(language) \(key)")
            }
        }
        XCTAssertEqual(Localizer.shared.arbValue("premium_manage", language: "en"), "Manage subscription in Google Play")
    }
}
