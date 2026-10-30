import XCTest
@testable import EkadashiCore

final class JourneyRewardsTests: XCTestCase {
    private let now = ISO8601.instant("2028-01-02T12:00:00Z")!
    private let zone = AppTimezone.ist.location

    private func events(_ year: Int, extra: Bool = false) -> [EkadashiOccurrence] {
        var result = (0..<24).map { i in
            EkadashiOccurrence(id: year * 1000 + i + 1, occurrenceUid: "ekadashi:\(year):\(String(format: "%02d", i + 1))",
                               name: "E", date: CivilDate(year, i / 2 + 1, i % 2 == 0 ? 3 : 18))
        }
        if extra { result.append(EkadashiOccurrence(id: year * 1000 + 25, occurrenceUid: "ekadashi:\(year):25",
                                                    name: "Saphala", date: CivilDate(year, 12, 23))) }
        return result
    }
    private func record(_ e: EkadashiOccurrence, _ status: ObservanceStatus = .observed, updated: String = "2028-01-01T00:00:00Z") -> VratRecord {
        VratRecord(id: e.occurrenceUid, ekadashiOccurrenceId: e.id, occurrenceUid: e.occurrenceUid,
                   ekadashiDate: e.date.iso, ekadashiName: e.name, status: status, recordedAtUTC: updated, updatedAtUTC: updated)
    }
    private func summary(_ list: [EkadashiOccurrence], _ rows: [VratRecord], complete: Set<Int> = [2026, 2027]) -> JourneySummary {
        JourneyRewards.calculate(occurrences: list, history: rows, completeYears: complete, now: now, zone: zone)
    }

    func testBackfilledMixedHistoryEndsAtLatestRecord() {
        let list = events(2026)
        let statuses: [ObservanceStatus] = [.observed, .partial, .partial, .missed,
            .observed, .observed, .observed, .observed, .partial, .observed, .partial, .observed, .observed]
        let s = summary(list, zip(list, statuses).map { record($0.0, $0.1) })
        XCTAssertEqual(s.year(2026).points, 1000)
        XCTAssertEqual(s.year(2026).observed, 8)
        XCTAssertEqual(s.year(2026).partial, 4)
        XCTAssertEqual(s.longestStreak, 9)
        XCTAssertEqual(s.fullLongestStreak, 4)
        XCTAssertEqual(s.fullCurrentStreak, 2)
        XCTAssertEqual(s.currentStreak, 9)
        // Later unrecorded occurrences do not change the run; the strict full run is separate.
        let earlier = JourneyRewards.calculate(occurrences: list, history: zip(list, statuses).map { record($0.0, $0.1) },
            completeYears: [2026], now: ISO8601.instant("2026-07-04T12:00:00Z")!, zone: zone)
        XCTAssertEqual(earlier.currentStreak, 9)
    }

    func testConsistencyUsesObservedAndPartialEndingAtLatestRecordWithInternalGaps() {
        let list = events(2026)
        let rows = [record(list[0]), record(list[1], .partial), record(list[2])]
        XCTAssertEqual(summary(list, rows).currentStreak, 3)
        XCTAssertEqual(summary(list, rows).longestStreak, 3)
        XCTAssertEqual(summary(list, rows + [record(list[4])]).currentStreak, 1)
        XCTAssertEqual(summary(list, rows + [record(list[3], .missed)]).currentStreak, 0)
        XCTAssertEqual(summary(list, rows).year(2026).observed, 2)
        XCTAssertEqual(summary(list, rows).year(2026).annualBonus, 0)
    }

    func testEveryBadgeRelocksWhenItsQualifyingHistoryIsRemoved() {
        let list = events(2026) + events(2027, extra: true)
        let full = summary(list, list.map { record($0) })
        let unlocked = JourneyBadgeEvaluator.evaluate(summary: full, current: [:], newUnlockLimit: nil, now: now).updated
        XCTAssertTrue(unlocked.values.contains(where: \.isUnlocked))
        let empty = JourneyBadgeEvaluator.evaluate(summary: summary(list, []), current: unlocked, newUnlockLimit: 0, now: now)
        XCTAssertTrue(empty.updated.values.allSatisfy { !$0.isUnlocked && $0.unlockedAtUTC == nil })
        XCTAssertTrue(empty.newlyUnlocked.isEmpty)
        let encouragement = summary(list, [record(list[0], .missed), record(list[1]), record(list[2], .partial), record(list[3], .partial), record(list[4], .partial)])
        let earned = JourneyBadgeEvaluator.evaluate(summary: encouragement, current: [:], newUnlockLimit: nil, now: now).updated
        XCTAssertEqual(earned["welcome_back"]?.isUnlocked, true)
        let reversed = JourneyBadgeEvaluator.evaluate(summary: summary(list, []), current: earned, newUnlockLimit: nil, now: now)
        XCTAssertTrue(reversed.updated.values.allSatisfy { !$0.isUnlocked })
    }

    func testCorrectionsRelockOnlyBadgesWhoseRulesFail() {
        let list = events(2026) + events(2027, extra: true)
        let rows = list.map { record($0) }
        let earned = JourneyBadgeEvaluator.evaluate(summary: summary(list, rows), current: [:], newUnlockLimit: nil, now: now).updated
        let changed = summary(list, Array(rows.dropFirst()))
        let result = JourneyBadgeEvaluator.evaluate(summary: changed, current: earned, newUnlockLimit: nil, now: now)
        XCTAssertFalse(result.updated["journey_2026_q1"]!.isUnlocked)
        XCTAssertFalse(result.updated["journey_2026_full"]!.isUnlocked)
        XCTAssertTrue(result.updated["journey_2027_full"]!.isUnlocked)
        XCTAssertTrue(result.updated["vrat_5"]!.isUnlocked)
        XCTAssertTrue(result.updated["streak_24"]!.isUnlocked)
        let partial = summary(events(2026), [record(list[0]), record(list[1], .partial), record(list[2])])
        let mixed = JourneyBadgeEvaluator.evaluate(summary: partial, current: [:], newUnlockLimit: nil, now: now)
        XCTAssertEqual(partial.currentStreak, 3)
        XCTAssertFalse(mixed.updated["consistent_observance"]!.isUnlocked)
    }

    func testDeletionRecalculatesStreakAndBadgesAndSurvivesReload() throws {
        let list = events(2026), store = InMemoryKeyValueStore()
        let tracker = VratTracker(store: store, premiumAchievements: { true }, now: { self.now })
        try tracker.load(occurrences: list)
        for e in list.prefix(3) {
            try tracker.record(occurrenceId: e.id, occurrenceUid: e.occurrenceUid, date: e.date.iso, name: e.name,
                               status: .observed, occurrences: list)
        }
        XCTAssertEqual(tracker.journey(list, completeYears: [2026]).currentStreak, 3)
        XCTAssertTrue(tracker.userAchievements["consistent_observance"]!.isUnlocked)
        try tracker.delete(occurrenceId: list[1].id, occurrences: list)
        XCTAssertFalse(tracker.userAchievements["consistent_observance"]!.isUnlocked)
        XCTAssertTrue(tracker.userAchievements["first_vrat"]!.isUnlocked)
        let restored = VratTracker(store: store, premiumAchievements: { true }, now: { self.now })
        try restored.load(occurrences: list)
        XCTAssertEqual(restored.journey(list, completeYears: [2026]).currentStreak, 1)
        XCTAssertFalse(restored.userAchievements["consistent_observance"]!.isUnlocked)
        for e in [list[0], list[2]] { try restored.delete(occurrenceId: e.id, occurrences: list) }
        XCTAssertTrue(restored.userAchievements.values.allSatisfy { !$0.isUnlocked })
    }

    func testRevocationDoesNotOverrideExplicitZeroUnlockAllowance() {
        let list = events(2026)
        let earned = JourneyBadgeEvaluator.evaluate(summary: summary(list, list.map { record($0) }), current: [:], newUnlockLimit: nil, now: now).updated
        let partial = summary(list, list.prefix(3).map { record($0, .partial) })
        let result = JourneyBadgeEvaluator.evaluate(summary: partial, current: earned, newUnlockLimit: 0, now: now)
        XCTAssertFalse(result.updated["every_effort"]!.isUnlocked)
        XCTAssertTrue(result.newlyUnlocked.isEmpty)
    }

    func testStatusPointsAndFutureExclusion() {
        let list = events(2027)
        let s = summary(list, [record(list[0]), record(list[1], .partial), record(list[2], .missed), record(list[3], .unrecorded)])
        XCTAssertEqual(s.year(2027).basePoints, 150)
        XCTAssertEqual(s.lifetimePoints, 150)
        let future = JourneyRewards.calculate(occurrences: list, history: list.map { record($0) }, completeYears: [2027],
                                               now: ISO8601.instant("2026-12-31T00:00:00Z")!, zone: zone)
        XCTAssertEqual(future.lifetimePoints, 0)
        XCTAssertTrue(future.year(2027).segments.allSatisfy(\.isFuture))
    }

    func testPerfect2026And2027HaveIndependentDynamicTargets() {
        let a = events(2026), b = events(2027, extra: true), list = a + b
        let s = summary(list, list.map { record($0) })
        XCTAssertEqual(s.year(2026).points, 4000)
        XCTAssertEqual(s.year(2027).points, 4100)
        XCTAssertEqual(s.year(2027).maximumPoints, 4100)
        XCTAssertEqual(s.year(2027).segments.count, 25)
        XCTAssertEqual(s.lifetimePoints, 8100)
        XCTAssertEqual(s.longestStreak, 49)
        XCTAssertEqual(s.currentStreak, 49)
        XCTAssertEqual(s.year(2027).quarters.map(\.points), [150, 150, 150, 150])
    }

    func testIncompleteAndEmptySchedulesNeverGrantBonuses() {
        let list = Array(events(2027).prefix(2))
        let s = summary(list, list.map { record($0) }, complete: [])
        XCTAssertEqual(s.year(2027).points, 200)
        XCTAssertEqual(s.year(2027).annualBonus, 0)
        XCTAssertTrue(s.year(2027).quarters.allSatisfy { $0.points == 0 })
        XCTAssertEqual(summary([], []).year(2026).points, 0)
    }

    func testPartialBreaksStreakAndBonusesButKeepsPoints() {
        let list = events(2026)
        var rows = list.map { record($0) }
        rows[1] = record(list[1], .partial)
        let s = summary(list, rows)
        XCTAssertEqual(s.year(2026).basePoints, 2350)
        XCTAssertEqual(s.year(2026).annualBonus, 0)
        XCTAssertEqual(s.year(2026).quarters.map(\.points), [0, 150, 150, 150])
        XCTAssertEqual(s.longestStreak, 24)
        XCTAssertEqual(s.fullLongestStreak, 22)
    }

    func testDuplicateSchedulesAndRecordsDoNotMultiplyPoints() {
        let list = events(2026)
        let s = summary(list + list, list.map { record($0) } + list.map { record($0) })
        XCTAssertEqual(s.year(2026).points, 4000)
        XCTAssertEqual(s.observedCount, 24)
        XCTAssertEqual(s.longestStreak, 24)
    }

    func testLatestCorrectionWinsAndDeletingRecalculates() {
        let list = events(2026)
        let original = list.map { record($0) }
        let edit = record(list[0], .missed, updated: "2028-01-02T00:00:00Z")
        let s = summary(list, original + [edit])
        XCTAssertEqual(s.year(2026).points, 2750)
        XCTAssertEqual(summary(list, Array(original.dropFirst())).year(2026).points, 2750)
    }

    func testUnknownRecordDoesNotCompleteTheAnnualSchedule() {
        let list = events(2026)
        var stranger = record(list[0]); stranger.occurrenceUid = "unknown"
        let s = summary(list, Array(list.dropFirst()).map { record($0) } + [stranger])
        XCTAssertEqual(s.year(2026).annualBonus, 0)
    }

    func testStreakCrossesYearsAndCityChangesKeepIdentity() {
        let list = [events(2026).last!, events(2027).first!]
        var changedCity = record(list[0]); changedCity.tradition = "vaishnava"; changedCity.timezone = "Europe/London"
        let s = summary(list, [changedCity, record(list[1])], complete: [])
        XCTAssertEqual(s.longestStreak, 2)
        XCTAssertEqual(s.lifetimePoints, 200)
    }

    func testParanaBoundaryNotDeviceDayControlsPoints() {
        let event = EkadashiOccurrence(id: 1, name: "E", date: CivilDate(2027, 1, 3), paranaStartISO: "2027-01-04T06:00:00+05:30")
        let before = JourneyRewards.calculate(occurrences: [event], history: [record(event)], completeYears: [],
                                              now: ISO8601.instant("2027-01-04T05:59:59+05:30")!, zone: zone)
        XCTAssertEqual(before.lifetimePoints, 0)
        let after = JourneyRewards.calculate(occurrences: [event], history: [record(event)], completeYears: [],
                                             now: ISO8601.instant("2027-01-04T06:00:00+05:30")!, zone: zone)
        XCTAssertEqual(after.lifetimePoints, 100)
    }

    func testAllBadgeConditionsAndDistinctAnnualIdentities() {
        let list = events(2026) + events(2027, extra: true)
        let s = summary(list, list.map { record($0) })
        let result = JourneyBadgeEvaluator.evaluate(summary: s, current: [:], newUnlockLimit: nil, now: now)
        for id in ["first_vrat", "vrat_5", "vrat_10", "vrat_12", "consistent_observance", "streak_6", "streak_12", "streak_24",
                   "full_year_observance", "journey_2026_q1", "journey_2026_q4", "journey_2027_q1", "journey_2027_q4",
                   "journey_2026_full", "journey_2027_full"] {
            XCTAssertEqual(result.updated[id]?.isUnlocked, true, id)
        }
        XCTAssertEqual(JourneyBadgeCatalog.all(years: [2026, 2027]).filter { $0.year != nil }.count, 10)
    }

    func testEncouragementBadgesDoNotAwardBonusPoints() {
        let list = events(2026)
        let rows = [record(list[0], .missed), record(list[1]), record(list[2], .partial), record(list[3], .partial), record(list[4], .partial)]
        let s = summary(list, rows)
        let result = JourneyBadgeEvaluator.evaluate(summary: s, current: [:], newUnlockLimit: nil, now: now)
        XCTAssertEqual(result.updated["welcome_back"]?.isUnlocked, true)
        XCTAssertEqual(result.updated["every_effort"]?.isUnlocked, true)
        XCTAssertEqual(s.lifetimePoints, 250)
    }

    func testFreeAllowanceAndLegacyEarnedBadgePreservation() {
        let list = events(2026)
        let s = summary(list, list.map { record($0) })
        let free = JourneyBadgeEvaluator.evaluate(summary: s, current: [:], newUnlockLimit: 3, now: now)
        XCTAssertEqual(free.updated.values.filter(\.isUnlocked).count, 3)
        let paid = JourneyBadgeEvaluator.evaluate(summary: s, current: free.updated, newUnlockLimit: nil, now: now)
        XCTAssertGreaterThan(paid.newlyUnlocked.count, 3)
        let corrected = JourneyBadgeEvaluator.evaluate(summary: summary(list, []), current: paid.updated, newUnlockLimit: 0, now: now)
        XCTAssertEqual(corrected.updated.values.filter(\.isUnlocked).count, 0)
        XCTAssertTrue(corrected.newlyUnlocked.isEmpty)
        XCTAssertNil(corrected.updated["first_vrat"]?.unlockedAtUTC)
    }

    func testTrackerReloadAndRepeatedSavesDoNotRepeatCelebrations() throws {
        let store = InMemoryKeyValueStore(), list = events(2026)
        let tracker = VratTracker(store: store, premiumAchievements: { true }, today: { CivilDate(2028, 1, 2) }, now: { self.now })
        try tracker.load(occurrences: list)
        let e = list[0]
        let unlocked = try tracker.record(occurrenceId: e.id, occurrenceUid: e.occurrenceUid, date: e.date.iso, name: e.name,
                                         status: .observed, occurrences: list)
        XCTAssertEqual(unlocked.map(\.id), ["first_vrat"])
        tracker.markAnnouncementsPresented(unlocked.map(\.id))
        XCTAssertTrue(try tracker.record(occurrenceId: e.id, occurrenceUid: e.occurrenceUid, date: e.date.iso, name: e.name,
                                        status: .observed, occurrences: list).isEmpty)
        let restored = VratTracker(store: store, premiumAchievements: { true }, now: { self.now })
        try restored.load(occurrences: list)
        XCTAssertTrue(try restored.refreshAchievements(list).isEmpty)
    }

    func testUnpresentedAwardsSurviveReloadAndPresentedOnesDoNotRepeat() throws {
        let store = InMemoryKeyValueStore(), list = events(2026)
        let make = { VratTracker(store: store, premiumAchievements: { true }, now: { self.now }) }
        let first = make(); try first.load(occurrences: list)
        let e = list[0]
        _ = try first.record(occurrenceId: e.id, occurrenceUid: e.occurrenceUid, date: e.date.iso, name: e.name,
                             status: .observed, occurrences: list)
        let next = make(); try next.load(occurrences: list)
        let pending = try next.refreshAchievements(list)
        XCTAssertEqual(pending.map(\.id), ["first_vrat"])
        next.markAnnouncementsPresented(pending.map(\.id))
        let final = make(); try final.load(occurrences: list)
        XCTAssertTrue(try final.refreshAchievements(list).isEmpty)
    }

    func testAwardWriteFailureDoesNotLoseHistoryAndCanRetry() throws {
        let store = JourneyAwardFailureStore(), list = events(2026)
        let tracker = VratTracker(store: store, premiumAchievements: { true }, now: { self.now })
        try tracker.load(occurrences: list)
        store.refuseAwards = true
        let e = list[0]
        XCTAssertTrue(try tracker.record(occurrenceId: e.id, occurrenceUid: e.occurrenceUid, date: e.date.iso, name: e.name,
                                        status: .observed, occurrences: list).isEmpty)
        XCTAssertEqual(tracker.record(forUid: e.occurrenceUid)?.status, .observed)
        XCTAssertTrue(tracker.rewardsStorageError)
        store.refuseAwards = false
        XCTAssertEqual(try tracker.refreshAchievements(list).map(\.id), ["first_vrat"])
        XCTAssertFalse(tracker.rewardsStorageError)
    }

    func testCorruptBadgeEnvelopeDoesNotBlockJournal() throws {
        for key in ["journey_badges_v1", "vrat_tracker_user_achievements"] {
            let store = InMemoryKeyValueStore()
            _ = store.set("invalid", forKey: key)
            let tracker = VratTracker(store: store, now: { self.now })
            try tracker.load(occurrences: events(2026))
            XCTAssertTrue(tracker.isEnabled)
            XCTAssertTrue(tracker.rewardsStorageError)
        }
    }

    func testTrackerAwardsUseTheHomeZoneWhenParanaIsUnavailable() throws {
        let now = ISO8601.instant("2026-01-04T01:00:00Z")!
        let event = EkadashiOccurrence(id: 1, name: "E", date: CivilDate(2026, 1, 3))
        let tracker = VratTracker(store: InMemoryKeyValueStore(), premiumAchievements: { true }, now: { now })
        tracker.journeyZone = AppTimezone.pst.location
        try tracker.load(occurrences: [event])
        _ = try tracker.record(occurrenceId: event.id, occurrenceUid: event.occurrenceUid, date: event.date.iso,
                               name: event.name, status: .observed, occurrences: [event])
        XCTAssertEqual(tracker.journey([event], completeYears: []).lifetimePoints, 0)
        XCTAssertNotEqual(tracker.userAchievements["first_vrat"]?.isUnlocked, true)
        tracker.journeyZone = AppTimezone.ist.location
        XCTAssertEqual(try tracker.refreshAchievements([event]).map(\.id), ["first_vrat"])
    }

    func testNextMilestoneNeverEncouragesMissingOrPartialFasts() {
        let list = events(2026)
        let full = summary(list, list.map { record($0) })
        let earned = JourneyBadgeEvaluator.evaluate(summary: full, current: [:], newUnlockLimit: nil, now: now).updated
        XCTAssertNil(JourneyBadgeCatalog.nextMilestone(summary: full, earned: earned))
        let rows = list.prefix(5).map { record($0) }
        let five = JourneyRewards.calculate(occurrences: list, history: rows, completeYears: [2026],
                                            now: ISO8601.instant("2026-03-17T12:00:00Z")!, zone: zone)
        let state = JourneyBadgeEvaluator.evaluate(summary: five, current: [:], newUnlockLimit: nil, now: now).updated
        XCTAssertEqual(JourneyBadgeCatalog.nextMilestone(summary: five, earned: state)?.id, "streak_6")
        let broken = JourneyRewards.calculate(occurrences: list, history: rows + [record(list[5], .missed)], completeYears: [2026],
                                              now: ISO8601.instant("2026-03-19T12:00:00Z")!, zone: zone)
        XCTAssertEqual(JourneyBadgeCatalog.nextMilestone(summary: broken, earned: state)?.id, "vrat_10")
        XCTAssertEqual(JourneyBadgeCatalog.definition("streak_6")?.goalProgress(in: broken), 0)
    }

    func testValidBadgeEnvelopeTakesPrecedenceOverCorruptLegacyBadges() throws {
        let store = InMemoryKeyValueStore(), list = events(2026)
        let first = VratTracker(store: store, now: { self.now })
        try first.load(occurrences: list)
        let e = list[0]
        let awards = try first.record(occurrenceId: e.id, occurrenceUid: e.occurrenceUid, date: e.date.iso,
                                      name: e.name, status: .observed, occurrences: list)
        first.markAnnouncementsPresented(awards.map(\.id))
        _ = store.set("invalid", forKey: "vrat_tracker_user_achievements")
        let restored = VratTracker(store: store, now: { self.now })
        try restored.load(occurrences: list)
        XCTAssertTrue(restored.isEnabled)
        XCTAssertFalse(restored.rewardsStorageError)
        XCTAssertEqual(restored.userAchievements["first_vrat"]?.isUnlocked, true)
        XCTAssertTrue(try restored.refreshAchievements(list).isEmpty)
    }

    func testBadgeVocabularyExistsInEveryAppLanguage() {
        for badge in JourneyBadgeCatalog.all(years: [2026, 2027]) {
            for language in Localizer.languages {
                XCTAssertNotEqual(Localizer.shared.translate(badge.achievement.titleKey, language: language), badge.achievement.titleKey)
                XCTAssertNotEqual(Localizer.shared.translate(badge.achievement.descriptionKey, language: language), badge.achievement.descriptionKey)
            }
        }
    }
}

private final class JourneyAwardFailureStore: KeyValueStore {
    let backing = InMemoryKeyValueStore()
    var refuseAwards = false
    func string(forKey key: String) -> String? { backing.string(forKey: key) }
    func bool(forKey key: String) -> Bool? { backing.bool(forKey: key) }
    func stringArray(forKey key: String) -> [String]? { backing.stringArray(forKey: key) }
    func set(_ value: String, forKey key: String) -> Bool {
        if refuseAwards && key == "journey_badges_v1" { return false }
        return backing.set(value, forKey: key)
    }
    func set(_ value: Bool, forKey key: String) -> Bool { backing.set(value, forKey: key) }
    func set(_ value: [String], forKey key: String) -> Bool { backing.set(value, forKey: key) }
    func remove(_ key: String) { backing.remove(key) }
    func keys() -> [String] { backing.keys() }
}
