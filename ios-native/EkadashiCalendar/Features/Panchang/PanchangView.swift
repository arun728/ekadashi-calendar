import SwiftUI
import EkadashiCore

/// Panchang (docs/ROADMAP.md Phases 2 and 3): calculated offline for any
/// location and date, in the app language. Key days (the month's
/// Ekadashis, Amavasya, Purnima, Shivaratri and festivals) comes first.
/// Free: published Ekadashis in Key days, the day's tithi, sun and moon
/// times, the day's festival names and the calculated Ekadashi list.
/// Premium: the other Key days, the five limbs, timings, Muhurta and Rashi.
struct PanchangView: View {
    enum Page: String, CaseIterable {
        case keyDays = "keydays", daily, muhurta, ekadashi, rashi

        var titleKey: String { "panchang_section_\(rawValue)" }
        /// Sections that browse a month rather than a day.
        var isMonthly: Bool { self == .keyDays || self == .ekadashi }
    }

    @Environment(AppModel.self) private var model
    var initialDate: CivilDate?
    var initialCity: PanchangCity?

    @State private var city = PanchangCity.newDelhi
    @State private var date = PanchangCity.newDelhi.today()
    @State private var month = PanchangCity.newDelhi.today().firstOfMonth
    @State private var day: PanchangDay?
    @State private var section: Page = .keyDays
    @State private var tradition: EkadashiTradition = .smarta
    @State private var editingLocation = false
    @State private var pickingDate = false
    @State private var pickingMonth = false
    @State private var showingNotes = false
    @State private var started = false
    @State private var toast: ToastMessage?

    private var language: String { model.language }
    private var isToday: Bool { section.isMonthly ? month == city.today().firstOfMonth : date == city.today() }

    var body: some View {
        VStack(spacing: 0) {
            sectionBar
            // The sections also change with a horizontal swipe.
            TabView(selection: $section) {
                ForEach(Page.allCases, id: \.self) { page in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            controls(page)
                            content(page)
                        }
                        .padding(EdgeInsets(top: 8, leading: 16, bottom: 100, trailing: 16))
                    }
                    .tag(page)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(model.t("today")) { goToToday() }
                    .disabled(isToday)
                    .accessibilityIdentifier("panchang_today")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingNotes = true } label: { Image(systemName: "info.circle") }
                    .accessibilityLabel(model.t("panchang_notes_title"))
                    .accessibilityIdentifier("panchang_notes")
            }
        }
        .sheet(isPresented: $editingLocation) {
            PanchangLocationSheet(city: city) { changeCity($0) }
        }
        .sheet(isPresented: $pickingDate) { datePicker }
        .sheet(isPresented: $pickingMonth) {
            PanchangMonthPicker(month: month) { month = $0 }
                .presentationDetents([.height(320)])
        }
        .sheet(isPresented: $showingNotes) { PanchangNotesSheet() }
        .toast($toast)
        .onAppear {
            start()
            openFocus()
        }
        .onChange(of: model.panchangFocus) { _, _ in openFocus() }
        .task(id: "\(city.id)|\(city.latitude)|\(city.longitude)|\(city.timeZoneId)|\(date.iso)") { await recalculate() }
    }

    // MARK: Header

    private var sectionBar: some View {
        SectionChips(Page.allCases, selection: $section, title: { model.t($0.titleKey) },
                     identifier: { "panchang_tab_\($0.rawValue)" })
    }

    /// The location, then the month or day being shown.
    private func controls(_ page: Page) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                locationMenu
                Spacer(minLength: 0)
                if city.timeZoneId != "Asia/Kolkata" {
                    Text(city.timeZoneLabel(language: language)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            if page.isMonthly {
                stepper(title: PanchangFormat.monthTitle(month, language: language), symbol: "calendar", monthly: true,
                        previous: { month = month.adding(months: -1) }, next: { month = month.adding(months: 1) },
                        pick: { pickingMonth = true }, id: "panchang_selected_month")
            } else {
                stepper(title: PanchangFormat.date(date, language: language), symbol: "calendar", monthly: false,
                        previous: { date = date.adding(days: -1) }, next: { date = date.adding(days: 1) },
                        pick: { pickingDate = true }, id: "panchang_selected_date")
            }
        }
    }

    private var locationMenu: some View {
        Menu {
            Section {
                ForEach(Array(Set(PanchangCity.supported + [city])).sorted { $0.label < $1.label }, id: \.self) { item in
                    Button { changeCity(item) } label: {
                        let name = PlaceNames.shared.label(item.label, language: language)
                        if item == city { Label(name, systemImage: "checkmark") } else { Text(name) }
                    }
                }
            }
            Button { editingLocation = true } label: {
                Label(model.t("panchang_search_location"), systemImage: "magnifyingglass")
            }
            .accessibilityIdentifier("panchang_edit_location")
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse").foregroundStyle(Theme.teal)
                Text(PlaceNames.shared.label(city.label, language: language)).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .glassCapsule()
        }
        .accessibilityIdentifier("panchang_city_selector")
    }

    private func stepper(title: String, symbol: String, monthly: Bool, previous: @escaping () -> Void, next: @escaping () -> Void,
                         pick: @escaping () -> Void, id: String) -> some View {
        HStack(spacing: 0) {
            Button(action: previous) { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                .accessibilityLabel(model.t("panchang_previous"))
                .accessibilityIdentifier(monthly ? "panchang_previous_month" : "panchang_previous_day")
            Spacer(minLength: 4)
            Button(action: pick) {
                HStack(spacing: 6) {
                    Image(systemName: symbol).font(.subheadline)
                    Text(title).font(.headline).lineLimit(1).minimumScaleFactor(0.8)
                }
                .foregroundStyle(.primary)
            }
            .accessibilityIdentifier(id)
            Spacer(minLength: 4)
            Button(action: next) { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                .accessibilityLabel(model.t("panchang_next"))
                .accessibilityIdentifier(monthly ? "panchang_next_month" : "panchang_next_day")
        }
        .foregroundStyle(Theme.teal)
        .padding(.horizontal, 4)
        .glassPanel(cornerRadius: 16)
    }

    private var datePicker: some View {
        NavigationStack {
            DatePicker(model.t("panchang_pick_date"),
                       selection: Binding(get: { date.utcMidnight }, set: { date = CivilDate(utc: $0) }),
                       in: CivilDate(1900, 1, 1).utcMidnight...CivilDate(2100, 12, 31).utcMidnight, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.timeZone, TimeZone(identifier: "UTC")!)
                .environment(\.locale, model.locale)
                .tint(Theme.teal)
                .padding()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button(model.t("panchang_done")) { pickingDate = false } }
                    ToolbarItem(placement: .cancellationAction) {
                        Button(model.t("today")) {
                            date = city.today()
                            pickingDate = false
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ page: Page) -> some View {
        switch page {
        case .keyDays:
            PanchangKeyDaysView(month: month, city: city) { selected in
                date = selected
                withAnimation(.snappy) { section = .daily }
            }
        case .ekadashi:
            PanchangEkadashiPanel(month: month, city: city, tradition: $tradition)
        case .daily:
            if let day {
                PanchangDailyView(day: day)
            } else {
                loading
            }
        case .muhurta:
            if !model.premium.isPremium {
                PanchangUpgradeCard()
            } else if let day {
                PanchangMuhurtaView(day: day)
            } else {
                loading
            }
        case .rashi:
            if !model.premium.isPremium {
                PanchangUpgradeCard()
            } else if let day {
                PanchangRashiView(day: day)
            } else {
                loading
            }
        }
    }

    private var loading: some View {
        ProgressView().tint(Theme.teal).frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: State

    private func start() {
        guard !started else { return }
        started = true
        let saved = initialCity ?? PanchangLocationStore(store: model.store).load() ?? .newDelhi
        city = saved
        date = initialDate ?? saved.today()
        month = date.firstOfMonth
        if initialDate != nil { section = .daily }
    }

    private func recalculate() async {
        start()
        let city = self.city, date = self.date
        let result = await Task.detached(priority: .userInitiated) { PanchangEngine().calculate(date, city: city) }.value
        if city == self.city && date == self.date { day = result }
    }

    /// A day opened from an event reminder (the Panchang tab only).
    private func openFocus() {
        guard initialDate == nil, let focus = model.panchangFocus else { return }
        model.panchangFocus = nil
        date = focus
        month = focus.firstOfMonth
        section = .daily
    }

    private func goToToday() {
        date = city.today()
        month = date.firstOfMonth
    }

    /// A new city keeps "today" on the new city's today.
    private func changeCity(_ newCity: PanchangCity) {
        guard newCity != city else { return }
        let wasToday = date == city.today()
        city = newCity
        if wasToday { date = newCity.today() }
        guard initialCity == nil else { return }
        do {
            try PanchangLocationStore(store: model.store).save(newCity)
            // Festival reminders follow the Panchang location.
            Task { await model.scheduleReminders() }
        } catch {
            toast = ToastMessage(text: model.t("panchang_location_not_saved"))
        }
    }
}

/// Month and year wheels (Apple's pattern for choosing a month).
struct PanchangMonthPicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let month: CivilDate
    /// The years offered (the Calendar's data years); any year by default.
    var years: ClosedRange<Int>? = nil
    let onPick: (CivilDate) -> Void
    @State private var selectedMonth = 1
    @State private var selectedYear = 2026

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker(model.t("panchang_month"), selection: $selectedMonth) {
                    ForEach(1...12, id: \.self) { value in
                        Text(PanchangFormat.format(CivilDate(2026, value, 1), "LLLL", model.language)).tag(value)
                    }
                }
                Picker(model.t("year"), selection: $selectedYear) {
                    ForEach(Array(years ?? 1900...2100), id: \.self) { value in Text(String(value)).tag(value) }
                }
            }
            .pickerStyle(.wheel)
            .padding(.horizontal)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(model.t("cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.t("panchang_done")) {
                        onPick(CivilDate(selectedYear, selectedMonth, 1))
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            selectedMonth = month.month
            selectedYear = month.year
        }
    }
}

/// How the Panchang is calculated, in a few lines (replaces the Guide tab).
struct PanchangNotesSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(model.t("panchang_notes_body")).font(.body)
                    Text(model.t("panchang_notes_traditions")).font(.body)
                    Text(model.t("panchang_notes_sources")).font(.footnote).foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .navigationTitle(model.t("panchang_notes_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(model.t("panchang_done")) { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// The paywall card for Premium Panchang sections.
struct PanchangUpgradeCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(model.t("panchang_premium_title"), systemImage: "lock.fill")
                .font(.headline).foregroundStyle(Theme.amber)
            Text(model.t("panchang_premium_body")).font(.subheadline).foregroundStyle(.secondary)
            Button {
                model.openPaywall()
            } label: {
                Label(model.t("panchang_unlock"), systemImage: "star.fill").frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .primaryActionStyle()
            .padding(.top, 4)
            .accessibilityIdentifier("panchang_unlock_button")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 22, tint: Theme.teal)
    }
}

/// A titled glass card.
struct PanchangCard<Content: View>: View {
    let title: String
    var symbol: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol).foregroundStyle(Theme.teal) }
                Text(title).font(.headline)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 20)
    }
}

/// A label on the left and a value on the right, wrapping when needed.
struct PanchangRow: View {
    let label: String
    let value: String
    var detail: String?
    var color: Color?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let color { Circle().fill(color).frame(width: 8, height: 8) }
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(value).font(.subheadline.weight(.semibold)).multilineTextAlignment(.trailing)
                if let detail { Text(detail).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.trailing) }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
