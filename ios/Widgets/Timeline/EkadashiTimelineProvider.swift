import WidgetKit
import SwiftUI

// MARK: - Timeline Entry
public struct EkadashiEntry: TimelineEntry {
    public let date: Date
    public let payload: WidgetPayload
    public let state: WidgetState
    public let cacheStatus: CacheStatus

    public init(
        date: Date,
        payload: WidgetPayload,
        state: WidgetState,
        cacheStatus: CacheStatus = .valid
    ) {
        self.date = date
        self.payload = payload
        self.state = state
        self.cacheStatus = cacheStatus
    }

    public static var placeholder: EkadashiEntry {
        EkadashiEntry(
            date: Date(),
            payload: WidgetPayload.fallback,
            state: .beforeEkadashi,
            cacheStatus: .valid
        )
    }
}

// MARK: - Timeline Provider
public struct EkadashiTimelineProvider: TimelineProvider {
    public typealias Entry = EkadashiEntry

    public init() {}

    public func placeholder(in context: Context) -> EkadashiEntry {
        .placeholder
    }

    public func getSnapshot(in context: Context, completion: @escaping (EkadashiEntry) -> Void) {
        let (payload, status) = SharedWidgetStorage.shared.loadPayload()
        let p = payload ?? WidgetPayload.fallback
        let currentState = p.nextEkadashi?.stateAt(date: Date()) ?? p.currentState
        completion(EkadashiEntry(date: Date(), payload: p, state: currentState, cacheStatus: status))
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<EkadashiEntry>) -> Void) {
        let now = Date()
        let (loadedPayload, status) = SharedWidgetStorage.shared.loadPayload()

        // 1. Fallback Handling
        guard let payload = loadedPayload, status.canDisplay, let currentEkadashi = payload.nextEkadashi else {
            let entry = EkadashiEntry(
                date: now,
                payload: loadedPayload ?? WidgetPayload.fallback,
                state: .fallback,
                cacheStatus: status
            )
            // Retry in 2 hours for fallback
            let reloadDate = Calendar.current.date(byAdding: .hour, value: 2, to: now) ?? now.addingTimeInterval(7200)
            let timeline = Timeline(entries: [entry], policy: .after(reloadDate))
            completion(timeline)
            return
        }

        // 2. Resolve Active Ekadashi & Handle Auto-Advance to NEXT_EKADASHI
        let (activeItem, activePayload) = resolveActiveEkadashi(from: payload, at: now)
        guard let currentEkadashi = activeItem else {
            let entry = EkadashiEntry(date: now, payload: payload, state: .beforeEkadashi, cacheStatus: status)
            completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(3600 * 6))))
            return
        }

        // 3. Compute Discrete Transition Dates
        var entries: [EkadashiEntry] = []

        // Entry 1: Current Moment
        let initialState = currentEkadashi.stateAt(date: now)
        entries.append(EkadashiEntry(date: now, payload: activePayload, state: initialState, cacheStatus: status))

        // Collect prospective transition points for current active Ekadashi
        var transitionDates: [(date: Date, payload: WidgetPayload, state: WidgetState)] = []

        if let fStart = currentEkadashi.fastingStartDate, fStart > now {
            transitionDates.append((fStart, activePayload, .fastingActive))
        }
        if let pStart = currentEkadashi.paranaStartDate, pStart > now {
            transitionDates.append((pStart, activePayload, .paranaAvailable))
        }
        if let pEnd = currentEkadashi.paranaEndDate, pEnd > now {
            transitionDates.append((pEnd, activePayload, .paranaCompleted))

            // State transition: PARANA_COMPLETED -> NEXT_EKADASHI (Advance to next upcoming Ekadashi 2 hours after Parana ends)
            let nextAdvanceDate = pEnd.addingTimeInterval(7200)
            if let firstUpcoming = activePayload.upcomingEkadashis.first {
                let advancedPayload = WidgetPayload(
                    metadata: activePayload.metadata,
                    currentState: .beforeEkadashi,
                    nextEkadashi: firstUpcoming,
                    upcomingEkadashis: Array(activePayload.upcomingEkadashis.dropFirst()),
                    localizedStrings: activePayload.localizedStrings
                )
                transitionDates.append((nextAdvanceDate, advancedPayload, .beforeEkadashi))
            }
        }

        // Add midnight boundaries up to 3 days to keep day countdowns fresh
        let calendar = Calendar.current
        for dayOffset in 1...3 {
            if let midnight = calendar.date(bySettingHour: 0, minute: 0, second: 1, of: calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now) {
                if midnight > now {
                    let (itemAtMidnight, payloadAtMidnight) = resolveActiveEkadashi(from: payload, at: midnight)
                    let stateAtMidnight = itemAtMidnight?.stateAt(date: midnight) ?? .beforeEkadashi
                    transitionDates.append((midnight, payloadAtMidnight, stateAtMidnight))
                }
            }
        }

        // Sort chronologically and deduplicate within 60 seconds
        transitionDates.sort { $0.date < $1.date }
        var lastDate = now
        for t in transitionDates {
            if t.date.timeIntervalSince(lastDate) >= 60 {
                entries.append(EkadashiEntry(date: t.date, payload: t.payload, state: t.state, cacheStatus: status))
                lastDate = t.date
            }
        }

        // 4. Determine Timeline Reload Policy
        let reloadDate: Date
        if let pEnd = currentEkadashi.paranaEndDate, pEnd > now {
            reloadDate = pEnd.addingTimeInterval(7260) // After Parana + completion window
        } else {
            reloadDate = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 5), matchingPolicy: .nextTime)
                ?? now.addingTimeInterval(3600 * 6)
        }

        let timeline = Timeline(entries: entries, policy: .after(reloadDate))
        completion(timeline)
    }

    /// Resolves the currently active Ekadashi. If nextEkadashi's Parana window has passed,
    /// promotes the first upcoming Ekadashi to maintain valid display without opening the app.
    private func resolveActiveEkadashi(from payload: WidgetPayload, at date: Date) -> (EkadashiItem?, WidgetPayload) {
        guard let next = payload.nextEkadashi else {
            return (nil, payload)
        }

        // If parana window is still in the future or within 2 hours of completion, keep it
        if let pEnd = next.paranaEndDate {
            if date <= pEnd.addingTimeInterval(7200) {
                return (next, payload)
            }
        } else if let fStart = next.fastingStartDate, date <= fStart {
            return (next, payload)
        }

        // Check if we have upcoming items to advance to
        if let firstUpcoming = payload.upcomingEkadashis.first {
            let advancedPayload = WidgetPayload(
                metadata: payload.metadata,
                currentState: firstUpcoming.stateAt(date: date),
                nextEkadashi: firstUpcoming,
                upcomingEkadashis: Array(payload.upcomingEkadashis.dropFirst()),
                localizedStrings: payload.localizedStrings
            )
            return (firstUpcoming, advancedPayload)
        }

        return (next, payload)
    }
}
