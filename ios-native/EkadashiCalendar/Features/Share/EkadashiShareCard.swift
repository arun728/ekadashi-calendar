import SwiftUI
import EkadashiCore

/// The texts on a share card, read from the app model before rendering
/// (ImageRenderer has no environment), all in the app language. No location
/// is shown on the card.
struct ShareCardContent {
    let observance: String
    let tradition: String
    let name: String
    let pakshaMonth: String
    let date: String
    let fastingTitle: String
    let fastingTime: String
    let paranaTitle: String
    let paranaTime: String
    let significanceTitle: String
    let significance: String
    let branding: String

    @MainActor
    init(event: EkadashiOccurrence, model: AppModel) {
        observance = model.t("share_card_observance")
        tradition = model.traditionName(model.tradition)
        name = event.name
        pakshaMonth = [event.paksha, event.month].filter { !$0.isEmpty }.map { $0.uppercased() }.joined(separator: " • ")
        date = Self.longDate(event.date, locale: model.locale)
        fastingTitle = model.t("share_card_fasting_begins")
        fastingTime = event.fastStartTime.isEmpty ? "--:--"
            : Localizer.shared.localizeClock(event.fastStartTime, language: model.language)
        paranaTitle = model.t("share_card_parana_window")
        let parana = EkadashiDisplay.breakTime(event)
        paranaTime = parana.isEmpty ? "--:--" : Localizer.shared.localizeClock(parana, language: model.language)
        significanceTitle = model.t("significance")
        significance = event.description.isEmpty ? event.benefits : event.description
        branding = model.t("app_title")
    }

    /// The full weekday, month and day of the Android card ("Friday,
    /// November 20, 2026"), in the app language.
    static func longDate(_ date: CivilDate, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.setLocalizedDateFormatFromTemplate("yMMMMEEEEd")
        return formatter.string(from: date.utcMidnight)
    }
}

/// The devotional share card of the Android app (PR #20,
/// shareable_ekadashi_card.dart, theme "divine teal"), drawn the same way:
/// header with the tradition badge, the name in serif, paksha and month,
/// the date capsule, the timings and significance beside Lord Vishnu, and
/// the branding. Free for everyone.
struct EkadashiShareCard: View {
    let content: ShareCardContent
    static let width: CGFloat = 360

    private static func color(_ hex: UInt32, _ opacity: Double = 1) -> Color { Theme.hex(hex).opacity(opacity) }
    private let accent = EkadashiShareCard.color(0x80CBC4)

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            header
            Text(content.name)
                .font(.system(size: 27, weight: .bold, design: .serif))
                .kerning(0.6)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.54), radius: 2, x: 0, y: 2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
            if !content.pakshaMonth.isEmpty {
                Text(content.pakshaMonth)
                    .font(.system(size: 11.5, weight: .semibold))
                    .kerning(1.8)
                    .foregroundStyle(accent)
                    .multilineTextAlignment(.center)
                    .padding(.top, 5)
            }
            Text(content.date)
                .font(.system(size: 16, weight: .bold))
                .kerning(0.3)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Self.color(0x004D40, 0.35), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Self.color(0x00796B, 0.4), lineWidth: 1))
                .padding(.top, 12)
            timings.padding(.top, 12)
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill").font(.system(size: 13)).foregroundStyle(accent.opacity(0.85))
                Text(content.branding)
                    .font(.system(size: 11.5, weight: .semibold))
                    .kerning(0.8)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.top, 14)
        }
        .padding(18)
        .frame(width: Self.width)
        .background {
            ZStack {
                LinearGradient(colors: [Self.color(0x00332A), Self.color(0x002922), Self.color(0x00221C)],
                               startPoint: .top, endPoint: .bottom)
                Circle().fill(Self.color(0x00897B, 0.18)).frame(width: 160, height: 160)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).offset(x: 30, y: -30)
                Circle().fill(Self.color(0x004D40, 0.15)).frame(width: 170, height: 170)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading).offset(x: -30, y: 40)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Self.color(0x00A19B, 0.75), lineWidth: 2.2))
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill").font(.system(size: 19)).foregroundStyle(accent)
                Text(content.observance.uppercased())
                    .font(.system(size: 11.5, weight: .bold))
                    .kerning(1.4)
                    .foregroundStyle(accent)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(content.tradition.uppercased())
                .font(.system(size: 11, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 4.5)
                .background(Self.color(0x002922, 0.7), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Self.color(0x00A19B, 0.6), lineWidth: 1.2))
        }
    }

    /// Fasting start, the Parana window and the significance, with the deity
    /// silhouette and its glow on the right.
    private var timings: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                row("sunrise.fill", accent, content.fastingTitle, content.fastingTime)
                divider
                row("sun.max.fill", Self.color(0xFFD54F), content.paranaTitle, content.paranaTime)
                if !content.significance.isEmpty {
                    divider
                    row("sparkles", accent, content.significanceTitle, content.significance,
                        lines: 3, size: 12.5, weight: .semibold)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Self.color(0x00E5FF, 0.18), Self.color(0x00A19B, 0.06), .clear],
                                         center: .center, startRadius: 0, endRadius: 45))
                    .frame(width: 90, height: 90)
                Image("share_card_logo").resizable().scaledToFit().frame(width: 95, height: 140)
            }
            .frame(width: 95, height: 140)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Self.color(0x001A15, 0.65), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Self.color(0x00796B, 0.45), lineWidth: 1.2))
    }

    private var divider: some View {
        Rectangle().fill(Self.color(0x004D40, 0.6)).frame(height: 1).padding(.vertical, 8)
    }

    private func row(_ symbol: String, _ tint: Color, _ title: String, _ value: String, lines: Int = 2,
                     size: CGFloat = 15.5, weight: Font.Weight = .bold) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbol).font(.system(size: 19)).foregroundStyle(tint).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 10.5, weight: .semibold))
                    .kerning(0.8)
                    .foregroundStyle(accent)
                    .lineLimit(1)
                Text(value)
                    .font(.system(size: size, weight: weight))
                    .kerning(0.2)
                    .foregroundStyle(.white)
                    .lineLimit(lines)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
