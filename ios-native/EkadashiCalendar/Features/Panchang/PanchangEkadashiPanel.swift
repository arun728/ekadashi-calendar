import SwiftUI
import EkadashiCore

/// Calculated Smarta or Gaudiya/ISKCON fasts for the month and location
/// (panchang_month_panels.dart), in the app language. A preview: the
/// published schedule still drives the calendar, reminders and Journey.
struct PanchangEkadashiPanel: View {
    @Environment(AppModel.self) private var model
    let month: CivilDate
    let city: PanchangCity
    @Binding var tradition: EkadashiTradition
    @State private var fasts: [CalculatedEkadashi]?
    @State private var failed = false

    private var language: String { model.language }
    private var terms: PanchangTerms { .shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(EkadashiTradition.allCases, id: \.self) { item in
                    GlassChip(title: model.t(item == .smarta ? "panchang_smarta" : "panchang_gaudiya"), selected: tradition == item) {
                        tradition = item
                    }
                }
            }
            Text(model.t(tradition == .smarta ? "panchang_smarta_rule" : "panchang_gaudiya_rule"))
                .font(.subheadline).foregroundStyle(.secondary)
            Group {
                if failed {
                    VStack(spacing: 8) {
                        Text(model.t("panchang_calculation_failed"))
                        Button(model.t("retry")) { Task { await load() } }
                    }
                    .frame(maxWidth: .infinity)
                } else if let fasts {
                    if fasts.isEmpty {
                        Text(model.t("panchang_no_calculated_fast")).font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        ForEach(fasts) { card($0) }
                    }
                } else {
                    ProgressView().tint(Theme.teal).frame(maxWidth: .infinity, minHeight: 120)
                }
            }
            Text(model.t("panchang_calculated_preview")).font(.caption).foregroundStyle(.secondary)
        }
        .task(id: "\(month.iso)|\(city.id)|\(city.latitude)|\(city.longitude)|\(city.timeZoneId)|\(tradition.rawValue)") { await load() }
    }

    private func load() async {
        fasts = nil
        failed = false
        let month = self.month, city = self.city, tradition = self.tradition
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try CalculatedEkadashiEngine().calculate(start: month, count: month.daysInMonth, city: city, tradition: tradition)
            }.value
            guard !Task.isCancelled else { return }
            fasts = result
        } catch {
            if !Task.isCancelled { failed = true }
        }
    }

    private func time(_ instant: Date?, _ date: CivilDate) -> String {
        PanchangFormat.time(instant, city: city, date: date, language: language)
    }

    private func card(_ fast: CalculatedEkadashi) -> some View {
        let parana: String = {
            guard let start = fast.paranaStart else { return model.t("panchang_unavailable") }
            guard let end = fast.paranaEnd else { return model.t("panchang_after", time(start, fast.paranaDate)) }
            return "\(time(start, fast.paranaDate)) – \(time(end, fast.paranaDate))"
        }()
        return VStack(alignment: .leading, spacing: 10) {
            Text(terms.translate(fast.name, .ekadashiName, language: language)).font(.headline)
            PanchangRow(label: model.t("panchang_fast_day"), value: PanchangFormat.date(fast.date, language: language),
                        detail: model.t("panchang_starts_at", time(fast.fastStarts, fast.date)))
            PanchangRow(label: model.t("panchang_parana"), value: PanchangFormat.date(fast.paranaDate, language: language),
                        detail: parana)
            if fast.nearBoundary {
                Label(model.t("panchang_near_boundary"), systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
            DisclosureGroup(model.t("panchang_calculation_details")) {
                VStack(alignment: .leading, spacing: 8) {
                    PanchangRow(label: model.t("panchang_rule"), value: terms.ekadashiNote(fast.rule, language: language))
                    Text(terms.ekadashiNote(fast.paranaReason, language: language)).font(.caption).foregroundStyle(.secondary)
                    PanchangRow(label: model.t("panchang_tithi"),
                                value: "\(time(fast.tithiStart, fast.date)) – \(time(fast.tithiEnd, fast.date))")
                    PanchangRow(label: model.t("panchang_hari_vasara_ends"), value: time(fast.hariVasaraEnd, fast.paranaDate))
                }
                .padding(.top, 6)
            }
            .font(.subheadline)
            .tint(Theme.teal)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 18)
    }
}
