import Foundation

/// The IANA time zone database bundled with the Android app (package:timezone
/// format, see lib/services/time_zone_data.dart), read with the same lookup
/// rules so both apps convert local times identically, whatever tz data the
/// phone's OS carries.
public final class TzDatabase: @unchecked Sendable {
    public static let shared: TzDatabase = {
        do {
            return try TzDatabase(data: CoreResources.data("tz/tzdb.tzf"),
                                  release: String(decoding: CoreResources.data("tz/release.txt"), as: UTF8.self)
                                      .trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            fatalError("Bundled time zone database is unreadable: \(error)")
        }
    }()

    public let release: String
    private let locations: [String: TzLocation]
    public var locationNames: [String] { locations.keys.sorted() }

    public init(data: Data, release: String) throws {
        self.release = release
        let bytes = [UInt8](data)
        var result: [String: TzLocation] = [:]
        var offset = 0
        func u32(_ at: Int) -> Int {
            Int(bytes[at]) << 24 | Int(bytes[at + 1]) << 16 | Int(bytes[at + 2]) << 8 | Int(bytes[at + 3])
        }
        while offset + 8 <= bytes.count {
            let length = u32(offset)
            offset += 8
            guard length % 8 == 0, offset + length <= bytes.count else { throw CoreError.invalidData("Corrupt tz database") }
            let location = try TzLocation(bytes: bytes, base: offset)
            result[location.name] = location
            offset += length
        }
        // package:timezone always provides UTC.
        if result["UTC"] == nil { result["UTC"] = TzLocation.utc }
        locations = result
    }

    public func location(_ name: String) -> TzLocation? { locations[name] }
}

public struct TzZone: Equatable, Sendable {
    public let offsetSeconds: Int
    public let isDst: Bool
    public let abbreviation: String
}

/// A local wall-clock reading of an instant in a location.
public struct WallClock: Equatable, Sendable {
    public let date: CivilDate
    public let hour: Int
    public let minute: Int
    public let second: Int
    public let offsetSeconds: Int
    public let abbreviation: String
    public var year: Int { date.year }
    public var month: Int { date.month }
    public var day: Int { date.day }
}

public struct TzLocation: Sendable {
    public let name: String
    let zones: [TzZone]
    /// Transition instants in milliseconds since the epoch.
    let transitionAt: [Int64]
    let transitionZone: [Int]

    static let utc = TzLocation(name: "UTC", zones: [TzZone(offsetSeconds: 0, isDst: false, abbreviation: "UTC")],
                                transitionAt: [], transitionZone: [])

    init(name: String, zones: [TzZone], transitionAt: [Int64], transitionZone: [Int]) {
        self.name = name
        self.zones = zones
        self.transitionAt = transitionAt
        self.transitionZone = transitionZone
    }

    /// `_deserializeLocation` from package:timezone's tzdb.dart.
    init(bytes: [UInt8], base: Int) throws {
        func u32(_ at: Int) -> Int {
            let i = base + at
            return Int(bytes[i]) << 24 | Int(bytes[i + 1]) << 16 | Int(bytes[i + 2]) << 8 | Int(bytes[i + 3])
        }
        func i32(_ at: Int) -> Int { Int(Int32(bitPattern: UInt32(u32(at)))) }
        let nameOffset = u32(0), nameLength = u32(4)
        let abbreviationsOffset = u32(8), abbreviationsLength = u32(12)
        let zonesOffset = u32(16), zonesLength = u32(20)
        let transitionsOffset = u32(24), transitionsLength = u32(28)
        name = String(decoding: bytes[(base + nameOffset)..<(base + nameOffset + nameLength)], as: UTF8.self)
        var abbreviations: [String] = []
        var start = abbreviationsOffset
        for i in abbreviationsOffset..<(abbreviationsOffset + abbreviationsLength) where bytes[base + i] == 0 {
            abbreviations.append(String(decoding: bytes[(base + start)..<(base + i)], as: UTF8.self))
            start = i + 1
        }
        var zones: [TzZone] = []
        for k in 0..<zonesLength {
            let at = zonesOffset + k * 8
            let index = Int(bytes[base + at + 5])
            guard index < abbreviations.count else { throw CoreError.invalidData("Corrupt tz zone") }
            zones.append(TzZone(offsetSeconds: i32(at), isDst: bytes[base + at + 4] == 1, abbreviation: abbreviations[index]))
        }
        var transitions: [Int64] = []
        for k in 0..<transitionsLength {
            var raw: UInt64 = 0
            for b in 0..<8 { raw = raw << 8 | UInt64(bytes[base + transitionsOffset + k * 8 + b]) }
            transitions.append(Int64(Double(bitPattern: raw)) * 1000)
        }
        let zoneIndexStart = base + transitionsOffset + transitionsLength * 8
        let transitionZone = (0..<transitionsLength).map { Int(bytes[zoneIndexStart + $0]) }
        self.zones = zones
        self.transitionAt = transitions
        self.transitionZone = transitionZone
    }

    /// `Location.lookupTimeZone`: the zone at [millis] and its validity range.
    func lookup(millis: Int64) -> (zone: TzZone, start: Int64, end: Int64) {
        let maxTime: Int64 = 8_640_000_000_000_000
        guard !zones.isEmpty else { return (TzLocation.utc.zones[0], -maxTime, maxTime) }
        if transitionAt.isEmpty || millis < transitionAt[0] {
            return (firstZone, -maxTime, transitionAt.first ?? maxTime)
        }
        var lo = 0, hi = transitionAt.count
        var end = maxTime
        while hi - lo > 1 {
            let m = lo + (hi - lo) / 2
            if millis < transitionAt[m] {
                end = transitionAt[m]
                hi = m
            } else {
                lo = m
            }
        }
        return (zones[transitionZone[lo]], transitionAt[lo], end)
    }

    /// `Location._firstZone` (localtime.c rules for instants before the first transition).
    private var firstZone: TzZone {
        if !transitionZone.contains(0) { return zones[0] }
        if let first = transitionZone.first, zones[first].isDst {
            for index in stride(from: first - 1, through: 0, by: -1) where !zones[index].isDst { return zones[index] }
        }
        for index in transitionZone where !zones[index].isDst { return zones[index] }
        return zones[0]
    }

    public func zone(at instant: Date) -> TzZone {
        lookup(millis: Int64((instant.timeIntervalSince1970 * 1000).rounded(.down))).zone
    }

    public func wallClock(_ instant: Date) -> WallClock {
        let zone = self.zone(at: instant)
        let local = instant.timeIntervalSince1970 + Double(zone.offsetSeconds)
        let days = Int(floor(local / 86400))
        let secondOfDay = Int(floor(local - Double(days) * 86400))
        return WallClock(date: CivilDate(daysSinceEpoch: days), hour: secondOfDay / 3600, minute: secondOfDay / 60 % 60,
                         second: secondOfDay % 60, offsetSeconds: zone.offsetSeconds, abbreviation: zone.abbreviation)
    }

    /// `TZDateTime(location, ...)`: the instant of a local wall-clock time,
    /// moving forward across a daylight-saving gap as package:timezone does.
    public func utc(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0, second: Int = 0) -> Date {
        let date = CivilDate(year, month, day)
        let localMillis = (Int64(date.daysSinceEpoch) * 86400 + Int64(hour * 3600 + minute * 60 + second)) * 1000
        let localOffset = Int64(lookup(millis: localMillis).zone.offsetSeconds) * 1000
        let adjusted = localMillis - localOffset
        let adjustedOffset = Int64(lookup(millis: adjusted).zone.offsetSeconds) * 1000
        var millis = localMillis - adjustedOffset
        if localOffset != adjustedOffset,
           localOffset - adjustedOffset < 0,
           adjustedOffset != Int64(lookup(millis: localMillis - adjustedOffset).zone.offsetSeconds) * 1000 {
            millis = adjusted
        }
        return Date(timeIntervalSince1970: Double(millis) / 1000)
    }

    public func utc(_ date: CivilDate, hour: Int = 0) -> Date {
        utc(year: date.year, month: date.month, day: date.day, hour: hour)
    }

    /// A Foundation time zone for formatting (the system's rules may be older).
    public var foundationTimeZone: TimeZone? { TimeZone(identifier: name) }
}
