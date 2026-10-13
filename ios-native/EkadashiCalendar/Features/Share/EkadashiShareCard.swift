import SwiftUI
import EkadashiCore

/// The texts on a share card, read from the app model before rendering
/// (ImageRenderer has no environment), all in the app language.
struct ShareCardContent {
    let observance: String
    let tradition: String
    let name: String
    let date: String
    let place: String
    let fastingTitle: String
    let fastingDate: String
    let fastingTime: String
    let paranaTitle: String
    let paranaDate: String
    let paranaTime: String
    let significanceTitle: String
    let significance: String
    let branding: String

    @MainActor
    init(event: EkadashiOccurrence, model: AppModel) {
        observance = model.t("share_card_observance")
        tradition = model.traditionName(model.tradition)
        name = event.name
        date = model.fullDate(event.date)
        place = "\(model.ekadashiCityName) • \(model.timeZoneLabel)"
        fastingTitle = model.t("share_card_fasting_begins")
        fastingDate = model.fullDate(event.date)
        fastingTime = Localizer.shared.localizeClock(event.fastStartTime, language: model.language)
        paranaTitle = model.t("share_card_parana_window")
        paranaDate = model.fullDate(event.date.adding(days: 1))
        paranaTime = Localizer.shared.localizeClock(EkadashiDisplay.breakTime(event), language: model.language)
        significanceTitle = model.t("significance")
        significance = event.description
        branding = model.t("app_title")
    }
}

/// The devotional share card from PR #20, in SwiftUI: a deep teal card with
/// the Ekadashi, its date and place, fasting start, the Parana window and
/// its significance. Free for everyone.
struct EkadashiShareCard: View {
    let content: ShareCardContent
    static let width: CGFloat = 360

    private let accent = Color(red: 0x80 / 255, green: 0xCB / 255, blue: 0xC4 / 255)
    private let gold = Color(red: 0xF5 / 255, green: 0xD0 / 255, blue: 0x7A / 255)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0, green: 0.30, blue: 0.25), Color(red: 0, green: 0.16, blue: 0.14)],
                           startPoint: .top, endPoint: .bottom)
            Circle().fill(Theme.teal.opacity(0.18)).frame(width: 170).offset(x: 140, y: -230)
            Circle().fill(Color(red: 0, green: 0.3, blue: 0.25).opacity(0.25)).frame(width: 180).offset(x: -140, y: 260)
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(content.observance.uppercased(), systemImage: "sun.max.fill")
                        .font(.caption.weight(.bold)).foregroundStyle(accent).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(content.tradition.uppercased())
                        .font(.caption2.weight(.bold)).foregroundStyle(accent).lineLimit(1)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.black.opacity(0.35), in: Capsule())
                        .overlay(Capsule().stroke(Theme.teal.opacity(0.6), lineWidth: 1))
                }
                HStack(alignment: .center, spacing: 12) {
                    Image("share_card_logo").resizable().scaledToFit().frame(width: 56, height: 96)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(content.name).font(.title.bold()).foregroundStyle(gold).fixedSize(horizontal: false, vertical: true)
                        Text(content.date).font(.headline).foregroundStyle(.white)
                        Label(content.place, systemImage: "mappin.and.ellipse").font(.footnote).foregroundStyle(.white.opacity(0.8))
                    }
                }
                HStack(spacing: 10) {
                    tile("moon.stars.fill", content.fastingTitle, content.fastingDate, content.fastingTime)
                    tile("sunrise.fill", content.paranaTitle, content.paranaDate, content.paranaTime)
                }
                if !content.significance.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(content.significanceTitle.uppercased()).font(.caption.weight(.bold)).foregroundStyle(accent)
                        Text(content.significance).font(.callout).foregroundStyle(.white.opacity(0.92))
                            .lineLimit(5).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Divider().overlay(accent.opacity(0.4))
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").foregroundStyle(gold)
                    Text(content.branding).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .frame(width: Self.width)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.teal.opacity(0.7), lineWidth: 2))
        .environment(\.colorScheme, .dark)
    }

    private func tile(_ symbol: String, _ title: String, _ date: String, _ time: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title.uppercased(), systemImage: symbol).font(.caption2.weight(.bold)).foregroundStyle(accent).lineLimit(2)
            Text(time).font(.headline).foregroundStyle(.white).minimumScaleFactor(0.7).lineLimit(2)
            Text(date).font(.caption2).foregroundStyle(.white.opacity(0.75)).lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 14))
    }
}
