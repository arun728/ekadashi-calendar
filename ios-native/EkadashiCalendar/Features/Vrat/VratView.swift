import SwiftUI
import EkadashiCore

/// Vrat tracker: overview, history, statistics and achievements
/// (vrat_tracker_screen.dart). History, editing, streaks and statistics stay
/// free; three entries and three badges are free, more need Premium.
/// The sections are glass chips, as in Panchang, and change with a swipe.
struct VratView: View {
    @Environment(AppModel.self) private var model
    enum Section: String, CaseIterable { case overview, history, statistics, achievements }
    @State private var section: Section = .overview
    @State private var selectedYear = CivilDate.today().year
    @State private var statusFilter: ObservanceStatus?
    @State private var recording: EkadashiOccurrence?

    private var journey: JourneySummary {
        model.vrat.journey(events, completeYears: Set(model.enabledYears), zone: model.scheduleZone)
    }

    private var events: [EkadashiOccurrence] { model.ekadashis }
    private var years: [Int] { model.vrat.years(events) }

    /// The chosen year when it has data, else this year, else the latest.
    private var year: Int {
        let available = years
        if available.contains(selectedYear) || available.isEmpty { return selectedYear }
        let current = CivilDate.today().year
        return available.contains(current) ? current : available.last!
    }

    var body: some View {
        VStack(spacing: 0) {
            if let error = model.vrat.storageError {
                ContentUnavailableView {
                    Label(model.t("tracker_storage_failed"), systemImage: AppSymbol.journeyStorageFailed)
                } description: {
                    Text(error)
                } actions: {
                    Button(model.t("retry")) { model.vrat.load(events) }.primaryActionStyle()
                }
            } else {
                sectionBar
                TabView(selection: $section) {
                    overview.tag(Section.overview)
                    history.tag(Section.history)
                    statistics.tag(Section.statistics)
                    achievements.tag(Section.achievements)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .sheet(item: $recording) { RecordVratSheet(event: $0) }
    }

    private var sectionBar: some View {
        SectionChips(Section.allCases, selection: $section, title: { model.t($0.rawValue) },
                     identifier: { "journey_tab_\($0.rawValue)" })
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("vrat_tabs_tube")
    }

    // MARK: Overview

    private var overview: some View {
        let records = model.vrat.allRecords
        let totalObserved = records.filter { $0.status == .observed }.count
        let longest = journey.longestStreak
        let stats = model.vrat.annualStats(year, events)
        let milestone = JourneyBadgeCatalog.nextMilestone(summary: journey, earned: model.vrat.userAchievements)
        let today = CivilDate.today()
        let recent = events.sorted { $0.date < $1.date }.filter { abs(today.days(until: $0.date)) <= 30 }.prefix(4)
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Spacer(); yearMenu.accessibilityIdentifier("journey_overview_year") }
                JourneyOverviewPanel(summary: journey, year: year)
                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        MetricCard(title: model.t("current_streak"), value: "\(journey.currentStreak)",
                                   subtitle: model.t("ekadashis_unit"), symbol: AppSymbol.journeyStreak, color: .orange)
                            .accessibilityIdentifier("journey_overview_streaks")
                        MetricCard(title: model.t("longest_streak"), value: "\(longest)", subtitle: model.t("ekadashis_unit"),
                                   symbol: AppSymbol.journeyBest, color: Theme.amber)
                    }
                    GridRow {
                        MetricCard(title: "\(year) \(model.t("annual_completion"))",
                                   value: "\(Int(stats.completionPercentage.rounded()))%",
                                   subtitle: "\(stats.observedCount) / \(stats.totalOccurrences)",
                                   symbol: AppSymbol.journeyRate, color: Theme.teal)
                        MetricCard(title: model.t("total_observed"), value: "\(totalObserved)", subtitle: model.t("ekadashis_unit"),
                                   symbol: AppSymbol.journeyObserved, color: Theme.observed)
                    }
                }
                if let milestone {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(model.t("next_milestone"), systemImage: AppSymbol.journeyMilestone)
                            Spacer()
                            Text("\(milestone.goalProgress(in: journey)) / \(milestone.target)")
                        }
                        .font(.caption.bold())
                        .foregroundStyle(Theme.teal)
                        Text(model.t(milestone.achievement.titleKey)).font(.headline)
                        if milestone.goalProgress(in: journey) >= milestone.target && !model.premium.isPremium {
                            Button(model.t("premium_more_achievements")) { model.openPaywall() }
                                .font(.caption.bold())
                        } else {
                            Text(model.t("ios_journey_remaining", String(max(0, milestone.target - milestone.goalProgress(in: journey)))))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        ProgressView(value: Double(milestone.goalProgress(in: journey)), total: Double(max(milestone.target, 1)))
                            .tint(Theme.teal)
                    }
                    .padding(16)
                    .glassPanel(cornerRadius: 16, tint: Theme.teal)
                    .padding(.top, 8)
                }
                Text(model.t("record_observance")).font(.headline).foregroundStyle(Theme.teal).padding(.top, 8)
                Text(model.t("tap_to_record_instruction")).font(.caption).foregroundStyle(.secondary)
                ForEach(Array(recent)) { row($0) }
            }
            .padding(16)
        }
    }

    // MARK: History

    private var history: some View {
        let filtered = events.filter { $0.date.year == year }
            .filter { event in
                guard let statusFilter else { return true }
                return (model.vrat.record(for: event.occurrenceUid)?.status ?? .unrecorded) == statusFilter
            }
            .sorted { $0.date < $1.date }
        return VStack(spacing: 8) {
            ScrollView(.horizontal) {
                GlassGroup(spacing: 8) {
                    HStack(spacing: 8) {
                        yearMenu
                        filterChip(nil, "filter_all")
                        filterChip(.observed, "observed")
                        filterChip(.partial, "partial")
                        filterChip(.missed, "missed")
                        filterChip(.unrecorded, "unrecorded")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }
            .scrollIndicators(.hidden)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("vrat_history_filters_tube")
            Text(model.t("tap_to_record_instruction")).font(.caption).foregroundStyle(.secondary)
            if filtered.isEmpty {
                ContentUnavailableView(model.t("no_ekadashi"), systemImage: AppSymbol.journeyEmpty)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) { ForEach(filtered) { row($0) } }.padding(16)
                }
            }
        }
    }

    private var yearMenu: some View {
        Menu {
            ForEach(years, id: \.self) { value in
                Button(String(value)) { selectedYear = value }
            }
        } label: {
            Label(String(year), systemImage: AppSymbol.journeyYear).font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .glassCapsule(tint: Theme.teal)
        }
    }

    private func filterChip(_ status: ObservanceStatus?, _ key: String) -> some View {
        GlassChip(title: model.t(key), color: status.map { VratStatusStyle($0).color } ?? Theme.teal,
                  selected: statusFilter == status) { statusFilter = status }
    }

    private func row(_ event: EkadashiOccurrence) -> some View {
        let record = model.vrat.record(for: event.occurrenceUid)
        let style = VratStatusStyle(record?.status)
        let date = model.fullDate(event.date)
        let open = model.canRecord(event)
        return Button {
            // Only fasts that have happened can be recorded (Phase 4).
            if open { recording = event } else { model.show("journey_record_after_parana") }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: style.symbol)
                    .foregroundStyle(style.color)
                    .frame(width: 38, height: 38)
                    .background(style.color.opacity(0.12), in: Circle())
                    .overlay(Circle().strokeBorder(style.color.opacity(0.35), lineWidth: 1.5))
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.name).font(.headline)
                    Text(date).font(.footnote).foregroundStyle(.secondary)
                    if let note = record?.note, !note.isEmpty {
                        Text("“\(note)”").font(.caption.italic()).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                StatusPill(text: model.t(style.listKey), color: style.color)
                Image(systemName: open ? AppSymbol.rowDisclosure : AppSymbol.journeyPending).font(.caption).foregroundStyle(.tertiary)
            }
            .opacity(open ? 1 : 0.55)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassPanel(cornerRadius: 14, interactive: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(event.name), \(date), \(model.t(style.listKey)). \(model.t("tap_to_record_semantics"))")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("journey_row_\(event.occurrenceUid)")
    }

    // MARK: Statistics

    private var statistics: some View {
        let stats = model.vrat.annualStats(year, events)
        return ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text("\(model.t("year")):").font(.headline)
                    Spacer()
                    yearMenu
                }
                VStack(spacing: 12) {
                    Text("\(year) \(model.t("annual_completion"))").font(.headline)
                    ZStack {
                        Circle().stroke(Theme.teal.opacity(0.15), lineWidth: 12)
                        Circle().trim(from: 0, to: stats.completionPercentage / 100)
                            .stroke(Theme.teal, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(stats.completionPercentage.rounded()))%").font(.title.bold()).foregroundStyle(Theme.teal)
                    }
                    .frame(width: 130, height: 130)
                    Text(model.t("observed_of_total", "\(stats.observedCount)", "\(stats.totalOccurrences)"))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .glassPanel(cornerRadius: 16)
                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        countCard("observed", stats.observedCount, Theme.observed)
                        countCard("partial", stats.partialCount, Theme.partial)
                    }
                    GridRow {
                        countCard("missed", stats.missedCount, Theme.missed)
                        countCard("unrecorded", stats.unrecordedCount, .gray)
                    }
                    GridRow {
                        countCard("current_streak", journey.currentStreak, .orange)
                        countCard("longest_streak", journey.longestStreak, Theme.amber)
                    }
                }
            }
            .padding(16)
        }
    }

    private func countCard(_ key: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Text("\(value)").font(.title3.bold()).foregroundStyle(color)
            Text(model.t(key)).font(.caption).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .glassPanel(cornerRadius: 14, tint: color)
    }

    // MARK: Achievements

    private var achievements: some View {
        JourneyBadgeCollection(summary: journey)
    }

}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: symbol).foregroundStyle(color)
                Spacer()
                Text(value).font(.title2.bold()).foregroundStyle(color)
            }
            Text(title).font(.caption.weight(.medium)).lineLimit(1).padding(.top, 6)
            Text(subtitle).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 16, tint: color)
    }
}
