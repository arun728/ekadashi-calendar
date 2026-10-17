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
        XCTAssertEqual(s.longestStreak, 22)
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
        XCTAssertEqual(corrected.updated.values.filter(\.isUnlocked).count, paid.updated.values.filter(\.isUnlocked).count)
        XCTAssertTrue(corrected.newlyUnlocked.isEmpty)
        XCTAssertEqual(corrected.updated["first_vrat"]?.unlockedAtUTC, paid.updated["first_vrat"]?.unlockedAtUTC)
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
        let store = InMemoryKeyValueStore()
        store.set("invalid", forKey: "journey_badges_v1")
        let tracker = VratTracker(store: store, now: { self.now })
        try tracker.load(occurrences: events(2026))
        XCTAssertTrue(tracker.isEnabled)
        XCTAssertTrue(tracker.rewardsStorageError)
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
