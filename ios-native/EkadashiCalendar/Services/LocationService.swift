import Foundation
import CoreLocation
import EkadashiCore

/// One-shot location for choosing the published schedule (LocationService.kt).
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
    static let cacheKey = "cached_location_v1"

    struct Fix: Codable, Equatable {
        let city: String
        let latitude: Double
        let longitude: Double
        let timezone: AppTimezone
        /// The place's IANA zone from reverse geocoding, when available.
        var zoneIdentifier: String?
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
    }

    var status: CLAuthorizationStatus { manager.authorizationStatus }
    var hasPermission: Bool { status == .authorizedWhenInUse || status == .authorizedAlways }
    var isDenied: Bool { status == .denied || status == .restricted }

    /// Asks once; iOS shows the dialog only while the status is undetermined.
    func requestPermission() async -> Bool {
        guard status == .notDetermined else { return hasPermission }
        let result = await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
        return result == .authorizedWhenInUse || result == .authorizedAlways
    }

    /// A fix within 15 seconds, named offline from the city catalog.
    func currentFix(store: KeyValueStore) async -> Fix? {
        guard hasPermission else { return nil }
        let location: CLLocation? = await withCheckedContinuation { continuation in
            finishLocation(nil)
            locationContinuation = continuation
            manager.requestLocation()
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                self?.finishLocation(nil)
            }
        }
        guard let location else { return nil }
        let lat = location.coordinate.latitude, lon = location.coordinate.longitude
        let nearest = PanchangCityCatalog.shared.nearest(latitude: lat, longitude: lon)
        var city = nearest?.label ?? ""
        let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
        if let name = placemark?.locality ?? placemark?.subAdministrativeArea ?? placemark?.administrativeArea {
            city = name
        } else if let range = city.range(of: " (") {
            city = String(city[..<range.lowerBound])
        }
        let fix = Fix(city: city, latitude: lat, longitude: lon, timezone: AppTimezone.detect(latitude: lat, longitude: lon),
                      zoneIdentifier: placemark?.timeZone?.identifier ?? nearest?.timeZoneId)
        if let data = try? JSONEncoder().encode(fix) { store.set(String(decoding: data, as: UTF8.self), forKey: Self.cacheKey) }
        return fix
    }

    /// The place at the coordinates named by Apple's geocoder in [language],
    /// for display; nil when it has none.
    func localizedName(latitude: Double, longitude: Double, language: String) async -> String? {
        let placemark = try? await CLGeocoder().reverseGeocodeLocation(
            CLLocation(latitude: latitude, longitude: longitude), preferredLocale: Localizer.locale(language)).first
        return placemark?.locality ?? placemark?.subAdministrativeArea ?? placemark?.administrativeArea
    }

    func cachedFix(store: KeyValueStore) -> Fix? {
        store.string(forKey: Self.cacheKey).flatMap { try? JSONDecoder().decode(Fix.self, from: Data($0.utf8)) }
    }

    private func finishLocation(_ location: CLLocation?) {
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard status != .notDetermined else { return }
            self.authorizationContinuation?.resume(returning: status)
            self.authorizationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in self.finishLocation(location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finishLocation(nil) }
    }
}
