import Foundation
import WidgetKit

/// Centralized manager for requesting iOS WidgetKit timeline reloads.
/// Ensures WidgetCenter calls are not scattered throughout unrelated application code.
public final class WidgetRefreshManager {
    public static let shared = WidgetRefreshManager()

    public static let widgetKinds = [
        "EkadashiTodayWidget",
        "UpcomingEkadashisWidget",
        "EkadashiCalendarWidget"
    ]

    private init() {}

    /// Reloads the timelines for all Ekadashi widgets specifically.
    /// Prefer targeted reloads over global reloads whenever possible to minimize system overhead.
    public func reloadEkadashiWidgets() {
        if #available(iOS 14.0, *) {
            for kind in Self.widgetKinds {
                NSLog("🔄 [WidgetRefreshManager] Requesting targeted reload for kind: %@", kind)
                WidgetCenter.shared.reloadTimelines(ofKind: kind)
            }
        }
    }

    /// Global reload for all app widgets when comprehensive configuration changes occur (e.g., App Group reset).
    public func reloadAllWidgets() {
        if #available(iOS 14.0, *) {
            NSLog("🔄 [WidgetRefreshManager] Requesting reload of all timelines")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
