import Foundation

/// Native iOS calculation reuse. Values contain no translated strings, so a
/// language change does not repeat astronomy. Coordinates and the IANA zone
/// remain part of every key; a different place never inherits stale timings.
public struct PanchangDataStore: Sendable {
    private struct DayKey: Hashable, Sendable { let date: CivilDate; let city: PanchangCity }
    private struct FastKey: Hashable, Sendable { let month: CivilDate; let city: PanchangCity; let tradition: EkadashiTradition }
    private let days: CalculationMemo<DayKey, PanchangDay>
    private let months: CalculationMemo<DayKey, [DatedObservance]>
    private let fastMonths: CalculationMemo<FastKey, Result<[CalculatedEkadashi], Error>>
    private let calculateDay: @Sendable (CivilDate, PanchangCity) -> PanchangDay
    private let calculateObservances: @Sendable (CivilDate, PanchangCity) -> [PanchangObservance]
    private let calculateFasts: @Sendable (CivilDate, PanchangCity, EkadashiTradition) throws -> [CalculatedEkadashi]

    public init() { self.init(day: nil, observances: nil, fasts: nil) }

    // Injection keeps work-count and concurrency regressions deterministic.
    init(day: (@Sendable (CivilDate, PanchangCity) -> PanchangDay)? = nil,
         observances: (@Sendable (CivilDate, PanchangCity) -> [PanchangObservance])? = nil,
         fasts: (@Sendable (CivilDate, PanchangCity, EkadashiTradition) throws -> [CalculatedEkadashi])? = nil,
         capacity: Int = 24) {
        days = CalculationMemo(capacity: capacity)
        months = CalculationMemo(capacity: capacity)
        fastMonths = CalculationMemo(capacity: capacity)
        calculateDay = day ?? { PanchangEngine().calculate($0, city: $1) }
        calculateObservances = observances ?? { PanchangEngine().observances(on: $0, city: $1) }
        calculateFasts = fasts ?? { try CalculatedEkadashiEngine().calculate(start: $0, count: $0.daysInMonth, city: $1, tradition: $2) }
    }

    /// Daily, Muhurta and Rashi use this same day, including concurrent requests.
    public func day(_ date: CivilDate, city: PanchangCity) async -> PanchangDay {
        let calculate = calculateDay
        return await days.value(for: DayKey(date: date, city: city)) { calculate(date, city) }
    }

    /// Key days needs only its displayed month, not a full year's astronomy.
    public func observances(month: CivilDate, city: PanchangCity) async -> [DatedObservance] {
        let month = month.firstOfMonth, calculate = calculateObservances
        return await months.value(for: DayKey(date: month, city: city)) {
            (0..<month.daysInMonth).flatMap { offset -> [DatedObservance] in
                let date = month.adding(days: offset)
                return calculate(date, city).map { DatedObservance(date: date, observance: $0) }
            }
        }
    }

    /// Search/reminders retain their whole-year coverage and share month work
    /// already requested by Key days. No background year is started by the UI.
    public func observances(year: Int, city: PanchangCity) async -> [DatedObservance] {
        var result: [DatedObservance] = []
        for month in 1...12 { result += await observances(month: CivilDate(year, month, 1), city: city) }
        return result
    }

    public func fasts(month: CivilDate, city: PanchangCity, tradition: EkadashiTradition) async throws -> [CalculatedEkadashi] {
        let month = month.firstOfMonth, calculate = calculateFasts
        let result = await fastMonths.value(for: FastKey(month: month, city: city, tradition: tradition),
            keep: { if case .success = $0 { return true }; return false }) {
                Result { try calculate(month, city, tradition) }
            }
        return try result.get()
    }
}

/// Shares both completed and in-flight work without holding a lock while
/// calculating. Detached work survives a cancelled view's waiter so another
/// visible page can still use it. Eviction bounds session memory and never
/// cancels work that another caller is awaiting.
private actor CalculationMemo<Key: Hashable & Sendable, Value: Sendable> {
    private struct Entry { let id: UUID; let task: Task<Value, Never> }
    private let capacity: Int
    private var entries: [Key: Entry] = [:]
    private var order: [Key] = []

    init(capacity: Int) { self.capacity = max(1, capacity) }

    func value(for key: Key, keep: @Sendable (Value) -> Bool = { _ in true },
               calculate: @escaping @Sendable () -> Value) async -> Value {
        if let entry = entries[key] { return await entry.task.value }
        let entry = Entry(id: UUID(), task: Task.detached(priority: .userInitiated, operation: calculate))
        entries[key] = entry
        order.append(key)
        if order.count > capacity { entries.removeValue(forKey: order.removeFirst()) }
        let value = await entry.task.value
        if !keep(value), entries[key]?.id == entry.id {
            entries.removeValue(forKey: key)
            order.removeAll { $0 == key }
        }
        return value
    }
}
