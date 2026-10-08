import SwiftUI
import WidgetKit
import EkadashiCore

/// The two home-screen widgets (docs/ROADMAP.md Phase 6), shared by the
/// widget extension and the in-app preview:
/// - Ekadashi: on an Ekadashi, "Today is Ekadashi", the fast's progress and
///   the time to Parana; otherwise the next Ekadashi and the days to go.
///   Small, medium and the lock screen.
/// - Upcoming: the next Ekadashis as date tiles. Medium and large.
/// Everything comes from the App Group snapshot and is re-evaluated at
/// render time, so states change on time even if the app has not run.
/// Text stays legible when iOS tints or clears the widget (accented and
/// vibrant rendering): key elements are accentable and the background is a
/// container background the system can remove.
enum WidgetStyle {
    static let cyan = Color(red: 0, green: 0xE5 / 255, blue: 1)
    static let mist = Color(red: 0xE0 / 255, green: 0xF7 / 255, blue: 0xFA / 255)
    static let tile = Color(red: 0x02 / 255, green: 0x1B / 255, blue: 0x24 / 255)
    static let tileBorder = Color(red: 0, green: 0x8F / 255, blue: 0xA0 / 255)
}

/// Deep teal gradient with a faint lotus (the Android widget background).
struct WidgetCardBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0x05 / 255, green: 0x33 / 255, blue: 0x3D / 255),
                                    Color(red: 0x02 / 255, green: 0x1C / 255, blue: 0x24 / 255),
                                    Color(red: 0, green: 0x0E / 255, blue: 0x14 / 255)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image("widget_bg_lotus_watermark").resizable().scaledToFill().opacity(0.14)
        }
    }
}

struct WidgetTimes {
    let snapshot: WidgetSnapshot

    private func formatter(_ pattern: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Localizer.locale(snapshot.locale)
        formatter.timeZone = TimeZone(identifier: snapshot.timeZone) ?? .current
        formatter.dateFormat = pattern
        return formatter
    }

    func time(_ date: Date?) -> String { date.map { formatter("h:mm a").string(from: $0) } ?? "--" }
    func month(_ item: WidgetItem) -> String { formatter("MMM").string(from: item.fastingStart).uppercased() }
    func day(_ item: WidgetItem) -> String { CivilDate(iso: item.date).map { String($0.day) } ?? "" }
}

/// Status line of an item: "Starts in 2 d 3 h", "Parana in 3 h", "Parana ends in 40 min".
func widgetStatus(_ item: WidgetItem, _ snapshot: WidgetSnapshot, now: Date) -> String {
    let state = item.state(at: now)
    let remaining = snapshot.remaining(until: item.target(for: state), now: now)
    switch state {
    case .fastingActive: return "\(snapshot.string("parana_in", "Parana in")) \(remaining)"
    case .paranaAvailable: return "\(snapshot.string("parana_ends", "Parana ends in")) \(remaining)"
    default: return "\(snapshot.string("starts_in", "Starts in")) \(remaining)"
    }
}

private struct OpenAppHint: View {
    let snapshot: WidgetSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "leaf.fill").foregroundStyle(WidgetStyle.cyan).widgetAccentable()
            Text(snapshot?.string("open_app_to_refresh", "Open the app to refresh") ?? "Open the app to refresh")
                .font(.caption).foregroundStyle(WidgetStyle.mist)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The fast's progress as a ring with the percentage inside.
private struct FastRing: View {
    let progress: Double
    var lineWidth: CGFloat = 6

    var body: some View {
        ZStack {
            Circle().stroke(WidgetStyle.cyan.opacity(0.22), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.02, progress))
                .stroke(WidgetStyle.cyan, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
            Text("\(Int((progress * 100).rounded()))%")
                .font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(.white)
                .minimumScaleFactor(0.6)
        }
    }
}

// MARK: - Ekadashi widget

struct EkadashiWidgetView: View {
    let snapshot: WidgetSnapshot?
    let now: Date
    var family: WidgetFamily = .systemSmall

    var body: some View {
        if let snapshot, let headline = snapshot.headline(at: now) {
            switch family {
            case .accessoryCircular: circular(snapshot, headline)
            case .accessoryRectangular: rectangular(snapshot, headline)
            case .systemMedium: medium(snapshot, headline)
            default: small(snapshot, headline)
            }
        } else {
            OpenAppHint(snapshot: snapshot)
        }
    }

    private func label(_ snapshot: WidgetSnapshot, _ headline: WidgetHeadline) -> String {
        if case .today = headline { return snapshot.string("today_is_ekadashi", "Today is Ekadashi") }
        return snapshot.string("next_ekadashi", "Next Ekadashi")
    }

    private func small(_ snapshot: WidgetSnapshot, _ headline: WidgetHeadline) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label(snapshot, headline).uppercased())
                .font(.caption2.weight(.bold)).foregroundStyle(WidgetStyle.cyan).lineLimit(1).minimumScaleFactor(0.7)
                .widgetAccentable()
            switch headline {
            case .today(let item, let progress):
                Text(item.name).font(.headline).foregroundStyle(.white).lineLimit(2).minimumScaleFactor(0.7)
                Spacer(minLength: 2)
                HStack(spacing: 8) {
                    FastRing(progress: progress, lineWidth: 5).frame(width: 44, height: 44)
                    Text(widgetStatus(item, snapshot, now: now))
                        .font(.caption.weight(.semibold)).foregroundStyle(WidgetStyle.mist).lineLimit(3).minimumScaleFactor(0.7)
                }
            case .next(let item, let days):
                Text(item.name).font(.headline).foregroundStyle(.white).lineLimit(2).minimumScaleFactor(0.7)
                Spacer(minLength: 2)
                Text(snapshot.daysToGo(days))
                    .font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(.white)
                    .lineLimit(2).minimumScaleFactor(0.6)
                    .widgetAccentable()
                Text(item.localizedDate).font(.caption2).foregroundStyle(WidgetStyle.mist).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func medium(_ snapshot: WidgetSnapshot, _ headline: WidgetHeadline) -> some View {
        let times = WidgetTimes(snapshot: snapshot)
        let item: WidgetItem
        switch headline {
        case .today(let current, _): item = current
        case .next(let next, _): item = next
        }
        return HStack(spacing: 16) {
            Group {
                switch headline {
                case .today(_, let progress):
                    FastRing(progress: progress, lineWidth: 8)
                case .next(_, let days):
                    VStack(spacing: 0) {
                        Text(days <= 1 ? times.day(item) : "\(days)")
                            .font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(.white)
                            .minimumScaleFactor(0.5).widgetAccentable()
                        Text(days <= 1 ? times.month(item) : snapshot.string("day_unit", "d"))
                            .font(.caption.weight(.bold)).foregroundStyle(WidgetStyle.cyan)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(WidgetStyle.tile.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(WidgetStyle.tileBorder.opacity(0.7)))
                }
            }
            .frame(width: 84, height: 84)
            VStack(alignment: .leading, spacing: 4) {
                Text(label(snapshot, headline).uppercased())
                    .font(.caption2.weight(.bold)).foregroundStyle(WidgetStyle.cyan).widgetAccentable()
                Text(item.name).font(.title3.weight(.bold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                if case .next(_, let days) = headline {
                    Text("\(item.localizedDate) · \(snapshot.daysToGo(days))")
                        .font(.caption).foregroundStyle(WidgetStyle.mist).lineLimit(1).minimumScaleFactor(0.7)
                } else {
                    Text(widgetStatus(item, snapshot, now: now)).font(.caption.weight(.semibold)).foregroundStyle(WidgetStyle.mist)
                        .lineLimit(1)
                }
                HStack(spacing: 14) {
                    detail(snapshot.string("fasting_starts", "Start"), times.time(item.fastingStart))
                    detail(snapshot.string("parana_window", "Parana"), "\(times.time(item.paranaStart)) – \(times.time(item.paranaEnd))")
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func detail(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(WidgetStyle.mist.opacity(0.8)).lineLimit(1)
            Text(value).font(.caption.weight(.semibold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    @ViewBuilder
    private func circular(_ snapshot: WidgetSnapshot, _ headline: WidgetHeadline) -> some View {
        switch headline {
        case .today(_, let progress):
            Gauge(value: progress) {
                Image(systemName: "leaf.fill")
            } currentValueLabel: {
                Text("\(Int((progress * 100).rounded()))")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .next(_, let days):
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: -2) {
                    Text("\(days)").font(.system(.title2, design: .rounded).weight(.bold)).widgetAccentable()
                    Text(snapshot.string("day_unit", "d")).font(.caption2)
                }
            }
        }
    }

    private func rectangular(_ snapshot: WidgetSnapshot, _ headline: WidgetHeadline) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label(snapshot, headline)).font(.caption.weight(.semibold)).widgetAccentable()
            switch headline {
            case .today(let item, _):
                Text(item.name).font(.headline).lineLimit(1)
                Text(widgetStatus(item, snapshot, now: now)).font(.caption).lineLimit(1)
            case .next(let item, let days):
                Text(item.name).font(.headline).lineLimit(1)
                Text(snapshot.daysToGo(days)).font(.caption).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Upcoming widget

/// The next Ekadashis as date tiles: three in medium, five in large.
struct UpcomingEkadashiWidgetView: View {
    let snapshot: WidgetSnapshot?
    let now: Date
    var family: WidgetFamily = .systemLarge

    private var rows: Int { family == .systemMedium ? 3 : 5 }

    var body: some View {
        if let snapshot, let next = snapshot.activeItem(at: now) {
            let times = WidgetTimes(snapshot: snapshot)
            let items = [next] + snapshot.upcoming(after: now).prefix(rows - 1)
            VStack(alignment: .leading, spacing: family == .systemMedium ? 6 : 10) {
                Text(snapshot.string("upcoming_ekadashis", "Upcoming Ekadashis").uppercased())
                    .font(.caption.weight(.bold)).foregroundStyle(WidgetStyle.cyan).widgetAccentable()
                ForEach(items) { item in
                    Link(destination: AppRoute.calendarURL(CivilDate(iso: item.date) ?? CivilDate(2026, 1, 1))) {
                        row(item, isNext: item.id == next.id, snapshot: snapshot, times: times)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            OpenAppHint(snapshot: snapshot)
        }
    }

    private func row(_ item: WidgetItem, isNext: Bool, snapshot: WidgetSnapshot, times: WidgetTimes) -> some View {
        HStack(spacing: 10) {
            VStack(spacing: 0) {
                Text(times.month(item)).font(.system(size: 9, weight: .bold)).foregroundStyle(WidgetStyle.cyan)
                Text(times.day(item)).font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(.white)
            }
            .frame(width: 40, height: family == .systemMedium ? 34 : 40)
            .background(WidgetStyle.tile.opacity(0.7), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(isNext ? WidgetStyle.cyan : WidgetStyle.tileBorder.opacity(0.6), lineWidth: isNext ? 1.5 : 1))
            .widgetAccentable(isNext)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
                Text(isNext ? widgetStatus(item, snapshot, now: now)
                     : "\(snapshot.string("fasting_starts", "Start")) \(times.time(item.fastingStart))")
                    .font(.caption2).foregroundStyle(isNext ? WidgetStyle.cyan : WidgetStyle.mist).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}
