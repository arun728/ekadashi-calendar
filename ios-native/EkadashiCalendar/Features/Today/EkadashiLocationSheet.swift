import SwiftUI
import EkadashiCore

/// Where Home and Calendar calculate Ekadashis: search the offline
/// worldwide city list (as on the Panchang tab) or use the current location.
/// Choosing a city here also sets the Panchang location.
struct EkadashiLocationSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var busy = false
    @State private var message: String?

    /// Before anything is typed: recent picks, then popular cities.
    private var shortlist: (recent: [PanchangCity], popular: [PanchangCity]) { RecentCities(store: model.store).shortlist() }

    private var matches: [PanchangCity] {
        let q = search.trimmingCharacters(in: .whitespaces)
        return q.count < 2 ? [] : PanchangCityCatalog.shared.search(q, language: model.language, limit: 20)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: model.ekadashiCityIsManual ? "mappin.and.ellipse" : "location.fill")
                            .foregroundStyle(Theme.teal)
                        VStack(alignment: .leading) {
                            Text(model.ekadashiCityName)
                            Text(model.timeZoneLabel).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("ekadashi_location_current")
                } footer: {
                    Text(model.t("home_location_footer"))
                }
                Section {
                    TextField(model.t("panchang_search_cities"), text: $search)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("ekadashi_location_search")
                    ForEach(matches, id: \.self) { row($0) }
                    Button {
                        Task { await useCurrentLocation() }
                    } label: {
                        Label(model.t(busy ? "panchang_locating" : "panchang_use_current_location"), systemImage: "location")
                    }
                    .disabled(busy)
                    .accessibilityIdentifier("ekadashi_location_current_button")
                    if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
                }
                if search.trimmingCharacters(in: .whitespaces).count < 2 {
                    let list = shortlist
                    if !list.recent.isEmpty {
                        Section(model.t("recent_searches")) { ForEach(list.recent, id: \.self) { row($0) } }
                            .accessibilityIdentifier("ekadashi_location_recent")
                    }
                    Section(model.t("home_popular_cities")) { ForEach(list.popular, id: \.self) { row($0) } }
                        .accessibilityIdentifier("ekadashi_location_popular")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(model.t("home_location_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(model.t("cancel")) { dismiss() } }
            }
        }
        .presentationBackground(.thinMaterial)
    }

    private func row(_ city: PanchangCity) -> some View {
        Button {
            model.chooseEkadashiCity(city)
            dismiss()
        } label: {
            VStack(alignment: .leading) {
                Text(PlaceNames.shared.label(city.label, language: model.language)).foregroundStyle(.primary)
                Text(city.timeZoneLabel(language: model.language)).font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("ekadashi_city_\(city.id)")
    }

    private func useCurrentLocation() async {
        busy = true
        message = nil
        defer { busy = false }
        if model.location.isDenied {
            message = model.t("panchang_location_denied")
            return
        }
        await model.useCurrentLocationForEkadashis()
        if case .located = model.locationState {
            dismiss()
        } else {
            message = model.t(model.location.isDenied ? "panchang_location_denied" : "panchang_location_unavailable")
        }
    }
}
