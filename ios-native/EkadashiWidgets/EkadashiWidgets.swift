import WidgetKit
import SwiftUI
import EkadashiCore

/// Small "Next Ekadashi", medium "Ekadashi Today" and large "Upcoming"
/// widgets, from the snapshot the app writes to the App Group.
@main
struct EkadashiWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextEkadashiWidget()
        TodayEkadashiWidget()
        UpcomingEkadashiWidget()
    }
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

/// Timeline entries at every fasting/Parana boundary and every 15 minutes
/// for the next six hours, so states and countdowns change on time without
/// the app running.
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
            for date in snapshot.refreshDates(after: now).prefix(12) { dates.insert(date) }
        }
        let entries = dates.sorted().map { SnapshotEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

private struct WidgetShell<Content: View>: View {
    let url: URL
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .containerBackground(for: .widget) { WidgetCardBackground() }
            .widgetURL(url)
    }
}

struct NextEkadashiWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextEkadashiWidget", provider: SnapshotProvider()) { entry in
            WidgetShell(url: AppRoute.dashboardURL) { NextEkadashiWidgetView(snapshot: entry.snapshot, now: entry.date) }
        }
        .configurationDisplayName(Localizer.shared.translate("ios_widget_small", language: WidgetLanguage.current))
        .description(Localizer.shared.translate("next_ekadashi", language: WidgetLanguage.current))
        .supportedFamilies([.systemSmall])
    }
}

struct TodayEkadashiWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayEkadashiWidget", provider: SnapshotProvider()) { entry in
            WidgetShell(url: entry.snapshot?.today.isEkadashi == true ? AppRoute.paranaURL : AppRoute.todayURL) {
                TodayEkadashiWidgetView(snapshot: entry.snapshot, now: entry.date)
            }
        }
        .configurationDisplayName(Localizer.shared.translate("ios_widget_medium", language: WidgetLanguage.current))
        .description(Localizer.shared.translate("widget_today_title", language: WidgetLanguage.current))
        .supportedFamilies([.systemMedium])
    }
}

struct UpcomingEkadashiWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UpcomingEkadashiWidget", provider: SnapshotProvider()) { entry in
            WidgetShell(url: AppRoute.dashboardURL) { UpcomingEkadashiWidgetView(snapshot: entry.snapshot, now: entry.date) }
        }
        .configurationDisplayName(Localizer.shared.translate("ios_widget_large", language: WidgetLanguage.current))
        .description(Localizer.shared.translate("upcoming_ekadashis", language: WidgetLanguage.current))
        .supportedFamilies([.systemLarge])
    }
}

/// The app's language for the widget gallery names (from the last snapshot).
enum WidgetLanguage {
    static var current: String { SnapshotProvider.load()?.locale ?? "en" }
}
