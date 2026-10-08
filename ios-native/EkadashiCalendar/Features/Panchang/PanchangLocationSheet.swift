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
                    TextField(model.t("panchang_search_cities"), text: $search)
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
                        Label(model.t(busy ? "panchang_locating" : "panchang_use_current_location"), systemImage: "location")
                    }
                    .disabled(busy)
                    if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
                }
                Section {
                    TextField(model.t("panchang_location_name"), text: $name).accessibilityIdentifier("location_name")
                    TextField(model.t("panchang_latitude"), text: $latitude).keyboardType(.numbersAndPunctuation)
                        .accessibilityIdentifier("location_latitude")
                    TextField(model.t("panchang_longitude"), text: $longitude).keyboardType(.numbersAndPunctuation)
                        .accessibilityIdentifier("location_longitude")
                    TextField(model.t("panchang_timezone"), text: $zone).autocorrectionDisabled().textInputAutocapitalization(.never)
                        .accessibilityIdentifier("location_timezone")
                } footer: {
                    Text(model.t("panchang_location_footer"))
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(model.t("panchang_location_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(model.t("cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.t("panchang_save_location")) {
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
            message = model.t("panchang_location_denied")
            return
        }
        guard let fix = await model.location.currentFix(store: model.store) else {
            message = model.t("panchang_location_unavailable")
            return
        }
        name = fix.city
        latitude = String(fix.latitude)
        longitude = String(fix.longitude)
        zone = fix.zoneIdentifier ?? TimeZone.current.identifier
        message = model.t("panchang_location_received")
    }
}
