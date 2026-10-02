import SwiftUI
import WidgetKit

public struct LargeWidgetView: View {
    public let entry: EkadashiEntry

    public init(entry: EkadashiEntry) {
        self.entry = entry
    }

    private var currentEkadashi: EkadashiItem? {
        entry.payload.nextEkadashi
    }

    private var heroDeepLink: URL {
        if entry.state == .paranaAvailable {
            return WidgetDeepLinks.paranaActiveURL
        } else {
            return WidgetDeepLinks.dashboardURL
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Hero Top Section: Current / Next Ekadashi State Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("🕉️")
                        .font(.system(size: 16))

                    Text(entry.payload.localized("widget.title", default: "Ekadashi Calendar").uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)

                    Spacer()

                    StatusBadgeView(
                        state: entry.state,
                        localizedText: stateBadgeTitle
                    )
                }

                if let current = currentEkadashi {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(current.localizedName.isEmpty ? current.name : current.localizedName)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(Color(red: 0.0, green: 0.63, blue: 0.61))

                            Text("\(current.localizedDate) • \(current.paksha) Paksha")
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if entry.state == .fastingActive {
                            CountdownView(
                                targetDate: current.paranaStartDate,
                                state: .fastingActive,
                                localizedString: entry.payload.localized("widget.parana_window", default: "Parana In")
                            )
                        } else if entry.state == .paranaAvailable {
                            CountdownView(
                                targetDate: current.paranaEndDate,
                                state: .paranaAvailable,
                                localizedString: entry.payload.localized("widget.parana_window", default: "Closes In")
                            )
                        } else {
                            CountdownView(
                                targetDate: current.fastingStartDate,
                                state: .beforeEkadashi,
                                localizedString: entry.payload.localized("widget.fasting_starts", default: "Starts In")
                            )
                        }
                    }

                    // Key Timings Strip
                    HStack(spacing: 12) {
                        timingChip(
                            title: entry.payload.localized("widget.fasting_starts", default: "Fasting Start"),
                            value: current.fastingStartDate != nil ? DateFormatter.localizedString(from: current.fastingStartDate!, dateStyle: .none, timeStyle: .short) : "--",
                            accent: false
                        )

                        timingChip(
                            title: entry.payload.localized("widget.parana_window", default: "Parana Window"),
                            value: paranaWindowString(current),
                            accent: entry.state == .paranaAvailable
                        )
                    }
                } else {
                    Text(entry.payload.localized("widget.open_app_to_refresh", default: "Open app to refresh timings"))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(UIColor.secondarySystemBackground).opacity(0.8))
            .cornerRadius(12)

            // Bottom Section: Upcoming 2-3 Ekadashis
            UpcomingListView(
                items: entry.payload.upcomingEkadashis,
                localizedTitle: entry.payload.localized("widget.upcoming_ekadashis", default: "Upcoming Ekadashis")
            )

            Spacer(minLength: 0)

            // Footer location & timezone
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 11))
                Text("\(entry.payload.metadata.locationName) (\(entry.payload.metadata.timezone))")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Text("v\(entry.payload.metadata.calculationVersion)")
                    .font(.system(size: 10))
            }
            .foregroundColor(.secondary)
        }
        .padding(14)
        .widgetURL(heroDeepLink)
        .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
        }
    }

    private func timingChip(title: String, value: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(accent ? Color(red: 0.18, green: 0.80, blue: 0.44) : .primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(6)
    }

    private func paranaWindowString(_ item: EkadashiItem) -> String {
        guard let pStart = item.paranaStartDate, let pEnd = item.paranaEndDate else { return "--" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: pStart)) - \(formatter.string(from: pEnd))"
    }

    private var stateBadgeTitle: String {
        switch entry.state {
        case .beforeEkadashi:
            return entry.payload.localized("widget.next_ekadashi", default: "NEXT EKADASHI").uppercased()
        case .fastingActive:
            return entry.payload.localized("widget.fasting_active", default: "Fasting Active")
        case .paranaAvailable:
            return entry.payload.localized("widget.parana_available", default: "Parana Available")
        case .paranaCompleted:
            return entry.payload.localized("widget.parana_completed", default: "Completed")
        case .fallback:
            return "Notice"
        }
    }
}
