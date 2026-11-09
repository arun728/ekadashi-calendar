import Foundation
import XCTest
@testable import EkadashiCore

final class LunarStartDateTests: XCTestCase {
    private let engine = PanchangEngine()
    private let lunarIds: Set<String> = ["purnima", "amavasya"]

    func testBothYearsUseLocalStartDatesWorldwideWithoutEndDayDuplicates() throws {
        let fixture = try Repo.json("test/fixtures/panchang/lunar_start_dates_2026_2027.json") as! [String: Any]
        let intervals = fixture["intervals"] as! [[String: Any]]
        for row in fixture["cities"] as! [[String: Any]] {
            let city = PanchangCity(id: row.string("id")!, label: row.string("label")!,
                                    latitude: row.double("lat")!, longitude: row.double("lon")!,
                                    timeZoneId: row.string("tz")!)
            for year in [2026, 2027] {
                let expected = intervals.compactMap { interval -> String? in
                    let date = city.wallClock(instant(interval.string("start")!)).date
                    guard date.year == year else { return nil }
                    return "\(interval.int("tithi") == 15 ? "purnima" : "amavasya"):\(date.iso)"
                }.sorted()
                let actual = engine.observanceCalendar(year: year, city: city)
                    .filter { lunarIds.contains($0.observance.id) }
                    .map { "\($0.observance.id):\($0.date.iso)" }.sorted()
                XCTAssertEqual(actual, expected, "\(city.id) \(year)")
                XCTAssertEqual(Set(actual).count, actual.count, "one entry per occurrence")
            }
        }
    }

    func testPhaseBoundariesAndEveryOtherChennaiObservanceRemainUnchanged() throws {
        let fixture = try Repo.json("test/fixtures/panchang/lunar_start_dates_2026_2027.json") as! [String: Any]
        for row in fixture["intervals"] as! [[String: Any]] {
            let start = instant(row.string("start")!), end = instant(row.string("end")!)
            let probe = start.addingTimeInterval(60)
            XCTAssertEqual(engine.tithiAt(probe).index, row.int("tithi"))
            XCTAssertEqual(engine.tithiStart(probe).timeIntervalSince1970, start.timeIntervalSince1970, accuracy: 0.01)
            XCTAssertEqual(engine.tithiAt(probe).endsAt!.timeIntervalSince1970, end.timeIntervalSince1970, accuracy: 0.01)
        }
        for row in fixture["other_chennai_observances"] as! [[String: Any]] {
            let date = CivilDate(iso: row.string("date")!)!
            let actual = engine.observances(on: date, city: .chennai)
                .filter { !lunarIds.contains($0.id) }.map(\.id).sorted()
            XCTAssertEqual(actual, row["ids"] as! [String], date.iso)
        }
    }

    func testDailyAndCalendarPathsAgreeOnStartEndAndPolarDays() {
        let polar = PanchangCity(id: "tromso", label: "Tromso", latitude: 69.6492, longitude: 18.9553,
                                 timeZoneId: "Europe/Oslo")
        for city in [PanchangCity.chennai, .newYork, polar] {
            for date in [CivilDate(2026, 11, 8), CivilDate(2026, 11, 9), CivilDate(2027, 6, 18),
                         CivilDate(2027, 12, 12), CivilDate(2027, 12, 13)] {
                XCTAssertEqual(engine.calculate(date, city: city).observances, engine.observances(on: date, city: city))
            }
        }
        XCTAssertTrue(engine.observances(on: CivilDate(2026, 11, 8), city: .chennai).contains { $0.id == "amavasya" })
        XCTAssertFalse(engine.observances(on: CivilDate(2026, 11, 9), city: .chennai).contains { $0.id == "amavasya" })
        XCTAssertTrue(engine.observances(on: CivilDate(2027, 6, 18), city: polar).contains { $0.id == "purnima" })
    }
}

final class ObservanceCategoryTests: XCTestCase {
    func testEveryCategoryKeepsFestivalItemsInFestivalsAndNameSearchStillFindsThem() {
        let date = CivilDate(2027, 7, 18)
        for category in SearchCategory.filters where category != .festival && category != .myCalendar && category != .ekadashi {
            let plain = SearchItem(id: "monthly", target: .observance(key: "monthly", date: date),
                                   categories: [category], title: "Monthly", titleEnglish: "Monthly",
                                   names: ["Monthly"], text: "", date: date, requiresPremium: true)
            let festival = SearchItem(id: "festival", target: .observance(key: "festival", date: date),
                                      categories: [.festival, category], title: "Guru Purnima", titleEnglish: "Guru Purnima",
                                      names: ["Guru Purnima"], text: "", date: date, requiresPremium: true)
            let search = UnifiedSearch(items: [plain, festival])
            XCTAssertEqual(search.search("", category: category, year: 2027, today: date).map(\.id), ["monthly"])
            XCTAssertTrue(search.search("guru", category: category, year: 2027, today: date).isEmpty)
            XCTAssertEqual(search.search("", category: .festival, year: 2027, today: date).map(\.id), ["festival"])
            XCTAssertEqual(Set(search.search("", year: 2027, today: date).map(\.id)), ["monthly", "festival"])
            let days = [KeyDay(id: "monthly", key: "monthly", date: date, title: "Monthly", categories: [category],
                               requiresPremium: true),
                        KeyDay(id: "festival", key: "festival", date: date, title: "Festival", categories: [.festival, category],
                               requiresPremium: true)]
            XCTAssertEqual(PanchangKeyDays.filter(days, category: category).map(\.id), ["monthly"])
            XCTAssertEqual(PanchangKeyDays.filter(days, category: .festival).map(\.id), ["festival"])
        }
        let festival = SearchItem(id: "guru", target: .observance(key: "guru-purnima", date: date),
                                 categories: [.festival, .purnima], title: "Guru Purnima", titleEnglish: "Guru Purnima",
                                 names: ["Guru Purnima"], text: "", date: date, requiresPremium: true)
        let search = UnifiedSearch(items: [festival])
        XCTAssertEqual(search.search("guru purnima", today: date).map(\.id), ["guru"])
        XCTAssertTrue(search.search("purnima", today: date).isEmpty)
        XCTAssertTrue(search.search("", category: .festival, year: 2026, today: date).isEmpty)
    }

    func testMonthlyVinayakaNameIsTranslatedAndAnnualGaneshNameIsPreserved() throws {
        let fixture = try Repo.json("test/fixtures/panchang/lunar_start_dates_2026_2027.json") as! [String: Any]
        let names = fixture["monthly_names"] as! [String: String]
        let monthly = PanchangObservance(id: "vinayaka-chaturthi", name: "Vinayaka Chaturthi (monthly)",
                                         ruleSource: "calculated", description: "", isMajor: true)
        let annual = PanchangObservance(id: "vinayaka-chaturthi", name: "Ganesh Chaturthi",
                                        ruleSource: "calculated", description: "", isMajor: true)
        for (language, expected) in names {
            XCTAssertEqual(PanchangTerms.shared.observanceName(monthly, language: language), expected)
            let dated = DatedObservance(date: CivilDate(2027, 2, 9), observance: monthly)
            let items = SearchCorpus.observanceItems([dated], language: language)
            XCTAssertEqual(items.first?.title, expected)
            let days = PanchangKeyDays.month(dated.date, observances: [dated], ekadashis: [], language: language)
            XCTAssertEqual(days.first?.title, expected)
        }
        XCTAssertEqual(PanchangTerms.shared.observanceName(annual, language: "en"), "Ganesh Chaturthi")
        XCTAssertEqual(SearchCatalog.bundled.observance(engineId: annual.id, name: annual.name)?.key, "ganesh-chaturthi")
    }
}
