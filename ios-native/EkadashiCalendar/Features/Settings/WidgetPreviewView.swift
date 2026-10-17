import SwiftUI
import WidgetKit
import EkadashiCore

/// Live schedule previews, never a simulated clock or a fabricated occurrence.
/// The same renderer is used by the extension; navigation keeps this screen's
/// Back path instead of jumping to an unrelated Home card.
struct WidgetPreviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var selection: WidgetSelection?
    @State private var size = PreviewSize.medium

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

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = context.date
            let snapshot = WidgetSnapshot.build(occurrences: model.ekadashis, timezone: model.ekadashiCity.timeZoneId,
                locationName: model.ekadashiCityName, language: model.language, now: now, tradition: model.tradition.rawValue)
            let chosen = selection ?? (snapshot.headline(at: now)?.isToday == true ? .today : .next)
            ScrollView {
                VStack(spacing: 20) {
                    Picker(model.t("widget_preview"), selection: Binding(get: { chosen }, set: { selection = $0 })) {
                        Text(model.t("today")).tag(WidgetSelection.today).accessibilityIdentifier("widget_preview_today")
                        Text(model.t("next_ekadashi")).tag(WidgetSelection.next).accessibilityIdentifier("widget_preview_next")
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("widget_preview_state")
                    Picker(model.t("widget_preview"), selection: $size) {
                        ForEach(PreviewSize.allCases, id: \.self) { value in
                            Text(model.t(value.key)).tag(value).accessibilityIdentifier("widget_preview_size_\(value.rawValue)")
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("widget_preview_size")
                    if model.isCalculating {
                        ProgressView().tint(Theme.teal)
                    } else if let headline = snapshot.headline(at: now, selection: chosen),
                       let event = model.ekadashis.first(where: { $0.occurrenceUid == headline.item.occurrenceUid }) {
                        GeometryReader { geometry in
                            let width = min(360, geometry.size.width)
                            VStack(spacing: 20) {
                                preview(snapshot, headline: headline, event: event, now: now, chosen: chosen, width: width, appearance: scheme)
                                if size != .lock {
                                    preview(snapshot, headline: headline, event: event, now: now, chosen: chosen, width: width,
                                            appearance: scheme == .dark ? .light : .dark)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .frame(height: previewStackHeight)
                        Text(model.t("widget_preview_tap")).font(.footnote).foregroundStyle(.secondary)
                    } else {
                        ContentUnavailableView {
                            Label(model.t(chosen == .today ? "no_ekadashi" : "widget_no_next"), systemImage: AppSymbol.widgetPreview)
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(AppBackground())
        .navigationTitle(model.t("widget_preview"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var previewStackHeight: CGFloat {
        switch size {
        case .small: return 360
        case .medium: return 360
        case .large: return 780
        case .lock: return 130
        }
    }

    private func preview(_ snapshot: WidgetSnapshot, headline: WidgetHeadline, event: EkadashiOccurrence,
                         now: Date, chosen: WidgetSelection, width: CGFloat, appearance: ColorScheme) -> some View {
        NavigationLink {
            EkadashiDetailsView(event: event)
        } label: {
            Group {
                if size == .lock {
                    HStack(spacing: 20) {
                        EkadashiWidgetView(snapshot: snapshot, now: now, family: .accessoryCircular, selection: chosen)
                            .frame(width: 64, height: 64)
                        EkadashiWidgetView(snapshot: snapshot, now: now, family: .accessoryRectangular, selection: chosen)
                            .frame(maxWidth: .infinity).frame(height: 64)
                    }
                    .padding(16).frame(width: width, height: 100)
                    .background(WidgetStyle.color(WidgetPalette.charcoal))
                    .environment(\.colorScheme, .dark)
                    .tint(.white)
                    .foregroundStyle(.white)
                } else {
                    EkadashiWidgetView(snapshot: snapshot, now: now, family: size.family, selection: chosen)
                        .padding(16)
                        .frame(width: size == .small ? 170 : width, height: size == .large ? 368 : 170)
                        .background(WidgetCardBackground())
                        .environment(\.colorScheme, appearance)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("widget_preview_open")
        .accessibilityLabel("\(headline.item.name)\n\(headline.item.localizedDate)\n\(model.t("start_fasting")): \(WidgetText(snapshot: snapshot).time(headline.item.fastingStart))\n\(model.t("break_fasting")): \(WidgetText(snapshot: snapshot).date(headline.item.paranaStart)), \(WidgetText(snapshot: snapshot).window(headline.item.paranaStart, headline.item.paranaEnd))")
        .accessibilityHint(model.t("widget_preview_tap"))
    }
}
