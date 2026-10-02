import Foundation

// MARK: - Widget State Enum
public enum WidgetState: String, Codable {
    case beforeEkadashi = "BEFORE_EKADASHI"
    case fastingActive = "FASTING_ACTIVE"
    case paranaAvailable = "PARANA_AVAILABLE"
    case paranaCompleted = "PARANA_COMPLETED"
    case fallback = "FALLBACK"

    public var isFastingActive: Bool {
        return self == .fastingActive
    }

    public var isParanaAvailable: Bool {
        return self == .paranaAvailable
    }
}

// MARK: - Widget Metadata
public struct WidgetMetadata: Codable, Equatable {
    public let schemaVersion: Int
    public let dataVersion: String
    public let generatedAtUTC: String
    public let lastUpdatedAtUTC: String
    public let lastSuccessfulCalculationUTC: String?
    public let locale: String
    public let timezone: String
    public let locationName: String
    public let location: String?
    public let tradition: String?
    public let latitude: Double?
    public let longitude: Double?
    public let calculationVersion: String

    public init(
        schemaVersion: Int = 2,
        dataVersion: String = "2.0.0",
        generatedAtUTC: String,
        lastUpdatedAtUTC: String,
        lastSuccessfulCalculationUTC: String? = nil,
        locale: String = "en",
        timezone: String = "IST",
        locationName: String = "Chennai",
        location: String? = nil,
        tradition: String? = "General",
        latitude: Double? = nil,
        longitude: Double? = nil,
        calculationVersion: String = "v10.1"
    ) {
        self.schemaVersion = schemaVersion
        self.dataVersion = dataVersion
        self.generatedAtUTC = generatedAtUTC
        self.lastUpdatedAtUTC = lastUpdatedAtUTC
        self.lastSuccessfulCalculationUTC = lastSuccessfulCalculationUTC ?? lastUpdatedAtUTC
        self.locale = locale
        self.timezone = timezone
        self.locationName = locationName
        self.location = location ?? locationName
        self.tradition = tradition
        self.latitude = latitude
        self.longitude = longitude
        self.calculationVersion = calculationVersion
    }
}

// MARK: - Today Status (Widget B)
public struct TodayStatus: Codable, Equatable {
    public let isEkadashi: Bool
    public let name: String
    public let fastingStatus: String
    public let fastingStartUTC: String
    public let paranaStartUTC: String
    public let paranaEndUTC: String
    public let state: String

    public init(
        isEkadashi: Bool = false,
        name: String = "",
        fastingStatus: String = "No Ekadashi Today",
        fastingStartUTC: String = "",
        paranaStartUTC: String = "",
        paranaEndUTC: String = "",
        state: String = "NO_EKADASHI_TODAY"
    ) {
        self.isEkadashi = isEkadashi
        self.name = name
        self.fastingStatus = fastingStatus
        self.fastingStartUTC = fastingStartUTC
        self.paranaStartUTC = paranaStartUTC
        self.paranaEndUTC = paranaEndUTC
        self.state = state
    }

    public static var empty: TodayStatus {
        TodayStatus()
    }
}

// MARK: - Ekadashi Item
public struct EkadashiItem: Codable, Identifiable, Equatable {
    public let id: Int
    public let name: String
    public let localizedName: String
    public let date: String // YYYY-MM-DD
    public let localizedDate: String
    public let paksha: String // "Shukla" or "Krishna"
    public let month: String
    public let fastingStartUTC: String // ISO-8601 UTC
    public let fastingEndUTC: String   // ISO-8601 UTC
    public let paranaStartUTC: String  // ISO-8601 UTC
    public let paranaEndUTC: String    // ISO-8601 UTC
    public let targetTimestampUTC: String?
    public let countdownTarget: String?
    public let description: String?

    public init(
        id: Int,
        name: String,
        localizedName: String,
        date: String,
        localizedDate: String,
        paksha: String,
        month: String,
        fastingStartUTC: String,
        fastingEndUTC: String,
        paranaStartUTC: String,
        paranaEndUTC: String,
        targetTimestampUTC: String? = nil,
        countdownTarget: String? = nil,
        description: String? = nil
    ) {
        self.id = id
        self.name = name
        self.localizedName = localizedName
        self.date = date
        self.localizedDate = localizedDate
        self.paksha = paksha
        self.month = month
        self.fastingStartUTC = fastingStartUTC
        self.fastingEndUTC = fastingEndUTC
        self.paranaStartUTC = paranaStartUTC
        self.paranaEndUTC = paranaEndUTC
        self.targetTimestampUTC = targetTimestampUTC ?? fastingStartUTC
        self.countdownTarget = countdownTarget ?? targetTimestampUTC ?? fastingStartUTC
        self.description = description
    }

    // Robust Date Accessors
    private static let isoFormatterWithMillis: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatterStandard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    public static func parseUTC(_ string: String?) -> Date? {
        guard let string = string, !string.isEmpty else { return nil }
        if let d = isoFormatterWithMillis.date(from: string) { return d }
        if let d = isoFormatterStandard.date(from: string) { return d }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        if let d = df.date(from: string) { return d }

        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        if let d = df.date(from: string) { return d }

        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: string)
    }

    public var fastingStartDate: Date? { Self.parseUTC(fastingStartUTC) }
    public var fastingEndDate: Date? { Self.parseUTC(fastingEndUTC) }
    public var paranaStartDate: Date? { Self.parseUTC(paranaStartUTC) }
    public var paranaEndDate: Date? { Self.parseUTC(paranaEndUTC) }
    public var countdownTargetDate: Date? {
        if let target = countdownTarget, let d = Self.parseUTC(target) { return d }
        if let target = targetTimestampUTC, let d = Self.parseUTC(target) { return d }
        return fastingStartDate
    }

    /// Evaluates the real-time religious state at a specific point in time
    public func stateAt(date: Date) -> WidgetState {
        guard let fStart = fastingStartDate,
              let pStart = paranaStartDate,
              let pEnd = paranaEndDate else {
            return .beforeEkadashi
        }

        if date < fStart {
            return .beforeEkadashi
        } else if date >= fStart && date < pStart {
            return .fastingActive
        } else if date >= pStart && date <= pEnd {
            return .paranaAvailable
        } else {
            return .paranaCompleted
        }
    }
}

// MARK: - Root Widget Payload
public struct WidgetPayload: Codable, Equatable {
    public let metadata: WidgetMetadata
    public let currentState: WidgetState
    public let nextEkadashi: EkadashiItem?
    public let today: TodayStatus?
    public let upcomingEkadashis: [EkadashiItem]
    public let localizedStrings: [String: String]

    public init(
        metadata: WidgetMetadata,
        currentState: WidgetState,
        nextEkadashi: EkadashiItem?,
        today: TodayStatus? = nil,
        upcomingEkadashis: [EkadashiItem],
        localizedStrings: [String: String]
    ) {
        self.metadata = metadata
        self.currentState = currentState
        self.nextEkadashi = nextEkadashi
        self.today = today
        self.upcomingEkadashis = upcomingEkadashis
        self.localizedStrings = localizedStrings
    }

    public func localized(_ key: String, default defaultVal: String = "") -> String {
        return localizedStrings[key] ?? defaultVal
    }

    public static var fallback: WidgetPayload {
        WidgetPayload(
            metadata: WidgetMetadata(
                generatedAtUTC: ISO8601DateFormatter().string(from: Date()),
                lastUpdatedAtUTC: ISO8601DateFormatter().string(from: Date())
            ),
            currentState: .fallback,
            nextEkadashi: nil,
            today: TodayStatus.empty,
            upcomingEkadashis: [],
            localizedStrings: [
                "widget.title": "Ekadashi Calendar",
                "widget.open_app_to_refresh": "Open app to refresh timings",
                "widget.next_ekadashi": "NEXT EKADASHI",
                "widget.fasting_active": "Fasting Active",
                "widget.parana_available": "Break Fasting (Parana)",
                "widget.parana_completed": "Parana Completed"
            ]
        )
    }
}
