import SwiftUI
import WidgetKit
import EkadashiCore

/// Shared by the extension and Settings: the same real occurrence, palette,
/// local dates, complete timings and filling progress ring on both surfaces.
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
    var lineHeightMultiple: CGFloat = 1.5

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
        .frame(height: ceil(size * lineHeightMultiple))
        .accessibilityLabel(value)
    }

    private func candidate(_ size: CGFloat) -> some View {
        Text(value).font(.system(size: size, weight: weight))
            .lineLimit(1).fixedSize(horizontal: true, vertical: true)
    }
}

struct WidgetStartCountdown: View {
    let item: WidgetItem
    let snapshot: WidgetSnapshot
    let now: Date
    let days: Int
    @Environment(\.isWidgetPresentation) private var nativeWidget
    var body: some View {
        if days <= 0 {
            Group {
                if nativeWidget && WidgetClock.supportsSystemCountdown {
                    let live = Date()
                    let target = WidgetClock.realDate(for: item.fastingStart, liveNow: live) ?? live
                    HStack(spacing: 0) {
                        if item.fastingStart.timeIntervalSince(now) < 36000 { Text("0") }
                        Text(timerInterval: live...max(live, target), countsDown: true, showsHours: true)
                            .multilineTextAlignment(.leading)
                    }
                } else {
                    Text(item.lifecycle(at: now, timeZone: snapshot.timeZone).countdown)
                }
            }.monospacedDigit().accessibilityIdentifier("ekadashi_start_countdown")
        } else { Text(snapshot.daysToGo(days)) }
    }
}

private struct WidgetPresentationKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var isWidgetPresentation: Bool {
        get { self[WidgetPresentationKey.self] }
        set { self[WidgetPresentationKey.self] = newValue }
    }
}

struct RemainingRing: View {
    let item: WidgetItem
    let snapshot: WidgetSnapshot
    let now: Date
    @Environment(\.widgetRenderingMode) private var rendering

    private var accent: Color { rendering == .fullColor ? WidgetStyle.teal : .primary }

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                Circle().inset(by: 2).stroke(Color.primary.opacity(0.15), lineWidth: 4)
                Circle().inset(by: 2)
                    .trim(from: 0, to: item.fastProgress(at: now))
                    .stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .widgetAccentable()
                Text("\(item.completedPercent(at: now))%")
                    .font(.system(size: side * 0.31, weight: .bold))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                    // Text owns a safe interior box, including the wider 100%.
                    .frame(width: side * 0.62, height: side * 0.36)
            }
            .frame(width: side, height: side)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.completedPercent(at: now))% \(Localizer.shared.translate("ios_fast_completed", language: snapshot.locale))")
        .accessibilityIdentifier("widget_remaining_ring")
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
                    // Protect Bengali glyph ink at the small widget's edges.
                    .padding(.horizontal, family == .systemSmall ? 2 : 0)
                    .padding(.bottom, family == .systemSmall ? 3 : 0)
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
            Text(headline.isToday ? headline.item.lifecycle(at: now, timeZone: snapshot.timeZone).label(language: snapshot.locale) : snapshot.string("next_ekadashi", ""))
                .font(.system(size: 10, weight: .bold)).foregroundStyle(accent).lineLimit(1).minimumScaleFactor(0.7).widgetAccentable()
            Spacer(minLength: 4)
            if case .next(_, let days) = headline, family != .systemSmall {
                WidgetStartCountdown(item: headline.item, snapshot: snapshot, now: now, days: days).font(.system(size: 10, weight: .semibold)).foregroundStyle(accent)
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
                WidgetStartCountdown(item: headline.item, snapshot: snapshot, now: now, days: days).font(.system(size: 19, weight: .bold)).foregroundStyle(accent)
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
        ViewThatFits(in: .vertical) {
            mediumContent(snapshot, headline, compact: false).fixedSize(horizontal: false, vertical: true)
            mediumContent(snapshot, headline, compact: true)
        }
    }

    private func mediumContent(_ snapshot: WidgetSnapshot, _ headline: WidgetHeadline, compact: Bool) -> some View {
        let item = headline.item
        let text = WidgetText(snapshot: snapshot)
        return VStack(alignment: .leading, spacing: compact && headline.isToday ? 1 : 2) {
            header(snapshot, headline)
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    name(item, font: .system(size: compact ? 16 : 17, weight: .bold))
                    Text(item.localizedDate).font(.system(size: compact ? 10 : 11)).foregroundStyle(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.75)
                }
                if headline.isToday {
                    RemainingRing(item: item, snapshot: snapshot, now: now)
                        .frame(width: compact ? 44 : 48, height: compact ? 44 : 48)
                }
            }
            HStack(alignment: .top, spacing: 12) {
                compactTiming(snapshot.string("fasting_starts", ""), date: text.date(item.fastingStart), value: text.time(item.fastingStart), compact: compact)
                compactTiming(snapshot.string("parana_window", ""), date: text.date(item.paranaStart), value: text.window(item.paranaStart, item.paranaEnd), compact: compact)
            }
            location(snapshot).padding(.top, headline.isToday ? 6 : 0)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// Equal-width columns keep translated labels readable instead of squeezing
    /// them beside a full-width date and Parana window.
    private func compactTiming(_ title: String, date: String, value: String, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            WidgetColumnText(value: title, size: compact ? 10 : 11, weight: .semibold, lineHeightMultiple: 1.3).foregroundStyle(accent)
            WidgetColumnText(value: date, size: compact ? 9 : 10, lineHeightMultiple: 1.3).foregroundStyle(.secondary)
            WidgetColumnText(value: value, size: compact ? 11 : 12, weight: .semibold, lineHeightMultiple: 1.3)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    private func circular(_ snapshot: WidgetSnapshot, _ headline: WidgetHeadline) -> some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            VStack(spacing: side * 0.03) {
                ZStack {
                    if headline.isToday {
                        Circle().inset(by: side * 0.02).stroke(.primary.opacity(0.2), lineWidth: side * 0.04)
                        Circle().inset(by: side * 0.02).trim(from: 0, to: headline.item.fastProgress(at: now))
                            .stroke(.primary, style: StrokeStyle(lineWidth: side * 0.04, lineCap: .round)).rotationEffect(.degrees(-90))
                    }
                    WidgetBrandIcon()
                        .frame(width: side * (headline.isToday ? 0.23 : 0.43), height: side * (headline.isToday ? 0.23 : 0.43))
                }
                .frame(width: side * (headline.isToday ? 0.52 : 0.43), height: side * (headline.isToday ? 0.52 : 0.43))
                Group {
                    if headline.isToday {
                        Text(headline.item.state(at: now) == .paranaAvailable ? Localizer.shared.translate("panchang_parana", language: snapshot.locale) : "\(headline.item.completedPercent(at: now))%")
                    } else if case .next(_, let days) = headline {
                        if days <= 0 {
                            WidgetStartCountdown(item: headline.item, snapshot: snapshot, now: now, days: days)
                        } else { Text("\(days) \(snapshot.string("day_unit", ""))") }
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
                    Text(headline.item.state(at: now) == .paranaAvailable
                        ? Localizer.shared.translate("panchang_parana", language: snapshot.locale)
                        : "\(snapshot.string("now", "")) · \(headline.item.completedPercent(at: now))% \(Localizer.shared.translate("ios_fast_completed", language: snapshot.locale))")
                        .font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.75)
                } else if case .next(_, let days) = headline {
                    WidgetStartCountdown(item: headline.item, snapshot: snapshot, now: now, days: days).font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.75)
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
