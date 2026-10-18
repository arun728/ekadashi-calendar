import Foundation

/// One versioned value is the commit boundary (tracker_history_store.dart).
public enum TrackerHistoryStore {
    public static let key = "vrat_tracker_history_v2"

    static func load(_ store: KeyValueStore) throws -> (records: [VratRecord], unresolved: [Any]) {
        guard let raw = store.string(forKey: key) else { return ([], []) }
        guard let envelope = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any],
              envelope["schemaVersion"] as? Int == 2, let rows = envelope["records"] as? [Any] else {
            throw CoreError.storage("Unsupported tracker storage version")
        }
        var seen = Set<String>()
        let records = try rows.map { row -> VratRecord in
            let record = try JSONDecoder().decode(VratRecord.self, from: JSONSerialization.data(withJSONObject: row))
            guard let uid = record.occurrenceUid, seen.insert(uid).inserted else {
                throw CoreError.storage("Invalid or duplicate tracker identity")
            }
            return record
        }
        return (records, envelope["unresolved"] as? [Any] ?? [])
    }

    static func save(_ store: KeyValueStore, records: [VratRecord], unresolved: [Any]) throws {
        let rows = try records.map { try JSONSerialization.jsonObject(with: JSONEncoder().encode($0)) }
        let data = try JSONSerialization.data(withJSONObject: ["schemaVersion": 2, "records": rows, "unresolved": unresolved],
                                              options: [.sortedKeys])
        let encoded = String(decoding: data, as: UTF8.self)
        guard store.set(encoded, forKey: key), store.string(forKey: key) == encoded else {
            throw CoreError.storage("Tracker history could not be saved")
        }
    }
}

/// Vrat tracking, statistics and achievements (vrat_tracker_service.dart).
/// Recording is free for three entries; a fourth new entry needs premium.
/// Editing, deleting and all history, streaks and badges always stay free.
public final class VratTracker {
    public static let freeEntryLimit = 3
    public static let freeAchievementLimit = 3
    static let enabledAtKey = "vrat_tracker_enabled_at"
    static let achievementsKey = "vrat_tracker_user_achievements"
    static let notifiedKey = "vrat_tracker_notified_achievements"
    static let badgeEnvelopeKey = "journey_badges_v1"
    private struct BadgeEnvelope: Codable { let achievements: [UserAchievement]; let presented: [String] }

    private let store: KeyValueStore
    private let premiumAchievements: () -> Bool
    private let today: () -> CivilDate
    private let now: () -> Date
    private var recordsByUid: [String: VratRecord] = [:]
    private var unresolved: [Any] = []
    private var notified = Set<String>()
    private var queued = Set<String>()
    public private(set) var rewardsStorageError = false
    public var journeyZone: TzLocation = AppTimezone.ist.location
    private var rewardsStoreCorrupt = false
    public private(set) var userAchievements: [String: UserAchievement] = [:]
    public private(set) var trackingEnabledAt: Date?
    public private(set) var isEnabled = false
    public private(set) var storageError: String?

    public init(store: KeyValueStore, premiumAchievements: @escaping () -> Bool = { false },
                today: @escaping () -> CivilDate = { CivilDate.today() },
                now: @escaping () -> Date = Date.init) {
        self.store = store
        self.premiumAchievements = premiumAchievements
        self.today = today
        self.now = now
    }

    /// History corruption blocks writes to protect private records. Badge
    /// metadata failures are isolated so the journal remains available.
    public func load(occurrences: [EkadashiOccurrence]) throws {
        do {
            let loaded = try TrackerHistoryStore.load(store)
            recordsByUid = Dictionary(loaded.records.map { ($0.occurrenceUid!, $0) }, uniquingKeysWith: { a, _ in a })
            unresolved = loaded.unresolved
            userAchievements = [:]
            rewardsStoreCorrupt = false
            rewardsStorageError = false
            notified = Set(store.stringArray(forKey: Self.notifiedKey) ?? [])
            // Once migrated, the envelope is authoritative. Stale legacy
            // bytes must never prevent loading a valid newer badge store.
            if let raw = store.string(forKey: Self.badgeEnvelopeKey) {
                if let envelope = try? JSONDecoder().decode(BadgeEnvelope.self, from: Data(raw.utf8)) {
                    userAchievements = Dictionary(envelope.achievements.map { ($0.achievementId, $0) }, uniquingKeysWith: { a, _ in a })
                    notified.formUnion(envelope.presented)
                } else {
                    rewardsStoreCorrupt = true
                    rewardsStorageError = true
                }
            } else if let raw = store.string(forKey: Self.achievementsKey) {
                if let list = try? JSONDecoder().decode([UserAchievement].self, from: Data(raw.utf8)) {
                    userAchievements = Dictionary(list.map { ($0.achievementId, $0) }, uniquingKeysWith: { a, _ in a })
                } else {
                    // Preserve damaged award data for recovery while keeping
                    // the observance journal writable.
                    rewardsStoreCorrupt = true
                    rewardsStorageError = true
                }
            }
            queued = []
            if let started = store.string(forKey: Self.enabledAtKey).flatMap(ISO8601.instant) {
                trackingEnabledAt = started
            } else {
                let stamp = ISO8601.string(now())
                store.set(stamp, forKey: Self.enabledAtKey)
                trackingEnabledAt = ISO8601.instant(stamp)
            }
            isEnabled = true
            storageError = nil
            if !occurrences.isEmpty { _ = evaluate(occurrences); queued = []; _ = persistAchievements() }
        } catch {
            isEnabled = false
            storageError = "\(error)"
            throw error
        }
    }

    public var history: [Int: VratRecord] {
        Dictionary(recordsByUid.values.map { ($0.ekadashiOccurrenceId, $0) }, uniquingKeysWith: { a, _ in a })
    }
    public var allRecords: [VratRecord] { recordsByUid.values.sorted { $0.ekadashiDate < $1.ekadashiDate } }
    public func record(forOccurrenceId id: Int) -> VratRecord? { history[id] }
    public func record(forUid uid: String) -> VratRecord? { recordsByUid[uid] }
    public var recordedEntryCount: Int { recordsByUid.values.filter { $0.status != .unrecorded }.count }

    public func needsPremiumToRecord(uid: String, premium: Bool) -> Bool {
        !premium && record(forUid: uid) == nil && recordedEntryCount >= Self.freeEntryLimit
    }

    /// Records or edits an observance; future Ekadashis cannot be recorded.
    /// Returns badges to announce (each only once).
    @discardableResult
    public func record(occurrenceId: Int, occurrenceUid: String? = nil, date: String, name: String, status: ObservanceStatus,
                       method: FastingMethod? = nil, methodOther: String? = nil, note: String? = nil, tradition: String? = nil,
                       timezone: String? = nil, occurrences: [EkadashiOccurrence] = []) throws -> [Achievement] {
        guard isEnabled else { throw CoreError.storage(storageError ?? "Tracker unavailable") }
        guard let day = CivilDate(iso: date.trimmingCharacters(in: .whitespaces)), day <= today() else { return [] }
        let uid = occurrenceUid ?? occurrences.first { $0.id == occurrenceId }?.occurrenceUid ?? "ekadashi:\(day.year):\(pad2(occurrenceId))"
        let existing = recordsByUid[uid]
        let stamp = ISO8601.string(now())
        let updated = VratRecord(
            id: existing?.id ?? "vrat_\(occurrenceId)_\(Int64(now().timeIntervalSince1970 * 1000))",
            localProfileId: existing?.localProfileId ?? "default", ekadashiOccurrenceId: occurrenceId, occurrenceUid: uid,
            ekadashiDate: date, ekadashiName: name, status: status, fastingMethod: method, fastingMethodOther: methodOther,
            note: note, recordedAtUTC: existing?.recordedAtUTC ?? stamp, updatedAtUTC: stamp,
            tradition: tradition ?? existing?.tradition, timezone: timezone ?? existing?.timezone,
            locationContext: existing?.locationContext)
        var staged = recordsByUid
        staged[uid] = updated
        try TrackerHistoryStore.save(store, records: Array(staged.values), unresolved: unresolved)
        recordsByUid = staged
        let unlocked = occurrences.isEmpty ? [] : evaluate(occurrences)
        guard persistAchievements() else { queued.subtract(unlocked.map(\.id)); return [] }
        return unlocked
    }

    public func delete(occurrenceId: Int, occurrences: [EkadashiOccurrence] = []) throws {
        guard isEnabled, let uid = history[occurrenceId]?.occurrenceUid else { return }
        var staged = recordsByUid
        staged.removeValue(forKey: uid)
        try TrackerHistoryStore.save(store, records: Array(staged.values), unresolved: unresolved)
        recordsByUid = staged
        if !occurrences.isEmpty { _ = evaluate(occurrences) }
        persistAchievements()
    }

    /// Re-evaluates badges, e.g. after premium changes.
    public func refreshAchievements(_ occurrences: [EkadashiOccurrence]) throws -> [Achievement] {
        guard isEnabled else { return [] }
        let unlocked = evaluate(occurrences)
        guard persistAchievements() else { queued.subtract(unlocked.map(\.id)); return [] }
        return unlocked
    }

    public func currentStreak(_ occurrences: [EkadashiOccurrence]) -> Int {
        VratStatistics.currentStreak(occurrences: occurrences, history: history, asOf: today())
    }

    public func longestStreak(_ occurrences: [EkadashiOccurrence]) -> Int {
        VratStatistics.longestStreak(occurrences: occurrences, history: history)
    }

    public func annualStats(year: Int, occurrences: [EkadashiOccurrence]) -> VratYearStats {
        VratStatistics.annualStats(year: year, occurrences: occurrences, history: history)
    }

    public func availableYears(_ occurrences: [EkadashiOccurrence]) -> [Int] {
        VratStatistics.availableYears(occurrences: occurrences, history: allRecords, currentYear: today().year)
    }

    /// Consumed only when the grouped celebration actually appears.
    public func markAnnouncementsPresented(_ ids: [String]) {
        let old = notified
        notified.formUnion(ids)
        if !persistAchievements() { notified = old }
    }

    public func journey(_ occurrences: [EkadashiOccurrence], completeYears: Set<Int>, zone: TzLocation? = nil) -> JourneySummary {
        JourneyRewards.calculate(occurrences: occurrences, history: allRecords, completeYears: completeYears, now: now(), zone: zone ?? journeyZone)
    }

    private func evaluate(_ occurrences: [EkadashiOccurrence]) -> [Achievement] {
        guard !rewardsStoreCorrupt else { return [] }
        let unlockedCount = userAchievements.values.filter(\.isUnlocked).count
        let limit = premiumAchievements() ? nil : max(0, Self.freeAchievementLimit - unlockedCount)
        let summary = journey(occurrences, completeYears: Set(occurrences.map(\.date.year)))
        let result = JourneyBadgeEvaluator.evaluate(summary: summary, current: userAchievements, newUnlockLimit: limit, now: now())
        userAchievements = result.updated
        let pending = JourneyBadgeCatalog.all(years: Array(summary.years.keys)).filter {
            userAchievements[$0.id]?.isUnlocked == true && !notified.contains($0.id) && !queued.contains($0.id)
        }.map(\.achievement)
        queued.formUnion(pending.map(\.id))
        return pending
    }

    /// One envelope is the commit boundary for badges and presented markers.
    /// History is already durable; secondary failure never erases the journal.
    @discardableResult private func persistAchievements() -> Bool {
        guard !rewardsStoreCorrupt else { return false }
        let list = userAchievements.values.sorted { $0.achievementId < $1.achievementId }
        guard let data = try? JSONEncoder().encode(BadgeEnvelope(achievements: list, presented: notified.sorted())) else {
            rewardsStorageError = true; return false
        }
        let raw = String(decoding: data, as: UTF8.self)
        let saved = store.set(raw, forKey: Self.badgeEnvelopeKey) && store.string(forKey: Self.badgeEnvelopeKey) == raw
        rewardsStorageError = !saved
        return saved
    }
}
