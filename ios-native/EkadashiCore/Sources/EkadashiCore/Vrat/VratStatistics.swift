import Foundation

/// The single source of truth for streaks and observance numbers
/// (vrat_statistics_service.dart).
public enum VratStatistics {
    /// Consecutive observed Ekadashis up to [asOf]. Missed, partial or an
    /// unrecorded past Ekadashi break the streak; today's unrecorded one does not.
    public static func currentStreak(occurrences: [EkadashiOccurrence], history: [Int: VratRecord], asOf today: CivilDate) -> Int {
        if occurrences.isEmpty || history.isEmpty { return 0 }
        let past = occurrences.filter { $0.date <= today }.sorted { $0.date < $1.date }
        var streak = 0
        for i in stride(from: past.count - 1, through: 0, by: -1) {
            let occurrence = past[i]
            if let record = history[occurrence.id] {
                if record.status == .observed { streak += 1 } else { break }
            } else {
                if streak == 0 && i == past.count - 1 && occurrence.date == today { continue }
                break
            }
        }
        return streak
    }

    public static func longestStreak(occurrences: [EkadashiOccurrence], history: [Int: VratRecord]) -> Int {
        if occurrences.isEmpty || history.isEmpty { return 0 }
        var longest = 0, run = 0
        for occurrence in occurrences.sorted(by: { $0.date < $1.date }) {
            if history[occurrence.id]?.status == .observed {
                run += 1
                longest = max(longest, run)
            } else {
                run = 0
            }
        }
        return longest
    }

    public static func annualStats(year: Int, occurrences: [EkadashiOccurrence], history: [Int: VratRecord]) -> VratYearStats {
        let events = occurrences.filter { $0.date.year == year }
        var observed = 0, partial = 0, missed = 0, unrecorded = 0
        for event in events {
            switch history[event.id]?.status ?? .unrecorded {
            case .unrecorded: unrecorded += 1
            case .observed: observed += 1
            case .partial: partial += 1
            case .missed: missed += 1
            }
        }
        return VratYearStats(year: year, totalOccurrences: events.count, observedCount: observed, partialCount: partial,
                             missedCount: missed, unrecordedCount: unrecorded,
                             completionPercentage: events.isEmpty ? 0 : Double(observed) / Double(events.count) * 100)
    }

    /// Years with occurrences or history, plus the current year, newest first.
    public static func availableYears(occurrences: [EkadashiOccurrence], history: [VratRecord], currentYear: Int) -> [Int] {
        var years = Set(occurrences.map(\.date.year))
        for record in history { if let date = CivilDate(iso: record.ekadashiDate) { years.insert(date.year) } }
        years.insert(currentYear)
        return years.sorted(by: >)
    }
}

/// Devotional milestones (achievement_evaluator.dart).
public enum AchievementEvaluator {
    public static let all: [Achievement] = [
        Achievement(id: "first_vrat", titleKey: "achievement_first_vrat_title", descriptionKey: "achievement_first_vrat_desc",
                    condition: .count, targetValue: 1, symbol: "leaf.fill", sortOrder: 1),
        Achievement(id: "vrat_5", titleKey: "achievement_5_vrat_title", descriptionKey: "achievement_5_vrat_desc",
                    condition: .count, targetValue: 5, symbol: "star", sortOrder: 2),
        Achievement(id: "vrat_10", titleKey: "achievement_10_vrat_title", descriptionKey: "achievement_10_vrat_desc",
                    condition: .count, targetValue: 10, symbol: "medal", sortOrder: 3),
        Achievement(id: "vrat_12", titleKey: "achievement_12_vrat_title", descriptionKey: "achievement_12_vrat_desc",
                    condition: .count, targetValue: 12, symbol: "rosette", sortOrder: 4),
        Achievement(id: "consistent_observance", titleKey: "achievement_consistent_title",
                    descriptionKey: "achievement_consistent_desc", condition: .streak, targetValue: 3, symbol: "bolt.fill", sortOrder: 5),
        Achievement(id: "full_year_observance", titleKey: "achievement_full_year_title",
                    descriptionKey: "achievement_full_year_desc", condition: .annualFull, targetValue: 100,
                    symbol: "sun.max.fill", sortOrder: 6),
    ]

    /// Progress stays free; [newUnlockLimit] limits only new badges, and
    /// earned badges are never removed.
    public static func evaluate(history: [VratRecord], occurrences: [EkadashiOccurrence], current: [String: UserAchievement],
                                newUnlockLimit: Int? = nil, now: Date = Date())
        -> (updated: [String: UserAchievement], newlyUnlocked: [Achievement]) {
        var remaining = newUnlockLimit ?? all.count
        var byOccurrence: [Int: VratRecord] = [:]
        for event in occurrences {
            for record in history where record.occurrenceUid == event.occurrenceUid
                || (record.occurrenceUid == nil && record.ekadashiOccurrenceId == event.id
                    && CivilDate(iso: record.ekadashiDate)?.year == event.date.year) {
                byOccurrence[event.id] = record
            }
        }
        let totalObserved = history.filter { $0.status == .observed }.count
        let longest = VratStatistics.longestStreak(occurrences: occurrences, history: byOccurrence)
        let years = VratStatistics.availableYears(occurrences: occurrences, history: history,
                                                  currentYear: Calendar(identifier: .gregorian).component(.year, from: now))
        let fullYear = years.contains { year in
            let stats = VratStatistics.annualStats(year: year, occurrences: occurrences, history: byOccurrence)
            return stats.totalOccurrences > 0 && stats.observedCount >= stats.totalOccurrences
        }
        let stamp = ISO8601.string(now)
        var updated = current
        var newly: [Achievement] = []
        for achievement in all {
            let existing = updated[achievement.id]
            let wasUnlocked = existing?.isUnlocked ?? false
            let progress: Int, meets: Bool
            switch achievement.condition {
            case .count:
                progress = min(totalObserved, achievement.targetValue)
                meets = totalObserved >= achievement.targetValue
            case .streak:
                progress = min(longest, achievement.targetValue)
                meets = longest >= achievement.targetValue
            case .annualFull:
                progress = fullYear ? 100 : 0
                meets = fullYear
            }
            let isUnlocked = wasUnlocked || (meets && remaining > 0)
            if !wasUnlocked && isUnlocked {
                remaining -= 1
                newly.append(achievement)
            }
            updated[achievement.id] = UserAchievement(
                id: existing?.id ?? "ua_\(achievement.id)", achievementId: achievement.id, progressValue: progress,
                isUnlocked: isUnlocked, unlockedAtUTC: wasUnlocked ? existing?.unlockedAtUTC : (isUnlocked ? stamp : nil),
                lastEvaluatedAtUTC: stamp)
        }
        return (updated, newly)
    }

    /// The next unearned milestone for the dashboard.
    public static func nextMilestone(userAchievements: [String: UserAchievement], totalObserved: Int, longestStreak: Int)
        -> (achievement: Achievement, currentProgress: Int, target: Int)? {
        for achievement in all where !(userAchievements[achievement.id]?.isUnlocked ?? false) {
            let progress: Int
            switch achievement.condition {
            case .count: progress = totalObserved
            case .streak: progress = longestStreak
            case .annualFull: progress = 0
            }
            return (achievement, min(max(progress, 0), achievement.targetValue), achievement.targetValue)
        }
        return nil
    }
}
