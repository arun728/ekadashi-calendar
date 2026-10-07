import Foundation
import WidgetKit
import EkadashiCore

/// Publishes the widget snapshot to the App Group and reloads the widgets.
enum WidgetBridge {
    static var appGroup: String { Bundle.main.object(forInfoDictionaryKey: "EkadashiAppGroup") as? String ?? "" }

    static func publish(_ snapshot: WidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroup), let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: WidgetSnapshot.appGroupKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
