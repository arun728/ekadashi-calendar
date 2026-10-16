import Foundation

/// The years the app shows Ekadashis for (assets/calendar/ekadashi_years.json).
/// Adding a year there is all a release needs: the engine supplies its dates
/// and times, and the texts come from the year packs by Ekadashi.
public enum EkadashiYears {
    public static func enabled() -> [Int] {
        guard let json = try? JSONSerialization.jsonObject(with: CoreResources.data("calendar/ekadashi_years.json"))
                as? [String: Any], json["schema_version"] as? Int == 1,
              let years = json["enabled_years"] as? [Int], !years.isEmpty else { return [2026, 2027] }
        return years.sorted()
    }

    /// The year to open: this year when enabled, else the nearest enabled one.
    public static func defaultYear(today: CivilDate, enabled: [Int] = enabled()) -> Int {
        if enabled.contains(today.year) { return today.year }
        return enabled.min { abs($0 - today.year) < abs($1 - today.year) } ?? today.year
    }
}

/// One calculated Ekadashi for a city and tradition, before any language:
/// the part that is cached.
public struct ScheduledEkadashi: Codable, Equatable, Sendable {
    public let occurrenceUid: String
    public let notificationId: Int
    public let legacyId: Int
    public let contentId: String
    /// The published row this fast keeps the identity and texts of, if any.
    public let publishedUid: String?
    public let date: String
    public let fastingStart: String
    public let paranaStart: String
    public let paranaEnd: String
    public let paksha: String
    public let month: String
    public let rule: String
}

/// Where the Ekadashi times are calculated (CalculatedEkadashi.ruleVersion).
public struct EkadashiScheduleKey: Hashable, Sendable {
    public let city: PanchangCity
    public let tradition: EkadashiTradition
    public let year: Int

    public init(city: PanchangCity, tradition: EkadashiTradition, year: Int) {
        self.city = city
        self.tradition = tradition
        self.year = year
    }

    /// A stable file-name-safe key, also used for the disk cache.
    public var cacheId: String {
        let place = "\(city.id)_\(String(format: "%.4f", city.latitude))_\(String(format: "%.4f", city.longitude))_\(city.timeZoneId)"
        return "\(EkadashiSchedule.formatVersion)|\(CalculatedEkadashi.ruleVersion)|\(tradition.rawValue)|\(year)|\(place)"
    }
}

/// Ekadashi dates and times from the Panchang engine for any city and
/// tradition, with the published texts and identities.
///
/// - Dates, fasting start and Parana come from [CalculatedEkadashiEngine]
///   at the city's sunrise in its own time zone.
/// - In a year with a published pack, each fast keeps the identity
///   (`occurrence_uid`, notification id) and texts of the published row of
///   the same Ekadashi within three days, so Vrat history, achievements and
///   reminders stay attached. A fast the pack lacks (Saphala on 23 Dec 2027)
///   gets the next number of that year.
/// - In other years every fast is numbered in date order, and the texts come
///   from the newest pack that has that Ekadashi.
public final class EkadashiSchedule: @unchecked Sendable {
    /// Bumped when the cached form changes (2: times cut to the minute like
    /// the Panchang tab, not rounded), so older caches are recalculated.
    public static let formatVersion = "schedule-2"
    private let repository: CalendarRepository
    private let localizer: Localizer
    private let engine: CalculatedEkadashiEngine
    private let memory = Locked<[String: [ScheduledEkadashi]]>([:])
    private let diskCache: URL?

    public init(repository: CalendarRepository, localizer: Localizer = .shared,
                engine: CalculatedEkadashiEngine = CalculatedEkadashiEngine(), cacheDirectory: URL? = nil) {
        self.repository = repository
        self.localizer = localizer
        self.engine = engine
        diskCache = cacheDirectory
    }

    /// The content id of an engine name ("Devutthana" is published as Prabodhini).
    public static func contentId(forEngineName name: String) -> String {
        let id = name.lowercased().replacingOccurrences(of: " ", with: "-")
        return id == "devutthana-ekadashi" ? "prabodhini-ekadashi" : id
    }

    /// Whether [key] is already calculated (in memory or on disk).
    public func isCached(_ key: EkadashiScheduleKey) -> Bool {
        if memory.withLock({ $0[key.cacheId] }) != nil { return true }
        guard let disk = readDisk(key) else { return false }
        memory.withLock { $0[key.cacheId] = disk }
        return true
    }

    /// The fasts of one year at one place; calculated once, then cached.
    public func scheduled(_ key: EkadashiScheduleKey) throws -> [ScheduledEkadashi] {
        if let hit = memory.withLock({ $0[key.cacheId] }) { return hit }
        if let disk = readDisk(key) {
            memory.withLock { $0[key.cacheId] = disk }
            return disk
        }
        let calculated = try calculate(key)
        memory.withLock { $0[key.cacheId] = calculated }
        writeDisk(key, calculated)
        return calculated
    }

    /// Occurrences for [years] at [city] in [language], sorted by date.
    public func ekadashis(city: PanchangCity, tradition: EkadashiTradition, language: String,
                          years: [Int]) throws -> [EkadashiOccurrence] {
        var result: [EkadashiOccurrence] = []
        for year in years {
            result += try scheduled(EkadashiScheduleKey(city: city, tradition: tradition, year: year))
                .map { occurrence($0, year: year, language: language) }
        }
        return result.sorted { $0.date < $1.date }
    }

    // MARK: Calculation

    func calculate(_ key: EkadashiScheduleKey) throws -> [ScheduledEkadashi] {
        let start = CivilDate(key.year, 1, 1)
        let days = start.days(until: CivilDate(key.year + 1, 1, 1))
        let fasts = try engine.calculate(start: start, count: days, city: key.city, tradition: key.tradition)
        let published = repository.rows(year: key.year)
        var unused = Set(published.indices)
        var nextNumber = published.compactMap { ($0["occurrence_uid"] as? String).flatMap(Self.number) }.max() ?? 0
        let zone = key.city.zone
        var result: [ScheduledEkadashi] = []
        for (ordinal, fast) in fasts.enumerated() {
            let contentId = Self.contentId(forEngineName: fast.name)
            // The published row of the same Ekadashi nearest in date.
            let match = unused.filter { published[$0]["content_id"] as? String == contentId }
                .compactMap { i -> (Int, Int)? in
                    guard let date = Self.publishedDate(published[i]) else { return nil }
                    let gap = abs(date.days(until: fast.date))
                    return gap <= 3 ? (i, gap) : nil
                }
                .min { $0.1 < $1.1 }?.0
            let uid: String, notificationId: Int, legacyId: Int
            var paksha = fast.isShukla ? "shukla" : "krishna"
            var month = Self.monthKey(fast.month)
            if let match {
                unused.remove(match)
                let row = published[match]
                uid = row["occurrence_uid"] as? String ?? ""
                notificationId = row["notification_id"] as? Int ?? 0
                legacyId = row["legacy_id"] as? Int ?? notificationId
                paksha = row["paksha"] as? String ?? paksha
                month = row["month"] as? String ?? month
            } else {
                let number: Int
                if published.isEmpty {
                    number = ordinal + 1
                } else {
                    nextNumber += 1
                    number = nextNumber
                }
                uid = "ekadashi:\(key.year):\(pad2(number))"
                notificationId = key.year * 1000 + number
                legacyId = number
            }
            let end = fast.paranaEnd ?? fast.paranaDaySunset
            result.append(ScheduledEkadashi(
                occurrenceUid: uid, notificationId: notificationId, legacyId: legacyId, contentId: contentId,
                publishedUid: match == nil ? nil : uid, date: fast.date.iso,
                fastingStart: Self.iso(fast.fastStarts, zone), paranaStart: fast.paranaStart.map { Self.iso($0, zone) } ?? "",
                paranaEnd: end.map { Self.iso($0, zone) } ?? "", paksha: paksha, month: month, rule: fast.rule))
        }
        return result
    }

    static func number(_ uid: String) -> Int? { uid.split(separator: ":").last.flatMap { Int($0) } }

    /// The IST date of a published row (the reference schedule of the packs).
    static func publishedDate(_ row: [String: Any]) -> CivilDate? {
        ((row["timing"] as? [String: Any])?["IST"] as? [String: Any])?["date"].flatMap { $0 as? String }.flatMap(CivilDate.init(iso:))
    }

    /// The `lunar_month_` key of an engine month ("Ashvina" → ashwin).
    static func monthKey(_ month: String) -> String {
        if month.hasPrefix("Adhika") { return "adhika" }
        let key = month.lowercased()
        return ["ashvina": "ashwin", "kartika": "kartik"][key] ?? key
    }

    /// Local wall-clock time with its offset, to the minute: the form of the
    /// published packs ("2026-01-14T06:35:00+05:30"). The seconds are dropped,
    /// as the Panchang tab shows the same instants, so both read the same.
    static func iso(_ instant: Date, _ zone: TzLocation) -> String {
        let wall = zone.wallClock(instant)
        let offset = abs(wall.offsetSeconds) / 60
        return "\(wall.date.iso)T\(pad2(wall.hour)):\(pad2(wall.minute)):00\(wall.offsetSeconds < 0 ? "-" : "+")"
            + "\(pad2(offset / 60)):\(pad2(offset % 60))"
    }

    // MARK: Texts

    func occurrence(_ fast: ScheduledEkadashi, year: Int, language: String) -> EkadashiOccurrence {
        let row = fast.publishedUid.flatMap { uid in repository.rows(year: year).first { $0["occurrence_uid"] as? String == uid } }
            ?? repository.contentRow(id: fast.contentId) ?? [:]
        let maps = ["name", "description", "story", "fasting_rules", "benefits"].map { row[$0] as? [String: String] ?? [:] }
        func text(_ map: [String: String], _ fallback: String = "") -> String { map[language] ?? map["en"] ?? fallback }
        func term(_ prefix: String, _ value: String) -> String {
            let key = prefix + value.lowercased()
            let translated = localizer.translate(key, language: language)
            return translated == key ? value : translated
        }
        let name = maps[0].isEmpty ? fast.contentId.replacingOccurrences(of: "-", with: " ").capitalized : text(maps[0])
        return EkadashiOccurrence(
            id: fast.notificationId, occurrenceUid: fast.occurrenceUid, legacyId: fast.legacyId, contentId: fast.contentId,
            usesContentFallback: maps.contains { $0[language] == nil }, name: name, date: CivilDate(iso: fast.date)!,
            fastStartTime: EkadashiTimeFormat.displayTime(fast.fastingStart),
            fastBreakTime: EkadashiTimeFormat.window(fast.paranaStart, fast.paranaEnd), description: text(maps[1]),
            story: text(maps[2], "Story coming soon..."), fastingRules: text(maps[3], "Standard Ekadashi fasting rules apply."),
            benefits: text(maps[4], "Grants spiritual merit."), paksha: term("paksha_", fast.paksha),
            month: term("lunar_month_", fast.month), fastingStartISO: fast.fastingStart, paranaStartISO: fast.paranaStart,
            paranaEndISO: fast.paranaEnd)
    }

    // MARK: Disk cache

    private func file(_ key: EkadashiScheduleKey) -> URL? {
        guard let diskCache else { return nil }
        let safe = key.cacheId.map { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "." ? String($0) : "_" }.joined()
        return diskCache.appendingPathComponent("ekadashi_\(safe).json")
    }

    private func readDisk(_ key: EkadashiScheduleKey) -> [ScheduledEkadashi]? {
        guard let url = file(key), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([ScheduledEkadashi].self, from: data)
    }

    private func writeDisk(_ key: EkadashiScheduleKey, _ value: [ScheduledEkadashi]) {
        guard let url = file(key), let data = try? JSONEncoder().encode(value) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
