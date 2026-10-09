import Foundation

/// Explicit coordinates and IANA time zone; never the device time zone.
public struct PanchangCity: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let label: String
    public let latitude: Double
    public let longitude: Double
    public let timeZoneId: String
    public let searchTerms: String

    public init(id: String, label: String, latitude: Double, longitude: Double,
                timeZoneId: String = "Asia/Kolkata", searchTerms: String = "") {
        self.id = id
        self.label = label
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneId = timeZoneId
        self.searchTerms = searchTerms
    }

    enum CodingKeys: String, CodingKey { case id, label, latitude, longitude, timeZoneId = "timezone" }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decode(String.self, forKey: .id), label: try c.decode(String.self, forKey: .label),
                  latitude: try c.decode(Double.self, forKey: .latitude), longitude: try c.decode(Double.self, forKey: .longitude),
                  timeZoneId: try c.decode(String.self, forKey: .timeZoneId))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(label, forKey: .label)
        try c.encode(latitude, forKey: .latitude)
        try c.encode(longitude, forKey: .longitude)
        try c.encode(timeZoneId, forKey: .timeZoneId)
    }

    public static func == (a: PanchangCity, b: PanchangCity) -> Bool {
        a.id == b.id && a.latitude == b.latitude && a.longitude == b.longitude && a.timeZoneId == b.timeZoneId && a.label == b.label
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(latitude)
        hasher.combine(longitude)
        hasher.combine(timeZoneId)
        hasher.combine(label)
    }

    /// The bundled IANA location (UTC if the zone is unknown; use [validate]).
    public var zone: TzLocation { TzDatabase.shared.location(timeZoneId) ?? TzLocation.utc }

    public func validate() throws {
        guard latitude.isFinite, abs(latitude) <= 90, longitude.isFinite, abs(longitude) <= 180,
              !label.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw CoreError.invalidArgument("Invalid location coordinates or name")
        }
        guard timeZoneId.contains("/") || timeZoneId == "UTC" else {
            throw CoreError.invalidArgument("Use an IANA timezone such as Asia/Kolkata")
        }
        guard TzDatabase.shared.location(timeZoneId) != nil else {
            throw CoreError.invalidArgument("Unknown timezone: \(timeZoneId)")
        }
    }

    public func wallClock(_ instant: Date) -> WallClock { zone.wallClock(instant) }
    public func midnight(_ date: CivilDate, dayOffset: Int = 0) -> Date { zone.utc(date.adding(days: dayOffset)) }
    public func dateAtHour(_ date: CivilDate, _ hour: Int) -> Date { zone.utc(date, hour: hour) }
    public var timezoneLabel: String { timeZoneId == "Asia/Kolkata" ? "IST" : timeZoneId }

    /// The time zone as [language] shows it: the IANA id in English, the UTC
    /// offset now in the language's script otherwise.
    public func timeZoneLabel(language: String, now: Date = Date()) -> String {
        guard language != "en", let zone = TimeZone(identifier: timeZoneId) else { return timezoneLabel }
        return Localizer.shared.utcOffset(minutes: zone.secondsFromGMT(for: now) / 60, language: language)
    }
    /// Today's civil date at this location.
    public func today(now: Date = Date()) -> CivilDate { wallClock(now).date }

    public static let newDelhi = PanchangCity(id: "new-delhi", label: "New Delhi", latitude: 28.6139, longitude: 77.2090)
    public static let mumbai = PanchangCity(id: "mumbai", label: "Mumbai", latitude: 19.0760, longitude: 72.8777)
    public static let chennai = PanchangCity(id: "chennai", label: "Chennai", latitude: 13.0827, longitude: 80.2707)
    public static let kolkata = PanchangCity(id: "kolkata", label: "Kolkata", latitude: 22.5726, longitude: 88.3639)
    public static let bengaluru = PanchangCity(id: "bengaluru", label: "Bengaluru", latitude: 12.9716, longitude: 77.5946)
    public static let hyderabad = PanchangCity(id: "hyderabad", label: "Hyderabad", latitude: 17.3850, longitude: 78.4867)
    public static let pune = PanchangCity(id: "pune", label: "Pune", latitude: 18.5204, longitude: 73.8567)
    public static let varanasi = PanchangCity(id: "varanasi", label: "Varanasi", latitude: 25.3176, longitude: 82.9739)
    public static let london = PanchangCity(id: "london", label: "London", latitude: 51.5074, longitude: -0.1278,
                                            timeZoneId: "Europe/London")
    public static let newYork = PanchangCity(id: "new-york", label: "New York", latitude: 40.7128, longitude: -74.006,
                                             timeZoneId: "America/New_York")
    public static let sydney = PanchangCity(id: "sydney", label: "Sydney", latitude: -33.8688, longitude: 151.2093,
                                            timeZoneId: "Australia/Sydney")

    public static let supported: [PanchangCity] = [newDelhi, mumbai, chennai, kolkata, bengaluru, hyderabad, pune,
                                                   varanasi, london, newYork, sydney]
}

/// GeoNames cities15000 (CC BY 4.0), the same offline catalog as Android.
public final class PanchangCityCatalog: @unchecked Sendable {
    public static let shared = PanchangCityCatalog()
    private let cache = Locked<[PanchangCity]?>(nil)

    public func cities() throws -> [PanchangCity] {
        if let cached = cache.withLock({ $0 }) { return cached }
        guard let rows = try JSONSerialization.jsonObject(with: CoreResources.data("panchang/cities.json")) as? [[Any]] else {
            throw CoreError.invalidData("Unreadable city catalog")
        }
        let cities = rows.compactMap { row -> PanchangCity? in
            guard row.count >= 7, let id = row[0] as? String, let name = row[1] as? String, let ascii = row[2] as? String,
                  let country = row[3] as? String, let lat = (row[4] as? NSNumber)?.doubleValue,
                  let lon = (row[5] as? NSNumber)?.doubleValue, let zone = row[6] as? String else { return nil }
            return PanchangCity(id: "geonames-\(id)", label: "\(name) (\(country))", latitude: lat, longitude: lon,
                                timeZoneId: zone, searchTerms: "\(name) \(ascii) \(country)".lowercased())
        }
        cache.withLock { $0 = cities }
        return cities
    }

    /// The closest catalog city, for naming a location fix without a network.
    public func nearest(latitude: Double, longitude: Double) -> PanchangCity? {
        guard let all = try? cities() else { return nil }
        let rad = Double.pi / 180
        func distance(_ city: PanchangCity) -> Double {
            let dLat = (city.latitude - latitude) * rad, dLon = (city.longitude - longitude) * rad
            let a = sin(dLat / 2) * sin(dLat / 2) + cos(latitude * rad) * cos(city.latitude * rad) * sin(dLon / 2) * sin(dLon / 2)
            return a
        }
        return all.min { distance($0) < distance($1) }
    }

    /// Matches names, ASCII names and country codes, as the Android picker,
    /// and names typed in the app [language].
    public func search(_ query: String, language: String = "en", limit: Int = 12) -> [PanchangCity] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard q.count >= 2, let all = try? cities() else { return [] }
        var result: [PanchangCity] = []
        let names = PlaceNames.shared
        for city in all where "\(city.label.lowercased()) \(city.searchTerms) \(names.label(city.label, language: language))".contains(q) {
            result.append(city)
            if result.count >= limit { break }
        }
        return result
    }
}

/// The Panchang location saved on this phone (Android key `panchang_location`).
public struct PanchangLocationStore {
    public static let key = "panchang_location"
    let store: KeyValueStore
    public init(store: KeyValueStore) { self.store = store }

    public func load() -> PanchangCity? {
        guard let raw = store.string(forKey: Self.key),
              let city = try? JSONDecoder().decode(PanchangCity.self, from: Data(raw.utf8)),
              (try? city.validate()) != nil else { return nil }
        return city
    }

    public func save(_ city: PanchangCity) throws {
        let data = try JSONEncoder().encode(city)
        guard store.set(String(decoding: data, as: UTF8.self), forKey: Self.key) else {
            throw CoreError.storage("Could not save Panchang location")
        }
    }
}
