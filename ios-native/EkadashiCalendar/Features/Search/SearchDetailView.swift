import SwiftUI
import EkadashiCore

/// A curated search result: katha, mantra, food, vrat rules, festival,
/// temple or event (search_detail_screen.dart).
struct SearchDetailView: View {
    @Environment(AppModel.self) private var model
    let result: SearchResult
    let download: () -> Void

    private var entry: SearchIndexEntry { result.entry }
    private var color: Color { Theme.hex(entry.contentType.colorHex) }

    /// Section titles and metadata keys per content type; lists show as bullets.
    private var sections: [(String, String)] {
        switch entry.contentType {
        case .katha: return [("story_history", "full_story"), ("story_history", "source")]
        case .mantra: return [("search_transliteration", "transliteration"), ("search_meaning", "meaning"),
                              ("spiritual_benefits", "benefits"), ("story_history", "source")]
        case .food: return [("category_food", "items"), ("search_ingredients", "ingredients"), ("search_steps", "steps"),
                            ("search_rules", "guidelines"), ("significance", "reason")]
        case .vratInfo: return [("search_rules", "key_rules"), ("search_stages", "stages"), ("search_levels", "levels"),
                                ("significance", "importance")]
        case .festival: return [("significance", "significance"), ("search_rules", "rituals")]
        case .temple: return [("search_location", "location"), ("search_deity", "deity"), ("category_temple", "highlights")]
        case .event: return [("search_location", "location"), ("category_event", "highlights"), ("significance", "description")]
        case .all, .ekadashi: return []
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    StatusPill(text: model.t(entry.contentType.localizationKey), systemImage: entry.contentType.symbol, color: color)
                    if model.searchIndex.isDownloaded(entry) {
                        StatusPill(text: model.t("downloaded"), systemImage: "checkmark.circle", color: Theme.teal)
                    } else {
                        StatusPill(text: model.t("online_only"), systemImage: "icloud", color: .secondary)
                    }
                }
                Text(entry.title).font(.title.bold())
                if let sanskrit = entry.metadataString("sanskrit"), !sanskrit.isEmpty {
                    Text(sanskrit).font(.title3).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .glassPanel(cornerRadius: 16, tint: color)
                }
                if entry.contentType != .katha || entry.metadata["full_story"]?.text == nil {
                    Text(entry.description).font(.body).lineSpacing(5)
                }
                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    if let text = entry.metadata[section.1]?.text, !text.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(model.t(section.0)).font(.headline).foregroundStyle(Theme.teal)
                            Text(text).font(.body).lineSpacing(4)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassPanel(cornerRadius: 16)
                    }
                }
                if !model.searchIndex.isDownloaded(entry) {
                    Button(action: download) {
                        Label(model.t("download"), systemImage: "arrow.down.circle").frame(maxWidth: .infinity).padding(.vertical, 4)
                    }
                    .primaryActionStyle()
                }
            }
            .padding(20)
        }
        .background(AppBackground())
        .navigationTitle(model.t(entry.contentType.localizationKey))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: "\(entry.title)\n\n\(entry.description)") { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel(model.t("share"))
            }
        }
    }
}
