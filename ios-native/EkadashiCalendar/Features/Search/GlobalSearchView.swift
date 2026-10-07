import SwiftUI
import EkadashiCore

/// Global search over Ekadashis, kathas, mantras, food, vrat rules,
/// festivals, temples and events (global_search_screen.dart). Only an
/// explicit submission is saved to recent searches, never live typing.
struct GlobalSearchView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var submitted = ""
    @State private var active = ""
    @State private var results: [SearchResult] = []
    @State private var suggestions: [String] = []
    @State private var recents: [String] = []
    @State private var category: SearchContentType = .all
    @State private var year: Int?
    @State private var contentLanguage: String?
    @State private var offline = false
    @State private var index: SearchIndex?
    @State private var debounce: Task<Void, Never>?
    @State private var toast: ToastMessage?

    private var language: String { contentLanguage ?? model.language }

    var body: some View {
        VStack(spacing: 0) {
            if offline {
                Label(model.t("offline_indicator"), systemImage: "bolt.horizontal.circle")
                    .font(.caption).foregroundStyle(Theme.amber)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 6)
            }
            filters
            categories
            content
        }
        .background(AppBackground())
        .navigationTitle(model.t("search"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: model.t("search_hint")) {
            ForEach(suggestions, id: \.self) { suggestion in
                Text(suggestion).searchCompletion(suggestion)
            }
        }
        .onSubmit(of: .search) { submit(query) }
        .onChange(of: query) { _, value in changed(value) }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: { Image(systemName: "chevron.down") }
                    .accessibilityIdentifier("global_search_back")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    offline.toggle()
                    rerun()
                } label: {
                    Image(systemName: offline ? "wifi.slash" : "wifi").foregroundStyle(offline ? Theme.amber : .secondary)
                }
                .accessibilityLabel(model.t(offline ? "offline_mode" : "online_mode"))
            }
        }
        .navigationDestination(for: SearchRoute.self) { route in
            switch route {
            case .ekadashi(let event): EkadashiDetailsView(event: event)
            case .detail(let box): SearchDetailView(result: box.result) { download(box.result) }
            }
        }
        .toast($toast)
        .onAppear {
            recents = model.recents.all()
            if index == nil { rebuild() }
        }
    }

    // MARK: Filters

    private var filters: some View {
        HStack(spacing: 12) {
            Menu {
                Button(model.t("filter_all")) { year = nil; rerun() }
                ForEach(Array(Set(model.ekadashis.map(\.date.year))).sorted(), id: \.self) { value in
                    Button(String(value)) { year = value; rerun() }
                }
            } label: {
                Label(year.map(String.init) ?? model.t("year"), systemImage: "calendar")
            }
            .accessibilityIdentifier("search_year_selector")
            Menu {
                ForEach(Localizer.languages, id: \.self) { code in
                    Button(Localizer.displayName(code)) {
                        contentLanguage = code
                        rebuild()
                    }
                }
            } label: {
                Label(Localizer.displayName(language), systemImage: "globe")
            }
            .accessibilityIdentifier("search_language_selector")
            Spacer()
        }
        .font(.subheadline.weight(.medium))
        .tint(Theme.teal)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search_filters_tube")
    }

    private var categories: some View {
        ScrollView(.horizontal) {
            GlassGroup(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(SearchContentType.allCases, id: \.self) { type in
                        GlassChip(title: model.t(type.localizationKey), systemImage: type.symbol, color: Theme.hex(type.colorHex),
                                  selected: category == type) {
                            guard category != type else { return }
                            category = type
                            if !active.isEmpty { run(active, save: false) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search_categories_tube")
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if active.isEmpty {
            start
        } else if results.isEmpty {
            ContentUnavailableView {
                Label("\(model.t("no_results_found")) \"\(submitted.isEmpty ? active : submitted)\"", systemImage: "magnifyingglass")
            } description: {
                Text(model.t(offline ? "no_offline_results" : "try_searching"))
            }
        } else {
            List(results) { result in
                NavigationLink(value: route(result)) { SearchResultRow(result: result, available: isAvailable(result)) }
                    .swipeActions {
                        if !isAvailable(result) {
                            Button(model.t("download")) { download(result) }.tint(Theme.teal)
                        }
                    }
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private var start: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !recents.isEmpty {
                    HStack {
                        Text(model.t("recent_searches").uppercased()).font(.caption.bold()).foregroundStyle(.secondary)
                        Spacer()
                        Button(model.t("clear_all")) {
                            model.recents.clear()
                            recents = []
                        }
                        .font(.caption)
                    }
                    ForEach(recents, id: \.self) { term in
                        HStack {
                            Button { submit(term) } label: {
                                Label(term, systemImage: "clock.arrow.circlepath").foregroundStyle(.primary)
                            }
                            Spacer()
                            Button {
                                model.recents.remove(term)
                                recents = model.recents.all()
                            } label: {
                                Image(systemName: "xmark").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Text(model.t("search_start")).font(.headline)
                FlowLayout(spacing: 8) {
                    ForEach(SearchContentType.allCases.filter { $0 != .all }, id: \.self) { type in
                        GlassChip(title: model.t(type.localizationKey), systemImage: type.symbol, color: Theme.hex(type.colorHex),
                                  selected: false) {
                            category = type
                            submit(model.t(type.localizationKey))
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("search_explore_tube")
            }
            .padding(16)
        }
    }

    // MARK: Searching

    private func rebuild() {
        let built = SearchIndex(downloaded: Set(model.store.stringArray(forKey: "ec2_downloaded_content_ids") ?? []))
        let events = model.repository?.ekadashis(timezone: model.timezone.rawValue, language: language) ?? model.ekadashis
        built.build(ekadashis: events, language: language)
        index = built
        rerun()
    }

    private func changed(_ value: String) {
        debounce?.cancel()
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            active = ""
            submitted = ""
            results = []
            suggestions = []
            recents = model.recents.all()
            return
        }
        suggestions = index?.suggestions(trimmed, limit: 5) ?? []
        // Live results after 250 ms; never saved to recent searches.
        debounce = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            run(trimmed, save: false)
        }
    }

    private func submit(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        debounce?.cancel()
        query = clean
        run(clean, save: true)
    }

    private func run(_ text: String, save: Bool) {
        active = text
        suggestions = []
        results = index?.search(text, filter: category, languageCode: language, year: year, offline: offline) ?? []
        if save {
            submitted = text
            model.recents.add(text)
            recents = model.recents.all()
        }
    }

    private func rerun() { if !active.isEmpty { run(active, save: false) } }

    private func isAvailable(_ result: SearchResult) -> Bool { index?.isDownloaded(result.entry) ?? true }

    private func download(_ result: SearchResult) {
        model.markDownloaded(result.id)
        index?.markDownloaded(result.id)
        toast = ToastMessage(text: model.t("saved_offline"))
        rerun()
    }

    private func route(_ result: SearchResult) -> SearchRoute {
        if result.entry.contentType == .ekadashi {
            let events = model.ekadashis
            if let event = events.first(where: { "ekadashi_\($0.id)" == result.id || String($0.id) == result.id
                || $0.name.lowercased() == result.title.lowercased() }) ?? events.first {
                return .ekadashi(event)
            }
        }
        return .detail(SearchResultBox(result: result))
    }
}

enum SearchRoute: Hashable {
    case ekadashi(EkadashiOccurrence)
    case detail(SearchResultBox)
}

/// A search result as a navigation value, identified by its entry id.
struct SearchResultBox: Hashable {
    let result: SearchResult
    static func == (a: SearchResultBox, b: SearchResultBox) -> Bool { a.result.id == b.result.id }
    func hash(into hasher: inout Hasher) { hasher.combine(result.id) }
}

struct SearchResultRow: View {
    @Environment(AppModel.self) private var model
    let result: SearchResult
    let available: Bool

    var body: some View {
        let type = result.entry.contentType
        let color = Theme.hex(type.colorHex)
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: type.symbol).foregroundStyle(color).frame(width: 36, height: 36)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    StatusPill(text: model.t(type.localizationKey), color: color)
                    if !available { StatusPill(text: model.t("online_only"), systemImage: "icloud", color: .secondary) }
                }
                Text(result.title).font(.headline).lineLimit(2)
                Text(result.snippet).font(.caption).foregroundStyle(.secondary).lineLimit(3)
            }
        }
        .padding(12)
        .glassPanel(cornerRadius: 16)
    }
}
