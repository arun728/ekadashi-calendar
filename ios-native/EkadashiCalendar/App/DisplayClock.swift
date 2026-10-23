import Foundation
import EkadashiCore

/// Live in the app. UI tests may pin a civil-date boundary without changing
/// the device clock; the override is absent from Release builds.
enum DisplayClock {
    static var isSimulationSession: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-lifecycle-testing")
        #else
        return false
        #endif
    }

    static var isFrozen: Bool {
        #if DEBUG
        if isSimulationSession { return WidgetClock.config?.rate == 0 }
        if ProcessInfo.processInfo.arguments.contains("-ui-testing"),
           ProcessInfo.processInfo.environment["EKADASHI_UI_TEST_NOW"].flatMap(ISO8601.instant) != nil { return true }
        #endif
        return false
    }

    static func realInterval(_ seconds: Double) -> Double {
        #if DEBUG
        if let rate = WidgetClock.config?.rate, rate > 0 { return max(0.05, seconds / rate) }
        #endif
        return max(0.05, seconds)
    }

    static func date(_ liveDate: Date,
                     arguments: [String] = ProcessInfo.processInfo.arguments,
                     environment: [String: String] = ProcessInfo.processInfo.environment) -> Date {
        #if DEBUG
        if arguments.contains("-ui-testing"), !arguments.contains("-lifecycle-testing"), let value = environment["EKADASHI_UI_TEST_NOW"],
           let date = ISO8601.instant(value) { return date }
        #endif
        return WidgetClock.date(liveDate)
    }
}
