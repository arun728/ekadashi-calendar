import SwiftUI
import EkadashiCore

/// Uses the bundled city index exclusively. No geocoding, current-location
/// permission, Home-city mutation or network request is needed for birthplace.
struct BirthPlaceSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let city: PanchangCity
    let pick: (PanchangCity) -> Void
    @State private var search = ""
    @State private var matches: [PanchangCity] = []
    @State private var name = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var zone = ""
    @State private var loaded = false
    private var candidate: PanchangCity? {
        guard let lat = Double(latitude.trimmingCharacters(in: .whitespaces)), let lon = Double(longitude.trimmingCharacters(in: .whitespaces)) else { return nil }
        let result = PanchangCity(id: "birth-custom", label: name.trimmingCharacters(in: .whitespaces), latitude: lat, longitude: lon,
                                  timeZoneId: zone.trimmingCharacters(in: .whitespaces))
        guard (try? result.validate()) != nil else { return nil }; return result
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(model.t("ios_birth_search"), text: $search).autocorrectionDisabled()
                        .accessibilityIdentifier("birth_city_search")
                    ForEach(search.isEmpty ? PanchangCity.supported : matches) { place in
                        Button {
                            pick(place); dismiss()
                        } label: {
                            VStack(alignment: .leading) {
                                Text(PlaceNames.shared.label(place.label, language: model.language))
                                Text(place.timeZoneId).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("birth_city_\(place.id)")
                    }
                }
                Section {
                    LabeledContent(model.t("ios_birth_place_name")) {
                        TextField(model.t("ios_birth_place_name"), text: $name)
                            .multilineTextAlignment(.trailing).accessibilityIdentifier("birth_manual_name")
                    }
                    LabeledContent(model.t("panchang_latitude")) {
                        TextField(model.t("panchang_latitude"), text: $latitude)
                            .keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing)
                    }
                    LabeledContent(model.t("panchang_longitude")) {
                        TextField(model.t("panchang_longitude"), text: $longitude)
                            .keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing)
                    }
                    LabeledContent(model.t("ios_birth_timezone")) {
                        TextField(model.t("ios_birth_timezone"), text: $zone)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                            .multilineTextAlignment(.trailing).accessibilityIdentifier("birth_manual_timezone")
                    }
                    Button(model.t("panchang_save_location")) {
                        guard let candidate else { return }; pick(candidate); dismiss()
                    }
                    .disabled(candidate == nil).accessibilityIdentifier("birth_manual_save")
                } header: { Text(model.t("ios_birth_manual")) } footer: { Text(model.t("ios_birth_range")) }
            }
            .navigationTitle(model.t("ios_birth_place"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(model.t("cancel")) { dismiss() } } }
            .task(id: search) {
                let query = search, language = model.language
                guard CitySearchIndex.query(query) != nil else { matches = []; return }
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                let found = await Task.detached(priority: .userInitiated) {
                    PanchangCityCatalog.shared.searchIndex(language: language).search(query, limit: 20)
                }.value
                guard !Task.isCancelled, query == search else { return }; matches = found
            }
            .onAppear {
                guard !loaded else { return }; loaded = true
                name = city.label; latitude = String(city.latitude); longitude = String(city.longitude); zone = city.timeZoneId
            }
        }
    }
}
