import SwiftUI
import WidgetKit
import EkadashiCore

/// Shared by the extension and Settings: the same real occurrence, palette,
/// local dates, complete timings and remaining-only ring on both surfaces.
enum WidgetStyle {
    static let teal = color(WidgetPalette.teal)
    static func color(_ hex: UInt32) -> Color {
        Color(red: Double(hex >> 16 & 255) / 255, green: Double(hex >> 8 & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

struct WidgetCardBackground: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        WidgetStyle.color(scheme == .dark ? WidgetPalette.charcoal : WidgetPalette.ivory)
    }
}

/// Choose an actually fitting font before drawing. This avoids clipping mixed
/// numeral/Indic-script runs when SwiftUI scales a constrained Text implicitly.
private struct WidgetColumnText: View {
    let value: String
    let size: CGFloat
    var weight: Font.Weight = .regular

    var body: some View {
        GeometryReader { geometry in
            ViewThatFits(in: .horizontal) {
                candidate(size)
                candidate(size - 1)
                candidate(size - 2)
                Text(value).font(.system(size: size - 3, weight: weight))
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
        }
        // A fixed line box accommodates Indic ascenders/descenders while the
        // flexible width gives ViewThatFits the actual column's proposal.
        .frame(height: ceil(size * 1.5))
        .accessibilityLabel(value)
    }

    private func candidate(_ size: CGFloat) -> some View {
        Text(value).font(.system(size: size, weight: weight))
            .lineLimit(1).fixedSize(horizontal: true, vertical: true)
    }
}

struct RemainingRing: View {
    let item: WidgetItem
    let snapshot: WidgetSnapshot
    let now: Date
    var prominent = false
    @Environment(\.widgetRenderingMode) private var rendering

    private var accent: Color { rendering == .fullColor ? WidgetStyle.teal : .primary }

    var body: some View {
        ZStack {
            Circle().inset(by: prominent ? 4.5 : 2).stroke(Color.primary.opacity(0.15), lineWidth: prominent ? 9 : 4)
            Circle().inset(by: prominent ? 4.5 : 2)
                .trim(from: 0, to: item.remainingFraction(at: now))
                .stroke(accent, style: StrokeStyle(lineWidth: prominent ? 9 : 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
            VStack(spacing: 0) {
                Text("\(item.remainingPercent(at: now))%")
                    .font(.system(size: prominent ? 30 : 16, weight: .bold))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
                Text(WidgetText(snapshot: snapshot).remainingLabel)
                    .font(.system(size: prominent ? 10 : 8)).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .padding(2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.remainingPercent(at: now))% \(WidgetText(snapshot: snapshot).remainingLabel)")
    }
}

struct EkadashiWidgetView: View {
    let snapshot: WidgetSnapshot?
    let now: Date
    var family: WidgetFamily = .systemSmall
    var selection: WidgetSelection = .automatic
    @Environment(\.locale) private var locale
    @Environment(\.widgetRenderingMode) private var rendering

    private var accent: Color { rendering == .fullColor ? WidgetStyle.teal : .primary }

    var body: some View {
        Group {
            if let snapshot, let headline = snapshot.headline(at: now, selection: selection) {
                switch family {
                case .accessoryCircular: circular(snapshot, headline)
                case .accessoryRectangular: rectangular(snapshot, headline)
                case .systemMedium: medium(snapshot, headline)
                default: small(snapshot, headline)
                }
            } else {
                Text(emptyLabel).font(.caption).multilineTextAlignment(.leading)
            }
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyLabel: String {
        guard let snapshot else { return Localizer.shared.translate("open_app_to_refresh", language: locale.language.languageCode?.identifier ?? "en") }
        return Localizer.shared.translate(selection == .today ? "no_ekadashi" : "widget_no_next", language: snapshot.locale)
    }

    private func header(_ snapshot: WidgetSnapshot, _ headline: WidgetHeadline) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(snapshot.string(headline.isToday ? "today_title" : "next_ekadashi", ""))
                .font(.system(size: 10, weight: .bold)).foregroundStyle(accent).lineLimit(1).minimumScaleFactor(0.7).widgetAccentable()
            Spacer(minLength: 4)
            if case .next(_, let days) = headline, family != .systemSmall {
                Text(snapshot.daysToGo(days)).font(.system(size: 10, weight: .semibold)).foregroundStyle(accent)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
    }

    private func name(_ item: WidgetItem, font: Font) -> some View {
        Text(item.name).font(font).lineLimit(2).minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func location(_ snapshot: WidgetSnapshot) -> some View {
        Text([snapshot.locationName, WidgetText(snapshot: snapshot).tradition].filter { !$0.isEmpty }.joined(separator: " · "))
            .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func small(_ snapshot: WidgetSnapshot, _ headline: WidgetHeadline) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            header(snapshot, headline)
            Spacer(minLength: 0)
            if headline.isToday {
                RemainingRing(item: headline.item, snapshot: snapshot, now: now)
                    .frame(width: 58, height: 58).frame(maxWidth: .infinity)
            } else if case .next(_, let days) = headline {
                Text(snapshot.daysToGo(days)).font(.system(size: 19, weight: .bold)).foregroundStyle(accent)
                    .lineLimit(2).minimumScaleFactor(0.75).widgetAccentable()
            }
            name(headline.item, font: .system(size: 13, weight: .bold))
            Spacer(minLength: 0)
            Text(headline.item.localizedDate).font(.system(size: 10)).foregroundStyle(.secondary)
                .lineLimit(2).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func medium(_ snapshot: WidgetSnapshot, _ headline: WidgetHeadline) -> some View {
        let item = headline.item
        let text = WidgetText(snapshot: snapshot)
        return VStack(alignment: .leading, spacing: 2) {
            header(snapshot, headline)
            HStack(spacing: 10) {
                if headline.isToday {
                    RemainingRing(item: item, snapshot: snapshot, now: now).frame(width: 42, height: 42)
                }
                VStack(alignment: .leading, spacing: 2) {
                    name(item, font: .system(size: 15, weight: .bold))
                    Text(item.localizedDate).font(.system(size: 10)).foregroundStyle(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.75)
                }
            }
            Spacer(minLength: 0)
            HStack(alignment: .top, spacing: 12) {
                compactTiming(snapshot.string("fasting_starts", ""), date: text.date(item.fastingStart), value: text.time(item.fastingStart))
                compactTiming(snapshot.string("parana_window", ""), date: text.date(item.paranaStart), value: text.window(item.paranaStart, item.paranaEnd))
            }
            Spacer(minLength: 0)
            location(snapshot)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Equal-width columns keep translated labels readable instead of squeezing
    /// them beside a full-width date and Parana window.
    private func compactTiming(_ title: String, date: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            WidgetColumnText(value: title, size: 9, weight: .semibold).foregroundStyle(accent)
            WidgetColumnText(value: date, size: 9).foregroundStyle(.secondary)
            WidgetColumnText(value: value, size: 10, weight: .semibold)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    private func circular(_ snapshot: WidgetSnapshot, _ headline: WidgetHeadline) -> some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            VStack(spacing: side * 0.03) {
                ZStack {
                    if headline.isToday {
                        Circle().inset(by: 2).stroke(.primary.opacity(0.2), lineWidth: 3)
                        Circle().inset(by: 2).trim(from: 0, to: headline.item.remainingFraction(at: now))
                            .stroke(.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
                    }
                    WidgetBrandIcon()
                        .padding(headline.isToday ? side * 0.055 : 0)
                }
                .frame(width: side * 0.43, height: side * 0.43)
                Group {
                    if headline.isToday {
                        Text("\(headline.item.remainingPercent(at: now))%")
                    } else if case .next(_, let days) = headline {
                        Text("\(days) \(snapshot.string("day_unit", ""))")
                    }
                }
                .font(.system(size: side * 0.22, weight: .bold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.65)
                .frame(width: side * 0.64, height: side * 0.24)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .foregroundStyle(.white)
            .background(AccessoryWidgetBackground())
            .clipShape(Circle())
        }
        .lineLimit(1).minimumScaleFactor(0.8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(headline.item.name), \(headline.item.localizedDate)")
    }

    private func rectangular(_ snapshot: WidgetSnapshot, _ headline: WidgetHeadline) -> some View {
        HStack(spacing: 6) {
            WidgetBrandIcon().frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(headline.item.name).font(.system(size: 12, weight: .bold)).lineLimit(2).minimumScaleFactor(0.75)
                if headline.isToday {
                    Text("\(headline.item.remainingPercent(at: now))% \(WidgetText(snapshot: snapshot).remainingLabel)")
                        .font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.75)
                } else if case .next(_, let days) = headline {
                    Text(snapshot.daysToGo(days)).font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.75)
                }
                Text(headline.item.localizedDate).font(.system(size: 9)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The app's Panchang symbol stays crisp and white in both Lock Screen families.
struct WidgetBrandIcon: View {
    var body: some View {
        Image(systemName: AppSymbol.tabPanchang).resizable().scaledToFit()
            .symbolRenderingMode(.monochrome).foregroundStyle(.white)
            .accessibilityIdentifier("widget_lock_icon")
            .accessibilityLabel(Text(verbatim: ""))
    }
}

/// A distinct widget with five future dates. Settings injects a Home action;
/// WidgetKit uses one occurrence-specific Link per row.
struct UpcomingEkadashiWidgetView: View {
    let snapshot: WidgetSnapshot?
    let now: Date
    var family: WidgetFamily = .systemLarge
    var onSelect: ((WidgetItem) -> Void)?
    @Environment(\.locale) private var locale

    var body: some View {
        if let snapshot {
            let items = snapshot.upcoming(after: now)
            VStack(alignment: .leading, spacing: family == .systemMedium ? 3 : 8) {
                Text(snapshot.string("upcoming_ekadashis", ""))
                    .font(.system(size: family == .systemMedium ? 11 : 14, weight: .bold))
                    .foregroundStyle(WidgetStyle.teal).lineLimit(1).minimumScaleFactor(0.75).widgetAccentable()
                if items.isEmpty {
                    Text(Localizer.shared.translate("widget_no_next", language: snapshot.locale)).font(.caption)
                }
                ForEach(items, id: \.occurrenceUid) { item in
                    Group {
                        if let onSelect {
                            Button { onSelect(item) } label: { row(item) }
                        } else {
                            Link(destination: item.detailsURL) { row(item) }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("widget_upcoming_open_\(item.occurrenceUid)")
                    .accessibilityLabel("\(item.name)\n\(item.localizedDate)")
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            Text(Localizer.shared.translate("open_app_to_refresh", language: locale.language.languageCode?.identifier ?? "en")).font(.caption)
        }
    }

    @ViewBuilder
    private func row(_ item: WidgetItem) -> some View {
        if family == .systemMedium {
            HStack(spacing: 8) {
                WidgetColumnText(value: item.name, size: 11, weight: .semibold)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                WidgetColumnText(value: item.localizedDate, size: 9).foregroundStyle(.secondary)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
            }
        } else {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.system(size: 15, weight: .semibold)).lineLimit(2).minimumScaleFactor(0.8)
                Text(item.localizedDate).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
