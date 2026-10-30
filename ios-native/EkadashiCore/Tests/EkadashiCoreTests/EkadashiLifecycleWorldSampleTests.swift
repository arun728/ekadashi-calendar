import XCTest
@testable import EkadashiCore

/// Eight timezone edge anchors plus twelve seeded catalog draws. No device
/// clock, network, platform timezone or non-reproducible Swift Hasher is used.
final class EkadashiLifecycleWorldSampleTests: XCTestCase {
    private func sample() throws -> [PanchangCity] {
        var cities: [PanchangCity] = [.chennai, .london, .newYork, .sydney,
            PanchangCity(id: "sample-kathmandu", label: "Kathmandu", latitude: 27.7172, longitude: 85.3240, timeZoneId: "Asia/Kathmandu"),
            PanchangCity(id: "sample-adelaide", label: "Adelaide", latitude: -34.9285, longitude: 138.6007, timeZoneId: "Australia/Adelaide"),
            PanchangCity(id: "sample-chatham", label: "Waitangi, Chatham Islands", latitude: -43.9535, longitude: -176.5597, timeZoneId: "Pacific/Chatham"),
            PanchangCity(id: "sample-honolulu", label: "Honolulu", latitude: 21.3099, longitude: -157.8581, timeZoneId: "Pacific/Honolulu")]
        var zones = Set(cities.map(\.timeZoneId))
        let catalog = try PanchangCityCatalog.shared.cities()
        func rank(_ city: PanchangCity) -> UInt64 {
            city.id.utf8.reduce(UInt64(0x20261023)) { ($0 ^ UInt64($1)) &* 1099511628211 }
        }
        for region in ["Africa/", "America/", "Asia/", "Australia/", "Europe/", "Pacific/"] {
            // This lifecycle sample has sunrise/sunset; polar-day astronomical
            // fallback policy belongs to the existing engine tests.
            let candidates = catalog.filter { $0.timeZoneId.hasPrefix(region) && abs($0.latitude) <= 55 }
                .sorted { rank($0) == rank($1) ? $0.id < $1.id : rank($0) < rank($1) }
            var draws = 0
            for city in candidates where !zones.contains(city.timeZoneId) {
                try city.validate()
                cities.append(city); zones.insert(city.timeZoneId); draws += 1
                if draws == 2 { break }
            }
            XCTAssertEqual(draws, 2, region)
        }
        XCTAssertEqual(cities.count, 20)
        XCTAssertEqual(zones.count, 20)
        return cities
    }

    func testSeededWorldSampleBothTraditionsAllOccurrencesIn2026And2027() throws {
        let cities = try sample()
        let schedule = EkadashiSchedule(repository: try CalendarRepository.bundled())
        var occurrenceCount = 0
        for city in cities {
            for tradition in EkadashiTradition.allCases {
                let events = try schedule.ekadashis(city: city, tradition: tradition, language: "en", years: [2026, 2027])
                XCTAssertGreaterThanOrEqual(events.count, 48, "\(city.label) \(tradition)")
                occurrenceCount += events.count
                for language in Localizer.languages {
                    let localized = try schedule.ekadashis(city: city, tradition: tradition, language: language, years: [2026, 2027])
                    let payload = WidgetSnapshot.build(occurrences: localized, timezone: city.timeZoneId,
                        locationName: city.label, language: language, now: try XCTUnwrap(events.first?.fastingStart).addingTimeInterval(-172800), tradition: tradition.rawValue)
                    for (index, event) in events.enumerated() {
                        let context = "\(city.label) \(city.timeZoneId) \(tradition) \(language) \(event.date.iso)"
                        let start = try XCTUnwrap(event.fastingStart), parana = try XCTUnwrap(event.paranaStart), end = try XCTUnwrap(event.paranaEnd)
                        guard start < parana, parana <= end else {
                            XCTFail("Invalid interval: \(context) start=\(event.fastingStartISO), Parana=\(event.paranaStartISO)…\(event.paranaEndISO)")
                            continue
                        }
                        let midnight = city.zone.utc(event.date)
                        XCTAssertGreaterThan(start, midnight, context)
                        let before = event.lifecycle(at: midnight, zone: city.zone)
                        XCTAssertEqual(before.phase, .countdown, context)
                        XCTAssertNil(before.progress, context)
                        XCTAssertEqual(before.secondsUntilStart, Int(ceil(start.timeIntervalSince(midnight))), context)
                        XCTAssertEqual(event.lifecycle(at: start.addingTimeInterval(-1), zone: city.zone).countdown, "00:00:01", context)
                        var states: [(Date, EkadashiLifecycle.Phase, Int)] = [
                            (start, .fasting, 0), (start.addingTimeInterval(parana.timeIntervalSince(start) / 2), .fasting, 50),
                            (parana.addingTimeInterval(-1), .fasting, 99)]
                        if parana < end { states += [(parana, .parana, 100), (end.addingTimeInterval(-1), .parana, 100)] }
                        for (instant, phase, percent) in states {
                            let status = event.lifecycle(at: instant, zone: city.zone)
                            XCTAssertEqual(status.phase, phase, context); XCTAssertEqual(status.percent, percent, context)
                            XCTAssertEqual(HomeSelection.index(of: events, now: instant, zone: city.zone, includeParana: true), index, context)
                            guard case .today(let item, let progress) = payload.headline(at: instant) else { XCTFail("Cached widget lost ongoing occurrence: \(context)"); continue }
                            XCTAssertEqual(item.occurrenceUid, event.occurrenceUid, context)
                            XCTAssertEqual(item.completedPercent(at: instant), percent, context)
                            XCTAssertEqual(progress, status.progress!, accuracy: 0.000001, context)
                            if language != "en" { XCTAssertNil(status.label(language: language).range(of: "[A-Za-z]", options: .regularExpression), context) }
                        }
                        let overnight = city.zone.utc(event.date.adding(days: 1))
                        if overnight < end { XCTAssertEqual(payload.headline(at: overnight)?.item.occurrenceUid, event.occurrenceUid, context) }
                        XCTAssertEqual(event.lifecycle(at: end, zone: city.zone).phase, .passed, context)
                        XCTAssertEqual(HomeSelection.index(of: events, now: end, zone: city.zone, includeParana: false), min(index + 1, events.count - 1), context)
                        XCTAssertEqual(payload.headline(at: end)?.item.occurrenceUid, index + 1 < events.count ? events[index + 1].occurrenceUid : nil, context)
                        XCTAssertEqual(payload.upcoming(after: start.addingTimeInterval(-1)).first?.occurrenceUid, event.occurrenceUid, context)
                        XCTAssertFalse(payload.upcoming(after: start).contains { $0.occurrenceUid == event.occurrenceUid }, context)
                        let fastingDay = EkadashiCalendarDay(events: events, day: event.date, zone: city.zone)
                        XCTAssertTrue(fastingDay.showsFastingMarker, context)
                        let paranaDate = city.wallClock(parana).date
                        let paranaDay = EkadashiCalendarDay(events: events, day: paranaDate, zone: city.zone)
                        XCTAssertTrue(paranaDay.parana.contains { $0.occurrenceUid == event.occurrenceUid }, context)
                        if paranaDate != event.date { XCTAssertFalse(paranaDay.showsFastingMarker, context) }
                    }
                }
                print("WORLD SAMPLE: \(city.label) | \(city.timeZoneId) | \(tradition.rawValue) | \(events.count) occurrences")
            }
        }
        print("WORLD SAMPLE TOTAL: \(cities.count) cities/zones, both traditions, \(occurrenceCount) occurrences, all six languages")
    }
}
