import Foundation
import EkadashiCore

/// Live in the app. UI tests may pin a civil-date boundary without changing
/// the device clock; the override is absent from Release builds.
enum DisplayClock {
    static func date(_ liveDate: Date,
                     arguments: [String] = ProcessInfo.processInfo.arguments,
                     environment: [String: String] = ProcessInfo.processInfo.environment) -> Date {
        #if DEBUG
        if arguments.contains("-ui-testing"), let value = environment["EKADASHI_UI_TEST_NOW"],
           let date = ISO8601.instant(value) { return date }
        #endif
        return liveDate
    }
}
