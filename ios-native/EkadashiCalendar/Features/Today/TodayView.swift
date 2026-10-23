import SwiftUI
import EkadashiCore

/// The home tab: location and language, the tradition and year menus, then
/// one card per Ekadashi of that year with arrows, opening on the current or
/// next Ekadashi. Dates and times are calculated by the Panchang engine for
/// the chosen city; the menus apply to Calendar, reminders and widgets too.
struct TodayView: View {
    @Environment(AppModel.self) private var model

    private var events: [EkadashiOccurrence] { model.homeEkadashis }

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            HomeControls()
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 12)
            if events.isEmpty && model.isCalculating {
                VStack(spacing: 12) {
                    ProgressView().tint(Theme.teal)
                    Text(model.t("calculating_ekadashis")).font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity)
                .accessibilityIdentifier("home_calculating")
            } else if events.isEmpty {
                ContentUnavailableView(model.t("no_ekadashi"), systemImage: AppSymbol.noEkadashi)
            } else {
                Text("\(model.homeIndex + 1) / \(events.count)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
                    .accessibilityIdentifier("home_page_indicator")
                HStack(spacing: 0) {
                    arrow(AppSymbol.previous, target: model.homeIndex - 1) { model.homeIndex -= 1 }
                    TabView(selection: $model.homeIndex) {
                        ForEach(Array(events.enumerated()), id: \.element.occurrenceUid) { index, event in
                            EkadashiCard(event: event, isVisible: index == model.homeIndex && model.selectedTab == .today)
                                .padding(4)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    // Years have different page counts. Recreate the pager so
                    // a linked final page is not reset against the previous year.
                    .id(model.selectedYear)
                    arrow(AppSymbol.next, target: model.homeIndex + 1) { model.homeIndex += 1 }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
                .animation(.easeInOut(duration: 0.3), value: model.homeIndex)
                .opacity(model.isCalculating ? 0.5 : 1)
                .overlay { if model.isCalculating { ProgressView().tint(Theme.teal) } }
            }
        }
    }

    /// An arrow to the card at [target], read out as that Ekadashi's name.
    private func arrow(_ symbol: String, target: Int, action: @escaping () -> Void) -> some View {
        let enabled = events.indices.contains(target)
        return Button(action: action) {
            Image(systemName: symbol).font(.system(size: 28, weight: .semibold))
                .frame(width: 40, height: 60)
        }
        .disabled(!enabled)
        .foregroundStyle(enabled ? Theme.teal : .gray)
        .accessibilityLabel(enabled ? events[target].name : "")
    }
}

/// The four Home menus in a 2×2 grid that lines up from top to bottom:
/// location over tradition on the left (same width, filling the row) and
/// language over year on the right (same width: each reserves the other's
/// label). Every pill has the same height and style, and each is its own
/// glass capsule, so opening one menu (iOS 26 morphs its glass) never hides
/// another.
struct HomeControls: View {
    @Environment(AppModel.self) private var model
    @State private var choosingCity = false
    static let spacing: CGFloat = 10
    static let pillHeight: CGFloat = 44
    static let traditions: [EkadashiTradition] = [.gaudiya, .smarta]

    var body: some View {
        VStack(spacing: Self.spacing) {
            HStack(spacing: Self.spacing) {
                location
                languageMenu
            }
            HStack(spacing: Self.spacing) {
                traditionMenu
                yearMenu
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home_options_tube")
        .sheet(isPresented: $choosingCity) { EkadashiLocationSheet() }
    }

    // MARK: Left column: fills the row

    /// The Ekadashi city; tapping it opens the city search.
    private var location: some View {
        Button {
            choosingCity = true
        } label: {
            pill(alignment: .leading) {
                if model.locationState == .detecting && !model.ekadashiCityIsManual {
                    ProgressView().controlSize(.small).tint(Theme.teal)
                } else {
                    Image(systemName: model.ekadashiCityIsManual ? AppSymbol.locationPicked : AppSymbol.locationDetected)
                        .foregroundStyle(Theme.teal)
                }
                Text(model.ekadashiCityName)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .accessibilityIdentifier("home_location_name")
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(model.t("home_location_hint"))
        .accessibilityIdentifier("home_location")
    }

    private var traditionMenu: some View {
        Menu {
            ForEach(Self.traditions, id: \.self) { tradition in
                Button { model.setTradition(tradition) } label: {
                    if tradition == model.tradition {
                        Label(model.traditionName(tradition), systemImage: AppSymbol.checkmark)
                    } else {
                        Text(model.traditionName(tradition))
                    }
                }
            }
        } label: {
            pill(alignment: .leading) {
                Image(systemName: AppSymbol.homeTradition).foregroundStyle(Theme.teal)
                Text(model.traditionName(model.tradition)).lineLimit(1)
            }
        }
        .accessibilityLabel("\(model.t("home_tradition")): \(model.traditionName(model.tradition))")
        .accessibilityIdentifier("home_tradition_menu")
    }

    // MARK: Right column: as wide as the wider of language and year

    private var languageName: String { Localizer.displayName(model.language) }
    private var yearText: String { String(model.selectedYear) }

    private var languageMenu: some View {
        Menu {
            ForEach(Localizer.languages, id: \.self) { code in
                Button {
                    model.setLanguage(code)
                } label: {
                    if code == model.language { Label(Localizer.displayName(code), systemImage: AppSymbol.checkmark) } else { Text(Localizer.displayName(code)) }
                }
            }
        } label: {
            rightPill(shown: (languageName, AppSymbol.homeLanguage), reserved: (yearText, AppSymbol.homeYear))
        }
        .fixedSize()
        .accessibilityIdentifier("language_menu")
    }

    private var yearMenu: some View {
        Menu {
            ForEach(model.enabledYears, id: \.self) { year in
                Button { model.setYear(year) } label: {
                    if year == model.selectedYear { Label(String(year), systemImage: AppSymbol.checkmark) } else { Text(String(year)) }
                }
            }
        } label: {
            rightPill(shown: (yearText, AppSymbol.homeYear), reserved: (languageName, AppSymbol.homeLanguage))
        }
        .fixedSize()
        .accessibilityLabel("\(model.t("year")): \(model.selectedYear)")
        .accessibilityIdentifier("home_year_menu")
    }

    /// A right-column pill sized for both labels, so language and year match.
    private func rightPill(shown: (String, String), reserved: (String, String)) -> some View {
        pill(alignment: .center) {
            ZStack {
                content(reserved).hidden()
                content(shown)
            }
        }
    }

    private func content(_ item: (String, String)) -> some View {
        HStack(spacing: 6) {
            Image(systemName: item.1).foregroundStyle(Theme.teal)
            Text(item.0).lineLimit(1)
        }
    }

    // MARK: Shared pill

    private func pill<Content: View>(alignment: Alignment, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 6) {
            content()
            if alignment == .leading { Spacer(minLength: 0) }
            Image(systemName: AppSymbol.menuDisclosure).font(.caption2).foregroundStyle(.secondary)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.primary)
        .padding(.horizontal, 14)
        .frame(maxWidth: alignment == .leading ? .infinity : nil, minHeight: Self.pillHeight)
        .glassCapsule(interactive: true)
        .contentShape(Capsule())
    }
}

/// One Ekadashi: countdown badge, dates, fast and Parana times, the short
/// description, View Details and the Vrat record button.
struct EkadashiCard: View {
    @Environment(AppModel.self) private var model
    let event: EkadashiOccurrence
    var isVisible = true
    @State private var recording = false
    @State private var sharing = false

    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(spacing: 0) {
                    OccurrenceTimeline(events: [event], timeZone: model.ekadashiCity.timeZoneId, active: isVisible) { now in
                        EkadashiStatusHeader(event: event, timeZone: model.ekadashiCity.timeZoneId,
                            language: model.language, now: now)
                    }
                    Text(model.fullDate(event.date)).font(.title2.weight(.light)).padding(.top, 16)
                    Text(event.name)
                        .font(.title.bold())
                        .foregroundStyle(Theme.teal)
                        .multilineTextAlignment(.center)
                        .padding(.top, 16)
                    timing(model.t("start_fasting"), event.date, event.fastStartTime).padding(.top, 24)
                    timing(model.t("break_fasting"), event.date.adding(days: 1), EkadashiDisplay.breakTime(event))
                        .padding(.top, 16)
                    Divider().padding(.vertical, 16)
                    Text(event.description)
                        .font(.callout.italic())
                        .foregroundStyle(.primary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            .scrollIndicators(.hidden)
            GlassGroup {
                HStack(spacing: 8) {
                    NavigationLink {
                        EkadashiDetailsView(event: event)
                    } label: {
                        Text(model.t("view_details")).font(.callout.bold()).frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .primaryActionStyle()
                    .accessibilityIdentifier("view_details")
                    Button {
                        sharing = true
                    } label: {
                        Image(systemName: AppSymbol.share).font(.title3).padding(.vertical, 4)
                    }
                    .secondaryActionStyle()
                    .accessibilityLabel(model.t("share_card"))
                    .accessibilityIdentifier("home_share_card")
                    if model.vrat.isEnabled {
                        OccurrenceTimeline(events: [event], timeZone: model.ekadashiCity.timeZoneId, active: isVisible) { now in
                            let open = model.canRecord(event, now: now)
                            Button {
                                recording = model.requestVratRecording(event)
                            } label: {
                                Image(systemName: VratStatusStyle(model.vrat.record(for: event.occurrenceUid)?.status).cardSymbol)
                                    .font(.title3)
                                    .padding(.vertical, 4)
                            }
                            .secondaryActionStyle()
                            .tint(open ? Theme.teal : .gray)
                            .foregroundStyle(open ? Theme.teal : .gray)
                            .opacity(open ? 1 : 0.6)
                            .accessibilityLabel(model.t(model.vrat.record(for: event.occurrenceUid) == nil ? "record_vrat" : "edit_record"))
                            .accessibilityHint(open ? "" : model.t("journey_record_after_parana"))
                            .accessibilityIdentifier("home_record_vrat")
                        }
                    }
                }
            }
        }
        .padding(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))
        .glassPanel(cornerRadius: 24)
        .sheet(isPresented: $recording) { RecordVratSheet(event: event) }
        .sheet(isPresented: $sharing) { ShareCardSheet(event: event) }
    }

    private func timing(_ title: String, _ date: CivilDate, _ time: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.callout.bold()).foregroundStyle(Theme.teal)
            Text(model.fullDate(date)).font(.subheadline).foregroundStyle(.secondary)
            Text(Localizer.shared.localizeClock(time, language: model.language)).font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Reserved status row: today's ring leads, the existing day badge trails.
/// The date, name and timings below retain the card's full text width.
struct EkadashiStatusHeader: View {
    let event: EkadashiOccurrence
    let timeZone: String
    let language: String
    let now: Date

    private var status: EkadashiLifecycle {
        event.lifecycle(at: now, zone: TzDatabase.shared.location(timeZone) ?? AppTimezone.ist.location)
    }

    var body: some View {
        HStack(spacing: 12) {
            if status.progress != nil {
                let snapshot = WidgetSnapshot.build(occurrences: [event], timezone: timeZone, locationName: "", language: language, now: now)
                if let headline = snapshot.headline(at: now) {
                    RemainingRing(item: headline.item, snapshot: snapshot, now: now)
                        .frame(width: 48, height: 48)
                        .accessibilityIdentifier("home_remaining_ring")
                }
            }
            Spacer(minLength: 0)
            Text(status.label(language: language))
                .font(.footnote.bold()).monospacedDigit().foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.6)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(status.phase == .passed ? Color.gray : Theme.teal, in: Capsule())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHint(status.phase == .countdown ? Localizer.shared.translate("widget_starts_in", language: language) : "")
                .accessibilityIdentifier("home_day_badge")
        }
    }
}

enum EkadashiDisplay {
    /// The Parana window without the leading "Mmm d, " the data carries.
    static func breakTime(_ event: EkadashiOccurrence) -> String {
        event.fastBreakTime.replacingOccurrences(of: #"^[a-zA-Z]{3} \d{1,2}, "#, with: "", options: .regularExpression)
    }
}
