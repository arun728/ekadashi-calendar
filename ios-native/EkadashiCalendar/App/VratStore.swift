import Foundation
import Observation
import EkadashiCore

/// Observable wrapper around the core Vrat tracker.
@MainActor
@Observable
final class VratStore {
    @ObservationIgnored let tracker: VratTracker
    private(set) var revision = 0

    init(store: KeyValueStore, premium: @escaping () -> Bool) {
        tracker = VratTracker(store: store, premiumAchievements: premium)
    }

    var isEnabled: Bool { _ = revision; return tracker.isEnabled }
    var storageError: String? { _ = revision; return tracker.storageError }
    var userAchievements: [String: UserAchievement] { _ = revision; return tracker.userAchievements }
    var allRecords: [VratRecord] { _ = revision; return tracker.allRecords }

    func load(_ occurrences: [EkadashiOccurrence]) {
        try? tracker.load(occurrences: occurrences)
        revision += 1
    }

    func record(for uid: String) -> VratRecord? { _ = revision; return tracker.record(forUid: uid) }
    func needsPremium(uid: String, premium: Bool) -> Bool { _ = revision; return tracker.needsPremiumToRecord(uid: uid, premium: premium) }
    func currentStreak(_ events: [EkadashiOccurrence]) -> Int { _ = revision; return tracker.currentStreak(events) }
    func longestStreak(_ events: [EkadashiOccurrence]) -> Int { _ = revision; return tracker.longestStreak(events) }
    func annualStats(_ year: Int, _ events: [EkadashiOccurrence]) -> VratYearStats { _ = revision; return tracker.annualStats(year: year, occurrences: events) }
    func years(_ events: [EkadashiOccurrence]) -> [Int] { _ = revision; return tracker.availableYears(events) }

    func save(_ event: EkadashiOccurrence, status: ObservanceStatus, method: FastingMethod?, methodOther: String?, note: String?,
              timezone: String, occurrences: [EkadashiOccurrence]) throws -> [Achievement] {
        defer { revision += 1 }
        return try tracker.record(occurrenceId: event.id, occurrenceUid: event.occurrenceUid, date: event.date.iso, name: event.name,
                                  status: status, method: method, methodOther: methodOther, note: note, timezone: timezone,
                                  occurrences: occurrences)
    }

    func delete(_ event: EkadashiOccurrence, occurrences: [EkadashiOccurrence]) throws {
        defer { revision += 1 }
        try tracker.delete(occurrenceId: event.id, occurrences: occurrences)
    }

    func refreshAchievements(_ events: [EkadashiOccurrence]) -> [Achievement] {
        defer { revision += 1 }
        return (try? tracker.refreshAchievements(events)) ?? []
    }
}
