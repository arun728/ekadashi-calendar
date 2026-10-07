import Foundation

public struct PanchangLimb: Equatable, Sendable {
    public let index: Int
    public let name: String
    public let endsAt: Date?
    public let paksha: String?

    public init(index: Int, name: String, endsAt: Date?, paksha: String? = nil) {
        self.index = index
        self.name = name
        self.endsAt = endsAt
        self.paksha = paksha
    }
}

public struct PanchangObservance: Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let ruleSource: String
    public let description: String
    public let isMajor: Bool
}

public struct PanchangPeriod: Equatable, Sendable {
    public let name: String
    public let start: Date
    public let end: Date
}

/// The sequence of one limb from sunrise to the next sunrise.
public struct PanchangLimbTimeline: Equatable, Sendable {
    public let name: String
    public let limbs: [PanchangLimb]
}

public struct PanchangDay: Sendable {
    /// Calendar date at the selected location.
    public let date: CivilDate
    public let city: PanchangCity
    public let sunrise: Date?
    public let sunset: Date?
    public let moonrise: Date?
    public let moonset: Date?
    public let nextSunrise: Date?
    public let tithi: PanchangLimb
    public let nakshatra: PanchangLimb
    public let yoga: PanchangLimb
    public let karana: PanchangLimb
    public let vara: String
    public let amantaMonth: String
    public let purnimantaMonth: String
    public let isAdhikaMonth: Bool
    public let rahukala: PanchangPeriod?
    public let yamaganda: PanchangPeriod?
    public let gulika: PanchangPeriod?
    public let abhijit: PanchangPeriod?
    public let brahmaMuhurta: PanchangPeriod?
    public let choghadiya: [PanchangPeriod]
    public let hora: [PanchangPeriod]
    public let additionalPeriods: [PanchangPeriod]
    public let lagna: [PanchangPeriod]
    public let specialYogas: [String]
    public let nakshatraPada: Int
    public let ayanamsa: Double
    public let ritu: String
    public let ayana: String
    public let sunRashi: String
    public let moonRashi: String
    public let sunRashiEndsAt: Date?
    public let moonRashiEndsAt: Date?
    public let padaEndsAt: Date?
    public let anandadiYoga: String
    public let shakaYear: Int
    public let vikramaYear: Int
    public let limbTimeline: [PanchangLimbTimeline]
    public let observances: [PanchangObservance]
}

/// Time with a day marker for events outside the selected civil day and the
/// zone abbreviation/offset, so repeated DST wall times stay distinguishable
/// (`formatPanchangTime` in panchang_models.dart).
public func formatPanchangTime(_ instant: Date?, city: PanchangCity, date: CivilDate) -> String {
    guard let instant else { return "—" }
    let local = city.wallClock(instant)
    let delta = date.days(until: local.date)
    let suffix = delta == 0 ? "" : " (\(delta > 0 ? "+" : "")\(delta) day)"
    let hour = local.hour % 12 == 0 ? 12 : local.hour % 12
    let offset = local.offsetSeconds / 60
    let offsetText = (offset < 0 ? "-" : "+") + pad2(abs(offset) / 60) + ":" + pad2(abs(offset) % 60)
    return "\(hour):\(pad2(local.minute)) \(local.hour < 12 ? "AM" : "PM") \(local.abbreviation) (UTC\(offsetText))\(suffix)"
}

/// `Weekday, Month d, yyyy`, English as the Panchang tab.
public func formatPanchangDate(_ date: CivilDate) -> String {
    let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September",
                  "October", "November", "December"]
    return "\(weekdays[date.weekday - 1]), \(months[date.month - 1]) \(date.day), \(date.year)"
}
