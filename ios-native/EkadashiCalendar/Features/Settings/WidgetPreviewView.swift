import SwiftUI
import WidgetKit
import EkadashiCore

/// Real schedule and clock, using the same two renderers as WidgetKit.
struct WidgetPreviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var kind = PreviewKind.single
    @State private var size = PreviewSize.medium

    private enum PreviewKind: String { case single, upcoming }
    private enum PreviewSize: String, CaseIterable {
        case small, medium, large, lock
        var key: String { "widget_size_\(rawValue)" }
        var family: WidgetFamily {
            switch self {
            case .small: return .systemSmall
            case .medium: return .systemMedium
            case .large: return .systemLarge
            case .lock: return .accessoryRectangular
            }
        }
    }

    private var sizes: [PreviewSize] { kind == .single ? [.small, .medium, .lock] : [.medium, .large] }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = context.date
            let snapshot = WidgetSnapshot.build(occurrences: model.ekadashis, timezone: model.ekadashiCity.timeZoneId,
                locationName: model.ekadashiCityName, language: model.language, now: now, tradition: model.tradition.rawValue)
            ScrollView {
                VStack(spacing: 20) {
                    Picker(model.t("widget_preview"), selection: $kind) {
                        Text(model.t("widget_name_ekadashi")).tag(PreviewKind.single)
                        Text(model.t("upcoming_ekadashis")).tag(PreviewKind.upcoming)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("widget_preview_kind")
                    Text(model.t(kind == .single ? "ios_widget_desc_ekadashi" : "ios_widget_desc_next"))
                        .font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Picker(model.t("widget_preview"), selection: $size) {
                        ForEach(sizes, id: \.self) { value in
                            Text(model.t(value.key)).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("widget_preview_size")
                    if model.isCalculating {
                        ProgressView().tint(Theme.teal)
                    } else {
                        preview(snapshot, now: now)
                        Text(model.t("widget_preview_tap")).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
        }
        .onChange(of: kind) { _, _ in
            if !sizes.contains(size) { size = .medium }
        }
        .background(AppBackground())
        .navigationTitle(model.t("widget_preview"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func open(_ item: WidgetItem) { model.open(.ekadashi(item.occurrenceUid)) }

    @ViewBuilder
    private func preview(_ snapshot: WidgetSnapshot, now: Date) -> some View {
        if kind == .upcoming {
            UpcomingEkadashiWidgetView(snapshot: snapshot, now: now, family: size.family, onSelect: open)
                .padding(16).frame(maxWidth: 360).frame(height: size == .large ? 368 : 170)
                .background(WidgetCardBackground())
                .clipShape(.rect(cornerRadius: 24))
        } else if let headline = snapshot.headline(at: now) {
            VStack(spacing: 20) {
                single(snapshot, headline: headline, now: now, appearance: scheme)
                if size != .lock {
                    single(snapshot, headline: headline, now: now, appearance: scheme == .dark ? .light : .dark)
                }
            }
        } else {
            ContentUnavailableView(model.t("widget_no_next"), systemImage: AppSymbol.widgetPreview)
        }
    }

    private func single(_ snapshot: WidgetSnapshot, headline: WidgetHeadline, now: Date, appearance: ColorScheme) -> some View {
        Button { open(headline.item) } label: {
            Group {
                if size == .lock {
                    HStack(spacing: 16) {
                        EkadashiWidgetView(snapshot: snapshot, now: now, family: .accessoryCircular)
                            .frame(width: 62, height: 62)
                        EkadashiWidgetView(snapshot: snapshot, now: now, family: .accessoryRectangular)
                            .frame(maxWidth: .infinity).frame(height: 62)
                    }
                    .padding(16).frame(maxWidth: 360).frame(height: 100)
                    .background(WidgetStyle.color(WidgetPalette.charcoal))
                    .environment(\.colorScheme, .dark).tint(.white).foregroundStyle(.white)
                } else {
                    EkadashiWidgetView(snapshot: snapshot, now: now, family: size.family)
                        .padding(16).frame(maxWidth: size == .small ? 170 : 360)
                        .frame(height: 170)
                        .background(WidgetCardBackground()).environment(\.colorScheme, appearance)
                }
            }
            .clipShape(.rect(cornerRadius: 24))
            .contentShape(.rect(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("widget_preview_open")
        .accessibilityLabel("\(headline.item.name)\n\(headline.item.localizedDate)\n\(model.t("start_fasting")): \(WidgetText(snapshot: snapshot).time(headline.item.fastingStart))\n\(model.t("break_fasting")): \(WidgetText(snapshot: snapshot).date(headline.item.paranaStart)), \(WidgetText(snapshot: snapshot).window(headline.item.paranaStart, headline.item.paranaEnd))")
        .accessibilityHint(model.t("widget_preview_tap"))
    }
}
