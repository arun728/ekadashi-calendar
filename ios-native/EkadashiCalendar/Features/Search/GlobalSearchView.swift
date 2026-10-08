import SwiftUI
import EkadashiCore

/// One search for the whole app (docs/ROADMAP.md Phase 1): Ekadashis,
/// Panchang festivals and observances, custom and Google calendar entries,
/// and app screens. The year filter comes first, then the type chips. Only
/// an explicit submission is saved to recent searches, never live typing.
struct GlobalSearchView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [SearchItem] = []
    @State private var suggestions: [String] = []
    @State private var recents: [String] = []
    @State private var category: SearchCategory?
    @State private var year: Int?
    @State private var index: UnifiedSearch?
    @State private var loadingObservances = false
    @State private var debounce: Task<Void, Never>?
    @State private var showPaywall = false
    @State private var pushed: SearchItem?

    private var hasInput: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || category != nil || year != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            filters
            content
        }
        .background(AppBackground())
        .navigationTitle(model.t("search"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: model.t("search_hint_all")) {
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
            if loadingObservances {
                ToolbarItem(placement: .primaryAction) { ProgressView().tint(Theme.teal) }
            }
        }
        .navigationDestination(item: $pushed) { item in destination(item) }
        .sheet(isPresented: $showPaywall) {
            NavigationStack { PremiumView(reason: nil) }
        }
        .onAppear {
            recents = model.recents.all()
            if index == nil { build() }
        }
        .onChange(of: model.entriesRevision) { _, _ in build() }
        .onChange(of: model.language) { _, _ in build() }
    }

    // MARK: Filters

    private var filters: some View {
        ScrollView(.horizontal) {
            GlassGroup(spacing: 8) {
                HStack(spacing: 8) {
                    Menu {
                        Button(model.t("search_all_years")) { year = nil; run() }
                        ForEach(model.repository?.availableYears ?? [], id: \.self) { value in
                            Button(String(value)) { year = value; run() }
                        }
                    } label: {
                        Label(year.map(String.init) ?? model.t("year"), systemImage: "calendar")
                            .font(.subheadline.weight(year == nil ? .regular : .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    }
                    .tint(year == nil ? .primary : Theme.teal)
                    .glassPanel(cornerRadius: 18)
                    .accessibilityIdentifier("search_year_selector")
                    GlassChip(title: model.t("filter_all"), systemImage: "square.grid.2x2", selected: category == nil) {
                        category = nil
                        run()
                    }
                    ForEach(SearchCategory.filters, id: \.self) { type in
                        GlassChip(title: model.t(type.localizationKey), systemImage: type.symbol, color: Theme.hex(type.colorHex),
                                  selected: category == type) {
                            category = category == type ? nil : type
                            run()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search_categories_tube")
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if !hasInput {
            start
        } else if results.isEmpty {
            ContentUnavailableView {
                Label(model.t("no_results_found"), systemImage: "magnifyingglass")
            } description: {
                Text(model.t("search_no_results_hint"))
            }
        } else {
            List(results) { item in
                Button { open(item) } label: { SearchResultRow(item: item, locked: isLocked(item)) }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("search_results")
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
                Text(model.t("search_start_all")).font(.headline)
                FlowLayout(spacing: 8) {
                    ForEach(SearchCategory.filters, id: \.self) { type in
                        GlassChip(title: model.t(type.localizationKey), systemImage: type.symbol, color: Theme.hex(type.colorHex),
                                  selected: false) {
                            category = type
                            run()
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

    /// Ekadashis, entries and screens at once; festivals follow when the
    /// Panchang calculation for the data years is ready.
    private func build() {
        index = model.searchIndex()
        run()
        loadingObservances = true
        Task {
            let observances = await model.searchObservances()
            index = model.searchIndex(observances: observances)
            loadingObservances = false
            run()
        }
    }

    private func changed(_ value: String) {
        debounce?.cancel()
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            suggestions = []
            recents = model.recents.all()
            run()
            return
        }
        suggestions = index?.suggestions(trimmed, limit: 5) ?? []
        // Live results after 200 ms; never saved to recent searches.
        debounce = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            run()
        }
    }

    private func submit(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        debounce?.cancel()
        query = clean
        suggestions = []
        run()
        model.recents.add(clean)
        recents = model.recents.all()
    }

    private func run() {
        results = index?.search(query, category: category, year: year, today: model.today) ?? []
    }

    // MARK: Opening results

    private func isLocked(_ item: SearchItem) -> Bool { item.requiresPremium && !model.premium.isPremium }

    private func open(_ item: SearchItem) {
        if isLocked(item) {
            showPaywall = true
            return
        }
        switch item.target {
        case .ekadashi, .observance, .widgetPreview:
            pushed = item
        case .entry(_, let date):
            model.open(.calendar(date))
        case .tab(let tab):
            model.open(.tab(tab))
        case .paywall:
            showPaywall = true
        }
    }

    @ViewBuilder
    private func destination(_ item: SearchItem) -> some View {
        switch item.target {
        case .ekadashi(let uid):
            if let event = model.ekadashis.first(where: { $0.occurrenceUid == uid }) {
                EkadashiDetailsView(event: event)
            }
        case .observance(_, let date):
            PanchangView(initialDate: date, initialCity: model.panchangCity)
                .background(AppBackground())
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
        case .widgetPreview:
            WidgetPreviewView()
        default:
            EmptyView()
        }
    }
}

struct SearchResultRow: View {
    @Environment(AppModel.self) private var model
    let item: SearchItem
    let locked: Bool

    /// Festivals show as festivals even when they are also, say, a Purnima.
    private var category: SearchCategory {
        item.categories.contains(.festival) ? .festival : item.categories.first ?? .screen
    }

    var body: some View {
        let color = Theme.hex(category.colorHex)
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: category.symbol)
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.headline).lineLimit(2)
                if locked {
                    Label(model.t("search_premium_locked"), systemImage: "lock.fill")
                        .font(.caption).foregroundStyle(Theme.amber)
                } else if let date = item.date {
                    Text(model.format(date, "EEE, d MMM yyyy")).font(.subheadline).foregroundStyle(.secondary)
                }
                Text(model.t(category.localizationKey)).font(.caption2.weight(.semibold)).foregroundStyle(color)
            }
            Spacer(minLength: 8)
            Image(systemName: locked ? "lock.fill" : "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(locked ? Theme.amber : Color.secondary)
        }
        .padding(12)
        .contentShape(Rectangle())
        .glassPanel(cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("search_result_\(item.id)")
    }
}
