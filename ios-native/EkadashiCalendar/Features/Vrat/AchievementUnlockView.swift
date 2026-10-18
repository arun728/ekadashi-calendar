import SwiftUI
import EkadashiCore

/// One celebration for every badge earned by the same update.
struct AchievementUnlockView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let achievements: [Achievement]
    @State private var selected: JourneyBadgeDefinition?
    @State private var appeared = false

    private var summary: JourneySummary {
        model.vrat.journey(model.ekadashis, completeYears: Set(model.enabledYears), zone: model.scheduleZone)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text(model.t("achievement_unlocked")).font(.caption.bold()).foregroundStyle(Theme.teal)
                ForEach(achievements) { achievement in
                    Button {
                        selected = JourneyBadgeCatalog.definition(achievement.id)
                    } label: {
                        HStack(spacing: 14) {
                            if let badge = JourneyBadgeCatalog.definition(achievement.id) {
                                JourneyBadgeArt(definition: badge).frame(width: 78, height: 78)
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                Text(model.t(achievement.titleKey)).font(.headline)
                                Text(model.t(achievement.descriptionKey)).font(.caption).foregroundStyle(.secondary)
                                Text(model.t("ios_journey_view_badge")).font(.caption.bold()).foregroundStyle(Theme.teal)
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Button(model.t("hari_om")) { dismiss() }.primaryActionStyle()
                    .accessibilityIdentifier("journey_celebration_close")
            }
            .padding(24)
            .opacity(appeared ? 1 : 0)
            .scaleEffect(reduceMotion || appeared ? 1 : 0.96)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: appeared)
        }
        .presentationBackground(.thinMaterial)
        .accessibilityIdentifier("journey_badge_celebration")
        .onAppear { appeared = true }
        .sensoryFeedback(.success, trigger: appeared) { _, new in new && model.badgeHaptics && !reduceMotion }
        .sheet(item: $selected) { JourneyBadgeDetail(definition: $0, summary: summary) }
    }
}

struct JourneyUnlockGroup: Identifiable {
    let achievements: [Achievement]
    var id: String { achievements.first?.id ?? "" }
}
