import Foundation

public enum BirthError: String, Error, Equatable, Sendable {
    case outOfRange, invalidTime, invalidPlace, nonexistentTime, ambiguousTime, premiumRequired, storage, corruptStorage
    public var localizationKey: String { "ios_birth_error_\(rawValue)" }
}

/// Gregorian wall-clock input, independent of Home/Panchang's current location.
/// repeatedChoice is explicitly selected: 0 = earlier UTC, 1 = later UTC.
public struct BirthInput: Codable, Equatable, Sendable {
    public var date: CivilDate
    public var hour: Int?
    public var minute: Int?
    public var city: PanchangCity
    public var repeatedChoice: Int?
    public init(date: CivilDate, hour: Int?, minute: Int?, city: PanchangCity, repeatedChoice: Int? = nil) {
        self.date = date; self.hour = hour; self.minute = minute; self.city = city; self.repeatedChoice = repeatedChoice
    }
}

public struct BirthValues: Codable, Equatable, Sendable {
    public let rashi: Int
    public let nakshatra: Int
    public let pada: Int
    public let tithi: Int
    public let siderealMoon: Double
    public var rashiName: String { PanchangEngine.signs[rashi - 1] }
    public var nakshatraName: String { PanchangEngine.nakshatras[nakshatra - 1] }
    public var tithiName: String { tithi == 30 ? "Amavasya" : PanchangEngine.tithis[(tithi - 1) % 15] }
    public var paksha: String { tithi <= 15 ? "Shukla" : "Krishna" }
    /// Longitude changes continuously; timeline identity concerns categories.
    func sameCategories(as other: Self) -> Bool {
        rashi == other.rashi && nakshatra == other.nakshatra && pada == other.pada && tithi == other.tithi
    }
    public static func == (a: Self, b: Self) -> Bool { a.sameCategories(as: b) }
}

public struct BirthSpan: Codable, Equatable, Identifiable, Sendable {
    public let start: Date
    public let end: Date
    public let values: BirthValues
    public var id: Date { start }
}

public struct BirthReading: Codable, Equatable, Sendable {
    public let instant: Date?
    public let spans: [BirthSpan]
    /// Exact-time input within two minutes of a classification transition.
    public let nearBoundary: Bool
    public var stableRashi: Bool { Set(spans.map(\.values.rashi)).count == 1 }
    public var stableNakshatra: Bool { Set(spans.map(\.values.nakshatra)).count == 1 }
    public var stablePada: Bool { Set(spans.map(\.values.pada)).count == 1 }
    public var stableTithi: Bool { Set(spans.map(\.values.tithi)).count == 1 }
}

public enum BirthCalculator {
    public static let firstDate = CivilDate(1900, 1, 1)
    public static let lastDate = CivilDate(2100, 12, 31)

    static func validate(_ input: BirthInput, now: Date = Date()) throws {
        do { try input.city.validate() } catch { throw BirthError.invalidPlace }
        guard input.date >= firstDate, input.date <= lastDate, input.date <= input.city.today(now: now) else { throw BirthError.outOfRange }
        guard (input.hour == nil) == (input.minute == nil),
              input.hour.map({ (0...23).contains($0) }) ?? true,
              input.minute.map({ (0...59).contains($0) }) ?? true else { throw BirthError.invalidTime }
    }

    /// Round-trip every historical offset. A gap has no candidates; a fold
    /// has two. Never use TzLocation.utc's deliberate gap normalization.
    public static func candidates(_ input: BirthInput) throws -> [Date] {
        try validate(input)
        guard let hour = input.hour, let minute = input.minute else { return [] }
        let local = input.date.utcMidnight.addingTimeInterval(Double(hour * 3600 + minute * 60))
        let zone = input.city.zone
        return Set(zone.zones.map(\.offsetSeconds)).compactMap { offset in
            let instant = local.addingTimeInterval(-Double(offset)), wall = zone.wallClock(instant)
            return wall.date == input.date && wall.hour == hour && wall.minute == minute && wall.second == 0 ? instant : nil
        }.sorted()
    }

    public static func values(at instant: Date) -> BirthValues {
        let moon = AstronomyCalculator.moonLongitude(instant)
        let sidereal = AstronomyCalculator.normalize(moon - AstronomyCalculator.apparentLahiriAyanamsa(instant))
        let elongation = AstronomyCalculator.normalize(moon - AstronomyCalculator.sunLongitude(instant))
        return BirthValues(rashi: Int(sidereal / 30) + 1, nakshatra: Int(sidereal / (360 / 27)) + 1,
                           pada: Int(sidereal / (360 / 108)) % 4 + 1, tithi: Int(elongation / 12) + 1, siderealMoon: sidereal)
    }

    public static func calculate(_ input: BirthInput) throws -> BirthReading {
        try validate(input)
        if input.hour != nil {
            let possible = try candidates(input)
            guard !possible.isEmpty else { throw BirthError.nonexistentTime }
            if possible.count > 1 && input.repeatedChoice == nil { throw BirthError.ambiguousTime }
            let choice = input.repeatedChoice ?? 0
            guard possible.indices.contains(choice) else { throw BirthError.invalidTime }
            let instant = possible[choice], result = values(at: instant)
            let near = !result.sameCategories(as: values(at: instant.addingTimeInterval(-120))) ||
                !result.sameCategories(as: values(at: instant.addingTimeInterval(120)))
            return BirthReading(instant: instant, spans: [BirthSpan(start: instant, end: instant, values: result)], nearBoundary: near)
        }
        guard input.repeatedChoice == nil else { throw BirthError.invalidTime }
        let ranges = dayRanges(input.date, zone: input.city.zone)
        guard !ranges.isEmpty else { throw BirthError.nonexistentTime }
        var spans: [BirthSpan] = []
        // Five-minute samples cannot skip a complete 3°20′ pada (the fastest
        // category). Bisect each detected change to within half a second.
        for range in ranges {
            var start = range.start, cursor = range.start
            var current = values(at: start)
            while cursor < range.end {
                let next = min(cursor.addingTimeInterval(300), range.end)
                let after = values(at: min(next, range.end.addingTimeInterval(-0.001)))
                if !current.sameCategories(as: after) {
                    var low = cursor, high = next
                    while high.timeIntervalSince(low) > 0.25 {
                        let mid = low.addingTimeInterval(high.timeIntervalSince(low) / 2)
                        if current.sameCategories(as: values(at: mid)) { low = mid } else { high = mid }
                    }
                    spans.append(BirthSpan(start: start, end: high, values: current))
                    start = high; current = values(at: high)
                    // Resume at the first boundary: another category can
                    // change within the remainder of this sampling window.
                    cursor = high
                    continue
                }
                cursor = next
            }
            spans.append(BirthSpan(start: start, end: range.end, values: current))
        }
        return BirthReading(instant: nil, spans: spans, nearBoundary: false)
    }

    /// Intersect UTC offset regimes with the desired local date. Handles
    /// skipped midnight, half-hour DST and skipped/repeated civil dates.
    static func dayRanges(_ day: CivilDate, zone: TzLocation) -> [DateInterval] {
        let localStart = day.utcMidnight, localEnd = day.adding(days: 1).utcMidnight
        let low = localStart.addingTimeInterval(-172800), high = localEnd.addingTimeInterval(172800)
        let cuts = [low] + zone.transitionAt.map { Date(timeIntervalSince1970: Double($0) / 1000) }.filter { $0 > low && $0 < high } + [high]
        var result: [DateInterval] = []
        for (a, b) in zip(cuts, cuts.dropFirst()) {
            let offset = Double(zone.zone(at: a).offsetSeconds)
            let start = max(a, localStart.addingTimeInterval(-offset)), end = min(b, localEnd.addingTimeInterval(-offset))
            guard start < end else { continue }
            if let previous = result.last, previous.end == start {
                result[result.count - 1] = DateInterval(start: previous.start, end: end)
            } else { result.append(DateInterval(start: start, end: end)) }
        }
        return result
    }
}

public struct SavedBirthProfile: Codable, Equatable, Sendable {
    public let input: BirthInput
    public let reading: BirthReading
    public let timezoneRelease: String
    public let calculationVersion: Int
}

/// One personal profile, in a dedicated local store. No app group, network,
/// analytics, accounts or logs. A versioned tombstone makes deletion verifiable.
public final class BirthProfileStore {
    public static let key = "personal_birth_profile_v1"
    private struct Envelope: Codable { let version: Int; let profile: SavedBirthProfile? }
    private let store: KeyValueStore
    public init(store: KeyValueStore) { self.store = store }
    public func load() throws -> SavedBirthProfile? {
        guard let raw = store.string(forKey: Self.key) else { return nil }
        guard let decoded = try? JSONDecoder().decode(Envelope.self, from: Data(raw.utf8)), decoded.version == 1 else {
            throw BirthError.corruptStorage
        }
        if let profile = decoded.profile {
            let reading = profile.reading
            guard profile.calculationVersion == 1, !profile.timezoneRelease.isEmpty,
                  (try? BirthCalculator.validate(profile.input)) != nil,
                  (profile.input.hour != nil) == (reading.instant != nil), !reading.spans.isEmpty,
                  reading.spans.allSatisfy({ span in
                      let v = span.values
                      return span.start.timeIntervalSince1970.isFinite && span.end.timeIntervalSince1970.isFinite &&
                          span.start <= span.end && (1...12).contains(v.rashi) && (1...27).contains(v.nakshatra) &&
                          (1...4).contains(v.pada) && (1...30).contains(v.tithi) &&
                          v.siderealMoon.isFinite && (0..<360).contains(v.siderealMoon)
                  }) else { throw BirthError.corruptStorage }
        }
        return decoded.profile
    }
    @discardableResult public func save(_ input: BirthInput, premium: Bool) throws -> SavedBirthProfile {
        guard premium else { throw BirthError.premiumRequired }
        _ = try load() // Do not overwrite unreadable or newer data.
        let profile = SavedBirthProfile(input: input, reading: try BirthCalculator.calculate(input),
                                        timezoneRelease: TzDatabase.shared.release, calculationVersion: 1)
        try write(profile)
        return profile
    }
    public func delete() throws { try write(nil) }
    private func write(_ profile: SavedBirthProfile?) throws {
        let raw = String(decoding: try JSONEncoder().encode(Envelope(version: 1, profile: profile)), as: UTF8.self)
        guard store.set(raw, forKey: Self.key), store.string(forKey: Self.key) == raw else { throw BirthError.storage }
    }
}
