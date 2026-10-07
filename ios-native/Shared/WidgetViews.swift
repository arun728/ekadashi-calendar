import SwiftUI
import EkadashiCore

/// The three home-screen widgets, shared by the widget extension and the
/// in-app preview (Android: next, today and upcoming widgets). Everything is
/// rendered from the App Group snapshot and re-evaluated at render time, so
/// states and countdowns stay right even if the app has not run since.
enum WidgetStyle {
    static let cyan = Color(red: 0, green: 0xE5 / 255, blue: 1)
    static let mist = Color(red: 0xE0 / 255, green: 0xF7 / 255, blue: 0xFA / 255)
    static let tile = Color(red: 0x02 / 255, green: 0x1B / 255, blue: 0x24 / 255)
    static let tileBorder = Color(red: 0, green: 0x8F / 255, blue: 0xA0 / 255)
}

/// Deep teal gradient with the lotus watermark (Android widget background).
struct WidgetCardBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0x04 / 255, green: 0x25 / 255, blue: 0x30 / 255),
                                    Color(red: 0x01 / 255, green: 0x18 / 255, blue: 0x20 / 255),
                                    Color(red: 0, green: 0x0E / 255, blue: 0x14 / 255)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image("widget_bg_lotus_watermark").resizable().scaledToFill().opacity(0.22)
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

/// Small: the next Ekadashi and its countdown.
struct NextEkadashiWidgetView: View {
    let snapshot: WidgetSnapshot?
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image("widget_vishnu_small").resizable().scaledToFit().frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Text((snapshot?.string("next_ekadashi", "Next Ekadashi") ?? "Next Ekadashi").uppercased())
                    .font(.caption2.weight(.heavy)).foregroundStyle(.white).lineLimit(2).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 2)
            if let snapshot, let item = snapshot.activeItem(at: now) {
                Text(item.name).font(.headline).foregroundStyle(.white).lineLimit(2).minimumScaleFactor(0.7)
                Text(item.localizedDate).font(.caption2).foregroundStyle(WidgetStyle.mist)
                Text(widgetStatus(item, snapshot, now: now)).font(.caption.weight(.semibold)).foregroundStyle(WidgetStyle.cyan)
                    .lineLimit(2).minimumScaleFactor(0.7)
            } else {
                Text(snapshot?.string("open_app_to_refresh", "Open app to refresh") ?? "Open app to refresh")
                    .font(.caption).foregroundStyle(WidgetStyle.mist)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Medium: today's Ekadashi with fasting and Parana times, or the next one.
struct TodayEkadashiWidgetView: View {
    let snapshot: WidgetSnapshot?
    let now: Date

    var body: some View {
        HStack(spacing: 14) {
            Image("widget_vishnu_medium").resizable().scaledToFit().frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text((snapshot?.string("today_title", "Ekadashi Today") ?? "Ekadashi Today").uppercased())
                    .font(.caption.weight(.heavy)).foregroundStyle(.white)
                if let snapshot, let item = snapshot.activeItem(at: now) {
                    let times = WidgetTimes(snapshot: snapshot)
                    let isToday = CivilDate(iso: item.date) == TzDatabase.shared.location(snapshot.timeZone)?.wallClock(now).date
                    Text(isToday ? item.name : "\(snapshot.string("no_ekadashi", "No Ekadashi today")) · \(item.name)")
                        .font(.headline).foregroundStyle(.white).lineLimit(2).minimumScaleFactor(0.7)
                    HStack(spacing: 10) {
                        label(snapshot.string("fasting_starts", "Start"), times.time(item.fastingStart))
                        label(snapshot.string("parana_window", "Parana"), "\(times.time(item.paranaStart))–\(times.time(item.paranaEnd))")
                    }
                    Text(widgetStatus(item, snapshot, now: now)).font(.caption.weight(.semibold)).foregroundStyle(WidgetStyle.cyan)
                    if !snapshot.locationName.isEmpty {
                        Label(snapshot.locationName, systemImage: "location.fill").font(.caption2).foregroundStyle(WidgetStyle.mist)
                            .lineLimit(1)
                    }
                } else {
                    Text(snapshot?.string("open_app_to_refresh", "Open app to refresh") ?? "Open app to refresh")
                        .font(.caption).foregroundStyle(WidgetStyle.mist)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func label(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.caption2).foregroundStyle(WidgetStyle.mist).lineLimit(1)
            Text(value).font(.caption.weight(.semibold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}

/// Large: the next Ekadashi and the following ones as date tiles.
struct UpcomingEkadashiWidgetView: View {
    let snapshot: WidgetSnapshot?
    let now: Date
    var maxRows = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image("widget_vishnu_large").resizable().scaledToFit().frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text((snapshot?.string("upcoming_ekadashis", "Upcoming Ekadashis") ?? "Upcoming Ekadashis").uppercased())
                    .font(.subheadline.weight(.heavy)).foregroundStyle(.white)
            }
            if let snapshot, let next = snapshot.activeItem(at: now) {
                let times = WidgetTimes(snapshot: snapshot)
                let items = [next] + snapshot.upcoming(after: now).prefix(maxRows - 1)
                ForEach(items) { item in
                    Link(destination: AppRoute.calendarURL(CivilDate(iso: item.date) ?? CivilDate(2026, 1, 1))) {
                        HStack(spacing: 10) {
                            VStack(spacing: 2) {
                                Text(times.month(item)).font(.caption2.bold()).foregroundStyle(WidgetStyle.cyan)
                                Text(times.day(item)).font(.headline.bold()).foregroundStyle(.white)
                            }
                            .frame(width: 50)
                            .padding(.vertical, 6)
                            .background(WidgetStyle.tile.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(WidgetStyle.tileBorder, lineWidth: 1.2))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
                                Text(item.id == next.id ? widgetStatus(item, snapshot, now: now)
                                     : "\(snapshot.string("fasting_starts", "Start")) \(times.time(item.fastingStart))")
                                    .font(.caption).foregroundStyle(item.id == next.id ? WidgetStyle.cyan : WidgetStyle.mist)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            } else {
                Text(snapshot?.string("open_app_to_refresh", "Open app to refresh") ?? "Open app to refresh")
                    .font(.caption).foregroundStyle(WidgetStyle.mist)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
