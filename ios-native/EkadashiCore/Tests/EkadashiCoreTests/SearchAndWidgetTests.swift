import Foundation
import XCTest
@testable import EkadashiCore

/// Ports search_accuracy_test.dart (Ekadashi matching) and the recent-search rules.
final class SearchTests: XCTestCase {
    private let today = CivilDate(2026, 10, 8)

    private func vaikuntha(_ language: String) -> [EkadashiOccurrence] {
        [2026, 2027].map { year in
            EkadashiOccurrence(id: year == 2026 ? 1 : 2027001, occurrenceUid: "ekadashi:\(year):01",
                               name: language == "te" ? "వైకుంఠ ఏకాదశి" : "Vaikuntha Ekadashi",
                               date: CivilDate(year, 1, 1),
                               description: language == "te" ? "భక్తితో ఉపవాసం" : "Devotional observance")
        }
    }

    private func search(_ events: @escaping (String) -> [EkadashiOccurrence], language: String = "en") -> UnifiedSearch {
        UnifiedSearch(items: SearchCorpus.ekadashiItems(events, language: language))
    }

    func testUnmatchedAndPunctuationOnlyQueriesReturnNothing() {
        let s = search(vaikuntha)
        XCTAssertTrue(s.search("zzzzreviewnomatch9999", today: today).isEmpty)
        XCTAssertTrue(s.search("!!!", today: today).isEmpty)
    }

    func testOneEditTranspositionAndTwoEditsFindTheIntendedEkadashi() {
        let s = search(vaikuntha)
        for query in ["vaikunta", "vaikuntah", "vaikntha", "vaikxxtha"] {
            let results = s.search(query, category: .ekadashi, today: today)
            XCTAssertFalse(results.isEmpty, query)
            XCTAssertTrue(results.allSatisfy { $0.titleEnglish == "Vaikuntha Ekadashi" }, query)
        }
        XCTAssertTrue(s.search("vx", category: .ekadashi, today: today).isEmpty)
        XCTAssertTrue(s.search("vaikuntha unrelatedword", category: .ekadashi, today: today).isEmpty)
    }

    func testTeluguQueryKeepsItsLettersAndEveryLanguageNameMatches() {
        XCTAssertEqual(SearchText.normalize("వైకుంఠ"), "వైకుంఠ")
        let telugu = search(vaikuntha, language: "te")
        XCTAssertEqual(telugu.search("వైకుంఠ", today: today).count, 2)
        XCTAssertEqual(telugu.search("vaikuntha", today: today).first?.title, "వైకుంఠ ఏకాదశి", "English name finds the Telugu title")
    }

    func testYearSelectionDistinguishesOccurrences() {
        let s = search(vaikuntha)
        for year in [2026, 2027] {
            let results = s.search("vaikuntha", year: year, today: today)
            XCTAssertEqual(results.map { $0.date?.year }, [year])
        }
    }

    func testExactTitleTokenRanksAboveAPrefixAndTitleAboveBody() {
        let prefix = search { _ in [EkadashiOccurrence(id: 1, occurrenceUid: "a", name: "Vaikuntham Ekadashi", date: CivilDate(2026, 1, 1)),
                                    EkadashiOccurrence(id: 2, occurrenceUid: "b", name: "Vaikuntha Ekadashi", date: CivilDate(2026, 1, 1))] }
        XCTAssertEqual(prefix.search("vaikuntha", today: today).first?.titleEnglish, "Vaikuntha Ekadashi")
        let body = search { _ in [EkadashiOccurrence(id: 1, occurrenceUid: "a", name: "Unrelated Ekadashi", date: CivilDate(2026, 1, 1),
                                                     description: "Reaches Vaikuntha"),
                                  EkadashiOccurrence(id: 2, occurrenceUid: "b", name: "Vaikuntha Ekadashi", date: CivilDate(2026, 1, 1))] }
        XCTAssertEqual(body.search("vaikunta", today: today).first?.titleEnglish, "Vaikuntha Ekadashi")
    }

    func testRecentSearchesDeduplicateDropTypingPrefixesAndCapAtTen() {
        let recents = RecentSearches(store: InMemoryKeyValueStore())
        for query in ["p", "pa", "par", "parana", "Parana", "mantra"] { recents.add(query) }
        XCTAssertEqual(recents.all(), ["mantra", "Parana"])
        for i in 0..<12 { recents.add("query \(i)") }
        XCTAssertEqual(recents.all().count, 10)
        recents.clear()
        XCTAssertTrue(recents.all().isEmpty)
        XCTAssertEqual(RecentSearches.sanitize(["v", "vaikuntha", "VAIKUNTHA"]), ["vaikuntha"])
    }
}

/// Ports widget_timeline_test.dart, widget_deep_link_test.dart and the
/// Android widget renderer's countdown text.
final class WidgetSnapshotTests: XCTestCase {
    private func event(_ year: Int, _ serial: Int, _ start: Date) -> EkadashiOccurrence {
        let date = TzDatabase.shared.location("UTC")!.wallClock(start).date
        return EkadashiOccurrence(id: year * 1000 + serial, occurrenceUid: "ekadashi:\(year):\(serial)", name: "Year \(year)",
                                  date: date, fastingStartISO: ISO8601.string(start),
                                  paranaStartISO: ISO8601.string(start.addingTimeInterval(86400)),
                                  paranaEndISO: ISO8601.string(start.addingTimeInterval(86400 + 7200)))
    }

    private func snapshot(_ events: [EkadashiOccurrence], _ now: Date, language: String = "en", zone: String = "IST") -> WidgetSnapshot {
        WidgetSnapshot.build(occurrences: events, timezone: zone, locationName: "Test", language: language, now: now)
    }

    func testUnsortedArchiveSkipsExpiredRowsAndSelects2027() {
        let a = event(2026, 1, utc(2026, 12, 1)), b = event(2026, 2, utc(2026, 12, 15)), c = event(2027, 1, utc(2027, 1, 5))
        let p = snapshot([c, a, b], utc(2027, 1, 1))
        XCTAssertEqual(p.nextEkadashi?.year, 2027)
        XCTAssertTrue(p.upcoming.isEmpty)
    }

    func testExhaustedCalendarFallsBack() {
        let p = snapshot([event(2027, 1, utc(2027, 1, 5))], utc(2028, 1, 1))
        XCTAssertNil(p.nextEkadashi)
        XCTAssertEqual(p.currentState, .fallback)
    }

    func testCountdownTargetsChangeAtExactTransitions() {
        let start = utc(2027, 1, 5)
        let e = event(2027, 1, start)
        for (now, state, target) in [(start.addingTimeInterval(-1), WidgetState.beforeEkadashi, e.fastingStart!),
                                     (start, .fastingActive, e.paranaStart!),
                                     (start.addingTimeInterval(86400), .paranaAvailable, e.paranaEnd!)] {
            let p = snapshot([e], now)
            XCTAssertEqual(p.currentState, state)
            XCTAssertEqual(p.nextEkadashi?.countdownTarget, target)
        }
        XCTAssertEqual(WidgetSnapshot.state(of: e, at: e.paranaEnd!), .paranaCompleted)
    }

    func testTodayUsesTheSelectedLocationAcrossMidnight() {
        let e = event(2027, 1, utc(2027, 1, 5))
        XCTAssertTrue(snapshot([e], utc(2027, 1, 4, 20), zone: "IST").today.isEkadashi)
        XCTAssertFalse(snapshot([e], utc(2027, 1, 4, 20), zone: "PST").today.isEkadashi)
    }

    func testEveryLanguageProvidesAllWidgetLabels() {
        for language in Localizer.languages {
            let strings = snapshot([event(2027, 1, utc(2027, 1, 5))], utc(2027, 1, 1), language: language).strings
            XCTAssertEqual(strings.count, WidgetSnapshot.stringKeys.count, language)
            XCTAssertEqual(strings.count, 28, language)
            XCTAssertTrue(strings.values.allSatisfy { !$0.isEmpty && !$0.hasPrefix("widget_") }, language)
            if language != "en" { XCTAssertNotEqual(strings["widget.next_ekadashi"], "Next Ekadashi") }
        }
    }

    func testSnapshotRoundTripsThroughTheAppGroupJson() throws {
        let p = snapshot([event(2027, 1, utc(2027, 1, 5)), event(2027, 2, utc(2027, 1, 20))], utc(2027, 1, 1))
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: try JSONEncoder().encode(p))
        XCTAssertEqual(decoded, p)
        XCTAssertEqual(decoded.schemaVersion, 2)
        XCTAssertEqual(decoded.upcoming.count, 1)
    }

    func testRemainingTimeTextMatchesTheAndroidWidget() {
        let strings = ["widget.now": "Now", "widget.day_unit": "d", "widget.hour_unit": "h", "widget.minute_unit": "min"]
        let now = utc(2027, 1, 1)
        XCTAssertEqual(WidgetSnapshot.remaining(until: nil, now: now, strings: strings), "--")
        XCTAssertEqual(WidgetSnapshot.remaining(until: now.addingTimeInterval(-5), now: now, strings: strings), "Now")
        XCTAssertEqual(WidgetSnapshot.remaining(until: now.addingTimeInterval(2 * 86400 + 3 * 3600 + 120), now: now, strings: strings), "2 d 3 h")
        XCTAssertEqual(WidgetSnapshot.remaining(until: now.addingTimeInterval(3 * 3600 + 120), now: now, strings: strings), "3 h 2 min")
        XCTAssertEqual(WidgetSnapshot.remaining(until: now.addingTimeInterval(59), now: now, strings: strings), "0 min")
    }

    func testTimelineRefreshesAtEveryStateChange() {
        let start = utc(2027, 1, 5)
        let p = snapshot([event(2027, 1, start)], utc(2027, 1, 1))
        let dates = p.refreshDates(after: utc(2027, 1, 1))
        XCTAssertEqual(Array(dates.prefix(3)), [start, start.addingTimeInterval(86400), start.addingTimeInterval(86400 + 7200)])
    }
}

final class DeepLinkTests: XCTestCase {
    func testRoutesMatchTheAndroidLinks() {
        XCTAssertEqual(AppRoute(url: URL(string: "ekadashi://dashboard")!), .tab(.today))
        XCTAssertEqual(AppRoute(url: URL(string: "ekadashi://dashboard?action=parana")!), .tab(.today))
        XCTAssertEqual(AppRoute(url: URL(string: "ekadashi://today")!), .tab(.today))
        XCTAssertEqual(AppRoute(url: URL(string: "ekadashi://parana")!), .tab(.today))
        XCTAssertEqual(AppRoute(url: URL(string: "ekadashi://calendar?date=2026-09-15")!), .calendar(CivilDate(2026, 9, 15)))
        XCTAssertEqual(AppRoute(url: URL(string: "ekadashi://calendar")!), .calendar(nil))
        XCTAssertEqual(AppRoute(url: URL(string: "ekadashi://calendar?date=not-a-date")!), .calendar(nil))
        XCTAssertEqual(AppRoute(url: URL(string: "ekadashi://vrat")!), .tab(.vrat))
        XCTAssertEqual(AppRoute(url: URL(string: "ekadashi://panchang")!), .tab(.panchang))
        XCTAssertEqual(AppRoute(url: URL(string: "ekadashi://more")!), .tab(.panchang))
        XCTAssertEqual(AppRoute(url: URL(string: "ekadashi://settings")!), .tab(.settings))
        XCTAssertEqual(AppRoute(url: URL(string: "ekadashi://search")!), .search)
        XCTAssertNil(AppRoute(url: URL(string: "https://dashboard")!))
        XCTAssertNil(AppRoute(url: URL(string: "ekadashi://unknown")!))
        XCTAssertEqual(AppRoute.calendarURL(CivilDate(2026, 9, 15)).absoluteString, "ekadashi://calendar?date=2026-09-15")
        XCTAssertEqual(AppTab.allCases.count, 5)
    }
}

/// Reminder schedule from NotificationScheduler.kt, within iOS's 64 pending
/// notification limit.
final class ReminderPlannerTests: XCTestCase {
    private let texts: (String) -> String = { Localizer.shared.translate($0, language: "en") }

    private func occurrence(_ id: Int, _ start: String, _ parana: String) -> EkadashiOccurrence {
        EkadashiOccurrence(id: id, name: "Shattila Ekadashi", date: CivilDate(iso: String(start.prefix(10)))!,
                           fastingStartISO: start, paranaStartISO: parana, paranaEndISO: parana)
    }

    func testPlansTheFourAndroidRemindersWithStableIds() throws {
        let event = occurrence(1, "2026-01-14T06:35:00+05:30", "2026-01-15T06:35:00+05:30")
        let plan = ReminderPlanner.plan(occurrences: [event], settings: ReminderSettings(), texts: texts, now: utc(2026, 1, 1))
        XCTAssertEqual(plan.map(\.id), [10, 11, 12, 13])
        XCTAssertEqual(plan.map(\.kind), [.twoDaysBefore, .oneDayBefore, .onFastingStart, .onParana])
        let start = try XCTUnwrap(event.fastingStart)
        XCTAssertEqual(plan[0].fireDate, start.addingTimeInterval(-48 * 3600))
        XCTAssertEqual(plan[1].fireDate, start.addingTimeInterval(-24 * 3600))
        XCTAssertEqual(plan[2].fireDate, start)
        XCTAssertEqual(plan[3].fireDate, event.paranaStart)
        XCTAssertEqual(plan[1].body, "Shattila Ekadashi \(texts("notif_1day_body")) 06:35 AM")
        XCTAssertEqual(plan[2].body, "\(texts("notif_start_body")) Shattila Ekadashi. \(texts("notif_start_suffix"))")
        XCTAssertEqual(plan[3].title, texts("notif_parana_title"))
    }

    func testRespectsSwitchesSkipsThePastAndCapsAtSixtyFour() {
        let events = (1...30).map { i -> EkadashiOccurrence in
            let start = CivilDate(2026, 1, 1).adding(days: i * 14)
            return occurrence(i, "\(start.iso)T06:00:00+05:30", "\(start.adding(days: 1).iso)T06:30:00+05:30")
        }
        var settings = ReminderSettings()
        XCTAssertEqual(ReminderPlanner.plan(occurrences: events, settings: settings, texts: texts, now: utc(2026, 1, 1)).count, 64)
        settings.twoDaysBefore = false
        settings.oneDayBefore = false
        let plan = ReminderPlanner.plan(occurrences: events, settings: settings, texts: texts, now: utc(2026, 6, 1))
        XCTAssertTrue(plan.allSatisfy { $0.fireDate > utc(2026, 6, 1) })
        XCTAssertTrue(plan.allSatisfy { $0.kind == .onFastingStart || $0.kind == .onParana })
        XCTAssertEqual(plan.map(\.fireDate), plan.map(\.fireDate).sorted())
        settings.enabled = false
        XCTAssertTrue(ReminderPlanner.plan(occurrences: events, settings: settings, texts: texts, now: utc(2026, 1, 1)).isEmpty)
    }

    func testSettingsUseTheAndroidKeysAndDefaults() {
        let store = InMemoryKeyValueStore()
        XCTAssertEqual(ReminderSettings.load(from: store), ReminderSettings())
        var settings = ReminderSettings()
        settings.onParana = false
        settings.save(to: store)
        XCTAssertEqual(store.bool(forKey: "remind_on_parana"), false)
        XCTAssertEqual(ReminderSettings.load(from: store).activeCount, 3)
    }
}

/// The iOS copies of the Flutter assets must match their sources.
final class ResourceSyncTests: XCTestCase {
    private func resource(_ path: String) throws -> Data {
        try Data(contentsOf: XCTUnwrap(CoreResources.url(path)))
    }

    func testCalendarAndCityAssetsAreByteIdentical() throws {
        for name in ["manifest.json", "2026.json", "2027.json"] {
            XCTAssertEqual(try resource("calendar/\(name)"), try Repo.data("assets/calendar/\(name)"), name)
        }
        XCTAssertEqual(try resource("panchang/cities.json"), try Repo.data("assets/panchang/cities.json"))
        XCTAssertEqual(try resource("panchang/place_names.json"), try Repo.data("assets/panchang/place_names.json"))
    }

    func testStringsMatchTheArbFiles() throws {
        for language in Localizer.languages {
            let arb = try Repo.json("lib/l10n/app_\(language).arb") as! [String: Any]
            for (key, value) in arb where !key.hasPrefix("@") {
                XCTAssertEqual(Localizer.shared.arbValue(key, language: language), value as? String, "\(language) \(key)")
            }
        }
    }

    func testEveryCalendarYearInTheManifestIsBundled() throws {
        let manifest = try Repo.json("assets/calendar/manifest.json") as! [String: Any]
        let years = (manifest.array("packs")! as! [[String: Any]]).map { $0.int("year")! }
        XCTAssertEqual(try CalendarRepository.bundled().availableYears, years)
    }

    /// No user-facing English literal in any iOS view, Panchang included
    /// (Phase 2: every screen follows the app language).
    func testIosAppSourcesDoNotBypassLocalization() throws {
        let views = #"(Text|Label|Button|TextField|SecureField|Toggle|Picker|DatePicker|DisclosureGroup|Section|navigationTitle|accessibilityLabel|accessibilityHint|ContentUnavailableView)"#
        let pattern = try NSRegularExpression(pattern: #"\b"# + views + #"\(\s*"([^"\\]*[A-Za-z][^"\\]*)""#)
        var violations: [String] = []
        for folder in ["ios-native/EkadashiCalendar", "ios-native/EkadashiWidgets", "ios-native/Shared"] {
            guard let files = FileManager.default.enumerator(at: Repo.url(folder), includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in files where url.pathExtension == "swift" {
                for line in try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n") {
                    for match in pattern.matches(in: line, range: NSRange(line.startIndex..., in: line)) {
                        violations.append("\(url.lastPathComponent): \((line as NSString).substring(with: match.range(at: 2)))")
                    }
                }
            }
        }
        XCTAssertEqual(violations, [])
    }

    /// Every translation key the iOS app and widgets use exists in English,
    /// Tamil, Hindi and Telugu (Android ARB strings or the iOS override table).
    func testEveryIosStringKeyIsTranslatedInAllLanguages() throws {
        let patterns = [
            #"\bt\("([^"\\]+)""#, #"show\("([^"\\]+)""#, #"reason: "([^"\\]+)""#, #"translate\("([^"\\]+)""#,
            #"statusCard\("([^"\\]+)""#, #"statusCard\("[^"]+", "([^"\\]+)""#, #"\bsection\("([^"\\]+)""#,
            #"\blabel\("([^"\\]+)"\)"#, #"filterChip\([^,]+, "([^"\\]+)"\)"#, #"\bchip\([^,]+, "([^"\\]+)""#,
            #"countCard\("([^"\\]+)""#, #"iconButton\("[^"]+", "([^"\\]+)""#, #"reminder\("([^"\\]+)""#,
            #"feature\("[^"]+", "([^"\\]+)"\)"#, #"caption\("([^"\\]+)"\)"#, #"\blink\("([^"\\]+)"\)"#,
            #"statusChip\([^,]+, "([^"\\]+)""#, #""(premium_[a-z_]+)""#,
            // Every literal inside t(...), including both sides of a ternary.
            #"\bt\([^()]*?"([a-z0-9_]+)"[^()]*?\)"#, #"\bt\([^()]*?"[a-z0-9_]+"[^()]*?"([a-z0-9_]+)"[^()]*?\)"#,
        ].map { try! NSRegularExpression(pattern: $0) }
        var keys: [String: String] = [:]
        for folder in ["ios-native/EkadashiCalendar", "ios-native/EkadashiWidgets", "ios-native/Shared"] {
            guard let files = FileManager.default.enumerator(at: Repo.url(folder), includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in files where url.pathExtension == "swift" {
                for line in try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
                where !line.contains("accessibilityIdentifier") {
                    for pattern in patterns {
                        for match in pattern.matches(in: line, range: NSRange(line.startIndex..., in: line)) {
                            keys[(line as NSString).substring(with: match.range(at: 1))] = url.lastPathComponent
                        }
                    }
                }
            }
        }
        // Keys built at runtime.
        for plan in PremiumPlanID.allCases {
            keys["premium_\(plan.rawValue)"] = "PremiumView.swift"
            if plan != .lifetime { keys["premium_\(plan.rawValue)_terms"] = "PremiumView.swift" }
        }
        for category in SearchCategory.allCases { keys[category.localizationKey] = "Search" }
        for screen in SearchCatalog.bundled.screens { keys[screen.titleKey] = "search_catalog.json" }
        for page in ["keydays", "daily", "muhurta", "ekadashi", "rashi"] { keys["panchang_section_\(page)"] = "PanchangView" }
        for limb in ["tithi", "nakshatra", "yoga", "karana"] { keys["panchang_\(limb)"] = "PanchangPages" }
        for key in ["panchang_am", "panchang_pm", "panchang_next_day_marker", "panchang_previous_day_marker", "panchang_day",
                    "panchang_night"] { keys[key] = "EkadashiCore" }
        for method in FastingMethod.allCases { keys[method.localizationKey] = "VratModels" }
        for status in ObservanceStatus.allCases where status != .unrecorded { keys[status.rawValue] = "VratStatusStyle" }
        for achievement in AchievementEvaluator.all {
            keys[achievement.titleKey] = "Achievements"
            keys[achievement.descriptionKey] = "Achievements"
        }
        for key in WidgetSnapshot.stringKeys.values { keys[key] = "WidgetSnapshot" }
        for group in EventReminderChoice.Kind.allCases { keys[group.titleKey] = "EventReminders" }
        for key in ["event_reminder_today", "event_reminder_tomorrow", "event_reminder_in_days", "event_reminder_all_custom",
                    "event_reminder_all_google"] { keys[key] = "EventReminders" }
        XCTAssertGreaterThan(keys.count, 150)
        var missing: [String] = []
        for language in Localizer.languages {
            let known = Set(Localizer.shared.keys(language: language)).union(Localizer.shared.overrideKeys(language: language))
            for (key, file) in keys where !known.contains(key) { missing.append("\(language) \(key) (\(file))") }
        }
        XCTAssertEqual(missing.sorted(), [])
    }
}

/// Phase 6: the two redesigned widgets (Ekadashi, Upcoming).
final class WidgetRedesignTests: XCTestCase {
    private func snapshot(now: Date) throws -> WidgetSnapshot {
        WidgetSnapshot.build(occurrences: try CalendarRepository.bundled().ekadashis(timezone: "IST", language: "en"),
                             timezone: "IST", locationName: "", language: "en", now: now)
    }

    func testBeforeAnEkadashiTheWidgetShowsTheNextOneAndDaysToGo() throws {
        let now = instant("2026-10-08T10:00:00+05:30")
        let snapshot = try snapshot(now: now)
        guard case .next(let item, let days) = snapshot.headline(at: now) else { return XCTFail("expected next") }
        XCTAssertEqual(item.name, "Papankusha Ekadashi")
        XCTAssertEqual(days, 14)
        XCTAssertEqual(snapshot.daysToGo(days), "14 days to go")
        XCTAssertEqual(snapshot.daysToGo(1), "Tomorrow")
    }

    func testOnTheEkadashiTheWidgetShowsProgressUntilParana() throws {
        let probe = try snapshot(now: instant("2026-10-08T10:00:00+05:30")).nextEkadashi!
        let middle = probe.fastingStart.addingTimeInterval(probe.paranaStart.timeIntervalSince(probe.fastingStart) / 2)
        let snapshot = try snapshot(now: middle)
        guard case .today(let item, let progress) = snapshot.headline(at: middle) else { return XCTFail("expected today") }
        XCTAssertEqual(item.id, probe.id)
        XCTAssertEqual(progress, 0.5, accuracy: 0.01)
        XCTAssertEqual(item.fastProgress(at: probe.fastingStart.addingTimeInterval(-60)), 0)
        XCTAssertEqual(item.fastProgress(at: probe.paranaEnd), 1)
        // During Parana the widget stays on today's Ekadashi, fully fasted.
        let parana = probe.paranaStart.addingTimeInterval(60)
        guard case .today(_, let done) = snapshot.headline(at: parana) else { return XCTFail("expected parana") }
        XCTAssertEqual(done, 1)
    }

    func testEveryLanguageHasTheNewWidgetStrings() {
        for language in Localizer.languages {
            for key in ["widget_today_is_ekadashi", "widget_days_to_go", "widget_fast_done"] {
                XCTAssertNotEqual(Localizer.shared.translate(key, language: language), key, "\(language) \(key)")
            }
        }
    }
}
