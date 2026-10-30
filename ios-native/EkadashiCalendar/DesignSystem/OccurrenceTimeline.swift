import SwiftUI
import EkadashiCore

/// A lazy, bounded-frequency schedule. Hidden/background views get one render
/// and no ticking sequence. It never reloads a schedule or computes astronomy.
struct OccurrenceTimelineSchedule: TimelineSchedule {
    let events: [EkadashiOccurrence]
    let zone: TzLocation
    let active: Bool

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnySequence<Date> {
        guard active, !DisplayClock.isFrozen else { return AnySequence([startDate]) }
        return AnySequence(sequence(state: Optional(startDate)) { cursor -> Date? in
            guard let current = cursor else { return nil }
            let now = DisplayClock.date(current)
            let next = events.compactMap { $0.nextLifecycleUpdate(after: now, zone: zone) }.min()
            cursor = next.map { current.addingTimeInterval(DisplayClock.realInterval($0.timeIntervalSince(now))) }
            return current
        })
    }
}

struct OccurrenceTimeline<Content: View>: View {
    let events: [EkadashiOccurrence]
    let timeZone: String
    var active = true
    @ViewBuilder var content: (Date) -> Content
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(OccurrenceTimelineSchedule(events: events,
            zone: TzDatabase.shared.location(timeZone) ?? AppTimezone.ist.location,
            active: active && scenePhase == .active)) { context in
                content(DisplayClock.date(context.date))
        }
    }
}
