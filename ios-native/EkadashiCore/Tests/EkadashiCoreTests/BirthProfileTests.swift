import XCTest
@testable import EkadashiCore

final class BirthProfileTests: XCTestCase {
    let ny = PanchangCity(id: "ny", label: "New York", latitude: 40.7, longitude: -74, timeZoneId: "America/New_York")
    func input(_ date: CivilDate = CivilDate(2000, 1, 1), hour: Int? = 12, minute: Int? = 0, choice: Int? = nil,
               city: PanchangCity = .newDelhi) -> BirthInput {
        BirthInput(date: date, hour: hour, minute: minute, city: city, repeatedChoice: choice)
    }
    func testLocalTimeUsesHistoricalOffsetRatherThanCurrentOrDeviceZone() throws {
        let dates = try BirthCalculator.candidates(input(CivilDate(1942, 9, 2), hour: 12))
        XCTAssertEqual(dates.map(ISO8601.string), ["1942-09-02T05:30:00.000Z"])
        let kathmandu = PanchangCity(id: "np", label: "Kathmandu", latitude: 27.7, longitude: 85.3, timeZoneId: "Asia/Kathmandu")
        XCTAssertEqual(try BirthCalculator.candidates(input(CivilDate(1985, 1, 1), city: kathmandu)).map(ISO8601.string), ["1985-01-01T06:30:00.000Z"])
    }
    func testSpringGapAndAutumnFoldAreNeverSilentlyAdjusted() throws {
        XCTAssertTrue(try BirthCalculator.candidates(input(CivilDate(2024, 3, 10), hour: 2, minute: 30, city: ny)).isEmpty)
        let ambiguous = input(CivilDate(2024, 11, 3), hour: 1, minute: 30, city: ny)
        XCTAssertEqual(try BirthCalculator.candidates(ambiguous).map(ISO8601.string), ["2024-11-03T05:30:00.000Z", "2024-11-03T06:30:00.000Z"])
        XCTAssertThrowsError(try BirthCalculator.calculate(ambiguous)) { XCTAssertEqual($0 as? BirthError, .ambiguousTime) }
        XCTAssertEqual(try BirthCalculator.calculate(input(CivilDate(2024, 11, 3), hour: 1, minute: 30, choice: 1, city: ny)).instant,
                       ISO8601.instant("2024-11-03T06:30:00.000Z"))
    }
    func testHalfHourFoldAndSkippedCivilDay() throws {
        let lordHowe = PanchangCity(id: "lh", label: "Lord Howe", latitude: -31.55, longitude: 159.08, timeZoneId: "Australia/Lord_Howe")
        let dates = try BirthCalculator.candidates(input(CivilDate(2024, 4, 7), hour: 1, minute: 45, city: lordHowe))
        XCTAssertEqual(dates.count, 2)
        XCTAssertEqual(dates[1].timeIntervalSince(dates[0]), 1800)
        let apia = PanchangCity(id: "apia", label: "Apia", latitude: -13.8, longitude: -171.75, timeZoneId: "Pacific/Apia")
        XCTAssertThrowsError(try BirthCalculator.calculate(input(CivilDate(2011, 12, 30), hour: nil, minute: nil, city: apia)))
    }
    func testUnknownTimeCoversAll23Or25HoursAndReportsChangingValues() throws {
        for (date, hours) in [(CivilDate(2024, 3, 10), 23), (CivilDate(2024, 11, 3), 25)] {
            let result = try BirthCalculator.calculate(input(date, hour: nil, minute: nil, city: ny))
            XCTAssertNil(result.instant)
            XCTAssertEqual(result.spans.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }, Double(hours * 3600), accuracy: 0.1)
            XCTAssertGreaterThan(result.spans.count, 1)
            for pair in zip(result.spans, result.spans.dropFirst()) { XCTAssertEqual(pair.0.end, pair.1.start) }
            for span in result.spans {
                XCTAssertEqual(span.values, BirthCalculator.values(at: span.start.addingTimeInterval(1)))
                XCTAssertEqual(span.values, BirthCalculator.values(at: span.end.addingTimeInterval(-1)))
            }
        }
    }
    func testExactValuesAreFromTheInstantAndNotSunrise() throws {
        let a = try BirthCalculator.calculate(input(hour: 0)), b = try BirthCalculator.calculate(input(hour: 23))
        XCTAssertNotEqual(a.spans.first?.values, b.spans.first?.values)
        XCTAssertEqual(a.spans.first?.values, BirthCalculator.values(at: try XCTUnwrap(a.instant)))
        let sameInstant = try BirthCalculator.calculate(input(hour: 12, minute: 30, city: ny))
        XCTAssertEqual(sameInstant.instant, b.instant)
        XCTAssertEqual(sameInstant.spans.first?.values, b.spans.first?.values)
    }
    func testInvalidDatesTimesZonesAndFutureBirthsAreRejected() {
        for item in [input(CivilDate(1899, 12, 31)), input(CivilDate(2101, 1, 1)), input(hour: 24), input(minute: 60),
                     input(hour: nil, minute: 0), input(choice: 1),
                     input(city: PanchangCity(id: "bad", label: "Bad", latitude: 0, longitude: 0, timeZoneId: "Invalid/Zone"))] {
            XCTAssertThrowsError(try BirthCalculator.calculate(item))
        }
    }
    func testLocalStoreGatesNewCalculationsPreservesOnFailureAndDeletesAfterExpiry() throws {
        let raw = InMemoryKeyValueStore(), store = BirthProfileStore(store: InMemoryKeyValueStore())
        XCTAssertNil(try store.load())
        XCTAssertThrowsError(try store.save(input(), premium: false))
        let persisted = BirthProfileStore(store: raw)
        let original = try persisted.save(input(), premium: true)
        XCTAssertEqual(try BirthProfileStore(store: raw).load(), original)
        raw.failWrites = true
        XCTAssertThrowsError(try persisted.save(input(hour: 15), premium: true))
        XCTAssertEqual(try persisted.load(), original)
        XCTAssertThrowsError(try persisted.delete())
        XCTAssertEqual(try persisted.load(), original)
        raw.failWrites = false
        try persisted.delete()
        XCTAssertNil(try persisted.load())
    }
    func testCorruptOrFutureStorageIsNeverOverwritten() throws {
        let raw = InMemoryKeyValueStore([BirthProfileStore.key: "{invalid"]), store = BirthProfileStore(store: raw)
        XCTAssertThrowsError(try store.load())
        XCTAssertThrowsError(try store.save(input(), premium: true))
        XCTAssertEqual(raw.string(forKey: BirthProfileStore.key), "{invalid")
        raw.set("{\"version\":99}", forKey: BirthProfileStore.key)
        XCTAssertThrowsError(try store.load())
        // Explicit deletion is still available for damaged personal data.
        try store.delete()
        XCTAssertNil(try store.load())
    }
    func testIndependentSwissReferencePositionsAndClassifications() throws {
        struct Fixture: Decodable { let samples: [Sample] }
        struct Sample: Decodable { let utc: String; let moon: Double; let sun: Double; let lahiri: Double; let rashi: Int; let nakshatra: Int; let pada: Int; let tithi: Int }
        let fixture = try JSONDecoder().decode(Fixture.self, from: Repo.data("test/fixtures/panchang/birth_reference.json"))
        XCTAssertGreaterThan(fixture.samples.count, 120)
        for row in fixture.samples {
            let instant = try XCTUnwrap(ISO8601.instant(row.utc))
            let actual = BirthCalculator.values(at: instant)
            XCTAssertEqual(actual.rashi, row.rashi, row.utc)
            XCTAssertEqual(actual.nakshatra, row.nakshatra, row.utc)
            XCTAssertEqual(actual.pada, row.pada, row.utc)
            XCTAssertEqual(actual.tithi, row.tithi, row.utc)
            XCTAssertEqual(AstronomyCalculator.signedAngle(actual.siderealMoon - (row.moon - row.lahiri)), 0, accuracy: 0.003, row.utc)
        }
    }

    func testBirthVocabularyUsesAllSixScriptsAndMatchingPlaceholders() {
        let keys = ["title", "intro", "create", "edit", "delete", "delete_body", "date", "known_time", "time", "place", "timezone", "calculate", "privacy", "convention", "unknown", "stable", "changes", "timeline", "exact", "boundary", "rashi", "nakshatra", "pada", "tithi", "rashi_help", "nakshatra_help", "pada_help", "tithi_help", "earlier", "later", "fold", "range", "utc", "search", "manual", "place_name", "offset", "error_outOfRange", "error_invalidTime", "error_invalidPlace", "error_nonexistentTime", "error_ambiguousTime", "error_premiumRequired", "error_storage", "error_corruptStorage"]
        for key in keys {
            let full = "ios_birth_" + key
            for language in Localizer.languages {
                let text = Localizer.shared.translate(full, language: language)
                XCTAssertNotEqual(text, full, "\(language) \(full)")
                if language != "en" { XCTAssertNil(text.range(of: "[A-Za-z]", options: .regularExpression), "\(language) \(full)") }
            }
        }
    }

}
