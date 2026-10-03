import SwiftUI
import WidgetKit

/// Adaptive view for Widget C (Upcoming Ekadashis) across iOS widget families.
/// Respects WidgetKit's glanceable model:
/// - systemSmall: 1 upcoming event with tap to its calendar date
/// - systemMedium: 2 upcoming events with independent links + "+ More" overflow
/// - systemLarge: Full hero card + 3-4 events + "+ More in Calendar" affordance
public struct UpcomingEkadashisView: View {
    @Environment(\.widgetFamily) var family
    public let entry: EkadashiEntry

    public init(entry: EkadashiEntry) {
        self.entry = entry
    }

    public var body: some View {
        switch family {
        case .systemSmall:
            smallUpcomingView
        case .systemMedium:
            mediumUpcomingView
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            mediumUpcomingView
        }
    }

    // MARK: - systemSmall (1 upcoming event)
    private var smallUpcomingView: some View {
        let upcomingItem = entry.payload.upcomingEkadashis.first ?? entry.payload.nextEkadashi
        let targetUrl = upcomingItem != nil ? WidgetDeepLinks.calendarDateURL(isoDate: upcomingItem!.date) : WidgetDeepLinks.calendarURL

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("🕉️")
                    .font(.system(size: 15))
                Spacer()
                Text(entry.payload.localized("widget.upcoming_ekadashis", default: "UPCOMING").uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
            }

            if let item = upcomingItem {
                Text(item.localizedName.isEmpty ? item.name : item.localizedName)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.0, green: 0.63, blue: 0.61))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text("\(item.localizedDate)\(item.paksha.isEmpty ? "" : " • " + item.paksha)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 2)

                HStack(spacing: 3) {
                    Text(entry.payload.localized("widget.view_details", default: "View Calendar"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(red: 0.0, green: 0.63, blue: 0.61))
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.0, green: 0.63, blue: 0.61))
                }
            } else {
                Text(entry.payload.localized("widget.open_app_to_refresh", default: "Open app to refresh"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .widgetURL(targetUrl)
        .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
        }
    }

    // MARK: - systemMedium (2 upcoming events + overflow)
    private var mediumUpcomingView: some View {
        let items = entry.payload.upcomingEkadashis.isEmpty
            ? (entry.payload.nextEkadashi != nil ? [entry.payload.nextEkadashi!] : [])
            : entry.payload.upcomingEkadashis

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("🕉️")
                    .font(.system(size: 14))
                Text(entry.payload.localized("widget.upcoming_ekadashis", default: "UPCOMING EKADASHIS").uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                if items.count > 2 {
                    Link(destination: WidgetDeepLinks.calendarURL) {
                        Text("+ \(items.count - 2) More")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(red: 0.0, green: 0.63, blue: 0.61))
                    }
                }
            }

            ForEach(items.prefix(2)) { item in
                Link(destination: WidgetDeepLinks.calendarDateURL(isoDate: item.date)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.localizedName.isEmpty ? item.name : item.localizedName)
                                .font(.system(size: 14.5, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            Text("\(item.localizedDate) • \(item.paksha) Paksha")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(red: 0.0, green: 0.63, blue: 0.61))
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                }
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
        }
    }
}
