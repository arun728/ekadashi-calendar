import SwiftUI

/// Colours shared with the Android app.
enum Theme {
    static let teal = Color(red: 0, green: 0xA1 / 255, blue: 0x9B / 255)
    static let googleBlue = Color(red: 0x42 / 255, green: 0x85 / 255, blue: 0xF4 / 255)
    static let customPurple = Color(red: 0x9C / 255, green: 0x27 / 255, blue: 0xB0 / 255)
    static let observed = Color.green
    static let partial = Color(red: 1.0, green: 0.63, blue: 0.0)
    static let missed = Color(red: 0.94, green: 0.33, blue: 0.31)
    static let amber = Color(red: 1.0, green: 0.76, blue: 0.03)

    static func hex(_ value: UInt32) -> Color {
        Color(red: Double(value >> 16 & 0xFF) / 255, green: Double(value >> 8 & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}

extension Color {
    /// The page background (Android scaffold colours: #121212 dark, grey 100 light).
    static func pageBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0x12 / 255, green: 0x12 / 255, blue: 0x12 / 255) : Color(red: 0.96, green: 0.96, blue: 0.96)
    }
}

/// A soft teal gradient behind the glass, so translucent surfaces read well.
struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Color.pageBackground(scheme)
            LinearGradient(colors: [Theme.teal.opacity(scheme == .dark ? 0.22 : 0.14), .clear, Theme.teal.opacity(0.08)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .ignoresSafeArea()
    }
}
