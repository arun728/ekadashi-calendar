import WidgetKit
import SwiftUI
import EkadashiCore

/// Keeps both installed widget kinds, each showing one real occurrence.
@main
struct EkadashiWidgetBundle: WidgetBundle {
    var body: some Widget {
        EkadashiWidget()
        UpcomingEkadashiWidget()
    }
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

/// Timeline entries at every fasting/Parana boundary and every 15 minutes
/// for the next six hours, so states, progress and countdowns change on
/// time without the app running.
struct SnapshotProvider: TimelineProvider {
    static var appGroup: String { Bundle.main.object(forInfoDictionaryKey: "EkadashiAppGroup") as? String ?? "" }

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: WidgetSnapshot.appGroupKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func placeholder(in context: Context) -> SnapshotEntry { SnapshotEntry(date: Date(), snapshot: Self.load()) }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: Date(), snapshot: Self.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let now = Date()
        let snapshot = Self.load()
        var dates = Set((0...24).map { now.addingTimeInterval(Double($0) * 15 * 60) })
        if let snapshot {
            let horizon = now.addingTimeInterval(6 * 3600)
            for date in snapshot.refreshDates(after: now) where date <= horizon { dates.insert(date) }
        }
        let entries = dates.sorted().map { SnapshotEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

private struct WidgetShell<Content: View>: View {
    @Environment(\.widgetFamily) private var family
    let url: URL
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .containerBackground(for: .widget) {
                if family == .accessoryCircular || family == .accessoryRectangular { Color.clear }
                else { WidgetCardBackground() }
            }
            .widgetURL(url)
    }
}

private struct EkadashiWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        WidgetShell(url: entry.snapshot?.headline(at: entry.date)?.item.detailsURL ?? AppRoute.dashboardURL) {
            EkadashiWidgetView(snapshot: entry.snapshot, now: entry.date, family: family)
        }
    }
}

private struct UpcomingWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        WidgetShell(url: entry.snapshot?.headline(at: entry.date)?.item.detailsURL ?? AppRoute.dashboardURL) {
            UpcomingEkadashiWidgetView(snapshot: entry.snapshot, now: entry.date, family: family)
        }
    }
}

/// Keeps the original kind so a placed "Next Ekadashi" widget becomes this one.
struct EkadashiWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextEkadashiWidget", provider: SnapshotProvider()) { entry in
            EkadashiWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(Localizer.shared.translate("widget_name_ekadashi", language: WidgetLanguage.current))
        .description(Localizer.shared.translate("ios_widget_desc_ekadashi", language: WidgetLanguage.current))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular])
    }
}

struct UpcomingEkadashiWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UpcomingEkadashiWidget", provider: SnapshotProvider()) { entry in
            UpcomingWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(Localizer.shared.translate("next_ekadashi", language: WidgetLanguage.current))
        .description(Localizer.shared.translate("ios_widget_desc_next", language: WidgetLanguage.current))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

/// The app's language for the widget gallery names (from the last snapshot).
enum WidgetLanguage {
    static var current: String { SnapshotProvider.load()?.locale ?? "en" }
}
