import SwiftUI
import EkadashiCore

/// The Panchang location, for every sub-tab: the same picker as Home
/// (search, current location, recent and popular cities with their time
/// zones), plus coordinates and an IANA timezone entered by hand.
/// Choosing here does not move Home's Ekadashi city.
struct PanchangLocationSheet: View {
    @Environment(AppModel.self) private var model
    let city: PanchangCity
    let save: (PanchangCity) -> Void

    var body: some View {
        CityPickerSheet(
            title: model.t("panchang_location_title"), footer: "", current: city, symbol: AppSymbol.panchangCity,
            pick: save,
            locate: {
                guard await model.location.requestPermission() else { return "panchang_location_denied" }
                guard let fix = await model.location.currentFix(store: model.store),
                      let place = AppModel.city(from: fix) else { return "panchang_location_unavailable" }
                RecentCities(store: model.store).add(place)
                save(place)
                return nil
            }) {
            ManualCoordinatesSection(city: city, save: save)
        }
    }
}

/// Coordinates and an IANA timezone typed by hand (panchang_location_dialog.dart).
private struct ManualCoordinatesSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let city: PanchangCity
    let save: (PanchangCity) -> Void
    @State private var name = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var zone = ""
    @State private var loaded = false

    private var candidate: PanchangCity? {
        guard let lat = Double(latitude.trimmingCharacters(in: .whitespaces)),
              let lon = Double(longitude.trimmingCharacters(in: .whitespaces)) else { return nil }
        let city = PanchangCity(id: "custom", label: name.trimmingCharacters(in: .whitespaces), latitude: lat, longitude: lon,
                                timeZoneId: zone.trimmingCharacters(in: .whitespaces))
        return (try? city.validate()) == nil ? nil : city
    }

    var body: some View {
        Section {
            TextField(model.t("panchang_location_name"), text: $name).accessibilityIdentifier("location_name")
            TextField(model.t("panchang_latitude"), text: $latitude).keyboardType(.numbersAndPunctuation)
                .accessibilityIdentifier("location_latitude")
            TextField(model.t("panchang_longitude"), text: $longitude).keyboardType(.numbersAndPunctuation)
                .accessibilityIdentifier("location_longitude")
            TextField(model.t("panchang_timezone"), text: $zone).autocorrectionDisabled().textInputAutocapitalization(.never)
                .accessibilityIdentifier("location_timezone")
            Button(model.t("panchang_save_location")) {
                guard let candidate else { return }
                save(candidate)
                dismiss()
            }
            .disabled(candidate == nil)
            .accessibilityIdentifier("location_save_coordinates")
        } footer: {
            Text(model.t("panchang_location_footer"))
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            name = city.label
            latitude = String(city.latitude)
            longitude = String(city.longitude)
            zone = city.timeZoneId
        }
    }
}
