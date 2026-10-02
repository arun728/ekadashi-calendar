import SwiftUI
import WidgetKit

public struct SmallWidgetView: View {
    public let entry: EkadashiEntry

    public init(entry: EkadashiEntry) {
        self.entry = entry
    }

    private var ekadashi: EkadashiItem? {
        entry.payload.nextEkadashi
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header Row: Motif & Category
            HStack {
                Text("🕉️")
                    .font(.system(size: 16))
                Spacer()
                if entry.state == .fastingActive {
                    StatusBadgeView(state: .fastingActive, localizedText: entry.payload.localized("widget.fasting_active", default: "FASTING"))
                } else if entry.state == .paranaAvailable {
                    StatusBadgeView(state: .paranaAvailable, localizedText: entry.payload.localized("widget.parana_available", default: "PARANA"))
                } else {
                    Text(entry.payload.localized("widget.next_ekadashi", default: "NEXT EKADASHI").uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: Color.black.opacity(0.35), radius: 1, x: 0, y: 1)
                        .lineLimit(1)
                }
            }

            if let item = ekadashi {
                // Ekadashi Name (Enhanced glanceability)
                Text(item.localizedName.isEmpty ? item.name : item.localizedName)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.0, green: 0.63, blue: 0.61))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                // Date & Paksha
                Text("\(item.localizedDate)\(item.paksha.isEmpty ? "" : " • " + item.paksha)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 2)

                // Dynamic Countdown
                if entry.state == .fastingActive {
                    CountdownView(
                        targetDate: item.paranaStartDate,
                        state: .fastingActive,
                        localizedString: entry.payload.localized("widget.parana_window", default: "Parana Starts")
                    )
                } else if entry.state == .paranaAvailable {
                    CountdownView(
                        targetDate: item.paranaEndDate,
                        state: .paranaAvailable,
                        localizedString: entry.payload.localized("widget.parana_window", default: "Parana Ends")
                    )
                } else {
                    CountdownView(
                        targetDate: item.countdownTargetDate ?? item.fastingStartDate,
                        state: .beforeEkadashi,
                        localizedString: entry.payload.localized("widget.fasting_starts", default: "Starts In")
                    )
                }
            } else {
                // Fallback state
                Spacer()
                Text(entry.payload.localized("widget.open_app_to_refresh", default: "Open app to refresh timings"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(12)
        .widgetURL(WidgetDeepLinks.dashboardURL)
        .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
        }
    }
}
