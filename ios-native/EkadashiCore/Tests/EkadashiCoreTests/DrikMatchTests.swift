import Foundation
import XCTest
@testable import EkadashiCore

/// Every time the app shows matches Drik Panchang to the minute, from the
/// same reference as test/unit/drik_match_test.dart
/// (test/fixtures/panchang/drik_reference.json; docs/PANCHANG_ACCURACY.md
/// "Drik time base"): Drik rounds to the nearest minute, its tithi,
/// nakshatra, yoga and karana moments are those of the Sun and Moon one
/// Delta T later than the astronomical moment, and its Lahiri ayanamsa is
/// the mean value plus 24.2″. Values within a few seconds of a half minute
/// can round either way and are counted but not required.
final class DrikMatchTests: XCTestCase {
    let engine = PanchangEngine()

    private func fixture() throws -> [String: Any] {
        try Repo.json("test/fixtures/panchang/drik_reference.json") as! [String: Any]
    }

    private func city(_ row: [String: Any], id: String? = nil) -> PanchangCity {
        PanchangCity(id: id ?? row.string("id") ?? row.string("city")!, label: row.string("label") ?? row.string("city")!,
                     latitude: row.double("lat")!, longitude: row.double("lon")!, timeZoneId: row.string("tz")!)
    }

    private func hm(_ instant: Date, _ city: PanchangCity) -> String {
        let local = city.displayClock(instant)
        return "\(pad2(local.hour)):\(pad2(local.minute))"
    }

    private func stamp(_ instant: Date, _ city: PanchangCity) -> String {
        let local = city.displayClock(instant)
        return "\(local.date.iso) \(hm(instant, city))"
    }

    /// Seconds between the exact local time and the nearest half minute.
    private func edge(_ instant: Date, _ city: PanchangCity) -> Double {
        let local = instant.timeIntervalSince1970 + Double(city.wallClock(instant).offsetSeconds)
        let seconds = local - 60 * (local / 60).rounded(.down)
        return abs(seconds - 30)
    }

    /// Shown values must match unless they sit on a half minute; returns the matched share.
    private func check(_ rows: [(String, Date?, String)], city: PanchangCity, knifeEdge: Double,
                       file: StaticString = #filePath, line: UInt = #line) -> Double {
        var failures: [String] = [], matched = 0
        for (label, actual, expected) in rows {
            guard let actual else { failures.append("\(label): none vs \(expected)"); continue }
            let shown = expected.count > 5 ? stamp(actual, city) : hm(actual, city)
            if shown == expected { matched += 1 } else if edge(actual, city) > knifeEdge {
                failures.append("\(label): shows \(shown), Drik \(expected)")
            }
        }
        XCTAssertEqual(failures, [], file: file, line: line)
        return Double(matched) / Double(max(rows.count, 1))
    }

    private func fasts(_ city: PanchangCity, _ tradition: EkadashiTradition, start: CivilDate, count: Int) throws
        -> [String: CalculatedEkadashi] {
        Dictionary(try CalculatedEkadashiEngine().calculate(start: start, count: count, city: city, tradition: tradition)
            .map { ($0.date.iso, $0) }, uniquingKeysWith: { a, _ in a })
    }

    private func delhiFasts(_ tradition: EkadashiTradition) throws -> [String: CalculatedEkadashi] {
        let delhi = city(try fixture().dict("city")!)
        return try fasts(delhi, tradition, start: CivilDate(2026, 1, 1), count: 365)
            .merging(try fasts(delhi, tradition, start: CivilDate(2027, 1, 1), count: 365)) { a, _ in a }
    }

    /// "2026-11-20 06:31" (IST) as an instant.
    private func ist(_ text: String) -> Date {
        instant(text.replacingOccurrences(of: " ", with: "T") + ":00+05:30")
    }

    func testDisplayRoundsToTheNearestMinuteInEveryTimeZone() throws {
        let delhi = city(try fixture().dict("city")!)
        let before = utc(2026, 11, 20, 0, 40, 29).addingTimeInterval(0.999)
        let after = utc(2026, 11, 20, 0, 40, 30)
        XCTAssertEqual(delhi.displayClock(before).minute, 10)
        XCTAssertEqual(delhi.displayClock(after).minute, 11)
        XCTAssertEqual(delhi.displayClock(after).second, 0)
        for (zone, offset) in [("Asia/Kathmandu", 345), ("Pacific/Chatham", 765), ("America/St_Johns", -150),
                               ("America/New_York", -240)] {
            let place = PanchangCity(id: zone, label: zone, latitude: 0, longitude: 0, timeZoneId: zone)
            let moment = utc(2026, 7, 1, 12, 0, 40)
            let expected = moment.addingTimeInterval(Double(offset * 60 + 20))
            let local = place.displayClock(moment)
            let utcCalendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()
            XCTAssertEqual([local.hour, local.minute],
                           [utcCalendar.component(.hour, from: expected), utcCalendar.component(.minute, from: expected)], zone)
        }
        XCTAssertEqual(PanchangFormat.time(after, city: delhi, date: CivilDate(2026, 11, 20), language: "en"),
                       Localizer.shared.clock(hour: 6, minute: 11, language: "en"))
        XCTAssertEqual(EkadashiSchedule.iso(after, delhi.zone), "2026-11-20T06:11:00+05:30")
        XCTAssertTrue(formatPanchangTime(after, city: delhi, date: CivilDate(2026, 11, 20)).hasPrefix("6:11 AM"))
        // 23:59:45 IST rounds into the next day, with the next-day marker.
        let midnight = utc(2026, 11, 20, 18, 29, 45)
        XCTAssertTrue(PanchangFormat.time(midnight, city: delhi, date: CivilDate(2026, 11, 20), language: "en")
            .contains(Localizer.shared.clock(hour: 0, minute: 0, language: "en")))
        XCTAssertTrue(formatPanchangTime(midnight, city: delhi, date: CivilDate(2026, 11, 20)).hasSuffix("(+1 day)"))
    }

    func testLahiriAyanamsaAndPositionsFollowDrik() throws {
        func degrees(_ dms: String) -> Double {
            let parts = dms.split(whereSeparator: { "°′″".contains($0) }).compactMap { Double($0) }
            return parts[0] + parts[1] / 60 + parts[2] / 3600
        }
        func arcsec(_ a: Double, _ b: Double) -> Double { abs(AstronomyCalculator.signedAngle(a - b)) * 3600 }
        for case let row as [String: Any] in try fixture().array("positions")! {
            let moment = ist(String(row.string("ist")!.prefix(16)))
            let tropical = row.dict("tropical")!, sidereal = row.dict("sidereal")!
            let ayanamsa = AstronomyCalculator.signedAngle(degrees(tropical.string("sun")!) - degrees(sidereal.string("sun")!))
            XCTAssertLessThan(arcsec(AstronomyCalculator.drikLahiriAyanamsa(moment), ayanamsa), 2, "ayanamsa \(moment)")
            XCTAssertLessThan(arcsec(AstronomyCalculator.drikSunLongitude(moment), degrees(tropical.string("sun")!)), 1.6)
            XCTAssertLessThan(arcsec(AstronomyCalculator.drikMoonLongitude(moment), degrees(tropical.string("moon")!)), 6)
        }
    }

    func testEkadashiTithiBeginsAndEndsShowDriksMinute() throws {
        let data = try fixture(), delhi = city(data.dict("city")!)
        var rows: [(String, Date?, String)] = []
        for (tradition, key) in [(EkadashiTradition.smarta, "smarta"), (.gaudiya, "vaishnava")] {
            let found = try delhiFasts(tradition)
            for case let row as [String: Any] in data.array(key)! {
                guard let fast = found[row.string("date")!] else { continue }
                rows.append(("\(key) \(fast.date) begins", fast.tithiStart, row.string("tithiBegins")!))
                rows.append(("\(key) \(fast.date) ends", fast.tithiEnd, row.string("tithiEnds")!))
            }
        }
        XCTAssertGreaterThanOrEqual(check(rows, city: delhi, knifeEdge: 6), 0.97)
        // Two Vaishnava fasts fall a day after Drik's list (GCal 11, below).
        XCTAssertGreaterThanOrEqual(rows.count, 192)
    }

    func testHeldOut2028TithiBoundariesShowDriksMinute() throws {
        let data = try fixture(), delhi = city(data.dict("city")!)
        var ends: [Date] = []
        for offset in -2..<370 {
            // The sunrise tithi's end and the next one's, so a tithi touching no sunrise counts too.
            if let end = engine.calculate(CivilDate(2028, 1, 1).adding(days: offset), city: delhi).tithi.endsAt {
                ends.append(end)
                if let next = engine.tithiAt(end.addingTimeInterval(1)).endsAt { ends.append(next) }
            }
        }
        let rows: [(String, Date?, String)] = (data.array("heldOut2028TithiBoundaries") as! [String]).map { text in
            let drik = ist(text)
            return ("2028 \(text)", ends.min { abs($0.timeIntervalSince(drik)) < abs($1.timeIntervalSince(drik)) }, text)
        }
        XCTAssertGreaterThanOrEqual(check(rows, city: delhi, knifeEdge: 6), 0.95)
    }

    func testSmartaFastDaysHariVasaraDwadashiEndAndParanaMatchDrik() throws {
        let data = try fixture(), delhi = city(data.dict("city")!)
        let found = try delhiFasts(.smarta)
        var rows: [(String, Date?, String)] = [], dates = Set<String>()
        for case let row as [String: Any] in data.array("smarta")! {
            let date = row.string("date")!
            dates.insert(date)
            guard let fast = found[date] else { XCTFail("Smarta \(date)"); continue }
            XCTAssertEqual(fast.paranaDate.iso, row.string("paranaDate"))
            if let value = row.string("hariVasara") { rows.append(("\(date) Hari Vasara", fast.hariVasaraEnd, value)) }
            if let value = row.string("dwadashiEnd") {
                rows.append(("\(date) Dwadashi end", engine.tithiAt(fast.tithiEnd.addingTimeInterval(1)).endsAt, value))
            }
            if let value = row.string("paranaStart") { rows.append(("\(date) Parana start", fast.paranaStart, value)) }
            if let value = row.string("paranaEnd") { rows.append(("\(date) Parana end", fast.paranaEnd, value)) }
        }
        XCTAssertGreaterThanOrEqual(check(rows, city: delhi, knifeEdge: 9), 0.9)
        XCTAssertEqual(Set(found.keys).subtracting(dates), [], "engine only")
        XCTAssertEqual(dates.subtracting(found.keys), [], "Drik only")
    }

    func testVaishnavaFastsFollowGcalWithinMinutesOfDrik() throws {
        // Vaishnava fasts and Parana follow GCal 11, as ISKCON publishes them
        // (IskconParityTests). Drik's own ISKCON list differs on two days,
        // where a Purnima or Shravana boundary sits within 20 seconds of
        // sunrise, and its Parana is up to 3 minutes apart: Drik rounds and
        // uses its own astronomy; GCal cuts the minute and uses GCal's.
        let data = try fixture(), delhi = city(data.dict("city")!)
        let found = try delhiFasts(.gaudiya)
        let expected = data.array("vaishnava") as! [[String: Any]]
        let gcalDays = ["2026-06-25": "2026-06-26", "2027-09-11": "2027-09-12"]
        XCTAssertEqual(Set(found.keys), Set(expected.map { gcalDays[$0.string("date")!] ?? $0.string("date")! }))
        var far: [String] = []
        for row in expected {
            guard let fast = found[row.string("date")!] else { continue }
            for (actual, drik) in [(fast.paranaStart, row.string("paranaStart")), (fast.paranaEnd, row.string("paranaEnd"))] {
                guard let drik else { continue }
                guard let actual else { far.append("\(fast.date): none vs \(drik)"); continue }
                let shown = delhi.displayClock(actual)
                let minutes = shown.hour * 60 + shown.minute - (Int(drik.prefix(2))! * 60 + Int(drik.suffix(2))!)
                if abs(minutes) > 3 { far.append("\(fast.date): \(hm(actual, delhi)) vs \(drik)") }
            }
        }
        XCTAssertEqual(far, [])
    }

    func testSunriseAndSunsetShowDriksMinuteOnAll730Days() throws {
        let data = try fixture(), delhi = city(data.dict("city")!)
        var sunrise: [(String, Date?, String)] = [], sunset: [(String, Date?, String)] = []
        for (date, value) in data.dict("sun")! {
            let times = value as! [String]
            let day = engine.calculate(CivilDate(iso: date)!, city: delhi)
            sunrise.append(("\(date) sunrise", day.sunrise, times[0]))
            sunset.append(("\(date) sunset", day.sunset, times[1]))
        }
        XCTAssertGreaterThanOrEqual(check(sunrise, city: delhi, knifeEdge: 9), 0.92)
        XCTAssertGreaterThanOrEqual(check(sunset, city: delhi, knifeEdge: 9), 0.93)
    }

    func testNakshatraEndsFollowDriksAyanamsaAndTimeBase() throws {
        let data = try fixture(), delhi = city(data.dict("city")!)
        var ends: [Date] = []
        for offset in -1..<732 {
            if let end = engine.calculate(CivilDate(2026, 1, 1).adding(days: offset), city: delhi).nakshatra.endsAt {
                ends.append(end)
            }
        }
        var matched = 0, total = 0
        for text in data.array("nakshatraEnds") as! [String] {
            let drik = ist(text)
            guard let nearest = ends.min(by: { abs($0.timeIntervalSince(drik)) < abs($1.timeIntervalSince(drik)) }),
                  abs(nearest.timeIntervalSince(drik)) <= 300 else { continue }
            total += 1
            if stamp(nearest, delhi) == text { matched += 1 }
        }
        XCTAssertGreaterThan(total, 690)
        XCTAssertGreaterThanOrEqual(Double(matched) / Double(total), 0.92)
    }

    func testSmartaDaysAndEkadashiTimesMatchDrikWorldwide() throws {
        // London, New York and Los Angeles (northern DST), Sydney (southern
        // DST), Kathmandu (UTC+5:45) and Chennai, at Drik's coordinates.
        for case let place as [String: Any] in try fixture().array("world2026")! {
            let site = city(place, id: place.string("city")!)
            let found = try fasts(site, .smarta, start: CivilDate(2025, 12, 31), count: 366).filter { $0.key.hasPrefix("2026") }
            var rows: [(String, Date?, String)] = []
            let expected = place.array("fasts") as! [[String: Any]]
            for row in expected {
                guard let fast = found[row.string("date")!] else { continue }
                rows.append(("\(site.id) \(fast.date) begins", fast.tithiStart, row.string("tithiBegins")!))
                rows.append(("\(site.id) \(fast.date) ends", fast.tithiEnd, row.string("tithiEnds")!))
            }
            XCTAssertGreaterThanOrEqual(check(rows, city: site, knifeEdge: 6), 0.95, site.id)
            XCTAssertEqual(Set(found.keys), Set(expected.map { $0.string("date")! }), site.id)
        }
    }

    func testMoonriseAndMoonsetFollowDrik() throws {
        // Disc centre, no refraction, the first after sunrise (Drik's day runs sunrise to sunrise).
        let data = try fixture(), delhi = city(data.dict("city")!)
        var rise: [(String, Date?, String)] = [], set: [(String, Date?, String)] = []
        for case let row as [String: Any] in data.array("moon")! {
            let day = engine.calculate(CivilDate(iso: row.string("date")!)!, city: delhi)
            rise.append(("\(row.string("date")!) moonrise", day.moonrise, row.string("moonrise")!))
            set.append(("\(row.string("date")!) moonset", day.moonset, row.string("moonset")!))
        }
        XCTAssertGreaterThanOrEqual(check(rise, city: delhi, knifeEdge: 6), 0.9)
        XCTAssertGreaterThanOrEqual(check(set, city: delhi, knifeEdge: 6), 0.9)
    }
}
