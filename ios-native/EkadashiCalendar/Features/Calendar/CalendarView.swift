import SwiftUI
import EkadashiCore

/// Month calendar of every data year with Ekadashi, Google and custom
/// entries (calendar_screen.dart). Google import is free once (the viewed
/// month) and Premium afterwards; see GoogleSyncCoordinator.
struct CalendarView: View {
    @Environment(AppModel.self) private var model
    @State private var month = CivilDate.today().firstOfMonth
    @State private var selected = CivilDate.today()
    @State private var filter: CalendarFilter = .all
    @State private var syncing = false
    @State private var editing: EntryEditorRequest?
    @State private var recording: EkadashiOccurrence?

    private var years: [Int] { model.repository?.availableYears ?? [CivilDate.today().year] }
    private var firstDay: CivilDate { CivilDate(years.first ?? month.year, 1, 1) }
    private var lastDay: CivilDate { CivilDate(years.last ?? month.year, 12, 31) }
    private var isFirstMonth: Bool { month == firstDay.firstOfMonth }
    private var isLastMonth: Bool { month == lastDay.firstOfMonth }

    private var entries: (list: [CalendarEntry], failed: Bool) {
        _ = model.entriesRevision
        do { return (try model.entries.all(), false) } catch { return ([], true) }
    }

    private var selectedEkadashi: EkadashiOccurrence? { model.ekadashis.first { $0.date == selected } }

    var body: some View {
        let loaded = entries
        ScrollView {
            VStack(spacing: 12) {
                if loaded.failed {
                    HStack {
                        Text(model.t("storage_failed"))
                        Spacer()
                        Button(model.t("retry")) { model.entriesChanged() }
                    }
                    .padding(.horizontal, 16)
                }
                actions
                filterBar
                yearAndMonth
                if selectedEkadashi == nil && filter == .ekadashi {
                    Text(model.t("no_ekadashi")).font(.subheadline).foregroundStyle(.secondary)
                }
                MonthGrid(month: month, selected: selected, today: CivilDate.today(), firstDay: firstDay, lastDay: lastDay,
                          markers: { markers(for: $0, loaded.list) }, select: { selected = $0 })
                    .padding(.horizontal, 12)
                    .gesture(DragGesture(minimumDistance: 30).onEnded { value in
                        if value.translation.width < -60 { move(1) } else if value.translation.width > 60 { move(-1) }
                    })
                if let event = selectedEkadashi, filter == .all || filter == .ekadashi {
                    CalendarEkadashiCard(event: event) { recording = event }
                        .padding(.horizontal, 16)
                }
                if filter != .ekadashi {
                    DayEntriesList(day: selected, entries: loaded.list, filter: filter,
                                   edit: { editing = EntryEditorRequest(day: selected, existing: $0) },
                                   delete: delete)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 100)
        }
        .sheet(item: $editing) { EntryEditorView(request: $0) }
        .sheet(item: $recording) { RecordVratSheet(event: $0) }
        .onAppear { focusInitial() }
        .onChange(of: model.calendarFocus) { _, date in
            guard let date else { return }
            focus(date)
            model.calendarFocus = nil
        }
    }

    // MARK: Header

    private var actions: some View {
        HStack {
            Spacer()
            GlassGroup(spacing: 4) {
                HStack(spacing: 4) {
                    iconButton("plus", "add_entry", id: "add_calendar_entry", disabled: entries.failed) {
                        editing = EntryEditorRequest(day: selected, existing: nil)
                    }
                    if syncing {
                        ProgressView().frame(width: 44, height: 44)
                    } else {
                        iconButton("arrow.triangle.2.circlepath", "sync_google", id: "import_google_year", disabled: false) {
                            Task { await sync() }
                        }
                    }
                    iconButton("link.badge.minus", "disconnect_google", id: "disconnect_google", disabled: syncing) {
                        Task { await disconnect() }
                    }
                }
                .padding(.horizontal, 6)
                .glassCapsule(interactive: false)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("calendar_actions_tube")
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    private func iconButton(_ symbol: String, _ key: String, id: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.title3).foregroundStyle(Theme.teal).frame(width: 44, height: 44)
        }
        .disabled(disabled)
        .accessibilityLabel(model.t(key))
        .accessibilityIdentifier(id)
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            GlassGroup(spacing: 8) {
                HStack(spacing: 8) {
                    chip(.all, "filter_all", Theme.teal)
                    chip(.ekadashi, "filter_ekadashi", Theme.teal)
                    chip(.google, "filter_google", Theme.googleBlue)
                    chip(.custom, "filter_custom", Theme.customPurple)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func chip(_ value: CalendarFilter, _ key: String, _ color: Color) -> some View {
        GlassChip(title: model.t(key), color: color, selected: filter == value) { filter = value }
    }

    private var yearAndMonth: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Text(model.t("year"))
                Menu {
                    ForEach(years, id: \.self) { year in
                        Button(String(year)) { selectYear(year) }
                    }
                } label: {
                    Label(String(month.year), systemImage: "chevron.up.chevron.down").labelStyle(TrailingIconLabel())
                }
                .accessibilityIdentifier("calendar_year_selector")
                Spacer()
            }
            .padding(.horizontal, 24)
            HStack {
                Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    .disabled(isFirstMonth)
                    .accessibilityLabel(model.format(month.adding(months: -1), "MMMM yyyy"))
                    .accessibilityIdentifier("calendar_previous_month")
                Spacer()
                Text(model.format(month, "MMMM yyyy")).font(.headline)
                Spacer()
                Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                    .disabled(isLastMonth)
                    .accessibilityLabel(model.format(month.adding(months: 1), "MMMM yyyy"))
                    .accessibilityIdentifier("calendar_next_month")
            }
            .foregroundStyle(Theme.teal)
            .padding(.horizontal, 8)
            .glassCapsule(interactive: false)
            .padding(.horizontal, 12)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("calendar_month_tube")
        }
    }

    // MARK: Navigation

    private func focusInitial() {
        if month < firstDay.firstOfMonth || month > lastDay.firstOfMonth { focus(CivilDate.today()) }
    }

    /// Today, clamped to the data years.
    private func focus(_ date: CivilDate) {
        let target = min(max(date, firstDay), lastDay)
        selected = target
        month = target.firstOfMonth
    }

    /// Another year opens on its January; the current year opens on today.
    private func selectYear(_ year: Int) {
        let today = CivilDate.today()
        focus(year == today.year ? today : CivilDate(year, 1, 1))
    }

    private func move(_ months: Int) {
        let target = month.adding(months: months).firstOfMonth
        guard target >= firstDay.firstOfMonth, target <= lastDay.firstOfMonth else { return }
        withAnimation(.easeInOut(duration: 0.3)) { month = target }
    }

    private func markers(for day: CivilDate, _ list: [CalendarEntry]) -> [Color] {
        var colors: [Color] = []
        let zone = TimeZone.current
        if (filter == .all || filter == .ekadashi) && model.ekadashis.contains(where: { $0.date == day }) { colors.append(Theme.teal) }
        if (filter == .all || filter == .google) && list.contains(where: { $0.source == .google && $0.occurs(on: day, in: zone) }) {
            colors.append(Theme.googleBlue)
        }
        if (filter == .all || filter == .custom) && list.contains(where: { $0.source == .custom && $0.occurs(on: day, in: zone) }) {
            colors.append(Theme.customPurple)
        }
        return colors
    }

    // MARK: Google and entries

    private func sync() async {
        guard !syncing else { return }
        syncing = true
        _ = await model.coordinator.sync(viewedMonth: month, now: Date(), calendarYears: model.calendarYears)
        model.entriesChanged()
        syncing = false
    }

    /// Premium belongs to the App Store purchase, not the Google sign-in.
    private func disconnect() async {
        guard !syncing else { return }
        syncing = true
        do { try await model.coordinator.disconnect() } catch { model.show("google_sync_failed") }
        model.entriesChanged()
        syncing = false
    }

    private func delete(_ entry: CalendarEntry) {
        do {
            try model.entries.delete(id: entry.id)
            model.entriesChanged()
        } catch {
            model.show("storage_failed")
        }
    }
}

private struct TrailingIconLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) { configuration.title; configuration.icon.imageScale(.small) }
    }
}

/// A month grid, Sunday first like the Android calendar, with up to three
/// marker dots per day.
struct MonthGrid: View {
    @Environment(AppModel.self) private var model
    let month: CivilDate
    let selected: CivilDate
    let today: CivilDate
    let firstDay: CivilDate
    let lastDay: CivilDate
    let markers: (CivilDate) -> [Color]
    let select: (CivilDate) -> Void

    private var weekdays: [String] {
        let formatter = DateFormatter()
        formatter.locale = model.locale
        return formatter.veryShortStandaloneWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
    }

    var body: some View {
        // CivilDate.weekday is Dart's (Monday 1 ... Sunday 7).
        let leading = month.weekday % 7
        let days = (0..<month.daysInMonth).map { month.adding(days: $0) }
        let cells: [CivilDate?] = Array(repeating: nil, count: leading) + days
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(weekdays.enumerated()), id: \.offset) { _, symbol in
                Text(symbol).font(.subheadline.weight(.medium)).frame(height: 28)
            }
            ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                if let day { cell(day) } else { Color.clear.frame(height: 48) }
            }
        }
    }

    private func cell(_ day: CivilDate) -> some View {
        let isSelected = day == selected, isToday = day == today
        let enabled = day >= firstDay && day <= lastDay
        let dots = markers(day)
        return Button {
            select(day)
        } label: {
            ZStack(alignment: .bottom) {
                Text("\(day.day)")
                    .font(.callout.weight(isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? .white : (enabled ? .primary : .secondary))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(isSelected ? Theme.teal : (isToday ? Theme.teal.opacity(0.5) : .clear)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack(spacing: 2) {
                    ForEach(Array(dots.enumerated()), id: \.offset) { _, color in Circle().fill(color).frame(width: 6, height: 6) }
                }
                .padding(.bottom, 1)
            }
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(model.format(day, "d MMMM yyyy"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The selected day's Ekadashi with View Details and the Vrat button.
struct CalendarEkadashiCard: View {
    @Environment(AppModel.self) private var model
    let event: EkadashiOccurrence
    let record: () -> Void

    var body: some View {
        let status = model.vrat.record(for: event.occurrenceUid)?.status
        let style = VratStatusStyle(status)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(event.name).font(.headline).foregroundStyle(Theme.teal)
                Spacer()
                if model.vrat.isEnabled {
                    StatusPill(text: model.t(style.listKey), systemImage: style.symbol, color: style.color)
                }
            }
            Text("\(model.t("start_fasting")): \(event.fastStartTime)").font(.subheadline)
            Text("\(model.t("break_fasting")): \(EkadashiDisplay.breakTime(event))").font(.subheadline)
            Text(model.format(event.date, "EEEE, MMM dd, yyyy")).font(.caption).foregroundStyle(.secondary)
            GlassGroup {
                HStack(spacing: 8) {
                    NavigationLink {
                        EkadashiDetailsView(event: event)
                    } label: {
                        Text(model.t("view_details")).font(.footnote.bold()).frame(maxWidth: .infinity)
                    }
                    .primaryActionStyle()
                    if model.vrat.isEnabled {
                        Button(action: record) {
                            Text(model.t(status == nil ? "record_vrat" : "edit_record")).font(.footnote.bold()).frame(maxWidth: .infinity)
                        }
                        .secondaryActionStyle()
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("calendar_card_actions_tube")
        }
        .padding(16)
        .glassPanel(cornerRadius: 18)
    }
}

/// Google and custom entries of one day; custom entries are editable and
/// swipe to delete. Google times are shown in the device time zone.
struct DayEntriesList: View {
    @Environment(AppModel.self) private var model
    let day: CivilDate
    let entries: [CalendarEntry]
    let filter: CalendarFilter
    let edit: (CalendarEntry) -> Void
    let delete: (CalendarEntry) -> Void

    var body: some View {
        let zone = TimeZone.current
        let items = entries
            .filter { $0.occurs(on: day, in: zone) }
            .filter { entry in
                switch filter {
                case .all: return true
                case .google: return entry.source == .google
                case .custom: return entry.source == .custom
                case .ekadashi: return false
                }
            }
            .sorted { $0.interval(in: zone).0 < $1.interval(in: zone).0 }
        if items.isEmpty {
            Text(model.t("no_entries")).font(.subheadline).foregroundStyle(.secondary).padding(24)
        } else {
            VStack(spacing: 8) {
                ForEach(items) { entry in row(entry) }
            }
        }
    }

    private func row(_ entry: CalendarEntry) -> some View {
        let color = entry.source == .google ? Theme.googleBlue : Theme.customPurple
        let subtitle = [time(entry), entry.notes ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4).fill(color).frame(width: 10, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title).font(.subheadline.weight(.semibold)).foregroundStyle(color)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            if entry.source == .custom { Image(systemName: "pencil").font(.footnote).foregroundStyle(.secondary) }
        }
        .padding(12)
        .glassPanel(cornerRadius: 14)
        .contentShape(Rectangle())
        .onTapGesture { if entry.source == .custom { edit(entry) } }
        .contextMenu {
            if entry.source == .custom {
                Button(model.t("edit_entry"), systemImage: "pencil") { edit(entry) }
                Button(model.t("delete_record"), systemImage: "trash", role: .destructive) { delete(entry) }
            }
        }
    }

    private func time(_ entry: CalendarEntry) -> String {
        if entry.isAllDay { return model.t("all_day") }
        let formatter = DateFormatter()
        formatter.locale = model.locale
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "\(formatter.string(from: entry.start)) – \(formatter.string(from: entry.end))"
    }
}
