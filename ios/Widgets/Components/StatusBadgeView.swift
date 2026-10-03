import SwiftUI

public struct StatusBadgeView: View {
    public let state: WidgetState
    public let localizedText: String

    public init(state: WidgetState, localizedText: String) {
        self.state = state
        self.localizedText = localizedText
    }

    private var badgeColor: Color {
        switch state {
        case .beforeEkadashi:
            return .white
        case .fastingActive:
            return Color(red: 0.95, green: 0.60, blue: 0.07) // Amber/Orange
        case .paranaAvailable:
            return Color(red: 0.18, green: 0.80, blue: 0.44) // Bright Emerald Green
        case .paranaCompleted:
            return Color.gray
        case .fallback:
            return Color.red.opacity(0.8)
        }
    }

    private var iconName: String {
        switch state {
        case .beforeEkadashi:
            return "calendar"
        case .fastingActive:
            return "flame.fill"
        case .paranaAvailable:
            return "sun.max.fill"
        case .paranaCompleted:
            return "checkmark.circle.fill"
        case .fallback:
            return "exclamationmark.triangle.fill"
        }
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .bold))
            Text(localizedText.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(state == .beforeEkadashi ? Color.white.opacity(0.16) : badgeColor.opacity(0.18))
        .foregroundStyle(state == .beforeEkadashi ? .white : badgeColor)
        .shadow(color: state == .beforeEkadashi ? Color.black.opacity(0.3) : Color.clear, radius: 1, x: 0, y: 1)
        .clipShape(Capsule())
    }
}
