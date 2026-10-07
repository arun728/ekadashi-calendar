import SwiftUI
import EkadashiCore

/// Search the offline worldwide city list, use the current location, or
/// enter coordinates and an IANA timezone (panchang_location_dialog.dart).
struct PanchangLocationSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let city: PanchangCity
    let save: (PanchangCity) -> Void

    @State private var search = ""
    @State private var name = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var zone = ""
    @State private var message: String?
    @State private var busy = false
    @State private var loaded = false

    private var matches: [PanchangCity] {
        let q = search.trimmingCharacters(in: .whitespaces)
        return q.count < 2 ? [] : PanchangCityCatalog.shared.search(q, limit: 12)
    }

    private var candidate: PanchangCity? {
        guard let lat = Double(latitude.trimmingCharacters(in: .whitespaces)),
              let lon = Double(longitude.trimmingCharacters(in: .whitespaces)) else { return nil }
        let city = PanchangCity(id: "custom", label: name.trimmingCharacters(in: .whitespaces), latitude: lat, longitude: lon,
                                timeZoneId: zone.trimmingCharacters(in: .whitespaces))
        return (try? city.validate()) == nil ? nil : city
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Search cities worldwide", text: $search)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                    ForEach(matches, id: \.self) { item in
                        Button { select(item) } label: {
                            VStack(alignment: .leading) {
                                Text(item.label).foregroundStyle(.primary)
                                Text(item.timeZoneId).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button {
                        Task { await useCurrentLocation() }
                    } label: {
                        Label(busy ? "Locating…" : "Use current location", systemImage: "location")
                    }
                    .disabled(busy)
                    if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
                }
                Section {
                    TextField("Location name", text: $name).accessibilityIdentifier("location_name")
                    TextField("Latitude", text: $latitude).keyboardType(.numbersAndPunctuation)
                        .accessibilityIdentifier("location_latitude")
                    TextField("Longitude", text: $longitude).keyboardType(.numbersAndPunctuation)
                        .accessibilityIdentifier("location_longitude")
                    TextField("IANA timezone", text: $zone).autocorrectionDisabled().textInputAutocapitalization(.never)
                        .accessibilityIdentifier("location_timezone")
                } footer: {
                    Text("Example: Asia/Kolkata or America/New_York\n\nCity data: GeoNames · CC BY 4.0. Calculations and city search work offline.")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Panchang location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save location") {
                        guard let candidate else { return }
                        save(candidate)
                        dismiss()
                    }
                    .disabled(candidate == nil || busy)
                }
            }
        }
        .presentationBackground(.thinMaterial)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            name = city.label
            latitude = String(city.latitude)
            longitude = String(city.longitude)
            zone = city.timeZoneId
        }
    }

    private func select(_ item: PanchangCity) {
        name = item.label
        latitude = String(item.latitude)
        longitude = String(item.longitude)
        zone = item.timeZoneId
        search = ""
    }

    private func useCurrentLocation() async {
        busy = true
        message = nil
        defer { busy = false }
        guard await model.location.requestPermission() else {
            message = "Location permission denied. Search or enter a location instead."
            return
        }
        guard let fix = await model.location.currentFix(store: model.store) else {
            message = "Location unavailable. Search or enter a location instead."
            return
        }
        name = fix.city
        latitude = String(fix.latitude)
        longitude = String(fix.longitude)
        zone = fix.zoneIdentifier ?? TimeZone.current.identifier
        message = "Coordinates received. Check the timezone before saving; the device timezone may differ from this location."
    }
}
