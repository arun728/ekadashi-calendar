import Foundation
import XCTest
@testable import EkadashiCore

/// Ports test/unit/vrat_tracker_test.dart, achievement_allowance_test.dart,
/// free_vrat_migration_test.dart and the free-entry limit of PR #13.
final class VratTrackerTests: XCTestCase {
    private func mockEkadashis(year: Int = 2026, count: Int = 25) -> [EkadashiOccurrence] {
        (0..<count).map { i in
            let month = min(max((i * 14) / 30 + 1, 1), 12)
            let day = min(max((i * 14) % 28 + 1, 1), 28)
            return EkadashiOccurrence(id: i + 1, name: "Ekadashi #\(i + 1)", date: CivilDate(year, month, day))
        }
    }

    private func tracker(_ store: KeyValueStore = InMemoryKeyValueStore(), premium: @escaping () -> Bool = { false },
                         today: CivilDate = CivilDate(2026, 12, 31)) -> VratTracker {
        VratTracker(store: store, premiumAchievements: premium, today: { today })
    }

    @discardableResult
    private func record(_ tracker: VratTracker, _ id: Int, _ date: String, _ status: ObservanceStatus = .observed,
                        method: FastingMethod? = nil, note: String? = nil, uid: String? = nil,
                        occurrences: [EkadashiOccurrence]) throws -> [Achievement] {
        try tracker.record(occurrenceId: id, occurrenceUid: uid, date: date, name: "E\(id)", status: status,
                           method: method, note: note, occurrences: occurrences)
    }

    func testTrackerIsAvailableFreeByDefault() throws {
        let service = tracker()
        try service.load(occurrences: [])
        XCTAssertTrue(service.isEnabled)
        XCTAssertNotNil(service.trackingEnabledAt)
        XCTAssertTrue(service.allRecords.isEmpty)
    }

    func testRecordsMethodAndNoteAndEditsWithoutDuplicates() throws {
        let occurrences = mockEkadashis()
        let service = tracker()
        try service.load(occurrences: occurrences)
        try record(service, 1, "2026-01-14", method: .waterOnly, note: "Felt very peaceful", occurrences: occurrences)
        XCTAssertEqual(service.record(forOccurrenceId: 1)?.fastingMethod, .waterOnly)
        XCTAssertEqual(service.record(forOccurrenceId: 1)?.note, "Felt very peaceful")
        try record(service, 1, "2026-01-14", .partial, method: .fruitsMilk, note: "Had milk", occurrences: occurrences)
        XCTAssertEqual(service.allRecords.count, 1)
        XCTAssertEqual(service.record(forOccurrenceId: 1)?.status, .partial)
        XCTAssertEqual(service.record(forOccurrenceId: 1)?.note, "Had milk")
    }

    func testDeleteRemovesOnlyHistory() throws {
        let occurrences = mockEkadashis()
        let service = tracker()
        try service.load(occurrences: occurrences)
        try record(service, 2, "2026-01-29", occurrences: occurrences)
        try service.delete(occurrenceId: 2, occurrences: occurrences)
        XCTAssertTrue(service.allRecords.isEmpty)
        XCTAssertNil(service.record(forOccurrenceId: 2))
        XCTAssertEqual(occurrences.count, 25)
    }

    func testFutureEkadashisCannotBeRecordedButPastOnesCan() throws {
        let occurrences = mockEkadashis()
        let service = tracker(today: CivilDate(2026, 6, 1))
        try service.load(occurrences: occurrences)
        try record(service, 20, "2026-10-14", occurrences: occurrences)
        XCTAssertNil(service.record(forOccurrenceId: 20))
        try record(service, 1, "2025-09-24", occurrences: occurrences)
        XCTAssertEqual(service.record(forOccurrenceId: 1)?.ekadashiDate, "2025-09-24")
    }

    func testThreeFreeEntriesThenPremiumForNewOnesButEditingStaysFree() throws {
        let occurrences = mockEkadashis()
        let service = tracker()
        try service.load(occurrences: occurrences)
        for event in occurrences.prefix(3) {
            XCTAssertFalse(service.needsPremiumToRecord(uid: event.occurrenceUid, premium: false))
            try record(service, event.id, event.date.iso, uid: event.occurrenceUid, occurrences: occurrences)
        }
        XCTAssertEqual(service.recordedEntryCount, 3)
        XCTAssertEqual(VratTracker.freeEntryLimit, 3)
        XCTAssertTrue(service.needsPremiumToRecord(uid: occurrences[3].occurrenceUid, premium: false))
        XCTAssertFalse(service.needsPremiumToRecord(uid: occurrences[3].occurrenceUid, premium: true))
        XCTAssertFalse(service.needsPremiumToRecord(uid: occurrences[0].occurrenceUid, premium: false))
    }

    func testRecordsSurviveRecreationFromTheSameStore() throws {
        let store = InMemoryKeyValueStore()
        let first = tracker(store)
        try first.load(occurrences: [])
        try record(first, 1, "2026-01-01", uid: "ekadashi:2026:01", occurrences: [])
        let again = tracker(store)
        try again.load(occurrences: [])
        XCTAssertEqual(again.record(forUid: "ekadashi:2026:01")?.status, .observed)
        XCTAssertEqual(again.trackingEnabledAt, first.trackingEnabledAt)
    }

    func testCorruptStorageBlocksWritesInsteadOfLosingHistory() {
        let store = InMemoryKeyValueStore()
        _ = store.set("{\"schemaVersion\": 99}", forKey: TrackerHistoryStore.key)
        let service = tracker(store)
        XCTAssertThrowsError(try service.load(occurrences: []))
        XCTAssertFalse(service.isEnabled)
        XCTAssertNotNil(service.storageError)
        XCTAssertThrowsError(try record(service, 1, "2026-01-01", occurrences: []))
        XCTAssertEqual(store.string(forKey: TrackerHistoryStore.key), "{\"schemaVersion\": 99}")
    }

    func testStoredRecordsUseTheAndroidSchema() throws {
        let store = InMemoryKeyValueStore()
        let service = tracker(store)
        try service.load(occurrences: [])
        try record(service, 1, "2026-01-01", uid: "ekadashi:2026:01", occurrences: [])
        let saved = try JSONSerialization.jsonObject(with: Data(store.string(forKey: TrackerHistoryStore.key)!.utf8)) as! [String: Any]
        XCTAssertEqual(saved.int("schemaVersion"), 2)
        let row = (saved.array("records")!.first as! [String: Any])
        XCTAssertEqual(row.string("occurrenceUid"), "ekadashi:2026:01")
        XCTAssertEqual(row.string("status"), "observed")
        XCTAssertEqual(row.int("ekadashiOccurrenceId"), 1)
    }

    // MARK: statistics

    private func history(_ statuses: [Int: ObservanceStatus]) -> [Int: VratRecord] {
        statuses.mapValues { status in
            VratRecord(id: "x", ekadashiOccurrenceId: 0, ekadashiDate: "", ekadashiName: "", status: status,
                       recordedAtUTC: "", updatedAtUTC: "")
        }
    }

    func testCurrentAndLongestStreak() {
        let occurrences = [CivilDate(2026, 1, 1), CivilDate(2026, 1, 15), CivilDate(2026, 2, 1), CivilDate(2026, 2, 15)]
            .enumerated().map { EkadashiOccurrence(id: $0.offset + 1, name: "E", date: $0.element) }
        let observed = history([1: .observed, 2: .observed, 3: .observed])
        XCTAssertEqual(VratStatistics.currentStreak(occurrences: occurrences, history: observed, asOf: CivilDate(2026, 2, 5)), 3)
        XCTAssertEqual(VratStatistics.longestStreak(occurrences: occurrences, history: observed), 3)
        let broken = history([1: .observed, 2: .missed, 3: .observed])
        XCTAssertEqual(VratStatistics.currentStreak(occurrences: occurrences, history: broken, asOf: CivilDate(2026, 2, 5)), 1)
        XCTAssertEqual(VratStatistics.longestStreak(occurrences: occurrences, history: broken), 1)
        // Today's unrecorded Ekadashi does not break the streak yet.
        XCTAssertEqual(VratStatistics.currentStreak(occurrences: occurrences, history: observed, asOf: CivilDate(2026, 2, 15)), 3)
    }

    func testAnnualCompletionUsesTheYearsOccurrences() {
        var statuses: [Int: ObservanceStatus] = [:]
        for i in 1...5 { statuses[i] = .observed }
        statuses[6] = .partial
        statuses[7] = .missed
        let stats = VratStatistics.annualStats(year: 2026, occurrences: mockEkadashis(), history: history(statuses))
        XCTAssertEqual(stats.totalOccurrences, 25)
        XCTAssertEqual(stats.observedCount, 5)
        XCTAssertEqual(stats.partialCount, 1)
        XCTAssertEqual(stats.missedCount, 1)
        XCTAssertEqual(stats.unrecordedCount, 18)
        XCTAssertEqual(stats.completionPercentage, 20.0)
        XCTAssertEqual(VratStatistics.availableYears(occurrences: mockEkadashis(), history: [], currentYear: 2028), [2028, 2026])
    }

    // MARK: achievements

    private func events() -> [EkadashiOccurrence] {
        (0..<12).map { EkadashiOccurrence(id: $0 + 1, name: "Event \($0 + 1)", date: CivilDate(2025, 1, $0 + 1)) }
    }

    private func observedHistory(_ count: Int) -> [VratRecord] {
        (0..<count).map { i in
            VratRecord(id: "\(i)", ekadashiOccurrenceId: i + 1, occurrenceUid: events()[i].occurrenceUid,
                       ekadashiDate: String(format: "2025-01-%02d", i + 1), ekadashiName: "", status: .observed,
                       recordedAtUTC: "2025-02-01T00:00:00Z", updatedAtUTC: "2025-02-01T00:00:00Z")
        }
    }

    func testEvaluatesAllSixMilestonesAndNextMilestone() {
        let five = AchievementEvaluator.evaluate(history: observedHistory(5), occurrences: events(), current: [:])
        XCTAssertEqual(Set(five.newlyUnlocked.map(\.id)), ["first_vrat", "vrat_5", "consistent_observance"])
        let next = AchievementEvaluator.nextMilestone(userAchievements: five.updated, totalObserved: 5, longestStreak: 5)
        XCTAssertEqual(next?.achievement.id, "vrat_10")
        XCTAssertEqual(next?.currentProgress, 5)
        XCTAssertEqual(next?.target, 10)
        XCTAssertEqual(AchievementEvaluator.all.map(\.id),
                       ["first_vrat", "vrat_5", "vrat_10", "vrat_12", "consistent_observance", "full_year_observance"])
        let full = AchievementEvaluator.evaluate(history: observedHistory(12), occurrences: events(), current: [:])
        XCTAssertEqual(full.updated.values.filter(\.isUnlocked).count, 6)
    }

    func testAllowanceCountsEarnedBadges() {
        var state: [String: UserAchievement] = [:]
        for count in [1, 3, 5, 12] {
            let remaining = max(0, min(3, 3 - state.values.filter(\.isUnlocked).count))
            state = AchievementEvaluator.evaluate(history: observedHistory(count), occurrences: events(), current: state,
                                                  newUnlockLimit: remaining).updated
        }
        XCTAssertEqual(Set(state.filter { $0.value.isUnlocked }.keys), ["first_vrat", "consistent_observance", "vrat_5"])
        XCTAssertEqual(state["vrat_12"]?.progressValue, 12)
        XCTAssertEqual(state["vrat_12"]?.isUnlocked, false)
    }

    func testGrandfatheredBadgesSurviveAZeroAllowance() {
        let full = AchievementEvaluator.evaluate(history: observedHistory(12), occurrences: events(), current: [:])
        let downgraded = AchievementEvaluator.evaluate(history: [], occurrences: events(), current: full.updated, newUnlockLimit: 0)
        XCTAssertEqual(downgraded.updated.values.filter(\.isUnlocked).count, 6)
        XCTAssertTrue(downgraded.newlyUnlocked.isEmpty)
    }

    func testPremiumUpgradeUnlocksProgressOnceAndDowngradeKeepsBadges() throws {
        var premium = false
        let store = InMemoryKeyValueStore()
        let service = tracker(store, premium: { premium })
        try service.load(occurrences: events())
        for event in events() {
            try record(service, event.id, event.date.iso, uid: event.occurrenceUid, occurrences: events())
        }
        XCTAssertEqual(service.userAchievements.values.filter(\.isUnlocked).count, 3)
        premium = true
        XCTAssertEqual(try service.refreshAchievements(events()).count, 3)
        XCTAssertTrue(try service.refreshAchievements(events()).isEmpty)
        premium = false
        _ = try service.refreshAchievements(events())
        XCTAssertEqual(service.userAchievements.values.filter(\.isUnlocked).count, 6)
        let recreated = tracker(store)
        try recreated.load(occurrences: events())
        XCTAssertEqual(recreated.userAchievements.values.filter(\.isUnlocked).count, 6)
    }

    func testUnlockDialogsAreShownOnlyOncePerBadge() throws {
        let store = InMemoryKeyValueStore()
        let service = tracker(store)
        try service.load(occurrences: events())
        XCTAssertEqual(try record(service, 1, "2025-01-01", uid: events()[0].occurrenceUid, occurrences: events()).map(\.id),
                       ["first_vrat"])
        try service.delete(occurrenceId: 1, occurrences: events())
        XCTAssertTrue(try record(service, 1, "2025-01-01", uid: events()[0].occurrenceUid, occurrences: events()).isEmpty)
    }
}

/// Phase 4 bug fix: a fast can be recorded only once it has happened.
final class VratRecordingWindowTests: XCTestCase {
    private let zone = AppTimezone.ist.location

    private func event(date: CivilDate, parana: String = "") -> EkadashiOccurrence {
        EkadashiOccurrence(id: 1, occurrenceUid: "ekadashi:2026:20", name: "Papankusha Ekadashi", date: date,
                           paranaStartISO: parana)
    }

    func testFutureEkadashiCannotBeRecorded() {
        let future = event(date: CivilDate(2026, 10, 22), parana: "2026-10-23T06:20:00+05:30")
        XCTAssertFalse(VratRecording.isOpen(future, now: instant("2026-10-08T10:00:00+05:30"), zone: zone))
    }

    func testTodaysEkadashiOpensAtParanaStart() {
        let today = event(date: CivilDate(2026, 10, 22), parana: "2026-10-23T06:20:00+05:30")
        XCTAssertFalse(VratRecording.isOpen(today, now: instant("2026-10-22T20:00:00+05:30"), zone: zone), "still fasting")
        XCTAssertFalse(VratRecording.isOpen(today, now: instant("2026-10-23T06:19:59+05:30"), zone: zone))
        XCTAssertTrue(VratRecording.isOpen(today, now: instant("2026-10-23T06:20:00+05:30"), zone: zone))
    }

    func testPastEkadashiIsOpenEvenWithoutParanaTime() {
        let past = event(date: CivilDate(2026, 9, 7))
        XCTAssertTrue(VratRecording.isOpen(past, now: instant("2026-10-08T10:00:00+05:30"), zone: zone))
        let todayWithoutParana = event(date: CivilDate(2026, 10, 8))
        XCTAssertFalse(VratRecording.isOpen(todayWithoutParana, now: instant("2026-10-08T23:00:00+05:30"), zone: zone))
    }

    /// The bundled schedule: every Ekadashi before today is open, none after.
    func testBundledScheduleOpensOnlyPastFasts() throws {
        let events = try CalendarRepository.bundled().ekadashis(timezone: "IST", language: "en")
        let now = instant("2026-10-08T10:00:00+05:30")
        for event in events {
            let open = VratRecording.isOpen(event, now: now, zone: zone)
            XCTAssertEqual(open, event.date < CivilDate(2026, 10, 8), event.occurrenceUid)
        }
    }
}
