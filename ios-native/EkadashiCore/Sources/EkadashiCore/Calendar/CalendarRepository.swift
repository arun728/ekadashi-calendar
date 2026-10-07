import Foundation

/// Bundled year packs (assets/calendar/<year>.json listed in manifest.json),
/// validated as a whole before anything is published (calendar_repository.dart).
public final class CalendarRepository: @unchecked Sendable {
    private let rows: [[String: Any]]
    public let availableYears: [Int]
    private let cache = Locked<[String: [EkadashiOccurrence]]>([:])
    private let localizer: Localizer

    public static func bundled(localizer: Localizer = .shared) throws -> CalendarRepository {
        guard let manifest = try JSONSerialization.jsonObject(with: CoreResources.data("calendar/manifest.json")) as? [String: Any],
              manifest["schema_version"] as? Int == 1, let packs = manifest["packs"] as? [[String: Any]] else {
            throw CoreError.invalidData("Unsupported calendar manifest")
        }
        var data: [Data] = []
        for pack in packs {
            guard let asset = pack["asset"] as? String, let year = pack["year"] as? Int else {
                throw CoreError.invalidData("Unsupported calendar manifest")
            }
            let blob = try CoreResources.data("calendar/" + (asset as NSString).lastPathComponent)
            guard let parsed = try JSONSerialization.jsonObject(with: blob) as? [String: Any], parsed["year"] as? Int == year else {
                throw CoreError.invalidData("Calendar pack year differs from manifest")
            }
            data.append(blob)
        }
        return try CalendarRepository(packs: data, localizer: localizer)
    }

    public init(packs: [Data], localizer: Localizer = .shared) throws {
        self.localizer = localizer
        var years = Set<Int>(), uids = Set<String>(), nativeIds = Set<Int>()
        var combined: [[String: Any]] = []
        for blob in packs {
            guard let pack = try JSONSerialization.jsonObject(with: blob) as? [String: Any], let year = pack["year"] as? Int,
                  pack["schema_version"] as? Int == 1, years.insert(year).inserted,
                  let events = pack["ekadashis"] as? [[String: Any]] else {
                throw CoreError.invalidData("Unsupported or duplicate calendar year")
            }
            for row in events {
                guard let uid = row["occurrence_uid"] as? String, let nativeId = row["notification_id"] as? Int,
                      uid.hasPrefix("ekadashi:\(year):"), uids.insert(uid).inserted, nativeId > 0, nativeId <= 0x7fff_ffff,
                      nativeIds.insert(nativeId).inserted else {
                    throw CoreError.invalidData("Invalid or duplicate calendar identity")
                }
                guard let english = (row["name"] as? [String: Any])?["en"] as? String,
                      !english.trimmingCharacters(in: .whitespaces).isEmpty else {
                    throw CoreError.invalidData("Calendar occurrence has no source name")
                }
                for case let timing as [String: Any] in (row["timing"] as? [String: Any] ?? [:]).values {
                    guard let date = timing["date"] as? String, CivilDate(iso: date) != nil,
                          let start = (timing["fasting_start"] as? String).flatMap(ISO8601.instant),
                          let parana = (timing["parana_start"] as? String).flatMap(ISO8601.instant),
                          let end = (timing["parana_end"] as? String).flatMap(ISO8601.instant),
                          parana > start, end > parana else {
                        throw CoreError.invalidData("Invalid calendar occurrence timing")
                    }
                }
                var copy = row
                copy["id"] = nativeId
                copy["calendar_year"] = year
                combined.append(copy)
            }
        }
        rows = combined
        availableYears = years.sorted()
    }

    /// Occurrences for one schedule ([timezone] is an app code such as IST)
    /// and language, sorted by date; English where a translation is missing.
    public func ekadashis(timezone: String, language: String, year: Int? = nil) -> [EkadashiOccurrence] {
        let key = "\(timezone)_\(language)_\(year.map(String.init) ?? "all")"
        if let hit = cache.withLock({ $0[key] }) { return hit }
        var result: [EkadashiOccurrence] = []
        for row in rows {
            guard let timing = (row["timing"] as? [String: Any])?[timezone] as? [String: Any],
                  let dateText = timing["date"] as? String, let date = CivilDate(iso: dateText) else { continue }
            if let year, date.year != year { continue }
            let maps = ["name", "description", "story", "fasting_rules", "benefits"].map { row[$0] as? [String: String] ?? [:] }
            func text(_ map: [String: String], _ fallback: String = "") -> String { map[language] ?? map["en"] ?? fallback }
            let start = timing["fasting_start"] as? String ?? ""
            let parana = timing["parana_start"] as? String ?? ""
            let end = timing["parana_end"] as? String ?? ""
            let paksha = row["paksha"] as? String ?? ""
            let month = row["month"] as? String ?? ""
            func term(_ prefix: String, _ value: String) -> String {
                let key = prefix + value.lowercased()
                let translated = localizer.translate(key, language: language)
                return translated == key ? value : translated
            }
            result.append(EkadashiOccurrence(
                id: row["id"] as? Int ?? 0, occurrenceUid: row["occurrence_uid"] as? String, legacyId: row["legacy_id"] as? Int,
                contentId: row["content_id"] as? String ?? "", usesContentFallback: maps.contains { $0[language] == nil },
                name: text(maps[0]), date: date, fastStartTime: EkadashiTimeFormat.displayTime(start),
                fastBreakTime: EkadashiTimeFormat.window(parana, end), description: text(maps[1]),
                story: text(maps[2], "Story coming soon..."), fastingRules: text(maps[3], "Standard Ekadashi fasting rules apply."),
                benefits: text(maps[4], "Grants spiritual merit."), paksha: term("paksha_", paksha),
                month: term("lunar_month_", month), fastingStartISO: start, paranaStartISO: parana, paranaEndISO: end))
        }
        result.sort { $0.date < $1.date }
        cache.withLock { $0[key] = result }
        return result
    }
}
