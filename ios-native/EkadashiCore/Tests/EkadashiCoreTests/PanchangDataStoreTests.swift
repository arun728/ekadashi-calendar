import XCTest
@testable import EkadashiCore

final class PanchangDataStoreTests: XCTestCase {
    private let month = CivilDate(2026, 10, 1)

    func testCachedLoadMeasurementsForAllFiveSubtabs() async throws {
        let store = PanchangDataStore()
        for pass in ["first", "repeat"] {
            var start = Date.timeIntervalSinceReferenceDate
            _ = await store.observances(month: month, city: .chennai)
            print("PANCHANG_OPTIMIZED \(pass) keydays_ms=\((Date.timeIntervalSinceReferenceDate-start)*1000)")
            for page in ["daily", "muhurta", "rashi"] {
                start = Date.timeIntervalSinceReferenceDate
                let day = await store.day(month, city: .chennai)
                XCTAssertEqual(day.city, .chennai)
                print("PANCHANG_OPTIMIZED \(pass) \(page)_ms=\((Date.timeIntervalSinceReferenceDate-start)*1000)")
            }
            for tradition in EkadashiTradition.allCases {
                start = Date.timeIntervalSinceReferenceDate
                _ = try await store.fasts(month: month, city: .chennai, tradition: tradition)
                print("PANCHANG_OPTIMIZED \(pass) ekadashi_\(tradition.rawValue)_ms=\((Date.timeIntervalSinceReferenceDate-start)*1000)")
            }
        }
    }

    func testKeyDaysCalculatesOnlyTheVisibleMonthAndCoalescesConcurrentLoads() async {
        let dates = Locked<[CivilDate]>([])
        let store = PanchangDataStore(observances: { date, _ in
            dates.withLock { $0.append(date) }
            return []
        })
        async let first = store.observances(month: month, city: .chennai)
        async let second = store.observances(month: month.adding(days: 25), city: .chennai)
        _ = await (first, second)
        XCTAssertEqual(dates.withLock { $0 }, (0..<31).map { month.adding(days: $0) })
        _ = await store.observances(month: month, city: .chennai)
        XCTAssertEqual(dates.withLock { $0.count }, 31, "Revisits and language changes reuse unlocalized data")
    }

    func testYearConsumersReuseTheVisibleMonthAndPreserveDayOrderAndLeapDay() async {
        let calls = Locked<[CivilDate]>([])
        let store = PanchangDataStore(observances: { date, _ in calls.withLock { $0.append(date) }; return [] })
        _ = await store.observances(month: CivilDate(2028, 2, 15), city: .chennai)
        _ = await store.observances(year: 2028, city: .chennai)
        let dates = calls.withLock { $0 }
        XCTAssertEqual(dates.count, 366)
        XCTAssertEqual(Set(dates).count, 366)
        XCTAssertTrue(dates.contains(CivilDate(2028, 2, 29)))
    }

    func testDailyMuhurtaAndRashiShareOneCalculationAndUseCompletePlaceKeys() async {
        let calls = Locked<Int>(0)
        let fixture = PanchangEngine().calculate(month, city: .chennai)
        let store = PanchangDataStore(day: { _, _ in calls.withLock { $0 += 1 }; return fixture })
        async let daily = store.day(month, city: .chennai)
        async let muhurta = store.day(month, city: .chennai)
        async let rashi = store.day(month, city: .chennai)
        _ = await (daily, muhurta, rashi)
        _ = await store.day(month, city: .chennai)
        XCTAssertEqual(calls.withLock { $0 }, 1)
        let moved = PanchangCity(id: PanchangCity.chennai.id, label: "Chennai", latitude: 40, longitude: -74, timeZoneId: "America/New_York")
        let zoneChanged = PanchangCity(id: moved.id, label: moved.label, latitude: moved.latitude, longitude: moved.longitude, timeZoneId: "UTC")
        _ = await store.day(month, city: moved)
        _ = await store.day(month, city: zoneChanged)
        _ = await store.day(month.adding(days: 1), city: zoneChanged)
        XCTAssertEqual(calls.withLock { $0 }, 4)
    }

    func testEkadashiCachesBothTraditionsSeparatelyAndRetriesFailures() async throws {
        enum Failure: Error { case sample }
        let calls = Locked<Int>(0)
        let store = PanchangDataStore(fasts: { _, _, _ in
            let count = calls.withLock { $0 += 1; return $0 }
            if count == 1 { throw Failure.sample }
            return []
        })
        do { _ = try await store.fasts(month: month, city: .chennai, tradition: .smarta); XCTFail("Expected error") } catch {}
        async let first = store.fasts(month: month, city: .chennai, tradition: .smarta)
        async let second = store.fasts(month: month, city: .chennai, tradition: .smarta)
        _ = try await (first, second)
        _ = try await store.fasts(month: month, city: .chennai, tradition: .gaudiya)
        _ = try await store.fasts(month: month, city: .chennai, tradition: .gaudiya)
        _ = try await store.fasts(month: month.adding(months: 1), city: .chennai, tradition: .gaudiya)
        _ = try await store.fasts(month: month, city: .mumbai, tradition: .gaudiya)
        XCTAssertEqual(calls.withLock { $0 }, 5)
    }

    func testCancelledWaiterDoesNotCancelTheCalculationNeededByAnotherPage() async {
        let calls = Locked<Int>(0)
        let store = PanchangDataStore(observances: { _, _ in calls.withLock { $0 += 1 }; return [] })
        let waiter = Task { await store.observances(month: month, city: .chennai) }
        waiter.cancel()
        _ = await waiter.value
        _ = await store.observances(month: month, city: .chennai)
        XCTAssertEqual(calls.withLock { $0 }, 31)
    }

    func testCachesAreBoundedAndEvictionRecalculatesCorrectly() async {
        let calls = Locked<Int>(0)
        let store = PanchangDataStore(observances: { _, _ in calls.withLock { $0 += 1 }; return [] }, capacity: 1)
        _ = await store.observances(month: month, city: .chennai)
        _ = await store.observances(month: month, city: .mumbai)
        _ = await store.observances(month: month, city: .chennai)
        XCTAssertEqual(calls.withLock { $0 }, 93)
    }

    func testMonthResultsMatchExistingEngineForWorldwideLocations() async {
        let store = PanchangDataStore()
        for city in [PanchangCity.chennai, .mumbai,
                     PanchangCity(id: "ny", label: "New York", latitude: 40.7128, longitude: -74.006, timeZoneId: "America/New_York")] {
            let results = await store.observances(month: month, city: city)
            let expected = (0..<31).flatMap { offset -> [DatedObservance] in
                let date = month.adding(days: offset)
                return PanchangEngine().observances(on: date, city: city).map { DatedObservance(date: date, observance: $0) }
            }
            XCTAssertEqual(results, expected)
        }
    }
}
