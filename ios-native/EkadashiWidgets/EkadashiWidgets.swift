import WidgetKit
import SwiftUI
import EkadashiCore

/// Two distinct widget kinds: today/next, and the next five future dates.
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
    var displayDate: Date { WidgetClock.date(date) }
}

/// Timeline entries at every fasting/Parana boundary and every 15 minutes
/// for the next six hours, so states, progress and countdowns change on
/// time without the app running.
struct SnapshotProvider: TimelineProvider {
    static var appGroup: String { Bundle.main.object(forInfoDictionaryKey: "EkadashiAppGroup") as? String ?? "" }

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: WidgetClock.snapshotKey) else { return nil }
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
            for boundary in snapshot.refreshDates(after: WidgetClock.date(now)) {
                if let date = WidgetClock.realDate(for: boundary, liveNow: now), date > now, date <= horizon { dates.insert(date) }
            }
            #if DEBUG
            if let config = WidgetClock.config {
                if config.rate == 0 { dates = [now] }
                else if config.rate != 1 {
                    // Accelerated Debug playback only; production uses system timer text.
                    dates.formUnion((1...120).map { now.addingTimeInterval(Double($0)) })
                }
            }
            #endif
        }
        let entries = dates.sorted().prefix(WidgetClock.isSimulating ? 60 : 500)
            .map { SnapshotEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: WidgetClock.isSimulating && !WidgetClock.supportsSystemCountdown && entries.count == 1 ? .never : .atEnd))
    }
}

private struct WidgetShell<Content: View>: View {
    @Environment(\.widgetFamily) private var family
    let url: URL
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .environment(\.isWidgetPresentation, true)
            .environment(\.locale, Localizer.locale(WidgetLanguage.current))
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
        WidgetShell(url: entry.snapshot?.headline(at: entry.displayDate)?.item.detailsURL ?? AppRoute.dashboardURL) {
            EkadashiWidgetView(snapshot: entry.snapshot, now: entry.displayDate, family: family)
        }
    }
}

private struct UpcomingWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        WidgetShell(url: entry.snapshot?.upcoming(after: entry.displayDate).first?.detailsURL ?? AppRoute.dashboardURL) {
            UpcomingEkadashiWidgetView(snapshot: entry.snapshot, now: entry.displayDate, family: family)
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
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct UpcomingEkadashiWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UpcomingEkadashiWidget", provider: SnapshotProvider()) { entry in
            UpcomingWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(Localizer.shared.translate("upcoming_ekadashis", language: WidgetLanguage.current))
        .description(Localizer.shared.translate("ios_widget_desc_next", language: WidgetLanguage.current))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

/// The app's language for the widget gallery names (from the last snapshot).
enum WidgetLanguage {
    static var current: String {
        let language = SnapshotProvider.load()?.locale
            ?? UserDefaults(suiteName: SnapshotProvider.appGroup)?.string(forKey: "language_code")
            ?? Locale.current.language.languageCode?.identifier ?? "en"
        return Localizer.languages.contains(language) ? language : "en"
    }
}
