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

private struct RemainingRing: View {
    let item: WidgetItem
    let snapshot: WidgetSnapshot
    let now: Date
    var prominent = false
    @Environment(\.widgetRenderingMode) private var rendering

    private var accent: Color { rendering == .fullColor ? WidgetStyle.teal : .primary }

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.15), lineWidth: 9)
            Circle()
                .trim(from: 0, to: item.remainingFraction(at: now))
                .stroke(accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
            VStack(spacing: 0) {
                Text("\(item.remainingPercent(at: now))%")
                    .font(prominent ? .largeTitle.bold() : .title2.bold())
                    .monospacedDigit()
                Text(WidgetText(snapshot: snapshot).remainingLabel)
                    .font(.caption2).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .padding(6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.remainingPercent(at: now))% \(WidgetText(snapshot: snapshot).remainingLabel)")
    }
}

struct EkadashiWidgetView: View {
    let snapshot: WidgetSnapshot?
    let now: Date
    var family: WidgetFamily = .systemSmall
    var selection: WidgetSelection = .automatic
    @Environment(\.widgetRenderingMode) private var rendering

    private var accent: Color { rendering == .fullColor ? WidgetStyle.teal : .primary }

    var body: some View {
        Group {
            if let snapshot, let headline = snapshot.headline(at: now, selection: selection) {
                switch family {
                case .accessoryCircular: circular(snapshot, headline)
                case .accessoryRectangular: rectangular(snapshot, headline)
                case .systemMedium: medium(snapshot, headline)
                case .systemLarge: large(snapshot, headline)
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
        guard let snapshot else { return Localizer.shared.translate("open_app_to_refresh", language: "en") }
        return Localizer.shared.translate(selection == .today ? "no_ekadashi" : "widget_no_next", language: snapshot.locale)
    }

    private func header(_ snapshot: WidgetSnapshot, _ headline: WidgetHeadline) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(snapshot.string(headline.isToday ? "today_title" : "next_ekadashi", ""))
                .font(.caption2.bold()).foregroundStyle(accent).lineLimit(1).widgetAccentable()
            Spacer(minLength: 4)
            if case .next(_, let days) = headline, family != .systemSmall {
                Text(snapshot.daysToGo(days)).font(.caption2.weight(.semibold)).foregroundStyle(accent)
            }
        }
    }

    private func name(_ item: WidgetItem, font: Font) -> some View {
        Text(item.name).font(font).lineLimit(2).minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func location(_ snapshot: WidgetSnapshot) -> some View {
        Text([snapshot.locationName, WidgetText(snapshot: snapshot).tradition].filter { !$0.isEmpty }.joined(separator: " · "))
            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func small(_ snapshot: WidgetSnapshot, _ headline: WidgetHeadline) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            header(snapshot, headline)
            if headline.isToday {
                RemainingRing(item: headline.item, snapshot: snapshot, now: now)
                    .frame(width: 76, height: 76).frame(maxWidth: .infinity)
                name(headline.item, font: .subheadline.bold())
            } else if case .next(let item, let days) = headline {
                Spacer(minLength: 0)
                Text(snapshot.daysToGo(days)).font(.title2.bold()).foregroundStyle(accent).widgetAccentable()
                    .lineLimit(2).minimumScaleFactor(0.8)
                name(item, font: .headline)
                Spacer(minLength: 0)
                Text(item.localizedDate).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func medium(_ snapshot: WidgetSnapshot, _ headline: WidgetHeadline) -> some View {
        let item = headline.item
        let text = WidgetText(snapshot: snapshot)
        return VStack(alignment: .leading, spacing: 5) {
            header(snapshot, headline)
            if headline.isToday {
                HStack(spacing: 14) {
                    RemainingRing(item: item, snapshot: snapshot, now: now).frame(width: 86, height: 86)
                    VStack(alignment: .leading, spacing: 3) {
                        name(item, font: .headline)
                        Text(item.localizedDate).font(.caption2).foregroundStyle(.secondary)
                        Text(snapshot.string("parana_window", "")).font(.caption2).foregroundStyle(accent)
                        Text("\(text.date(item.paranaStart))\n\(text.window(item.paranaStart, item.paranaEnd))")
                            .font(.caption2.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            } else {
                name(item, font: .headline)
                Text(item.localizedDate).font(.caption2).foregroundStyle(.secondary)
                Divider()
                timingRow(snapshot.string("fasting_starts", ""), "\(text.date(item.fastingStart)) · \(text.time(item.fastingStart))")
                timingRow(snapshot.string("parana_window", ""), "\(text.date(item.paranaStart)) · \(text.window(item.paranaStart, item.paranaEnd))")
                Spacer(minLength: 0)
            }
            location(snapshot)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func timingRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(value).font(.caption2.weight(.semibold)).multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true).layoutPriority(1)
        }
    }

    private func large(_ snapshot: WidgetSnapshot, _ headline: WidgetHeadline) -> some View {
        let item = headline.item
        let text = WidgetText(snapshot: snapshot)
        return VStack(alignment: .leading, spacing: 8) {
            header(snapshot, headline)
            name(item, font: .title2.bold())
            Text(item.localizedDate).font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if headline.isToday {
                RemainingRing(item: item, snapshot: snapshot, now: now, prominent: true)
                    .frame(width: 140, height: 140).frame(maxWidth: .infinity)
            } else {
                timingSection(snapshot.string("fasting_starts", ""), date: text.date(item.fastingStart), value: text.time(item.fastingStart))
            }
            Spacer(minLength: 0)
            Divider()
            timingSection(snapshot.string("parana_window", ""), date: text.date(item.paranaStart), value: text.window(item.paranaStart, item.paranaEnd))
            Spacer(minLength: 0)
            location(snapshot)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func timingSection(_ label: String, date: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption.bold()).foregroundStyle(accent).widgetAccentable()
            Text(date).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold()).fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func circular(_ snapshot: WidgetSnapshot, _ headline: WidgetHeadline) -> some View {
        if headline.isToday {
            Gauge(value: headline.item.remainingFraction(at: now)) {
                Text(WidgetText(snapshot: snapshot).remainingLabel)
            } currentValueLabel: {
                Text("\(headline.item.remainingPercent(at: now))%")
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .accessibilityLabel("\(headline.item.name), \(headline.item.remainingPercent(at: now))% \(WidgetText(snapshot: snapshot).remainingLabel)")
        } else if case .next(_, let days) = headline {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text("\(days)").font(.title2.bold())
                    Text(snapshot.string("day_unit", "")).font(.caption2)
                }
            }
        }
    }

    private func rectangular(_ snapshot: WidgetSnapshot, _ headline: WidgetHeadline) -> some View {
        HStack(spacing: 6) {
            if headline.isToday { circular(snapshot, headline).frame(width: 44, height: 44) }
            VStack(alignment: .leading, spacing: 1) {
                Text(headline.item.name).font(.headline).lineLimit(1).minimumScaleFactor(0.8)
                if headline.isToday {
                    Text("\(headline.item.remainingPercent(at: now))% \(WidgetText(snapshot: snapshot).remainingLabel)").font(.caption)
                    Text(WidgetText(snapshot: snapshot).time(headline.item.paranaStart)).font(.caption2)
                } else if case .next(let item, let days) = headline {
                    Text(snapshot.daysToGo(days)).font(.caption)
                    Text(item.localizedDate).font(.caption2).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// Existing installed Upcoming widgets keep their kind, and adopt the same
/// single-occurrence design rather than listing several unrelated dates.
struct UpcomingEkadashiWidgetView: View {
    let snapshot: WidgetSnapshot?
    let now: Date
    var family: WidgetFamily = .systemLarge
    var body: some View { EkadashiWidgetView(snapshot: snapshot, now: now, family: family) }
}
