import SwiftUI

public struct CountdownView: View {
    public let targetDate: Date?
    public let state: WidgetState
    public let localizedString: String

    public init(targetDate: Date?, state: WidgetState, localizedString: String) {
        self.targetDate = targetDate
        self.state = state
        self.localizedString = localizedString
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(localizedString)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            if let date = targetDate {
                if date > Date() {
                    Text(date, style: .relative)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(primaryAccentColor)
                } else {
                    Text(Date(), style: .date)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }
            } else {
                Text("--")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var primaryAccentColor: Color {
        switch state {
        case .fastingActive:
            return Color(red: 0.95, green: 0.60, blue: 0.07)
        case .paranaAvailable:
            return Color(red: 0.18, green: 0.80, blue: 0.44)
        default:
            return Color(red: 0.0, green: 0.63, blue: 0.61) // Teal
        }
    }
}
