import Foundation

extension PanchangCityCatalog {
    /// Cities offered before anything is typed: where most users live, in
    /// India first, then the diaspora (GeoNames ids from cities.json).
    public static let popularIds = [
        "1264527", "1261481", "1275339", "1277333", "1269843", "1275004", "1259229", "1279233", "1253405", "1269515",
        "5128581", "5097529", "5368361", "5391959", "4887398", "4699066", "5809844", "4180439", "4140963",
        "6167865", "6173331", "2643743", "2925533", "2988507", "292223", "290030", "1880252", "1735161",
        "2147714", "2158177", "2063523", "2193733", "993800", "184745", "1283240", "1248991", "934154",
    ]

    /// The popular cities, in the order above.
    public func popular() -> [PanchangCity] {
        guard let all = try? cities() else { return [] }
        let byId = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return Self.popularIds.compactMap { byId["geonames-\($0)"] }
    }
}

/// The cities picked on Home, newest first (at most [limit]), shown above
/// the popular cities so a place can be chosen again without typing.
public struct RecentCities {
    public static let key = "ekadashi_recent_cities"
    public static let limit = 8
    let store: KeyValueStore
    public init(store: KeyValueStore) { self.store = store }

    public func all() -> [PanchangCity] {
        guard let raw = store.string(forKey: Self.key),
              let cities = try? JSONDecoder().decode([PanchangCity].self, from: Data(raw.utf8)) else { return [] }
        return cities.filter { (try? $0.validate()) != nil }
    }

    public func add(_ city: PanchangCity) {
        var list = all().filter { $0.id != city.id || $0.latitude != city.latitude || $0.longitude != city.longitude }
        list.insert(city, at: 0)
        if let data = try? JSONEncoder().encode(Array(list.prefix(Self.limit))) {
            store.set(String(decoding: data, as: UTF8.self), forKey: Self.key)
        }
    }

    /// What the search shows with an empty query: recent picks, then popular
    /// cities not already among them. Never empty.
    public func shortlist(catalog: PanchangCityCatalog = .shared) -> (recent: [PanchangCity], popular: [PanchangCity]) {
        let recent = all()
        let ids = Set(recent.map(\.id))
        return (recent, catalog.popular().filter { !ids.contains($0.id) })
    }
}
