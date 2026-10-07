import SwiftUI
import EkadashiCore

/// Panchang (panchang_screen.dart): English-only by design, calculated
/// offline for any location and date with its IANA timezone. The daily
/// preview, today's vrat/festival names, the calculated Ekadashi list and
/// the guide are free; the full limbs, Muhurta, Rashi and the festival
/// finder are Premium.
struct PanchangView: View {
    enum Section: String, CaseIterable { case daily = "Daily", muhurta = "Muhurta", ekadashi = "Ekadashi", rashi = "Rashi",
                                         festivals = "Festivals", guide = "Guide" }

    @Environment(AppModel.self) private var model
    var initialDate: CivilDate?
    var initialCity: PanchangCity?

    @State private var city = PanchangCity.newDelhi
    @State private var date = PanchangCity.newDelhi.today()
    @State private var day: PanchangDay?
    @State private var section: Section = .daily
    @State private var tradition: EkadashiTradition = .smarta
    @State private var editingLocation = false
    @State private var pickingDate = false
    @State private var started = false
    @State private var toast: ToastMessage?

    private var premium: Bool { model.premium.isPremium }
    private var isToday: Bool { date == city.today() }

    var body: some View {
        VStack(spacing: 0) {
            sectionBar
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header.id("top")
                        content
                    }
                    .padding(EdgeInsets(top: 16, leading: 20, bottom: 100, trailing: 20))
                }
                .onChange(of: section) { _, _ in proxy.scrollTo("top", anchor: .top) }
            }
        }
        .sheet(isPresented: $editingLocation) {
            PanchangLocationSheet(city: city) { changeCity($0) }
        }
        .sheet(isPresented: $pickingDate) { datePicker }
        .toast($toast)
        .onAppear { start() }
        .task(id: "\(city.id)|\(city.latitude)|\(city.longitude)|\(city.timeZoneId)|\(date.iso)") { await recalculate() }
    }

    // MARK: Header

    private var sectionBar: some View {
        ScrollView(.horizontal) {
            GlassGroup(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(Section.allCases, id: \.self) { item in
                        GlassChip(title: item.rawValue, selected: section == item) { section = item }
                            .accessibilityIdentifier("panchang_tab_\(item.rawValue.lowercased())")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    title
                    Spacer()
                    cityMenu.frame(maxWidth: 200)
                }
                VStack(alignment: .leading, spacing: 8) {
                    title
                    cityMenu
                }
            }
            Text("\(city.timezoneLabel) · English").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.teal)
            Button {
                editingLocation = true
            } label: {
                Label("Search city / use location", systemImage: "mappin.and.ellipse")
            }
            .font(.subheadline)
            .accessibilityIdentifier("panchang_edit_location")
            HStack {
                Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    .accessibilityLabel("Previous day")
                    .accessibilityIdentifier("panchang_previous_day")
                Spacer()
                VStack(spacing: 2) {
                    Button { pickingDate = true } label: {
                        Text(formatPanchangDate(date)).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
                            .foregroundStyle(.primary)
                    }
                    .accessibilityIdentifier("panchang_selected_date")
                    if !isToday {
                        Button("Today") { date = city.today() }.font(.caption)
                    }
                }
                Spacer()
                Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                    .accessibilityLabel("Next day")
                    .accessibilityIdentifier("panchang_next_day")
            }
            .foregroundStyle(Theme.teal)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .glassPanel(cornerRadius: 18)
            .padding(.top, 7)
        }
    }

    private var title: some View {
        Text("Panchang").font(.largeTitle.bold())
    }

    private var cityMenu: some View {
        Menu {
            ForEach(Array(Set(PanchangCity.supported + [city])).sorted { $0.label < $1.label }, id: \.self) { item in
                Button(item.label) { changeCity(item) }
            }
        } label: {
            HStack {
                Text(city.label).lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.down").font(.caption)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassCapsule()
        }
        .accessibilityIdentifier("panchang_city_selector")
    }

    private var datePicker: some View {
        NavigationStack {
            DatePicker("Date", selection: Binding(get: { date.utcMidnight }, set: { date = CivilDate(utc: $0) }),
                       in: CivilDate(1900, 1, 1).utcMidnight...CivilDate(2100, 12, 31).utcMidnight, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.timeZone, TimeZone(identifier: "UTC")!)
                .environment(\.locale, Locale(identifier: "en_US"))
                .padding()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { pickingDate = false } }
                }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch section {
        case .daily:
            if let day {
                PanchangHero(day: day)
                if premium {
                    PanchangLimbGrid(day: day)
                    PanchangExtendedDetails(day: day)
                    PanchangObservancesPanel(day: day)
                    Label("Festival dates follow the displayed sunrise, sunset or night rule. Regional and community traditions can differ; Amanta and Purnimanta month names are shown in the calculation notes.",
                          systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    PanchangFreePreview(day: day)
                    PanchangUpgradeCard()
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 200)
            }
        case .ekadashi:
            PanchangEkadashiPanel(month: date.firstOfMonth, city: city, tradition: $tradition)
        case .guide:
            PanchangGuide()
        case .muhurta, .rashi, .festivals:
            if !premium {
                PanchangUpgradeCard()
            } else if section == .festivals {
                NavigationLink {
                    PanchangFestivalExplorer()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "party.popper").foregroundStyle(Theme.teal)
                        VStack(alignment: .leading) {
                            Text("Festival finder").font(.headline)
                            Text("Browse calculated observances for your saved location").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .glassPanel(cornerRadius: 18, interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("panchang_festival_finder")
            } else if let day {
                if section == .muhurta {
                    PanchangTimingPanel(day: day)
                    PanchangMuhurtaPanel(day: day)
                } else {
                    PanchangRashiPanel(day: day)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 200)
            }
        }
    }

    // MARK: State

    private func start() {
        guard !started else { return }
        started = true
        if let initialCity {
            city = initialCity
            date = initialDate ?? initialCity.today()
        } else {
            let saved = PanchangLocationStore(store: model.store).load() ?? .newDelhi
            city = saved
            date = initialDate ?? saved.today()
        }
    }

    private func recalculate() async {
        start()
        let city = self.city, date = self.date
        let result = await Task.detached(priority: .userInitiated) { PanchangEngine().calculate(date, city: city) }.value
        if city == self.city && date == self.date { day = result }
    }

    private func move(_ days: Int) { date = date.adding(days: days) }

    /// A new city keeps "today" on the new city's today.
    private func changeCity(_ newCity: PanchangCity) {
        guard newCity != city else { return }
        let wasToday = isToday
        city = newCity
        if wasToday { date = newCity.today() }
        guard initialCity == nil else { return }
        do {
            try PanchangLocationStore(store: model.store).save(newCity)
        } catch {
            toast = ToastMessage(text: "Location changed, but could not be saved.")
        }
    }
}

// MARK: - Panels

struct PanchangPanel<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title3.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 24)
    }
}

/// Tithi at sunrise, its end, sunrise and sunset.
struct PanchangHero: View {
    let day: PanchangDay
    private func time(_ instant: Date?) -> String { formatPanchangTime(instant, city: day.city, date: day.date) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    label
                    Spacer()
                    Text("Amanta · \(day.amantaMonth)").font(.caption)
                }
                VStack(alignment: .leading, spacing: 5) {
                    label
                    Text("Amanta · \(day.amantaMonth)").font(.caption)
                }
            }
            Text("\(day.tithi.paksha ?? "") \(day.tithi.name)").font(.title2.bold())
                .accessibilityIdentifier("panchang_tithi_title")
            Text(day.tithi.endsAt == nil ? "Tithi transition unavailable" : "Changes at \(time(day.tithi.endsAt))")
                .font(.subheadline).foregroundStyle(.secondary)
            FlowLayout(spacing: 8) {
                pill("sun.max", "Sunrise", time(day.sunrise))
                pill("sunset", "Sunset", time(day.sunset))
            }
            .padding(.top, 6)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 28, tint: Theme.teal)
        .accessibilityIdentifier("panchang_daily_overview")
    }

    private var label: some View {
        Label(day.sunrise == nil ? "TITHI AT 06:00 · NO SUNRISE" : "TITHI AT SUNRISE", systemImage: "moon.fill")
            .font(.caption2.weight(.bold)).foregroundStyle(Theme.teal)
    }

    private func pill(_ symbol: String, _ title: String, _ value: String) -> some View {
        Label("\(title)  \(value)", systemImage: symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .glassCapsule(interactive: false)
    }
}

struct PanchangLimbGrid: View {
    let day: PanchangDay

    var body: some View {
        let limbs: [(String, String, Date?)] = [
            ("Tithi", "\(day.tithi.paksha ?? "") \(day.tithi.name)", day.tithi.endsAt),
            ("Nakshatra", day.nakshatra.name, day.nakshatra.endsAt),
            ("Yoga", day.yoga.name, day.yoga.endsAt),
            ("Karana", day.karana.name, day.karana.endsAt),
            ("Vara", day.vara, nil),
        ]
        VStack(alignment: .leading, spacing: 11) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Five limbs").font(.title3.bold())
                Text(day.sunrise == nil ? "No sunrise: limbs sampled at 06:00 local time" : "Panchang at local sunrise")
                    .font(.caption).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(limbs, id: \.0) { limb in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(limb.0).font(.caption.weight(.bold)).foregroundStyle(Theme.teal)
                        Text(limb.1).font(.headline).lineLimit(1)
                        if let end = limb.2 {
                            Text("Until \(formatPanchangTime(end, city: day.city, date: day.date))").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassPanel(cornerRadius: 20)
                }
            }
        }
    }
}

struct PanchangExtendedDetails: View {
    let day: PanchangDay
    private func time(_ instant: Date?) -> String { formatPanchangTime(instant, city: day.city, date: day.date) }

    var body: some View {
        PanchangPanel(title: "Detailed Panchang", subtitle: day.city.timezoneLabel) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Moonset · \(time(day.moonset))")
                Text("Surya Rashi · \(day.sunRashi)")
                Text("Chandra Rashi · \(day.moonRashi)")
                Text("Nakshatra Pada · \(day.nakshatraPada)")
                Text("Lahiri Ayanamsa · \(String(format: "%.4f", day.ayanamsa))°")
                Text("Ritu · \(day.ritu)")
                Text("Ayana · \(day.ayana)")
                Text("Shaka · \(day.shakaYear) / Vikrama · \(day.vikramaYear) (Chaitra start)")
                Text("Anandadi Yoga · \(day.anandadiYoga)")
                Text("Amanta · \(day.amantaMonth)")
                Text("Purnimanta · \(day.purnimantaMonth)")
                Text("At sunrise · \(day.specialYogas.isEmpty ? "No listed special yoga" : day.specialYogas.joined(separator: " · "))")
                if day.sunrise == nil || day.sunset == nil {
                    Text("No complete solar day at this location. Sunrise-based periods and observances are unavailable.")
                }
                Divider().padding(.vertical, 6)
                Text("Limb transitions · sunrise to next sunrise").font(.subheadline.weight(.semibold))
                ForEach(day.limbTimeline, id: \.name) { entry in
                    ForEach(Array(entry.limbs.enumerated()), id: \.offset) { _, limb in
                        Text("\(entry.name) · \(limb.paksha ?? "") \(limb.name) — until \(time(limb.endsAt))").padding(.top, 4)
                    }
                }
            }
            .font(.subheadline)
        }
    }
}

struct PanchangObservancesPanel: View {
    let day: PanchangDay

    var body: some View {
        PanchangPanel(title: "Observances", subtitle: "Calculated for \(day.city.label)") {
            if day.observances.isEmpty {
                Text("No supported observance rule matches this date.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(day.observances) { event in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: event.isMajor ? "sparkles" : "circle.fill")
                            .font(event.isMajor ? .body : .system(size: 7)).foregroundStyle(Theme.teal).frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.name).fontWeight(.semibold)
                            if !event.description.isEmpty {
                                Text(event.description).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Free: up to two major observances (today's vrat and festival names).
struct PanchangFreePreview: View {
    let day: PanchangDay

    var body: some View {
        let events = day.observances.filter(\.isMajor).prefix(2)
        PanchangPanel(title: "Today’s observances", subtitle: "A local preview") {
            if events.isEmpty {
                Text("Explore the full Panchang for observances and daily timings.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(Array(events)) { event in
                    Label(event.name, systemImage: "sparkles").symbolRenderingMode(.multicolor)
                }
            }
        }
    }
}

struct PanchangUpgradeCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Full Panchang · Premium", systemImage: "star.circle.fill").font(.headline).foregroundStyle(Theme.teal)
            Text("See all five limbs, lunar transitions, observances and city-specific daily timings.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button {
                model.openPaywall()
            } label: {
                Label("Unlock full Panchang", systemImage: "lock.open.fill").frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .primaryActionStyle()
            .padding(.top, 6)
            .accessibilityIdentifier("panchang_unlock_button")
        }
        .padding(18)
        .glassPanel(cornerRadius: 24, tint: Theme.teal)
    }
}

struct PanchangTimingPanel: View {
    let day: PanchangDay
    private func time(_ instant: Date?) -> String { formatPanchangTime(instant, city: day.city, date: day.date) }

    var body: some View {
        PanchangPanel(title: "Daily timings", subtitle: day.city.label) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Lunar month labels", systemImage: "moon")
                Text("Amanta · \(day.amantaMonth)")
                Text("Purnimanta · \(day.purnimantaMonth)").font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            ForEach([day.rahukala, day.yamaganda, day.gulika, day.abhijit, day.brahmaMuhurta].compactMap { $0 }, id: \.name) { period in
                HStack {
                    Label(period.name, systemImage: "clock")
                    Spacer()
                    Text("\(time(period.start)) – \(time(period.end))").font(.caption.weight(.semibold)).multilineTextAlignment(.trailing)
                }
            }
            Divider()
            HStack {
                Label("Moonrise", systemImage: "moonrise")
                Spacer()
                Text(time(day.moonrise)).font(.caption)
            }
        }
        .font(.subheadline)
    }
}

struct PanchangMuhurtaPanel: View {
    let day: PanchangDay

    var body: some View {
        PanchangPanel(title: "Additional periods", subtitle: "Local sunrise to next sunrise") {
            if day.additionalPeriods.isEmpty { Text("No periods available for this solar day.") }
            periods(day.additionalPeriods)
            Divider()
            heading("Day and night Choghadiya", "Amrit, Shubh, Labh: favourable · Chal: neutral · Rog, Kaal, Udveg: unfavourable")
            periods(day.choghadiya)
            Divider()
            heading("Hora", "Planetary hours · twelve by day and twelve by night")
            periods(day.hora)
            Divider()
            heading("Udaya Lagna", "Sidereal ascendant · local horizon")
            if day.lagna.isEmpty { Text("Lagna periods unavailable for this location or solar day.") }
            periods(day.lagna)
        }
        .font(.subheadline)
    }

    private func heading(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title3.bold())
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func periods(_ list: [PanchangPeriod]) -> some View {
        ForEach(Array(list.enumerated()), id: \.offset) { _, period in
            VStack(alignment: .leading, spacing: 1) {
                Text(period.name).fontWeight(.medium)
                Text("\(formatPanchangTime(period.start, city: day.city, date: day.date)) – \(formatPanchangTime(period.end, city: day.city, date: day.date))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }
}

struct PanchangRashiPanel: View {
    let day: PanchangDay
    private func time(_ instant: Date?) -> String { formatPanchangTime(instant, city: day.city, date: day.date) }

    var body: some View {
        PanchangPanel(title: "Rashi and Nakshatra", subtitle: "Sidereal positions at local sunrise · Lahiri") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Surya Rashi · \(day.sunRashi)").font(.headline)
                Text("Changes at \(time(day.sunRashiEndsAt))")
                Divider().padding(.vertical, 8)
                Text("Chandra Rashi · \(day.moonRashi)").font(.headline)
                Text("Changes at \(time(day.moonRashiEndsAt))")
                Divider().padding(.vertical, 8)
                Text("Nakshatra · \(day.nakshatra.name)").font(.headline)
                Text("Pada \(day.nakshatraPada) · until \(time(day.padaEndsAt))")
                Text("Nakshatra ends at \(time(day.nakshatra.endsAt))")
                Divider().padding(.vertical, 8)
                Text("Lahiri Ayanamsa · \(String(format: "%.4f", day.ayanamsa))°")
                Text("Ritu · \(day.ritu)")
                Text("Ayana · \(day.ayana)")
                Text("These are the Sun and Moon positions for the selected day. A personal Janma Rashi requires birth date, time and location.")
                    .padding(.top, 12)
            }
            .font(.subheadline)
        }
    }
}
