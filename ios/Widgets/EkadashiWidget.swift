import WidgetKit
import SwiftUI

public struct EkadashiWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    public let entry: EkadashiEntry

    public init(entry: EkadashiEntry) {
        self.entry = entry
    }

    public var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

public struct EkadashiTodayWidget: Widget {
    public static let kind: String = "EkadashiTodayWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: EkadashiTimelineProvider()) { entry in
            MediumWidgetView(entry: entry)
        }
        .configurationDisplayName("Ekadashi Today")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

public struct UpcomingEkadashisWidget: Widget {
    public static let kind: String = "UpcomingEkadashisWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: EkadashiTimelineProvider()) { entry in
            UpcomingEkadashisView(entry: entry)
        }
        .configurationDisplayName("Upcoming Ekadashi")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

public struct EkadashiWidget: Widget {
    public static let kind: String = "EkadashiCalendarWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: EkadashiTimelineProvider()) { entry in
            EkadashiWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Next Ekadashi")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

@main
public struct EkadashiWidgetBundle: WidgetBundle {
    public init() {}

    public var body: some Widget {
        EkadashiTodayWidget()
        UpcomingEkadashisWidget()
        EkadashiWidget()
    }
}
