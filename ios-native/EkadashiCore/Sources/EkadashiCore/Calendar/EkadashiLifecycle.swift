import Foundation

/// Parana remains a linked calendar entry, but only a fasting date gets a dot.
public struct EkadashiCalendarDay {
    public let fasting: [EkadashiOccurrence]
    public let parana: [EkadashiOccurrence]
    public var showsFastingMarker: Bool { !fasting.isEmpty }

    public init(events: [EkadashiOccurrence], day: CivilDate, zone: TzLocation) {
        fasting = events.filter { $0.date == day }
        parana = events.filter { $0.date != day && $0.hasParana(on: day, zone: zone) }
    }
}

/// One occurrence has two boundaries: progress completes when Parana opens,
/// while the occurrence remains current until Parana closes. All comparisons
/// use instants; only the pre-start countdown's date uses the schedule zone.
public struct EkadashiLifecycle: Equatable, Sendable {
    public enum Phase: Equatable, Sendable { case scheduled, countdown, fasting, parana, passed, unavailable }
    public let phase: Phase
    public let progress: Double?
    public let secondsUntilStart: Int
    public let daysUntil: Int

    public init(date: CivilDate, start: Date?, parana: Date?, end: Date?, now: Date, zone: TzLocation) {
        daysUntil = zone.wallClock(now).date.days(until: date)
        // The existing schedule drops seconds. A sub-minute Parana may collapse
        // to one recorded instant; keep the fast valid without inventing time.
        guard let start, let parana, let end, start < parana, parana <= end else {
            phase = .unavailable; progress = nil; secondsUntilStart = 0; return
        }
        secondsUntilStart = max(0, Int(ceil(start.timeIntervalSince(now))))
        if now < start {
            phase = daysUntil <= 0 ? .countdown : .scheduled; progress = nil
        } else if now < parana {
            phase = .fasting; progress = max(0, min(1, now.timeIntervalSince(start) / parana.timeIntervalSince(start)))
        } else if now < end {
            phase = .parana; progress = 1
        } else {
            phase = .passed; progress = nil
        }
    }

    public var percent: Int? { progress.map { min(100, Int(floor($0 * 100 + 0.000000001))) } }
    public var countdown: String {
        String(format: "%02d:%02d:%02d", secondsUntilStart / 3600, secondsUntilStart / 60 % 60, secondsUntilStart % 60)
    }
    public func label(language: String, localizer: Localizer = .shared) -> String {
        func t(_ key: String) -> String { localizer.translate(key, language: language) }
        switch phase {
        case .countdown: return countdown
        case .fasting: return t("widget_now")
        case .parana: return t("panchang_parana")
        case .passed: return t("passed")
        case .scheduled, .unavailable:
            if daysUntil < 0 { return t("passed") }
            if daysUntil == 1 { return t("tomorrow") }
            return localizer.translate("in_days", language: language, args: [String(max(0, daysUntil))])
        }
    }
}

public extension EkadashiOccurrence {
    func lifecycle(at now: Date, zone: TzLocation) -> EkadashiLifecycle {
        EkadashiLifecycle(date: date, start: fastingStart, parana: paranaStart, end: paranaEnd, now: now, zone: zone)
    }
    func hasParana(on date: CivilDate, zone: TzLocation) -> Bool {
        guard let start = paranaStart, let end = paranaEnd, end >= start else { return false }
        if end == start { return date == zone.wallClock(start).date }
        return date >= zone.wallClock(start).date && date <= zone.wallClock(end.addingTimeInterval(-0.001)).date
    }
}

public extension WidgetItem {
    func lifecycle(at now: Date, timeZone: String) -> EkadashiLifecycle {
        EkadashiLifecycle(date: CivilDate(iso: date) ?? CivilDate(utc: fastingStart), start: fastingStart,
            parana: paranaStart, end: paranaEnd, now: now,
            zone: TzDatabase.shared.location(timeZone) ?? AppTimezone.ist.location)
    }
    /// Completed percentage; never announce 100% before Parana starts.
    func completedPercent(at now: Date) -> Int { min(100, Int(floor(fastProgress(at: now) * 100 + 0.000000001))) }
}

public extension EkadashiOccurrence {
    /// UI cadence: one second for a visible countdown; one minute for progress;
    /// hourly before the fasting day. Always include the next exact boundary.
    func nextLifecycleUpdate(after now: Date, zone: TzLocation) -> Date? {
        let status = lifecycle(at: now, zone: zone)
        let cadence: Double
        switch status.phase {
        case .countdown: cadence = 1
        case .fasting, .parana: cadence = 60
        case .scheduled: cadence = 3600
        case .passed, .unavailable: return nil
        }
        let boundaries = [fastingStart, paranaStart, paranaEnd, zone.utc(date)]
            .compactMap { $0 }.filter { $0 > now }
        return ([now.addingTimeInterval(cadence)] + boundaries).min()
    }
}
