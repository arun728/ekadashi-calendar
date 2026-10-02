import SwiftUI

public struct UpcomingListView: View {
    public let items: [EkadashiItem]
    public let localizedTitle: String
    public let maxVisibleCount: Int

    public init(items: [EkadashiItem], localizedTitle: String, maxVisibleCount: Int = 3) {
        self.items = items
        self.localizedTitle = localizedTitle
        self.maxVisibleCount = maxVisibleCount
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localizedTitle.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            ForEach(items.prefix(maxVisibleCount)) { item in
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

            // Hidden events affordance when more events exist than the current widget displays
            if items.count > maxVisibleCount {
                Link(destination: WidgetDeepLinks.calendarURL) {
                    HStack {
                        Text("+ \(items.count - maxVisibleCount) More in Calendar")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(red: 0.0, green: 0.63, blue: 0.61))
                        Spacer()
                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(red: 0.0, green: 0.63, blue: 0.61))
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                }
            }
        }
    }
}
