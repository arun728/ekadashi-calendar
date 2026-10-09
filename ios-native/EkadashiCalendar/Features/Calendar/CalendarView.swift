import SwiftUI
import EkadashiCore

/// Month calendar of every data year with Ekadashi, Google and custom
/// entries (calendar_screen.dart). Google import is free once (the viewed
/// month) and Premium afterwards; see GoogleSyncCoordinator.
///
/// Layout (docs/ROADMAP.md Phase 4): Today at the top left, Add and the
/// Google actions at the top right, filter chips, then the month title
/// (tap for a month and year picker) with arrows, the grid (swipe between
/// months) and the selected day. Recording a fast lives on Home and
/// Journey only.
struct CalendarView: View {
    @Environment(AppModel.self) private var model
    @State private var month = CivilDate.today().firstOfMonth
    @State private var selected = CivilDate.today()
    @State private var filter: CalendarFilter = .all
    @State private var syncing = false
    @State private var editing: EntryEditorRequest?
    @State private var pickingMonth = false

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
                filterBar
                // A horizontal swipe on the month title, the grid or the
                // selected day changes the month, as on Android.
                VStack(spacing: 12) {
                    monthHeader
                    MonthGrid(month: month, selected: selected, today: CivilDate.today(), firstDay: firstDay, lastDay: lastDay,
                              markers: { markers(for: $0, loaded.list) }, select: { selected = $0 })
                        .padding(.horizontal, 12)
                    selectedDay(loaded.list)
                }
                .contentShape(Rectangle())
                .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { value in
                    let dx = value.translation.width, dy = value.translation.height
                    guard abs(dx) > 60, abs(dx) > abs(dy) else { return }
                    move(dx < 0 ? 1 : -1)
                })
            }
            .padding(.top, 4)
            .padding(.bottom, 100)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(model.t("today")) { focus(CivilDate.today()) }
                    .disabled(selected == CivilDate.today() && month == CivilDate.today().firstOfMonth)
                    .accessibilityIdentifier("calendar_today")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { editing = EntryEditorRequest(day: selected, existing: nil) } label: { Image(systemName: "plus") }
                    .disabled(loaded.failed)
                    .accessibilityLabel(model.t("add_entry"))
                    .accessibilityIdentifier("add_calendar_entry")
                googleMenu
            }
        }
        .sheet(item: $editing) { EntryEditorView(request: $0) }
        .sheet(isPresented: $pickingMonth) {
            PanchangMonthPicker(month: month, years: years.first.map { $0...(years.last ?? $0) }) { focusMonth($0) }
                .presentationDetents([.height(320)])
        }
        .onAppear { focusInitial() }
        .onChange(of: model.calendarFocus) { _, date in
            guard let date else { return }
            focus(date)
            model.calendarFocus = nil
        }
    }

    // MARK: Header

    @ViewBuilder
    private var googleMenu: some View {
        if syncing {
            ProgressView().tint(Theme.teal)
        } else {
            Menu {
                Button { Task { await sync() } } label: {
                    Label(model.t("sync_google"), systemImage: "arrow.triangle.2.circlepath")
                }
                .accessibilityIdentifier("import_google_year")
                Button(role: .destructive) { Task { await disconnect() } } label: {
                    Label(model.t("disconnect_google"), systemImage: "person.crop.circle.badge.minus")
                }
                .accessibilityIdentifier("disconnect_google")
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.circle")
            }
            .accessibilityLabel(model.t("google_calendar"))
            .accessibilityIdentifier("calendar_google_menu")
        }
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

    /// The selected date opens the month and year picker; arrows step months.
    private var monthHeader: some View {
        HStack(spacing: 0) {
            Button { pickingMonth = true } label: {
                HStack(spacing: 6) {
                    // The selected date in full, as on every tab.
                    Text(model.fullDate(selected)).font(.title3.weight(.bold)).foregroundStyle(.primary)
                    Image(systemName: "chevron.down").font(.footnote.weight(.bold)).foregroundStyle(Theme.teal)
                }
            }
            .accessibilityIdentifier("calendar_year_selector")
            Spacer()
            Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                .disabled(isFirstMonth)
                .accessibilityLabel(model.fullDate(selected.steppingMonths(-1)))
                .accessibilityIdentifier("calendar_previous_month")
            Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                .disabled(isLastMonth)
                .accessibilityLabel(model.fullDate(selected.steppingMonths(1)))
                .accessibilityIdentifier("calendar_next_month")
        }
        .foregroundStyle(Theme.teal)
        .padding(.horizontal, 20)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("calendar_month_tube")
    }

    @ViewBuilder
    private func selectedDay(_ list: [CalendarEntry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let event = selectedEkadashi, filter == .all || filter == .ekadashi {
                CalendarEkadashiCard(event: event)
            } else if filter == .ekadashi {
                Text(model.t("no_ekadashi")).font(.subheadline).foregroundStyle(.secondary)
            }
            if filter != .ekadashi {
                DayEntriesList(day: selected, entries: list, filter: filter,
                               edit: { editing = EntryEditorRequest(day: selected, existing: $0) }, delete: delete)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: Navigation

    private func focusInitial() {
        if month < firstDay.firstOfMonth || month > lastDay.firstOfMonth { focus(CivilDate.today()) }
    }

    /// Today, clamped to the data years.
    private func focus(_ date: CivilDate) {
        let target = min(max(date, firstDay), lastDay)
        selected = target
        withAnimation(.easeInOut(duration: 0.25)) { month = target.firstOfMonth }
    }

    /// A picked month selects today when it is this month, else its first day.
    private func focusMonth(_ picked: CivilDate) {
        let today = CivilDate.today()
        focus(picked.firstOfMonth == today.firstOfMonth ? today : picked.firstOfMonth)
    }

    /// A new month keeps the day of the month selected (its last day when
    /// shorter), within the data years.
    private func move(_ months: Int) {
        let target = month.adding(months: months).firstOfMonth
        guard target >= firstDay.firstOfMonth, target <= lastDay.firstOfMonth else { return }
        selected = min(max(selected.steppingMonths(months), firstDay), lastDay)
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
        .accessibilityLabel(model.fullDate(day))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The selected day's Ekadashi with its times and View Details. Recording
/// the fast happens on Home and Journey.
struct CalendarEkadashiCard: View {
    @Environment(AppModel.self) private var model
    let event: EkadashiOccurrence

    var body: some View {
        let status = model.vrat.record(for: event.occurrenceUid)?.status
        let style = VratStatusStyle(status)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(event.name).font(.headline).foregroundStyle(Theme.teal)
                Spacer()
                if model.vrat.isEnabled, status != nil {
                    StatusPill(text: model.t(style.listKey), systemImage: style.symbol, color: style.color)
                }
            }
            Text("\(model.t("start_fasting")): \(event.fastStartTime)").font(.subheadline)
            Text("\(model.t("break_fasting")): \(EkadashiDisplay.breakTime(event))").font(.subheadline)
            NavigationLink {
                EkadashiDetailsView(event: event)
            } label: {
                Text(model.t("view_details")).font(.footnote.bold()).frame(maxWidth: .infinity)
            }
            .primaryActionStyle()
            .accessibilityIdentifier("calendar_view_details")
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
