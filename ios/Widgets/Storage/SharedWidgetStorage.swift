import Foundation

public enum CacheStatus: String {
    case valid = "VALID"
    case stale = "STALE"
    case invalid = "INVALID"
    case corrupted = "CORRUPTED"
    case unavailable = "UNAVAILABLE"

    public var canDisplay: Bool {
        return self == .valid || self == .stale
    }
}

public final class SharedWidgetStorage {
    public static let shared = SharedWidgetStorage()

    // Configurable App Group Identifier
    public static let appGroupIdentifier = "group.com.applausestudios.ekadashicalendar"
    private static let storageKey = "ekadashi_widget_payload_v2"
    private static let lastSaveTimeKey = "ekadashi_widget_last_save_time"
    private static let expectedSchemaVersion = 2
    private static let maxCacheAgeSeconds: TimeInterval = 14 * 24 * 60 * 60 // 14 days

    private let userDefaults: UserDefaults?

    public init(suiteName: String = SharedWidgetStorage.appGroupIdentifier) {
        self.userDefaults = UserDefaults(suiteName: suiteName)
        if self.userDefaults == nil {
            NSLog("⚠️ SharedWidgetStorage: Failed to initialize UserDefaults with suite: %@", suiteName)
        }
    }

    // MARK: - Save Function
    @discardableResult
    public func savePayload(_ payload: WidgetPayload) -> Bool {
        guard let defaults = userDefaults else {
            NSLog("❌ SharedWidgetStorage: UserDefaults suite unavailable during save.")
            return false
        }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(payload)
            defaults.set(data, forKey: Self.storageKey)
            defaults.set(Date().timeIntervalSince1970, forKey: Self.lastSaveTimeKey)
            defaults.synchronize()
            NSLog("✅ SharedWidgetStorage: Successfully persisted widget payload (size: %d bytes).", data.count)
            return true
        } catch {
            NSLog("❌ SharedWidgetStorage: JSON encoding error: %@", error.localizedDescription)
            return false
        }
    }

    // MARK: - Read Function
    public func loadPayload() -> (payload: WidgetPayload?, status: CacheStatus) {
        guard let defaults = userDefaults else {
            return (WidgetPayload.fallback, .unavailable)
        }

        guard let data = defaults.data(forKey: Self.storageKey) else {
            if let seeded = seedFromBundledData() {
                savePayload(seeded)
                return (seeded, .valid)
            }
            return (WidgetPayload.fallback, .unavailable)
        }

        do {
            let decoder = JSONDecoder()
            let payload = try decoder.decode(WidgetPayload.self, from: data)

            // 1. Validate Schema Version
            guard payload.metadata.schemaVersion == Self.expectedSchemaVersion else {
                NSLog("⚠️ SharedWidgetStorage: Schema version mismatch. Expected %d, got %d",
                      Self.expectedSchemaVersion, payload.metadata.schemaVersion)
                return (WidgetPayload.fallback, .invalid)
            }

            // 2. Validate Metadata Fields
            guard !payload.metadata.generatedAtUTC.isEmpty,
                  !payload.metadata.lastUpdatedAtUTC.isEmpty,
                  !payload.metadata.timezone.isEmpty,
                  !payload.metadata.locationName.isEmpty,
                  !payload.metadata.calculationVersion.isEmpty else {
                NSLog("⚠️ SharedWidgetStorage: Missing required metadata fields")
                return (WidgetPayload.fallback, .invalid)
            }

            // 3. Validate Next Ekadashi Required Fields and Chronological Order (if present)
            if let next = payload.nextEkadashi {
                guard next.id > 0,
                      !next.name.isEmpty,
                      !next.date.isEmpty,
                      let fStart = next.fastingStartDate,
                      let pStart = next.paranaStartDate,
                      let pEnd = next.paranaEndDate else {
                    NSLog("⚠️ SharedWidgetStorage: Missing or invalid required fields in nextEkadashi")
                    return (WidgetPayload.fallback, .invalid)
                }

                // Verify timestamp validity: fastingStart <= paranaStart <= paranaEnd
                guard fStart <= pStart && pStart <= pEnd else {
                    NSLog("⚠️ SharedWidgetStorage: Invalid chronological timestamp sequence")
                    return (WidgetPayload.fallback, .invalid)
                }
            }

            // 4. Check Cache Freshness
            let lastSave = defaults.double(forKey: Self.lastSaveTimeKey)
            if lastSave > 0 {
                let age = Date().timeIntervalSince1970 - lastSave
                if age > Self.maxCacheAgeSeconds {
                    NSLog("⚠️ SharedWidgetStorage: Cache is stale (age: %.1f hours).", age / 3600.0)
                    return (payload, .stale)
                }
            }

            return (payload, .valid)
        } catch {
            NSLog("❌ SharedWidgetStorage: JSON decode error (corrupted data): %@", error.localizedDescription)
            return (WidgetPayload.fallback, .corrupted)
        }
    }

    // MARK: - Clear / Invalidation
    public func clearPayload() {
        guard let defaults = userDefaults else { return }
        defaults.removeObject(forKey: Self.storageKey)
        defaults.removeObject(forKey: Self.lastSaveTimeKey)
        defaults.synchronize()
        NSLog("ℹ️ SharedWidgetStorage: Cache cleared.")
    }

    private func seedFromBundledData() -> WidgetPayload? {
        let possibleUrls = [
            Bundle.main.url(forResource: "flutter_assets/assets/ekadashi_data", withExtension: "json"),
            Bundle.main.url(forResource: "ekadashi_data", withExtension: "json")
        ]

        for url in possibleUrls.compactMap({ $0 }) {
            do {
                let data = try Data(contentsOf: url)
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let ekadashisArray = json["ekadashis"] as? [[String: Any]] else {
                    continue
                }

                let now = Date()
                let targetTz = "IST"
                var nextItem: EkadashiItem?
                var upcomingList: [EkadashiItem] = []

                for (idx, ekDict) in ekadashisArray.enumerated() {
                    let id = ekDict["id"] as? Int ?? (idx + 1)
                    let names = ekDict["name"] as? [String: String] ?? [:]
                    let name = names["en"] ?? "Ekadashi"
                    let paksha = ekDict["paksha"] as? String ?? ""
                    let month = ekDict["month"] as? String ?? ""

                    guard let timingMap = ekDict["timing"] as? [String: Any],
                          let tzTiming = (timingMap[targetTz] ?? timingMap["IST"]) as? [String: Any] else {
                        continue
                    }

                    let dateStr = tzTiming["date"] as? String ?? ""
                    let fStart = tzTiming["fasting_start"] as? String ?? ""
                    let pStart = tzTiming["parana_start"] as? String ?? ""
                    let pEnd = tzTiming["parana_end"] as? String ?? ""

                    let item = EkadashiItem(
                        id: id,
                        name: name,
                        localizedName: name,
                        date: dateStr,
                        localizedDate: dateStr,
                        paksha: paksha,
                        month: month,
                        fastingStartUTC: fStart,
                        fastingEndUTC: pStart,
                        paranaStartUTC: pStart,
                        paranaEndUTC: pEnd,
                        targetTimestampUTC: fStart,
                        countdownTarget: fStart
                    )

                    if let pEndDate = item.paranaEndDate, now < pEndDate {
                        if nextItem == nil {
                            nextItem = item
                        } else if upcomingList.count < 10 {
                            upcomingList.append(item)
                        }
                    }
                }

                if let next = nextItem {
                    let nowIso = ISO8601DateFormatter().string(from: now)
                    let meta = WidgetMetadata(
                        schemaVersion: 2,
                        dataVersion: "2.0.0",
                        generatedAtUTC: nowIso,
                        lastUpdatedAtUTC: nowIso,
                        timezone: targetTz,
                        locationName: "India (IST)"
                    )
                    let payload = WidgetPayload(
                        metadata: meta,
                        currentState: next.stateAt(date: now),
                        nextEkadashi: next,
                        today: TodayStatus(
                            isEkadashi: false,
                            name: next.name,
                            fastingStatus: "Upcoming",
                            fastingStartUTC: next.fastingStartUTC,
                            paranaStartUTC: next.paranaStartUTC,
                            paranaEndUTC: next.paranaEndUTC,
                            state: "BEFORE_EKADASHI"
                        ),
                        upcomingEkadashis: upcomingList,
                        localizedStrings: [
                            "widget.title": "Ekadashi Calendar",
                            "widget.next_ekadashi": "NEXT EKADASHI",
                            "widget.fasting_active": "Fasting Active",
                            "widget.parana_available": "Break Fasting (Parana)",
                            "widget.parana_completed": "Parana Completed",
                            "widget.upcoming_ekadashis": "Upcoming Ekadashis"
                        ]
                    )
                    NSLog("✅ [SharedWidgetStorage] Seeded initial widget payload from bundle asset: %@", url.lastPathComponent)
                    return payload
                }
            } catch {
                NSLog("⚠️ [SharedWidgetStorage] Bundled seed error: %@", error.localizedDescription)
            }
        }
        return nil
    }
}

