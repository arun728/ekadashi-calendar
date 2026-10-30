import Foundation
import XCTest
@testable import EkadashiCore

/// Widely searched festivals added in October 2026, checked against Drik
/// Panchang's New Delhi calendars for 2026-2027 and Prokerala's pages
/// (test/fixtures/panchang/searched_festivals.json, searched_festival_test.dart).
final class SearchedFestivalTests: XCTestCase {
    nonisolated(unsafe) private static var calendars: [String: [DatedObservance]] = [:]

    private func fixture() throws -> [String: Any] {
        try Repo.json("test/fixtures/panchang/searched_festivals.json") as! [String: Any]
    }

    private func city(_ id: String) throws -> PanchangCity {
        let row = try fixture().dict("cities")!.dict(id)!
        return PanchangCity(id: id, label: id, latitude: row.double("lat")!, longitude: row.double("lon")!,
                            timeZoneId: row.string("tz")!)
    }

    private func calendar(_ city: PanchangCity, _ year: Int) -> [DatedObservance] {
        let key = "\(city.id)|\(year)"
        if let hit = Self.calendars[key] { return hit }
        let found = PanchangEngine().observanceCalendar(year: year, city: city)
        Self.calendars[key] = found
        return found
    }

    private func festivals() throws -> [[String: Any]] { try fixture().array("festivals") as! [[String: Any]] }

    func testPublishedDates() throws {
        var failures: [String] = []
        for row in try festivals() {
            let id = row.string("id")!, place = try city(row.string("city")!)
            for case let text as String in row.array("dates")! {
                let date = CivilDate(iso: text)!
                let found = calendar(place, date.year).filter { $0.observance.id == id }.map(\.date.iso)
                if found != [text] { failures.append("\(id) \(date.year): \(found) vs \(text)") }
            }
        }
        XCTAssertEqual(failures, [])
    }

    func testTheEngineListsExactlyTheFixtureFestivals() throws {
        XCTAssertEqual(PanchangEngine.searchedFestivalIds, Set(try festivals().map { $0.string("id")! }))
    }

    func testEachHappensOnceAYearAndIsMajor() throws {
        for id in PanchangEngine.searchedFestivalIds {
            for year in [2026, 2027] {
                let found = calendar(.newDelhi, year).filter { $0.observance.id == id }
                XCTAssertEqual(found.count, 1, "\(id) \(year)")
                XCTAssertEqual(found.first?.observance.isMajor, true, id)
            }
        }
    }

    func testSearchableAndNamedInEveryLanguage() throws {
        for id in PanchangEngine.searchedFestivalIds {
            let observance = try XCTUnwrap(calendar(.newDelhi, 2026).first { $0.observance.id == id }?.observance, id)
            let entry = try XCTUnwrap(SearchCatalog.bundled.observance(engineId: id, name: observance.name), id)
            for language in ["en", "hi", "ta", "te", "gu", "bn"] {
                let name = try XCTUnwrap(entry.names[language], "\(id) \(language)")
                if language != "en" {
                    XCTAssertNil(name.range(of: "[A-Za-z]", options: .regularExpression), "\(id) \(language): \(name)")
                }
            }
        }
    }
}
