import Foundation
import EkadashiCore

/// Release contains only the live clock and production snapshot key. The
/// simulation payload, lookup and alternate snapshot key compile in Debug only.
enum WidgetClock {
    static var group: String { Bundle.main.object(forInfoDictionaryKey: "EkadashiAppGroup") as? String ?? "" }
    static var snapshotKey: String {
        #if DEBUG
        if isSimulating { return "debug_lifecycle_snapshot" }
        #endif
        return WidgetSnapshot.appGroupKey
    }
    static var isSimulating: Bool {
        #if DEBUG
        return config != nil
        #else
        return false
        #endif
    }
    static func date(_ live: Date) -> Date {
        #if DEBUG
        if let config {
            return Date(timeIntervalSince1970: config.virtualAnchor + (live.timeIntervalSince1970 - config.realAnchor) * config.rate)
        }
        #endif
        return live
    }
    /// Convert a simulation boundary back to a real WidgetKit timeline date.
    /// Paused Debug sessions refresh only when their controls publish a snapshot.
    static func realDate(for target: Date, liveNow: Date) -> Date? {
        #if DEBUG
        if let config {
            guard config.rate > 0 else { return nil }
            return liveNow.addingTimeInterval(target.timeIntervalSince(date(liveNow)) / config.rate)
        }
        #endif
        return target
    }
    static var supportsSystemCountdown: Bool {
        #if DEBUG
        if let config { return config.rate == 1 }
        #endif
        return true
    }
    #if DEBUG
    struct Configuration: Codable {
        let virtualAnchor: Double
        let realAnchor: Double
        let rate: Double
    }
    static let configurationKey = "EKADASHI_LIFECYCLE_TEST_CLOCK"
    static var config: Configuration? {
        guard let data = UserDefaults(suiteName: group)?.data(forKey: configurationKey) else { return nil }
        return try? JSONDecoder().decode(Configuration.self, from: data)
    }
    static func set(_ date: Date?, rate: Double = 0, live: Date = Date()) {
        let defaults = UserDefaults(suiteName: group)
        if let date {
            defaults?.set(try? JSONEncoder().encode(Configuration(virtualAnchor: date.timeIntervalSince1970,
                realAnchor: live.timeIntervalSince1970, rate: rate.isFinite ? max(0, min(rate, 3600)) : 0)), forKey: configurationKey)
        } else {
            defaults?.removeObject(forKey: configurationKey)
            defaults?.removeObject(forKey: "debug_lifecycle_snapshot")
        }
    }
    #endif
}
