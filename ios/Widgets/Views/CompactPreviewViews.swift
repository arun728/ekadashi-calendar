import SwiftUI

// ============================================================================
// MODULE 13 — WIDGET PREVIEW CARD SIMPLIFICATION (iOS SwiftUI Specification)
// ============================================================================

/// Card 1 Preview: [LOTUS LOGO] EKADASHI TODAY ONLY
public struct CompactTodayEkadashiPreview: View {
    public init() {}

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.15, blue: 0.19), Color(red: 0.01, green: 0.09, blue: 0.13), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Attached Background Banner (Watermark style, responsive, scaledToFill)
            Image("widget_banner_bg")
                .resizable()
                .scaledToFill()
                .opacity(0.28)

            // Subtle dark translucent overlay
            Color.black.opacity(0.35)

            HStack(spacing: 14) {
                Image("widget_lotus_deity")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text("EKADASHI TODAY")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundColor(.white)
                    .tracking(1.1)

                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 78)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color(red: 0.0, green: 0.9, blue: 1.0).opacity(0.12), radius: 10, x: 0, y: 3)
    }
}

/// Card 2 Preview: [LOTUS LOGO] NEXT EKADASHI + Starts in 2 days ONLY
public struct CompactNextEkadashiPreview: View {
    public init() {}

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.15, blue: 0.19), Color(red: 0.01, green: 0.09, blue: 0.13), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Attached Background Banner (Watermark style, responsive, scaledToFill)
            Image("widget_banner_bg")
                .resizable()
                .scaledToFill()
                .opacity(0.28)

            // Subtle dark translucent overlay
            Color.black.opacity(0.35)

            HStack(spacing: 14) {
                Image("widget_lotus_deity")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text("NEXT EKADASHI")
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundColor(.white)
                        .tracking(1.1)

                    Text("Starts in 2 days")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(red: 0.88, green: 0.97, blue: 0.98))
                }

                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 94)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color(red: 0.0, green: 0.9, blue: 1.0).opacity(0.12), radius: 10, x: 0, y: 3)
    }
}

/// Card 3 Preview: [LOTUS LOGO] UPCOMING EKADASHI + 2–3 compact date boxes ONLY
public struct CompactUpcomingEkadashiPreview: View {
    public let dates: [(month: String, day: String)]

    public init(dates: [(month: String, day: String)] = [("OCT", "11"), ("OCT", "26"), ("NOV", "10")]) {
        self.dates = dates
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.15, blue: 0.19), Color(red: 0.01, green: 0.09, blue: 0.13), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Attached Background Banner (Watermark style, responsive, scaledToFill)
            Image("widget_banner_bg")
                .resizable()
                .scaledToFill()
                .opacity(0.28)

            // Subtle dark translucent overlay
            Color.black.opacity(0.35)

            HStack(spacing: 14) {
                Image("widget_lotus_deity")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    Text("UPCOMING EKADASHI")
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundColor(.white)
                        .tracking(1.1)

                    HStack(spacing: 8) {
                        ForEach(Array(dates.prefix(3).enumerated()), id: \.offset) { _, item in
                            VStack(spacing: 2) {
                                Text(item.month)
                                     .font(.system(size: 10, weight: .bold))
                                     .foregroundColor(Color(red: 0.0, green: 0.9, blue: 1.0))
                                Text(item.day)
                                     .font(.system(size: 17, weight: .bold))
                                     .foregroundColor(.white)
                            }
                            .frame(width: 50, height: 46)
                            .background(Color(red: 0.01, green: 0.11, blue: 0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color(red: 0.0, green: 0.56, blue: 0.63), lineWidth: 1.2)
                            )
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 122)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color(red: 0.0, green: 0.9, blue: 1.0).opacity(0.12), radius: 10, x: 0, y: 3)
    }
}
