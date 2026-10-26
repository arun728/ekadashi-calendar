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

/// Render only visible changes over the next six hours. System timer text
/// handles seconds; progress and every lifecycle boundary remain scheduled.
struct SnapshotProvider: TimelineProvider {
    var includesProgress = true
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
        let horizon = now.addingTimeInterval(6 * 3600)
        var dates: Set<Date> = [now, horizon]
        if let snapshot {
            dates = Set(snapshot.timelineDates(after: WidgetClock.date(now), through: WidgetClock.date(horizon),
                includesProgress: includesProgress).compactMap { WidgetClock.realDate(for: $0, liveNow: now) })
            dates.insert(now)
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
    let language: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .environment(\.isWidgetPresentation, true)
            .environment(\.locale, Localizer.locale(language))
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
        WidgetShell(url: entry.snapshot?.headline(at: entry.displayDate)?.item.detailsURL ?? AppRoute.dashboardURL, language: entry.snapshot?.locale ?? WidgetLanguage.current) {
            EkadashiWidgetView(snapshot: entry.snapshot, now: entry.displayDate, family: family)
        }
    }
}

private struct UpcomingWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        WidgetShell(url: entry.snapshot?.upcoming(after: entry.displayDate).first?.detailsURL ?? AppRoute.dashboardURL, language: entry.snapshot?.locale ?? WidgetLanguage.current) {
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
        StaticConfiguration(kind: "UpcomingEkadashiWidget", provider: SnapshotProvider(includesProgress: false)) { entry in
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
