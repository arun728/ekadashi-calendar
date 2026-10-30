import SwiftUI
import EkadashiCore

struct JourneyOverviewPanel: View {
    @Environment(AppModel.self) private var model
    let summary: JourneySummary
    let year: Int
    @State private var sharing = false

    private var progress: JourneyYear { summary.year(year) }
    private var currentQuarter: Int { year == model.today.year ? (model.today.month - 1) / 3 + 1 : 1 }

    var body: some View {
        VStack(spacing: 14) {
            if model.vrat.rewardsStorageError {
                Text(model.t("ios_journey_storage_error")).font(.caption).foregroundStyle(.orange)
            }
            VStack(spacing: 6) {
                Text(model.t("ios_journey_title", String(year))).font(.title3.weight(.semibold))
                Text(progress.points.formatted(.number.locale(model.locale)))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(Theme.teal)
                Text(model.t("ios_journey_points")).font(.subheadline.weight(.medium))
                Text(model.t("ios_journey_year_points", String(progress.points), String(progress.maximumPoints)))
                    .font(.caption).foregroundStyle(.white.opacity(0.75))
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("journey_year_points")
            JourneyMandala(progress: progress).frame(maxWidth: 310)
            Text(model.t("ios_journey_summary", String(progress.observed), String(progress.partial)))
                .font(.subheadline).foregroundStyle(.white.opacity(0.75))
            Label("\(model.t("current_streak")) · \(summary.currentStreak)", systemImage: AppSymbol.journeyStreak)
                .font(.subheadline).foregroundStyle(Theme.teal)
            HStack {
                Text(model.t("ios_journey_lifetime"))
                Spacer()
                Text(summary.lifetimePoints.formatted(.number.locale(model.locale))).fontWeight(.semibold)
            }
            .font(.subheadline)
            .accessibilityIdentifier("journey_lifetime_points")
            Divider()
            ForEach(progress.quarters) { quarter in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(model.t("ios_journey_quarter", String(quarter.id), String(year))).fontWeight(.semibold)
                        Spacer()
                        Text(model.t("ios_journey_quarter_progress", String(quarter.observed), String(quarter.total)))
                    }
                    .font(.caption)
                    ProgressView(value: Double(quarter.observed), total: Double(max(1, quarter.total)))
                        .tint(quarter.completed ? Theme.amber : Theme.teal)
                    if quarter.completed || quarter.id == currentQuarter {
                        Text(model.t(quarter.completed ? "ios_journey_bonus_earned" : "ios_journey_quarter_bonus"))
                            .font(.caption2).foregroundStyle(quarter.completed ? Theme.teal : .secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("journey_quarter_\(year)_\(quarter.id)")
            }
            if progress.annualBonus > 0 {
                Text(model.t("ios_journey_annual_bonus")).font(.subheadline.bold()).foregroundStyle(Theme.teal)
            }
            Text(model.t("ios_journey_scoring")).font(.caption2).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center)
            Button { sharing = true } label: {
                Label(model.t("ios_journey_share"), systemImage: AppSymbol.share).frame(maxWidth: .infinity)
            }
            .primaryActionStyle()
            .accessibilityIdentifier("journey_share_year")
            if !model.premium.isPremium {
                Button { model.openPaywall(reason: "ios_journey_premium_desc") } label: {
                    VStack(spacing: 4) {
                        Text(model.t("ios_journey_premium")).font(.subheadline.bold())
                        Text(model.t("ios_journey_premium_desc")).font(.caption).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                .primaryActionStyle()
                .accessibilityIdentifier("journey_rewards_premium")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(JourneyCardPalette.gradient, in: RoundedRectangle(cornerRadius: 24))
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .sheet(isPresented: $sharing) { JourneyShareSheet(progress: progress, badges: earnedAnnualBadges) }
    }

    private var earnedAnnualBadges: [JourneyBadgeDefinition] {
        JourneyBadgeCatalog.all(years: [year]).filter { badge in
            model.vrat.userAchievements[badge.id]?.isUnlocked == true && (badge.year == nil || badge.year == year)
        }
    }
}

struct JourneyBadgeCollection: View {
    @Environment(AppModel.self) private var model
    let summary: JourneySummary
    var selectedYear: Int? = nil
    @State private var selected: JourneyBadgeDefinition?
    @State private var collection: String?

    private func group(_ badge: JourneyBadgeDefinition) -> String {
        switch badge.rule {
        case .observed: return "milestones"
        case .streak: return "consistency"
        case .partial, .returned: return "encouragement"
        case .annual, .quarter, .legacyAnnual: return "annual"
        }
    }

    private var definitions: [JourneyBadgeDefinition] {
        JourneyBadgeCatalog.all(years: model.enabledYears)
            .filter { $0.isVisible(inYear: selectedYear) }
            .filter { $0.id != "full_year_observance" || model.vrat.userAchievements[$0.id]?.isUnlocked == true }
            .filter { collection == nil || group($0) == collection }
            .sorted {
                let a = model.vrat.userAchievements[$0.id]?.isUnlocked == true
                let b = model.vrat.userAchievements[$1.id]?.isUnlocked == true
                if a != b { return a }
                return $0.achievement.sortOrder == $1.achievement.sortOrder ? $0.id < $1.id : $0.achievement.sortOrder < $1.achievement.sortOrder
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(model.t("ios_journey_badges")).font(.title3.bold())
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        GlassChip(title: model.t("filter_all"), color: Theme.teal, selected: collection == nil) { collection = nil }
                            .accessibilityIdentifier("journey_badge_filter_all")
                        ForEach(["milestones", "consistency", "encouragement", "annual"], id: \.self) { group in
                            GlassChip(title: model.t("ios_journey_collection_\(group)"), color: Theme.teal, selected: collection == group) { collection = group }
                                .accessibilityIdentifier("journey_badge_filter_\(group)")
                        }
                    }
                }
                .scrollIndicators(.hidden)
                Text(model.t("premium_free_achievements")).font(.subheadline).foregroundStyle(.secondary)
                if !model.premium.isPremium {
                    Button(model.t("premium_more_achievements")) { model.openPaywall() }.secondaryActionStyle()
                }
                JourneyUniformGrid {
                    ForEach(definitions) { badge in
                        let earned = model.vrat.userAchievements[badge.id]?.isUnlocked == true
                        Button { selected = badge } label: {
                            VStack(spacing: 8) {
                                JourneyBadgeArt(definition: badge, earned: earned).frame(width: 82, height: 82)
                                Text(model.t(badge.achievement.titleKey)).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
                                if let year = badge.year { Text(String(year)).font(.caption).foregroundStyle(Theme.teal) }
                                Text(model.t(badge.achievement.descriptionKey)).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                                if earned {
                                    Text(model.t("unlocked")).font(.caption.bold()).foregroundStyle(Theme.teal)
                                } else {
                                    badgeProgress(badge)
                                    if !model.premium.isPremium && model.vrat.userAchievements.values.filter(\.isUnlocked).count >= VratTracker.freeAchievementLimit {
                                        Text(model.t("premium_title")).font(.caption2.bold()).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 210, maxHeight: .infinity, alignment: .top)
                            .padding(12)
                            .glassPanel(cornerRadius: 18, tint: earned ? Theme.teal : nil)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("journey_badge_\(badge.id)")
                    }
                }
            }
            .padding(16)
        }
        .sheet(item: $selected) { JourneyBadgeDetail(definition: $0, summary: summary) }
    }

    @ViewBuilder private func badgeProgress(_ badge: JourneyBadgeDefinition) -> some View {
        let progress = badge.progress(in: summary)
        if case .quarter(let year, let q) = badge.rule {
            let quarter = summary.year(year).quarters[q - 1]
            Text(model.t("ios_journey_progress", String(quarter.observed), String(quarter.total))).font(.caption)
        } else if case .annual(let year) = badge.rule {
            Text(model.t("ios_journey_progress", String(summary.year(year).observed), String(summary.year(year).segments.count))).font(.caption)
        } else {
            Text(model.t("ios_journey_progress", String(progress), String(badge.target))).font(.caption)
        }
    }
}

struct JourneyBadgeDetail: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let definition: JourneyBadgeDefinition
    let summary: JourneySummary

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    JourneyBadgeArt(definition: definition, earned: earned).frame(width: 160, height: 160)
                    Text(model.t(definition.achievement.titleKey)).font(.title2.bold()).multilineTextAlignment(.center)
                    if let year = definition.year { Text(String(year)).font(.headline).foregroundStyle(Theme.teal) }
                    Text(model.t(definition.achievement.descriptionKey)).multilineTextAlignment(.center)
                    Text(model.t(earned ? "unlocked" : "locked")).font(.headline).foregroundStyle(Theme.teal)
                    let progress = displayedProgress
                    ProgressView(value: Double(progress.value), total: Double(max(1, progress.target))).tint(Theme.teal)
                    Text(model.t("ios_journey_progress", String(progress.value), String(progress.target))).font(.caption)
                    if let stamp = model.vrat.userAchievements[definition.id]?.unlockedAtUTC,
                       let date = ISO8601.instant(stamp) {
                        Text(model.t("ios_journey_earned", model.fullDate(model.scheduleZone.wallClock(date).date)))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(28)
            }
            .background(AppBackground())
            .toolbar { AppToolbarItem(placement: .confirmationAction) { Button(model.t("info_close")) { dismiss() } } }
        }
        .glassSheetBackground()
        .accessibilityIdentifier("journey_badge_detail")
    }
    private var earned: Bool { model.vrat.userAchievements[definition.id]?.isUnlocked == true }
    private var displayedProgress: (value: Int, target: Int) {
        switch definition.rule {
        case .quarter(let year, let q):
            let quarter = summary.year(year).quarters[q - 1]
            return (quarter.observed, quarter.total)
        case .annual(let year): return (summary.year(year).observed, summary.year(year).segments.count)
        default: return (definition.progress(in: summary), definition.target)
        }
    }
}

struct JourneyShareSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    let progress: JourneyYear
    let badges: [JourneyBadgeDefinition]
    @State private var image: UIImage?
    @State private var selectedIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    card.accessibilityIdentifier("journey_share_preview")
                    if !badges.isEmpty {
                        ForEach(badges) { badge in
                            Toggle(isOn: Binding(get: { selectedIDs.contains(badge.id) }, set: { selected in
                                if selected { selectedIDs.insert(badge.id) } else { selectedIDs.remove(badge.id) }
                                render()
                            })) { Text(model.t(badge.achievement.titleKey)) }
                            .tint(Theme.teal)
                        }
                    }
                    if let image {
                        ShareLink(item: Image(uiImage: image),
                                  message: Text(model.t("ios_journey_share_message", String(progress.year), String(progress.points))),
                                  preview: SharePreview(model.t("ios_journey_title", String(progress.year)), image: Image(uiImage: image))) {
                            Label(model.t("share"), systemImage: AppSymbol.share).frame(maxWidth: .infinity)
                        }
                        .primaryActionStyle()
                        .accessibilityIdentifier("journey_share_confirm")
                    }
                }
                .padding(20)
            }
            .background(AppBackground())
            .navigationTitle(model.t("ios_journey_share_preview"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { AppToolbarItem(placement: .cancellationAction) { Button(model.t("cancel")) { dismiss() } } }
        }
        .glassSheetBackground()
        .task {
            selectedIDs = Set(badges.map(\.id))
            render()
        }
    }

    private var card: some View {
        JourneyAnnualShareCard(progress: progress, badges: badges.filter { selectedIDs.contains($0.id) })
    }

    @MainActor private func render() {
        let renderer = ImageRenderer(content: card.frame(width: 360).environment(model))
        renderer.scale = max(2, displayScale)
        image = renderer.uiImage
    }
}

/// A self-contained export surface; no journal notes or location fields.
struct JourneyAnnualShareCard: View {
    @Environment(AppModel.self) private var model
    let progress: JourneyYear
    let badges: [JourneyBadgeDefinition]

    var body: some View {
        VStack(spacing: 12) {
            Text(model.t("ios_journey_title", String(progress.year))).font(.title2.bold()).foregroundStyle(.white)
            JourneyMandala(progress: progress).frame(height: 260)
            Text("\(progress.points.formatted(.number.locale(model.locale))) \(model.t("ios_journey_points"))")
                .font(.title3.bold()).foregroundStyle(.white)
            Text(model.t("ios_journey_summary", String(progress.observed), String(progress.partial)))
                .font(.subheadline).foregroundStyle(.white.opacity(0.85))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 46), spacing: 6)], spacing: 6) {
                ForEach(badges) { badge in
                    JourneyBadgeArt(definition: badge).frame(width: 46, height: 46)
                }
            }
            Text(model.t("app_title")).font(.caption).foregroundStyle(.white.opacity(0.7))
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(JourneyCardPalette.gradient, in: RoundedRectangle(cornerRadius: 24))
        .padding(6)
        .background(JourneyCardPalette.matte)
        .environment(\.colorScheme, .dark)
    }

}

/// Opaque export canvas prevents receivers from replacing transparent corners
/// with white. The rounded inner card remains visible against the green matte.
enum JourneyCardPalette {
    static let matte = Color(red: 0.02, green: 0.14, blue: 0.14)
    static var gradient: LinearGradient {
        LinearGradient(colors: [Color(red: 0.02, green: 0.18, blue: 0.18),
                                Color(red: 0.03, green: 0.08, blue: 0.13)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
