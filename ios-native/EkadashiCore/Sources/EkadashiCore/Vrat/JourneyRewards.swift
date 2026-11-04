import Foundation

/// Derived personal progress, never a wallet or a persisted balance.
public struct JourneySegment: Identifiable, Equatable, Sendable {
    public let id: String
    public let date: CivilDate
    public let status: ObservanceStatus
    public let isFuture: Bool
    public var points: Int { isFuture ? 0 : status == .observed ? 100 : status == .partial ? 50 : 0 }
}

public struct JourneyQuarter: Identifiable, Equatable, Sendable {
    public let id: Int
    public let total: Int
    public let observed: Int
    public let completed: Bool
    public var points: Int { completed ? 150 : 0 }
}

public struct JourneyYear: Equatable, Sendable {
    public let year: Int
    public let segments: [JourneySegment]
    public let quarters: [JourneyQuarter]
    public let scheduleComplete: Bool
    public var basePoints: Int { segments.reduce(0) { $0 + $1.points } }
    public var observed: Int { segments.filter { !$0.isFuture && $0.status == .observed }.count }
    public var partial: Int { segments.filter { !$0.isFuture && $0.status == .partial }.count }
    public var annualBonus: Int { scheduleComplete && !segments.isEmpty && quarters.allSatisfy(\.completed) ? 1000 : 0 }
    public var points: Int { basePoints + quarters.reduce(0) { $0 + $1.points } + annualBonus }
    public var maximumPoints: Int { segments.count * 100 + (scheduleComplete && !segments.isEmpty ? 1600 : 0) }
}

public struct JourneySummary: Sendable {
    public let years: [Int: JourneyYear]
    public let asOf: CivilDate
    public let observedCount: Int
    public let partialCount: Int
    public let currentStreak: Int
    public let longestStreak: Int
    public let fullCurrentStreak: Int
    public let fullLongestStreak: Int
    public let hasReturned: Bool
    private let lifetimeBasePoints: Int
    public var lifetimePoints: Int { lifetimeBasePoints + years.values.reduce(0) { $0 + $1.points - $1.basePoints } }

    public var segments: [JourneySegment] { years.keys.sorted().flatMap { years[$0]!.segments } }
    public var eligibleSegments: [JourneySegment] { segments.filter { !$0.isFuture } }
    /// Current year first, followed by the other supported calendars (including future years).
    public var visibleYears: [Int] {
        years.keys.filter { $0 >= 2026 }.sorted {
            if $0 == asOf.year { return true }
            if $1 == asOf.year { return false }
            return $0 > $1
        }
    }
    public var totalOccurrences: Int { segments.count }
    public var missedCount: Int { eligibleSegments.filter { $0.status == .missed }.count }
    public var unrecordedCount: Int { max(0, totalOccurrences - observedCount - partialCount - missedCount) }
    public var completionPercentage: Double {
        totalOccurrences == 0 ? 0 : Double(observedCount) / Double(totalOccurrences) * 100
    }

    /// Presentation-only scope. Persisted awards and lifetime points use the original summary.
    public func scoped(toYear year: Int?) -> JourneySummary {
        let selected = years.filter { key, _ in year.map { key == $0 } ?? (key >= 2026) }
        let ordered = selected.keys.sorted().flatMap { selected[$0]!.segments }
        let eligible = ordered.filter { !$0.isFuture }
        let observed = eligible.filter { $0.status == .observed }.count
        let partial = eligible.filter { $0.status == .partial }.count
        let streak = JourneyRewards.streaks(ordered)
        return JourneySummary(years: selected, observedCount: observed, partialCount: partial,
            currentStreak: streak.current, longestStreak: streak.longest, hasReturned: streak.returned,
            lifetimeBasePoints: observed * 100 + partial * 50, fullCurrentStreak: streak.fullCurrent,
            fullLongestStreak: streak.fullLongest, asOf: asOf)
    }

    public func nextMilestone(earned: [String: UserAchievement]) -> JourneyBadgeDefinition? {
        var periodEarned: [String: UserAchievement] = [:]
        for badge in JourneyBadgeCatalog.all(years: Array(years.keys)) where badge.progress(in: self) >= badge.target {
            if let state = earned[badge.id], state.isUnlocked { periodEarned[badge.id] = state }
        }
        return JourneyBadgeCatalog.nextMilestone(summary: self, earned: periodEarned)
    }

    public func year(_ year: Int) -> JourneyYear {
        years[year] ?? JourneyYear(year: year, segments: [], quarters: (1...4).map {
            JourneyQuarter(id: $0, total: 0, observed: 0, completed: false)
        }, scheduleComplete: false)
    }

    init(years: [Int: JourneyYear], observedCount: Int, partialCount: Int, currentStreak: Int,
         longestStreak: Int, hasReturned: Bool, lifetimeBasePoints: Int, fullCurrentStreak: Int = 0, fullLongestStreak: Int = 0, asOf: CivilDate = CivilDate.today()) {
        self.asOf = asOf
        self.years = years; self.observedCount = observedCount; self.partialCount = partialCount
        self.currentStreak = currentStreak; self.longestStreak = longestStreak
        self.fullCurrentStreak = fullCurrentStreak; self.fullLongestStreak = fullLongestStreak
        self.hasReturned = hasReturned; self.lifetimeBasePoints = lifetimeBasePoints
    }
}

public enum JourneyRewards {
    /// `completeYears` is supplied only after the complete engine schedules
    /// load. Partial/empty lists can show base points but cannot earn bonuses.
    /// UID identity survives city, language and tradition changes.
    public static func calculate(occurrences: [EkadashiOccurrence], history: [VratRecord], completeYears: Set<Int>,
                                 now: Date = Date(), zone: TzLocation = AppTimezone.ist.location) -> JourneySummary {
        var events: [String: EkadashiOccurrence] = [:]
        for event in occurrences where events[event.occurrenceUid] == nil { events[event.occurrenceUid] = event }
        let ordered = events.values.sorted { $0.date == $1.date ? $0.occurrenceUid < $1.occurrenceUid : $0.date < $1.date }
        var records: [String: VratRecord] = [:]
        // Sort so corrections beat stale copies regardless of input ordering.
        for row in history.sorted(by: {
            if $0.updatedAtUTC == $1.updatedAtUTC { return $0.id < $1.id }
            return $0.updatedAtUTC < $1.updatedAtUTC
        }) {
            guard let date = CivilDate(iso: row.ekadashiDate) else { continue }
            let uid = row.occurrenceUid ?? "ekadashi:\(date.year):\(pad2(row.ekadashiOccurrenceId))"
            records[uid] = row
        }
        let today = zone.wallClock(now).date
        var lifetimeObserved = 0, lifetimePartial = 0
        for (uid, row) in records {
            guard let date = CivilDate(iso: row.ekadashiDate), date <= today else { continue }
            if let event = events[uid], !VratRecording.isOpen(event, now: now, zone: zone) { continue }
            // Unscheduled legacy history still contributes to lifetime milestones.
            if row.status == .observed { lifetimeObserved += 1 }
            if row.status == .partial { lifetimePartial += 1 }
        }
        let segments = ordered.map { event in
            JourneySegment(id: event.occurrenceUid, date: event.date, status: records[event.occurrenceUid]?.status ?? .unrecorded,
                           isFuture: !VratRecording.isOpen(event, now: now, zone: zone))
        }
        var years: [Int: JourneyYear] = [:]
        for year in Set(segments.map(\.date.year)) {
            let list = segments.filter { $0.date.year == year }
            let quarterLists = (1...4).map { quarter in list.filter { ($0.date.month - 1) / 3 + 1 == quarter } }
            let complete = completeYears.contains(year) && quarterLists.allSatisfy { !$0.isEmpty }
            let quarters = quarterLists.enumerated().map { index, list in
                let observed = list.filter { !$0.isFuture && $0.status == .observed }.count
                return JourneyQuarter(id: index + 1, total: list.count, observed: observed,
                                      completed: complete && !list.isEmpty && observed == list.count)
            }
            years[year] = JourneyYear(year: year, segments: list, quarters: quarters, scheduleComplete: complete)
        }
        let streak = Self.streaks(segments)
        return JourneySummary(years: years, observedCount: lifetimeObserved, partialCount: lifetimePartial,
                              currentStreak: streak.current, longestStreak: streak.longest, hasReturned: streak.returned,
                              lifetimeBasePoints: lifetimeObserved * 100 + lifetimePartial * 50, fullCurrentStreak: streak.fullCurrent, fullLongestStreak: streak.fullLongest, asOf: today)
    }
    fileprivate static func streaks(_ segments: [JourneySegment]) -> (current: Int, longest: Int, fullCurrent: Int, fullLongest: Int, returned: Bool) {
        var run = 0, longest = 0, returned = false
        var fullRun = 0, fullLongest = 0
        let eligible = segments.filter { !$0.isFuture }
        let lastRecorded = eligible.lastIndex { $0.status != .unrecorded }
        var previous: JourneySegment?
        for segment in lastRecorded.map({ Array(eligible[...$0]) }) ?? [] {
            if segment.status == .observed {
                fullRun += 1; fullLongest = max(fullLongest, fullRun)
                if previous?.status == .missed { returned = true }
            } else { fullRun = 0 }
            if segment.status == .observed || segment.status == .partial {
                run += 1; longest = max(longest, run)
            } else { run = 0 }
            previous = segment
        }
        return (run, longest, fullRun, fullLongest, returned)
    }

}

public struct JourneyBadgeDefinition: Identifiable, Sendable {
    public enum Rule: Equatable, Sendable { case observed(Int), streak(Int), partial(Int), returned, quarter(Int, Int), annual(Int), legacyAnnual }
    public enum Art: String, Sendable { case lamp, leaves, lotus, lights, flame, arcs, thread, wreath, sunrise, petals, quarter, annual }
    public func isVisible(inYear selectedYear: Int?) -> Bool {
        selectedYear == nil || year == nil || year == selectedYear
    }

    public let achievement: Achievement
    public let rule: Rule
    public let art: Art
    public let year: Int?
    public let quarter: Int?
    public var id: String { achievement.id }
    public var target: Int { achievement.targetValue }

    /// A new streak must be built from the current run; its historical best
    /// remains visible in the badge collection but is not "one more" after a gap.
    public func goalProgress(in summary: JourneySummary) -> Int {
        if case .streak = rule { return min(target, summary.fullCurrentStreak) }
        return progress(in: summary)
    }

    public func progress(in summary: JourneySummary) -> Int {
        let value: Int
        switch rule {
        case .observed: value = summary.observedCount
        case .streak: value = summary.fullLongestStreak
        case .partial: value = summary.partialCount
        case .returned: value = summary.hasReturned ? 1 : 0
        case .quarter(let year, let quarter):
            value = summary.year(year).quarters[quarter - 1].completed ? 1 : 0
        case .annual(let year): value = summary.year(year).annualBonus > 0 ? 1 : 0
        case .legacyAnnual: value = summary.years.values.contains { $0.annualBonus > 0 } ? target : 0
        }
        return min(target, max(0, value))
    }
}

public enum JourneyBadgeCatalog {
    public static func all(years: [Int]) -> [JourneyBadgeDefinition] {
        typealias Rule = JourneyBadgeDefinition.Rule
        typealias Art = JourneyBadgeDefinition.Art
        let rows: [(String, String, Rule, Art, Int)] = [
            ("first_vrat", "first", .observed(1), .lamp, 1),
            ("vrat_5", "root", .observed(5), .leaves, 5),
            ("vrat_10", "bloom", .observed(10), .lotus, 10),
            ("vrat_12", "lights", .observed(12), .lights, 12),
            ("consistent_observance", "flame", .streak(3), .flame, 3),
            ("streak_6", "rhythm", .streak(6), .arcs, 6),
            ("streak_12", "thread", .streak(12), .thread, 12),
            ("streak_24", "wreath", .streak(24), .wreath, 24),
            ("welcome_back", "return", .returned, .sunrise, 1),
            ("every_effort", "effort", .partial(3), .petals, 3),
        ]
        var result = rows.enumerated().map { index, row in
            badge(row.0, row.1, rule: row.2, art: row.3, target: row.4, order: index + 1)
        }
        // Keep the legacy annual ID; new annual seals are separate collectibles.
        result.append(JourneyBadgeDefinition(achievement: AchievementEvaluator.all.last!, rule: .legacyAnnual,
                                             art: .annual, year: nil, quarter: nil))
        for year in Set(years).sorted() where [2026, 2027].contains(year) {
            for quarter in 1...4 {
                result.append(badge("journey_\(year)_q\(quarter)", "q\(quarter)", rule: .quarter(year, quarter), art: .quarter,
                                    target: 1, order: result.count + 1, year: year, quarter: quarter))
            }
            result.append(badge("journey_\(year)_full", "annual", rule: .annual(year), art: .annual,
                                target: 1, order: result.count + 1, year: year))
        }
        return result
    }

    public static func nextMilestone(summary: JourneySummary, earned: [String: UserAchievement]) -> JourneyBadgeDefinition? {
        all(years: []).filter { badge in
            guard earned[badge.id]?.isUnlocked != true else { return false }
            switch badge.rule {
            case .observed, .streak: return true
            default: return false
            }
        }.min { a, b in
            let left = a.target - a.goalProgress(in: summary), right = b.target - b.goalProgress(in: summary)
            return left == right ? a.achievement.sortOrder < b.achievement.sortOrder : left < right
        }
    }

    public static func definition(_ id: String) -> JourneyBadgeDefinition? { all(years: [2026, 2027]).first { $0.id == id } }

    private static func badge(_ id: String, _ key: String, rule: JourneyBadgeDefinition.Rule, art: JourneyBadgeDefinition.Art,
                              target: Int, order: Int, year: Int? = nil, quarter: Int? = nil) -> JourneyBadgeDefinition {
        JourneyBadgeDefinition(achievement: Achievement(id: id, titleKey: "ios_journey_badge_\(key)",
            descriptionKey: "ios_journey_badge_\(key)_desc", condition: .count, targetValue: target,
            symbol: AppSymbol.achievementFirst, sortOrder: order), rule: rule, art: art, year: year, quarter: quarter)
    }
}

public enum JourneyBadgeEvaluator {
    public static func evaluate(summary: JourneySummary, current: [String: UserAchievement], newUnlockLimit: Int?, now: Date)
        -> (updated: [String: UserAchievement], newlyUnlocked: [Achievement]) {
        var updated = current, newly: [Achievement] = [], remaining = max(0, newUnlockLimit ?? Int.max)
        let definitions = JourneyBadgeCatalog.all(years: Array(summary.years.keys))
        let stamp = ISO8601.string(now)
        for definition in definitions {
            let existing = current[definition.id], wasUnlocked = existing?.isUnlocked ?? false
            let progress = definition.progress(in: summary)
            let unlocked = progress == definition.target && (wasUnlocked || remaining > 0)
            if unlocked && !wasUnlocked { remaining -= 1; newly.append(definition.achievement) }
            updated[definition.id] = UserAchievement(id: existing?.id ?? "ua_\(definition.id)", achievementId: definition.id,
                progressValue: progress, isUnlocked: unlocked, unlockedAtUTC: unlocked ? (wasUnlocked ? existing?.unlockedAtUTC : stamp) : nil,
                lastEvaluatedAtUTC: stamp)
        }
        return (updated, newly)
    }
}
