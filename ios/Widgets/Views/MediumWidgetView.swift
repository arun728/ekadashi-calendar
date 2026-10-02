import SwiftUI
import WidgetKit

public struct MediumWidgetView: View {
    public let entry: EkadashiEntry

    public init(entry: EkadashiEntry) {
        self.entry = entry
    }

    private var ekadashi: EkadashiItem? {
        entry.payload.nextEkadashi
    }

    private var targetDeepLink: URL {
        if entry.state == .paranaAvailable {
            return WidgetDeepLinks.paranaActiveURL
        } else {
            return WidgetDeepLinks.todayURL
        }
    }

    public var body: some View {
        HStack(spacing: 14) {
            // Left Column: Ekadashi Identity & State
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("🕉️")
                        .font(.system(size: 15))

                    StatusBadgeView(
                        state: entry.state,
                        localizedText: stateBadgeTitle
                    )
                }

                if let item = ekadashi {
                    Text(item.localizedName.isEmpty ? item.name : item.localizedName)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.0, green: 0.63, blue: 0.61))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Text("\(item.localizedDate) • \(item.paksha)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text(entry.payload.localized("widget.open_app_to_refresh", default: "Open app to refresh timings"))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)

                // Location / Timezone tag
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                    Text("\(entry.payload.metadata.locationName) • \(entry.payload.metadata.timezone)")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.secondary)
            }

            Divider()

            // Right Column: Timings & Countdown
            VStack(alignment: .leading, spacing: 7) {
                if let item = ekadashi {
                    // Fasting window
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.payload.localized("widget.fasting_starts", default: "Fasting Start").uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        if let fStart = item.fastingStartDate {
                            Text(fStart, style: .time)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundColor(.primary)
                        } else {
                            Text("--")
                                .font(.system(size: 13))
                        }
                    }

                    // Parana window
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.payload.localized("widget.parana_window", default: "Parana Window").uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(entry.state == .paranaAvailable ? Color(red: 0.18, green: 0.80, blue: 0.44) : .secondary)

                        if let pStart = item.paranaStartDate, let pEnd = item.paranaEndDate {
                            Text("\(pStart, style: .time) - \(pEnd, style: .time)")
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundColor(entry.state == .paranaAvailable ? Color(red: 0.18, green: 0.80, blue: 0.44) : .primary)
                        } else {
                            Text("--")
                                .font(.system(size: 13))
                        }
                    }

                    Spacer(minLength: 0)

                    // Relative countdown
                    if entry.state == .beforeEkadashi {
                        CountdownView(
                            targetDate: item.countdownTargetDate ?? item.fastingStartDate,
                            state: .beforeEkadashi,
                            localizedString: entry.payload.localized("widget.days_remaining", default: "Starts In")
                        )
                    } else if entry.state == .fastingActive {
                        CountdownView(
                            targetDate: item.paranaStartDate,
                            state: .fastingActive,
                            localizedString: entry.payload.localized("widget.parana_window", default: "Parana In")
                        )
                    } else if entry.state == .paranaAvailable {
                        CountdownView(
                            targetDate: item.paranaEndDate,
                            state: .paranaAvailable,
                            localizedString: entry.payload.localized("widget.parana_window", default: "Parana Closes In")
                        )
                    }
                } else {
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .widgetURL(targetDeepLink)
        .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
        }
    }

    private var stateBadgeTitle: String {
        switch entry.state {
        case .beforeEkadashi:
            return entry.payload.localized("widget.next_ekadashi", default: "NEXT EKADASHI").uppercased()
        case .fastingActive:
            return entry.payload.localized("widget.fasting_active", default: "Fasting")
        case .paranaAvailable:
            return entry.payload.localized("widget.parana_available", default: "Parana")
        case .paranaCompleted:
            return entry.payload.localized("widget.parana_completed", default: "Completed")
        case .fallback:
            return "Notice"
        }
    }
}
