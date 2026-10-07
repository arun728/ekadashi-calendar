import Foundation

public enum ObservanceStatus: String, Codable, CaseIterable, Sendable {
    case unrecorded, observed, partial, missed

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = ObservanceStatus.allCases.first { $0.rawValue.lowercased() == value.lowercased() } ?? .unrecorded
    }
}

public enum FastingMethod: String, Codable, CaseIterable, Sendable {
    case fullFast, waterOnly, fruitsMilk, oneMeal, other

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = FastingMethod.allCases.first { $0.rawValue.lowercased() == value.lowercased() } ?? .other
    }

    /// Translation key, e.g. `method_full_fast`.
    public var localizationKey: String {
        switch self {
        case .fullFast: return "method_full_fast"
        case .waterOnly: return "method_water_only"
        case .fruitsMilk: return "method_fruits_milk"
        case .oneMeal: return "method_one_meal"
        case .other: return "method_other"
        }
    }
}

/// A private devotional record of an Ekadashi observance (`VratHistory`),
/// stored in the same JSON shape as on Android.
public struct VratRecord: Codable, Equatable, Sendable {
    public var id: String
    public var localProfileId: String
    public var ekadashiOccurrenceId: Int
    public var occurrenceUid: String?
    public var ekadashiDate: String
    public var ekadashiName: String
    public var status: ObservanceStatus
    public var fastingMethod: FastingMethod?
    public var fastingMethodOther: String?
    public var note: String?
    public var recordedAtUTC: String
    public var updatedAtUTC: String
    public var tradition: String?
    public var timezone: String?
    public var locationContext: String?

    public init(id: String, localProfileId: String = "default", ekadashiOccurrenceId: Int, occurrenceUid: String? = nil,
                ekadashiDate: String, ekadashiName: String, status: ObservanceStatus, fastingMethod: FastingMethod? = nil,
                fastingMethodOther: String? = nil, note: String? = nil, recordedAtUTC: String, updatedAtUTC: String,
                tradition: String? = nil, timezone: String? = nil, locationContext: String? = nil) {
        self.id = id
        self.localProfileId = localProfileId
        self.ekadashiOccurrenceId = ekadashiOccurrenceId
        self.occurrenceUid = occurrenceUid
        self.ekadashiDate = ekadashiDate
        self.ekadashiName = ekadashiName
        self.status = status
        self.fastingMethod = fastingMethod
        self.fastingMethodOther = fastingMethodOther
        self.note = note
        self.recordedAtUTC = recordedAtUTC
        self.updatedAtUTC = updatedAtUTC
        self.tradition = tradition
        self.timezone = timezone
        self.locationContext = locationContext
    }

    enum CodingKeys: String, CodingKey {
        case id, localProfileId, ekadashiOccurrenceId, occurrenceUid, ekadashiDate, ekadashiName, status, fastingMethod
        case fastingMethodOther, note, recordedAtUTC, updatedAtUTC, tradition, timezone, locationContext
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let now = ISO8601.string(Date())
        self.init(id: try c.decodeIfPresent(String.self, forKey: .id) ?? "",
                  localProfileId: try c.decodeIfPresent(String.self, forKey: .localProfileId) ?? "default",
                  ekadashiOccurrenceId: try c.decodeIfPresent(Int.self, forKey: .ekadashiOccurrenceId) ?? 0,
                  occurrenceUid: try c.decodeIfPresent(String.self, forKey: .occurrenceUid),
                  ekadashiDate: try c.decodeIfPresent(String.self, forKey: .ekadashiDate) ?? "",
                  ekadashiName: try c.decodeIfPresent(String.self, forKey: .ekadashiName) ?? "",
                  status: try c.decodeIfPresent(ObservanceStatus.self, forKey: .status) ?? .unrecorded,
                  fastingMethod: (try? c.decodeIfPresent(String.self, forKey: .fastingMethod))
                    .flatMap { $0?.isEmpty == false ? $0 : nil }
                    .map { value in FastingMethod.allCases.first { $0.rawValue.lowercased() == value.lowercased() } ?? .other },
                  fastingMethodOther: try c.decodeIfPresent(String.self, forKey: .fastingMethodOther),
                  note: try c.decodeIfPresent(String.self, forKey: .note),
                  recordedAtUTC: try c.decodeIfPresent(String.self, forKey: .recordedAtUTC) ?? now,
                  updatedAtUTC: try c.decodeIfPresent(String.self, forKey: .updatedAtUTC) ?? now,
                  tradition: try c.decodeIfPresent(String.self, forKey: .tradition),
                  timezone: try c.decodeIfPresent(String.self, forKey: .timezone),
                  locationContext: try c.decodeIfPresent(String.self, forKey: .locationContext))
    }

    /// Android writes explicit nulls; so does iOS, for a byte-compatible export.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(localProfileId, forKey: .localProfileId)
        try c.encode(ekadashiOccurrenceId, forKey: .ekadashiOccurrenceId)
        try c.encode(occurrenceUid, forKey: .occurrenceUid)
        try c.encode(ekadashiDate, forKey: .ekadashiDate)
        try c.encode(ekadashiName, forKey: .ekadashiName)
        try c.encode(status, forKey: .status)
        try c.encode(fastingMethod, forKey: .fastingMethod)
        try c.encode(fastingMethodOther, forKey: .fastingMethodOther)
        try c.encode(note, forKey: .note)
        try c.encode(recordedAtUTC, forKey: .recordedAtUTC)
        try c.encode(updatedAtUTC, forKey: .updatedAtUTC)
        try c.encode(tradition, forKey: .tradition)
        try c.encode(timezone, forKey: .timezone)
        try c.encode(locationContext, forKey: .locationContext)
    }
}

/// A milestone definition. [symbol] is an SF Symbol matching the Android icon.
public struct Achievement: Equatable, Sendable, Identifiable {
    public enum Condition: String, Sendable { case count, streak, annualFull = "annual_full" }
    public let id: String
    public let titleKey: String
    public let descriptionKey: String
    public let condition: Condition
    public let targetValue: Int
    public let symbol: String
    public let sortOrder: Int
}

public struct UserAchievement: Codable, Equatable, Sendable {
    public var id: String
    public var localProfileId: String
    public var achievementId: String
    public var progressValue: Int
    public var isUnlocked: Bool
    public var unlockedAtUTC: String?
    public var lastEvaluatedAtUTC: String

    public init(id: String, localProfileId: String = "default", achievementId: String, progressValue: Int, isUnlocked: Bool,
                unlockedAtUTC: String?, lastEvaluatedAtUTC: String) {
        self.id = id
        self.localProfileId = localProfileId
        self.achievementId = achievementId
        self.progressValue = progressValue
        self.isUnlocked = isUnlocked
        self.unlockedAtUTC = unlockedAtUTC
        self.lastEvaluatedAtUTC = lastEvaluatedAtUTC
    }
}

public struct VratYearStats: Equatable, Sendable {
    public let year: Int
    public let totalOccurrences: Int
    public let observedCount: Int
    public let partialCount: Int
    public let missedCount: Int
    public let unrecordedCount: Int
    public let completionPercentage: Double
}
