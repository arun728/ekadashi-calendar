import WidgetKit
import SwiftUI
import EkadashiCore

/// Two widgets (docs/ROADMAP.md Phase 6): Ekadashi (today's fast with its
/// progress, or the next Ekadashi with the days to go; small, medium and
/// the lock screen) and Upcoming Ekadashis (medium and large), from the
/// snapshot the app writes to the App Group.
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

private struct EkadashiWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        let today: Bool = {
            if case .today? = entry.snapshot?.headline(at: entry.date) { return true }
            return false
        }()
        WidgetShell(url: today ? AppRoute.paranaURL : AppRoute.dashboardURL) {
            EkadashiWidgetView(snapshot: entry.snapshot, now: entry.date, family: family)
        }
    }
}

private struct UpcomingWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        WidgetShell(url: AppRoute.dashboardURL) {
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
        .description(Localizer.shared.translate("widget_desc_ekadashi", language: WidgetLanguage.current))
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct UpcomingEkadashiWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UpcomingEkadashiWidget", provider: SnapshotProvider()) { entry in
            UpcomingWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(Localizer.shared.translate("upcoming_ekadashis", language: WidgetLanguage.current))
        .description(Localizer.shared.translate("widget_desc_upcoming", language: WidgetLanguage.current))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

/// The app's language for the widget gallery names (from the last snapshot).
enum WidgetLanguage {
    static var current: String { SnapshotProvider.load()?.locale ?? "en" }
}
