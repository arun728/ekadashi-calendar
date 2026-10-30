import Foundation

public enum WidgetSelection: String, CaseIterable, Sendable { case automatic, today, next }

/// The widget extension and Settings use the same palette and schedule formatter.
public enum WidgetPalette {
    public static let teal: UInt32 = 0x00A19B
    public static let ivory: UInt32 = 0xFAF5E8
    public static let charcoal: UInt32 = 0x121212
}

public struct WidgetText {
    public let snapshot: WidgetSnapshot
    public init(snapshot: WidgetSnapshot) { self.snapshot = snapshot }

    private var zone: TimeZone { TimeZone(identifier: snapshot.timeZone) ?? TimeZone(secondsFromGMT: 0)! }
    public var remainingLabel: String { snapshot.string("remaining", Localizer.shared.translate("widget_remaining", language: snapshot.locale)) }

    public var tradition: String {
        let key = snapshot.tradition.lowercased() == "smarta" ? "tradition_smarta" : "tradition_vaishnava"
        return Localizer.shared.translate(key, language: snapshot.locale)
    }

    public func date(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Localizer.locale(snapshot.locale)
        formatter.timeZone = zone
        formatter.dateFormat = "EEE, d MMM yyyy"
        return formatter.string(from: date)
    }

    public func time(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return Localizer.shared.clock(hour: calendar.component(.hour, from: date), minute: calendar.component(.minute, from: date), language: snapshot.locale)
    }

    public func window(_ start: Date, _ end: Date) -> String { "\(time(start)) – \(time(end))" }
}
