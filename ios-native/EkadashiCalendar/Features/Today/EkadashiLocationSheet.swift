import SwiftUI
import EkadashiCore

/// Where Home and Calendar calculate Ekadashis. Choosing a city here also
/// sets the Panchang location.
struct EkadashiLocationSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        CityPickerSheet(
            title: model.t("home_location_title"), footer: model.t("home_location_footer"),
            current: model.ekadashiCity, symbol: model.ekadashiCityIsManual ? AppSymbol.locationPicked : AppSymbol.locationDetected,
            pick: { model.chooseEkadashiCity($0) },
            locate: {
                await model.useCurrentLocationForEkadashis()
                if case .located = model.locationState { return nil }
                return model.location.isDenied ? "panchang_location_denied" : "panchang_location_unavailable"
            }) { EmptyView() }
    }
}

/// The one city picker of the app (Home and every Panchang sub-tab): the
/// current place, a worldwide search, "Use current location", then recent
/// picks and popular cities, every city with its time zone ("IST", "EDT",
/// "GMT"…). [extra] adds screen-specific sections at the end.
struct CityPickerSheet<Extra: View>: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let title: String
    let footer: String
    let current: PanchangCity
    let symbol: String
    let pick: (PanchangCity) -> Void
    /// Uses the device location; nil when done, else the message key to show.
    let locate: () async -> String?
    @ViewBuilder var extra: () -> Extra

    @State private var search = ""
    @State private var busy = false
    @State private var message: String?

    /// Before anything is typed: recent picks, then popular cities.
    private var shortlist: (recent: [PanchangCity], popular: [PanchangCity]) { RecentCities(store: model.store).shortlist() }

    /// Results for [search], found off the main thread (see [find]) so the
    /// keyboard never waits for the search.
    @State private var matches: [PanchangCity] = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: symbol).foregroundStyle(Theme.teal)
                        VStack(alignment: .leading) {
                            Text(model.cityDisplayName(current))
                            Text(current.timeZoneLabel(language: model.language)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("ekadashi_location_current")
                } footer: {
                    Text(footer)
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
                        Label(model.t(busy ? "panchang_locating" : "panchang_use_current_location"), systemImage: AppSymbol.useCurrentLocation)
                    }
                    .disabled(busy)
                    .accessibilityIdentifier("ekadashi_location_current_button")
                    if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
                }
                // No identifiers on these Sections: they would replace the
                // rows' ekadashi_city_<id> identifiers.
                if CitySearchIndex.query(search) == nil {
                    let list = shortlist
                    if !list.recent.isEmpty {
                        Section(model.t("recent_searches")) { ForEach(list.recent, id: \.self) { row($0) } }
                    }
                    Section(model.t("home_popular_cities")) { ForEach(list.popular, id: \.self) { row($0) } }
                }
                extra()
            }
            .scrollContentBackground(.hidden)
            // Prepares the names in the app language while the sheet opens.
            .task { await Self.index(model.language) }
            // A new keystroke cancels the search for the previous one.
            .task(id: search) { await find(search) }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // Same key as Android's city_picker_cancel.
                    Button(model.t("cancel")) { dismiss() }.accessibilityIdentifier("city_picker_cancel")
                }
            }
        }
        .glassSheetBackground()
    }

    private func row(_ city: PanchangCity) -> some View {
        Button {
            RecentCities(store: model.store).add(city)
            pick(city)
            dismiss()
        } label: {
            HStack {
                Text(model.cityDisplayName(city)).foregroundStyle(.primary)
                Spacer(minLength: 8)
                Text(city.timeZoneLabel(language: model.language)).font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("ekadashi_city_\(city.id)")
    }

    /// The language's search index, built off the main thread on first use.
    private static func index(_ language: String) async -> CitySearchIndex {
        await Task.detached(priority: .userInitiated) {
            PanchangCityCatalog.shared.searchIndex(language: language)
        }.value
    }

    /// Searches after a short pause in typing, off the main thread, and keeps
    /// only the answer for the text still in the field.
    private func find(_ text: String) async {
        guard CitySearchIndex.query(text) != nil else {
            matches = []
            return
        }
        try? await Task.sleep(for: .milliseconds(150))
        guard !Task.isCancelled else { return }
        let index = await Self.index(model.language)
        let found = await Task.detached(priority: .userInitiated) { index.search(text, limit: 20) }.value
        guard !Task.isCancelled, text == search else { return }
        matches = found
    }

    private func useCurrentLocation() async {
        busy = true
        message = nil
        defer { busy = false }
        if model.location.isDenied {
            message = model.t("panchang_location_denied")
            return
        }
        if let failure = await locate() {
            message = model.t(failure)
        } else {
            dismiss()
        }
    }
}
