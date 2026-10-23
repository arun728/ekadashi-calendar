import SwiftUI
import EkadashiCore

/// The home tab: location and language, the tradition and year menus, then
/// one card per Ekadashi of that year with arrows, opening on the current or
/// next Ekadashi. Dates and times are calculated by the Panchang engine for
/// the chosen city; the menus apply to Calendar, reminders and widgets too.
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.paneLayout) private var panes

    private var events: [EkadashiOccurrence] { model.homeEkadashis }

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            HomeControls()
                .readableWidth()
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
                // Wide screens list the year's Ekadashis beside the card.
                AdaptivePanes(stackedSpacing: 0) {
                    VStack(spacing: 0) {
                        Text("\(model.homeIndex + 1) / \(events.count)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 8)
                            .accessibilityIdentifier("home_page_indicator")
                        HStack(spacing: 0) {
                            arrow(AppSymbol.previous, target: model.homeIndex - 1) { model.homeIndex -= 1 }
                            TabView(selection: $model.homeIndex) {
                                ForEach(Array(events.enumerated()), id: \.element.occurrenceUid) { index, event in
                                    EkadashiCard(event: event)
                                        .padding(4)
                                        .tag(index)
                                }
                            }
                            .tabViewStyle(.page(indexDisplayMode: .never))
                            arrow(AppSymbol.next, target: model.homeIndex + 1) { model.homeIndex += 1 }
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 8)
                        .animation(.easeInOut(duration: 0.3), value: model.homeIndex)
                        .opacity(model.isCalculating ? 0.5 : 1)
                        .overlay { if model.isCalculating { ProgressView().tint(Theme.teal) } }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("home_card_pane")
                } trailing: {
                    if panes.isSideBySide {
                        HomeEkadashiList(events: events)
                            .padding(.trailing, 16)
                            .padding(.bottom, 8)
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("home_list_pane")
                            .opacity(model.isCalculating ? 0.5 : 1)
                    }
                }
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

/// The year's Ekadashis beside the card on wide screens (docs/FOLDABLES.md):
/// the card's Ekadashi is highlighted and a tap opens another's card.
struct HomeEkadashiList: View {
    @Environment(AppModel.self) private var model
    let events: [EkadashiOccurrence]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    Text(String(model.selectedYear) + " " + model.t("ekadashis_unit"))
                        .font(.headline)
                        .foregroundStyle(Theme.teal)
                        .padding(.horizontal, 4)
                    ForEach(Array(events.enumerated()), id: \.element.occurrenceUid) { index, event in
                        row(index, event).id(index)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .onAppear { proxy.scrollTo(model.homeIndex, anchor: .center) }
            .onChange(of: model.homeIndex) { _, index in
                withAnimation { proxy.scrollTo(index, anchor: .center) }
            }
        }
    }

    private func row(_ index: Int, _ event: EkadashiOccurrence) -> some View {
        let selected = index == model.homeIndex
        let passed = model.today.days(until: event.date) < 0
        let status = model.vrat.isEnabled ? model.vrat.record(for: event.occurrenceUid)?.status : nil
        return Button {
            model.homeIndex = index
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selected ? Theme.teal : .primary)
                        .lineLimit(2)
                    Text(model.fullDate(event.date)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if let status {
                    let style = VratStatusStyle(status)
                    Image(systemName: style.symbol).foregroundStyle(style.color)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassPanel(cornerRadius: 14, tint: selected ? Theme.teal : nil, interactive: true)
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(selected ? Theme.teal : .clear, lineWidth: 1.5))
        .opacity(passed && !selected ? 0.6 : 1)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("home_list_row_\(index)")
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
            ForEach(EkadashiTradition.allCases, id: \.self) { tradition in
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
    @State private var recording = false
    @State private var sharing = false

    private var daysUntil: Int { model.today.days(until: event.date) }

    private var daysText: String {
        switch daysUntil {
        case 0: return model.t("today")
        case 1: return model.t("tomorrow")
        case ..<0: return model.t("passed")
        default: return model.t("in_days", String(daysUntil))
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(spacing: 0) {
                    Text(daysText)
                        .font(.footnote.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(daysUntil < 0 ? Color.gray : Theme.teal, in: Capsule())
                        .frame(maxWidth: .infinity, alignment: .trailing)
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
                        Button {
                            recording = true
                        } label: {
                            Image(systemName: VratStatusStyle(model.vrat.record(for: event.occurrenceUid)?.status).cardSymbol)
                                .font(.title3)
                                .padding(.vertical, 4)
                        }
                        .secondaryActionStyle()
                        .disabled(!model.canRecord(event))
                        .accessibilityLabel(model.t(model.vrat.record(for: event.occurrenceUid) == nil ? "record_vrat" : "edit_record"))
                        .accessibilityHint(model.canRecord(event) ? "" : model.t("journey_record_after_parana"))
                        .accessibilityIdentifier("home_record_vrat")
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

enum EkadashiDisplay {
    /// The Parana window without the leading "Mmm d, " the data carries.
    static func breakTime(_ event: EkadashiOccurrence) -> String {
        event.fastBreakTime.replacingOccurrences(of: #"^[a-zA-Z]{3} \d{1,2}, "#, with: "", options: .regularExpression)
    }
}
