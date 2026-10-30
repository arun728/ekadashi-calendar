import Foundation
import XCTest
@testable import EkadashiCore

/// The Ekadashi dates and times on Home and Calendar come from the Panchang
/// engine for the chosen city and tradition, keeping the published identities
/// and texts (docs/EKADASHI_ENGINE_SCHEDULE.md).
final class EkadashiScheduleTests: XCTestCase {
    private static let repository = try! CalendarRepository.bundled()
    private static let schedule = EkadashiSchedule(repository: repository)
    private var schedule: EkadashiSchedule { Self.schedule }

    private static let chennai = PanchangCity(id: "geonames-1264527", label: "Chennai (IN)", latitude: 13.08784,
                                              longitude: 80.27847, timeZoneId: "Asia/Kolkata")
    private static let newDelhi = PanchangCity(id: "geonames-1261481", label: "New Delhi (IN)", latitude: 28.62137,
                                               longitude: 77.2148, timeZoneId: "Asia/Kolkata")

    private func published(_ year: Int) throws -> [[String: Any]] {
        (try Repo.json("assets/calendar/\(year).json") as! [String: Any])["ekadashis"] as! [[String: Any]]
    }

    private func ist(_ row: [String: Any], _ field: String) -> String {
        ((row["timing"] as! [String: Any])["IST"] as! [String: Any])[field] as! String
    }

    private func minutesApart(_ a: String, _ b: String) -> Double {
        secondsBetween(ISO8601.instant(a), ISO8601.instant(b)) / 60
    }

    /// Home (and everything that follows it) shows exactly what the Panchang
    /// tab's Ekadashi sub-tab shows: same dates, and the same hour and minute
    /// for the fast start and the Parana window, which the sub-tab reads
    /// from the engine's instants month by month, rounded to the nearest
    /// minute as Drik Panchang shows them.
    func testHomeTimesMatchThePanchangEkadashiSubTabWorldwide() throws {
        let ids = ["1264527", "1261481", "1275339", "5128581", "5368361", "2643743", "2925533", "2147714", "1880252", "292223"]
        let all = try PanchangCityCatalog.shared.cities()
        let cities = ids.map { id in all.first { $0.id == "geonames-\(id)" }! }
        var mismatches: [String] = []
        for city in cities {
            for tradition in EkadashiTradition.allCases {
                for year in [2026, 2027] {
                    var panel: [CalculatedEkadashi] = []
                    for month in 1...12 {
                        let first = CivilDate(year, month, 1)
                        panel += try CalculatedEkadashiEngine().calculate(start: first, count: first.daysInMonth, city: city,
                                                                          tradition: tradition)
                    }
                    let home = try schedule.scheduled(EkadashiScheduleKey(city: city, tradition: tradition, year: year))
                    if home.map(\.date) != panel.map(\.date.iso) {
                        mismatches.append("\(city.label) \(tradition) \(year) dates")
                        continue
                    }
                    func same(_ iso: String, _ instant: Date?, _ what: String, _ fast: CalculatedEkadashi) {
                        guard let instant else { return }
                        let wall = city.displayClock(instant)
                        let shown = ISO8601.wallClockTime(iso)
                        if shown?.hour != wall.hour || shown?.minute != wall.minute || !iso.hasPrefix(wall.date.iso) {
                            mismatches.append("\(city.label) \(tradition) \(fast.date.iso) \(what): home \(iso) panchang \(wall.date.iso) \(wall.hour):\(wall.minute)")
                        }
                    }
                    for (row, fast) in zip(home, panel) {
                        same(row.fastingStart, fast.fastStarts, "fast start", fast)
                        same(row.paranaStart, fast.paranaStart, "parana start", fast)
                        same(row.paranaEnd, fast.paranaEnd, "parana end", fast)
                    }
                }
            }
        }
        XCTAssertEqual(mismatches.count, 0, mismatches.prefix(12).joined(separator: "\n"))
    }

    func testEnabledYearsComeFromTheSharedConfig() throws {
        XCTAssertEqual(EkadashiYears.enabled(), [2026, 2027])
        XCTAssertEqual(try Repo.data("assets/calendar/ekadashi_years.json"),
                       try Repo.data("ios-native/EkadashiCore/Sources/EkadashiCore/Resources/calendar/ekadashi_years.json"))
        XCTAssertEqual(EkadashiYears.defaultYear(today: CivilDate(2026, 10, 13)), 2026)
        XCTAssertEqual(EkadashiYears.defaultYear(today: CivilDate(2028, 2, 1)), 2027)
        XCTAssertEqual(EkadashiYears.defaultYear(today: CivilDate(2025, 12, 31)), 2026)
    }

    /// The 2026 pack is Chennai's Smarta schedule: every date and identity
    /// matches; two published fasting starts are typos (sunrise is earlier).
    func testChennaiSmarta2026MatchesThePublishedSchedule() throws {
        let rows = try published(2026)
        let fasts = try schedule.scheduled(EkadashiScheduleKey(city: Self.chennai, tradition: .smarta, year: 2026))
        XCTAssertEqual(fasts.map(\.occurrenceUid), rows.map { $0["occurrence_uid"] as! String })
        XCTAssertEqual(fasts.map(\.date), rows.map { ist($0, "date") })
        XCTAssertEqual(fasts.map(\.notificationId), rows.map { $0["notification_id"] as! Int })
        let typos: Set<String> = ["varuthini-ekadashi", "indira-ekadashi"]
        for (fast, row) in zip(fasts, rows) where !typos.contains(fast.contentId) {
            XCTAssertLessThanOrEqual(minutesApart(fast.fastingStart, ist(row, "fasting_start")), 2, fast.contentId)
        }
    }

    /// The 2027 pack is New Delhi's Smarta schedule; the engine also finds
    /// the year's 25th Ekadashi (Saphala, 23 Dec), which the pack lacks.
    func testNewDelhiSmarta2027KeepsIdentitiesAndAddsTheDecemberSaphala() throws {
        let rows = try published(2027)
        let fasts = try schedule.scheduled(EkadashiScheduleKey(city: Self.newDelhi, tradition: .smarta, year: 2027))
        XCTAssertEqual(fasts.count, 25)
        for (fast, row) in zip(fasts, rows) {
            XCTAssertEqual(fast.occurrenceUid, row["occurrence_uid"] as? String)
            XCTAssertEqual(fast.date, ist(row, "date"))
            for (mine, theirs) in [("fastingStart", "fasting_start"), ("paranaStart", "parana_start"), ("paranaEnd", "parana_end")] {
                let value = [ "fastingStart": fast.fastingStart, "paranaStart": fast.paranaStart, "paranaEnd": fast.paranaEnd][mine]!
                XCTAssertLessThanOrEqual(minutesApart(value, ist(row, theirs)), 1, "\(fast.contentId) \(mine)")
            }
        }
        let saphala = fasts.last!
        XCTAssertEqual(saphala.date, "2027-12-23")
        XCTAssertEqual(saphala.contentId, "saphala-ekadashi")
        XCTAssertEqual(saphala.occurrenceUid, "ekadashi:2027:25")
        XCTAssertEqual(saphala.notificationId, 2_027_025)
        XCTAssertNil(saphala.publishedUid)
        let english = try schedule.ekadashis(city: Self.newDelhi, tradition: .smarta, language: "en", years: [2027])
        XCTAssertEqual(english.last?.name, "Saphala Ekadashi")
        XCTAssertFalse(english.last!.story.isEmpty)
        XCTAssertEqual(Set(english.map(\.id)).count, 25, "notification ids stay unique")
    }

    /// A Vaishnava fast a day after the Smarta one is the same Ekadashi: it
    /// keeps the published identity (Vrat records and reminders follow it).
    func testGaudiyaShiftKeepsThePublishedIdentity() throws {
        let smarta = try schedule.scheduled(EkadashiScheduleKey(city: Self.chennai, tradition: .smarta, year: 2026))
        let gaudiya = try schedule.scheduled(EkadashiScheduleKey(city: Self.chennai, tradition: .gaudiya, year: 2026))
        XCTAssertEqual(Set(gaudiya.map(\.occurrenceUid)), Set(smarta.map(\.occurrenceUid)))
        let yogini = gaudiya.first { $0.contentId == "yogini-ekadashi" }!
        XCTAssertEqual(yogini.date, "2026-07-11")
        XCTAssertEqual(yogini.occurrenceUid, smarta.first { $0.contentId == "yogini-ekadashi" }!.occurrenceUid)
        // Gaudiya Parana runs to the earlier of tithi end and a third of daylight.
        XCTAssertEqual(ISO8601.wallClockTime(yogini.paranaEnd)?.hour, 10)
    }

    /// Outside India the dates are the local ones, in the city's time zone.
    func testNewYorkUsesLocalDatesAndOffsets() throws {
        let newYork = PanchangCity(id: "geonames-5128581", label: "New York City (US)", latitude: 40.71427,
                                   longitude: -74.00597, timeZoneId: "America/New_York")
        let fasts = try schedule.scheduled(EkadashiScheduleKey(city: newYork, tradition: .smarta, year: 2026))
        let mohini = fasts.first { $0.contentId == "mohini-ekadashi" }!
        XCTAssertEqual(mohini.date, "2026-04-27")
        XCTAssertTrue(mohini.fastingStart.hasSuffix("-04:00"))
        XCTAssertEqual(mohini.occurrenceUid, try published(2026).first { $0["content_id"] as? String == "mohini-ekadashi" }!["occurrence_uid"] as? String)
    }

    /// A year without a pack: numbered in date order, texts reused by Ekadashi
    /// in every language. Enabling 2028 needs only ekadashi_years.json.
    func testAFutureYearNeedsNoNewData() throws {
        let fasts = try schedule.ekadashis(city: Self.chennai, tradition: .smarta, language: "ta", years: [2028])
        XCTAssertTrue((24...25).contains(fasts.count))
        XCTAssertEqual(fasts.first?.occurrenceUid, "ekadashi:2028:01")
        XCTAssertEqual(fasts.first?.id, 2_028_001)
        for fast in fasts {
            XCTAssertFalse(fast.usesContentFallback, fast.contentId)
            XCTAssertFalse(fast.name.isEmpty)
            XCTAssertFalse(fast.story.isEmpty)
            XCTAssertNotNil(fast.fastingStart)
            XCTAssertNotNil(fast.paranaEnd)
            XCTAssertGreaterThan(fast.paranaEnd!, fast.paranaStart!)
        }
    }

    /// Every name the engine gives, in normal and Adhika years, has texts.
    func testEveryEngineNameHasPublishedContent() throws {
        for year in [2026, 2028, 2029] {
            for tradition in EkadashiTradition.allCases {
                for fast in try schedule.scheduled(EkadashiScheduleKey(city: Self.newDelhi, tradition: tradition, year: year)) {
                    XCTAssertNotNil(Self.repository.contentRow(id: fast.contentId), "\(year) \(fast.contentId)")
                }
            }
        }
    }

    func testCalculatedYearsAreCachedOnDisk() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("schedule-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let key = EkadashiScheduleKey(city: Self.chennai, tradition: .smarta, year: 2027)
        let first = EkadashiSchedule(repository: Self.repository, cacheDirectory: folder)
        XCTAssertFalse(first.isCached(key))
        let calculated = try first.scheduled(key)
        let second = EkadashiSchedule(repository: Self.repository, cacheDirectory: folder)
        XCTAssertTrue(second.isCached(key))
        XCTAssertEqual(try second.scheduled(key), calculated)
    }

    func testEngineNamesMapToPublishedContentIds() {
        XCTAssertEqual(EkadashiSchedule.contentId(forEngineName: "Devutthana Ekadashi"), "prabodhini-ekadashi")
        XCTAssertEqual(EkadashiSchedule.contentId(forEngineName: "Shravana Putrada Ekadashi"), "shravana-putrada-ekadashi")
        XCTAssertEqual(EkadashiSchedule.monthKey("Ashvina"), "ashwin")
        XCTAssertEqual(EkadashiSchedule.monthKey("Adhika Jyeshtha"), "adhika")
    }

    func testOneYearForOneCityIsQuick() throws {
        let city = PanchangCity(id: "perf", label: "Perf", latitude: 19.07, longitude: 72.88, timeZoneId: "Asia/Kolkata")
        let started = Date()
        _ = try EkadashiSchedule(repository: Self.repository)
            .scheduled(EkadashiScheduleKey(city: city, tradition: .gaudiya, year: 2027))
        let seconds = Date().timeIntervalSince(started)
        print("One city, one year, one tradition: \(String(format: "%.2f", seconds)) s")
        XCTAssertLessThan(seconds, 20)
    }
}
