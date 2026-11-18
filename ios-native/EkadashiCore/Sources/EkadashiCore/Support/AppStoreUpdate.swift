import Foundation

/// Reads the public App Store catalog for the user's storefront.
public enum AppStoreUpdate {
    private struct Lookup: Decodable {
        var results: [Listing]
    }

    private struct Listing: Decodable {
        var version: String
        var minimumOsVersion: String
        var bundleId: String
        var trackId: Int
    }

    public static func lookupURL(appID: String, storefrontCode: String) -> URL? {
        guard Int(appID).map({ $0 > 0 }) == true,
              let country = Locale(identifier: "en_\(storefrontCode)").region?.identifier, country.count == 2,
              Locale.Region.isoRegions.contains(Locale.Region(country)) else { return nil }
        var url = URLComponents()
        url.scheme = "https"
        url.host = "itunes.apple.com"
        url.path = "/lookup"
        url.queryItems = [URLQueryItem(name: "id", value: appID), URLQueryItem(name: "country", value: country.lowercased())]
        return url.url
    }

    public static func availableVersion(in data: Data, appID: String, bundleID: String,
                                        installedVersion: String, systemVersion: String) -> String? {
        guard let catalog = try? JSONDecoder().decode(Lookup.self, from: data),
              let listing = catalog.results.first(where: { $0.bundleId == bundleID && $0.trackId == Int(appID) }),
              let installed = compare(installedVersion, listing.version), installed == .orderedAscending,
              let system = compare(systemVersion, listing.minimumOsVersion), system != .orderedAscending else { return nil }
        return listing.version
    }

    private static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult? {
        func components(_ version: String) -> [Int]? {
            let pieces = version.split(separator: ".", omittingEmptySubsequences: false)
            guard !pieces.isEmpty, pieces.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } })
            else { return nil }
            let numbers = pieces.compactMap { Int($0) }
            return numbers.count == pieces.count ? numbers : nil
        }
        guard let left = components(lhs), let right = components(rhs) else { return nil }
        for index in 0..<max(left.count, right.count) {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a != b { return a < b ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }
}
