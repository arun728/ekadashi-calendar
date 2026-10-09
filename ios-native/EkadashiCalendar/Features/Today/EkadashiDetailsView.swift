import SwiftUI
import EkadashiCore

/// Significance, story, rules, benefits, timings and the Vrat button
/// (details_screen.dart).
struct EkadashiDetailsView: View {
    @Environment(AppModel.self) private var model
    let event: EkadashiOccurrence
    @State private var recording = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 4) {
                    Text(model.format(event.date, "MMM dd, yyyy")).font(.title2.weight(.light))
                    Text(event.name).font(.largeTitle.bold()).foregroundStyle(Theme.teal).multilineTextAlignment(.center)
                    StatusPill(text: model.timeZoneLabel, color: Theme.teal)
                }
                .frame(maxWidth: .infinity)
                if event.usesContentFallback {
                    Text(model.t("content_fallback")).italic()
                }
                section("significance", event.description)
                section("story_history", event.story)
                section("fasting_rules", event.fastingRules)
                section("spiritual_benefits", event.benefits)
                VStack(spacing: 0) {
                    timing("fork.knife", model.t("start_fasting"), event.date, event.fastStartTime)
                    Divider().padding(.vertical, 12)
                    timing("sunrise", model.t("break_fasting"), event.date.adding(days: 1), EkadashiDisplay.breakTime(event))
                }
                .padding(16)
                .glassPanel(cornerRadius: 16, tint: Theme.teal)
                if model.vrat.isEnabled { vratButton }
            }
            .padding(20)
        }
        .background(AppBackground())
        .navigationTitle(model.t("app_title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $recording) { RecordVratSheet(event: event) }
    }

    private func section(_ key: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.t(key)).font(.title3.bold()).foregroundStyle(Theme.teal)
            Text(text).font(.body).lineSpacing(5)
        }
    }

    private func timing(_ symbol: String, _ title: String, _ date: CivilDate, _ time: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Theme.teal).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).bold().foregroundStyle(Theme.teal)
                Text(model.format(date, "MMM dd, yyyy")).font(.footnote).foregroundStyle(.secondary)
                Text(Localizer.shared.localizeClock(time, language: model.language)).font(.title3)
            }
            Spacer(minLength: 0)
        }
    }

    private var vratButton: some View {
        let record = model.vrat.record(for: event.occurrenceUid)
        let style = VratStatusStyle(record?.status)
        let open = model.canRecord(event)
        let label = record != nil ? "\(model.t("vrat")): \(model.t(style.detailKey))"
            : model.t(open ? "record_vrat" : "journey_record_after_parana")
        return Button {
            recording = true
        } label: {
            Label(label, systemImage: style.symbol)
                .font(.callout.bold())
                .foregroundStyle(style.color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .secondaryActionStyle()
        .disabled(!open)
        .accessibilityIdentifier("details_record_vrat")
    }
}
