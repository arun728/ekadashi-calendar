import Foundation

/// The published Ekadashi schedules (assets/calendar), one per region.
public enum AppTimezone: String, CaseIterable, Codable, Sendable {
    case ist = "IST", est = "EST", cst = "CST", mst = "MST", pst = "PST"

    public var ianaIdentifier: String {
        switch self {
        case .ist: return "Asia/Kolkata"
        case .est: return "America/New_York"
        case .cst: return "America/Chicago"
        case .mst: return "America/Denver"
        case .pst: return "America/Los_Angeles"
        }
    }

    public var location: TzLocation { TzDatabase.shared.location(ianaIdentifier)! }

    /// IANA id for an app code; other strings are returned unchanged.
    public static func iana(_ code: String) -> String { AppTimezone(rawValue: code)?.ianaIdentifier ?? code }

    /// The schedule closest to the device time zone, when location is
    /// unavailable (`getDeviceAppTimezone` in ekadashi_service.dart).
    public static func matching(deviceIdentifier zone: String) -> AppTimezone {
        let direct: [String: AppTimezone] = [
            "Asia/Kolkata": .ist, "Asia/Calcutta": .ist,
            "America/New_York": .est, "America/Detroit": .est, "America/Toronto": .est,
            "America/Indiana/Indianapolis": .est, "America/Kentucky/Louisville": .est,
            "America/Chicago": .cst, "America/Winnipeg": .cst, "America/Mexico_City": .cst,
            "America/Denver": .mst, "America/Edmonton": .mst, "America/Phoenix": .mst, "America/Boise": .mst,
            "America/Los_Angeles": .pst, "America/Vancouver": .pst, "America/Tijuana": .pst,
        ]
        if let match = direct[zone] { return match }
        if zone.hasPrefix("America/") {
            if ["New_York", "Detroit", "Toronto", "Indiana", "Kentucky"].contains(where: zone.contains) { return .est }
            if ["Chicago", "Winnipeg", "Mexico"].contains(where: zone.contains) { return .cst }
            if ["Denver", "Phoenix", "Edmonton", "Boise"].contains(where: zone.contains) { return .mst }
            if ["Los_Angeles", "Vancouver", "Seattle", "Portland"].contains(where: zone.contains) { return .pst }
        }
        return .ist
    }

    public struct City: Hashable, Sendable, Identifiable {
        public let id: String
        public let name: String
        public let country: String
        public let timezone: AppTimezone
    }

    public var cities: [City] {
        let rows: [(String, String)]
        switch self {
        case .ist:
            rows = [("chennai", "Chennai"), ("mumbai", "Mumbai"), ("delhi", "Delhi"), ("kolkata", "Kolkata"),
                    ("bangalore", "Bangalore"), ("hyderabad", "Hyderabad"), ("pune", "Pune"), ("ahmedabad", "Ahmedabad"),
                    ("jaipur", "Jaipur"), ("lucknow", "Lucknow")]
        case .est:
            rows = [("new_york", "New York"), ("boston", "Boston"), ("newark", "Newark (NJ)"), ("philadelphia", "Philadelphia"),
                    ("atlanta", "Atlanta"), ("miami", "Miami"), ("washington_dc", "Washington DC")]
        case .cst:
            rows = [("chicago", "Chicago"), ("houston", "Houston"), ("dallas", "Dallas"), ("san_antonio", "San Antonio"),
                    ("austin", "Austin")]
        case .mst:
            rows = [("denver", "Denver"), ("phoenix", "Phoenix"), ("albuquerque", "Albuquerque"),
                    ("salt_lake_city", "Salt Lake City")]
        case .pst:
            rows = [("los_angeles", "Los Angeles"), ("san_francisco", "San Francisco"), ("san_jose", "San Jose"),
                    ("seattle", "Seattle"), ("portland", "Portland")]
        }
        return rows.map { City(id: $0.0, name: $0.1, country: self == .ist ? "India" : "United States", timezone: self) }
    }

    public static var citiesByCountry: [String: [City]] { Dictionary(grouping: allCases.flatMap(\.cities), by: \.country) }
    public static func city(id: String) -> City? { allCases.flatMap(\.cities).first { $0.id == id } }
    public static func timezone(forCity id: String) -> AppTimezone { city(id: id)?.timezone ?? .ist }
}
