import SwiftUI
import EkadashiCore

/// Calculated Smarta or Gaudiya/ISKCON fasts for the selected month and
/// location (panchang_month_panels.dart). A preview: the published schedule
/// still drives the calendar, reminders and Vrat history.
struct PanchangEkadashiPanel: View {
    let month: CivilDate
    let city: PanchangCity
    @Binding var tradition: EkadashiTradition
    @State private var fasts: [CalculatedEkadashi]?
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Calculated Ekadashi").font(.title3.bold())
            HStack(spacing: 8) {
                ForEach(EkadashiTradition.allCases, id: \.self) { item in
                    GlassChip(title: item.label, selected: tradition == item) { tradition = item }
                }
            }
            Text(tradition == .smarta
                 ? "Smarta householders: sunrise tithi, first day when Ekadashi repeats."
                 : "Gaudiya/ISKCON: Arunodaya 96 minutes before local sunrise, with Mahadvadashi rules.")
                .font(.subheadline)
            Text("Calculation preview. Existing calendar dates and reminders still use the published schedule while these results are validated.")
                .font(.caption).foregroundStyle(.secondary)
            Group {
                if failed {
                    VStack {
                        Text("Could not calculate this month.")
                        Button("Retry") { Task { await load() } }
                    }
                } else if let fasts {
                    if fasts.isEmpty {
                        Text("No calculated fast is available for this month/location. A valid local sunrise is required.")
                    } else {
                        ForEach(fasts) { card($0) }
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 120)
                }
            }
            .padding(.top, 8)
        }
        .task(id: "\(month.iso)|\(city.id)|\(city.latitude)|\(city.longitude)|\(city.timeZoneId)|\(tradition.rawValue)") { await load() }
    }

    private func load() async {
        fasts = nil
        failed = false
        let month = self.month, city = self.city, tradition = self.tradition
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try CalculatedEkadashiEngine().calculate(start: month, count: month.daysInMonth, city: city, tradition: tradition)
            }.value
            guard !Task.isCancelled else { return }
            fasts = result
        } catch {
            if !Task.isCancelled { failed = true }
        }
    }

    private func card(_ fast: CalculatedEkadashi) -> some View {
        let parana: String = {
            guard let start = fast.paranaStart else { return "Unavailable" }
            let from = formatPanchangTime(start, city: city, date: fast.paranaDate)
            guard let end = fast.paranaEnd else { return "After \(from)" }
            return "\(from) – \(formatPanchangTime(end, city: city, date: fast.paranaDate))"
        }()
        return VStack(alignment: .leading, spacing: 4) {
            Text(fast.name).font(.headline)
            Text("Fast · \(fast.date.iso)").bold()
            Text("Starts at \(formatPanchangTime(fast.fastStarts, city: city, date: fast.date))")
            Text("Parana · \(fast.paranaDate.iso)").bold().padding(.top, 8)
            Text(parana)
            Text("Rule · \(fast.rule)").padding(.top, 8)
            Text(fast.paranaReason)
            if fast.nearBoundary {
                Label("A limb transition is within five minutes of a decision boundary. Verify this date with your tradition’s calendar.",
                      systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            DisclosureGroup("Calculation details") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ekadashi tithi: \(formatPanchangTime(fast.tithiStart, city: city, date: fast.date)) – \(formatPanchangTime(fast.tithiEnd, city: city, date: fast.date))")
                    Text("Hari Vasara ends: \(formatPanchangTime(fast.hariVasaraEnd, city: city, date: fast.paranaDate))")
                    Text("Current-location apparent sunrise · Lahiri sidereal model · \(CalculatedEkadashi.ruleVersion)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }
            .tint(Theme.teal)
            .padding(.top, 4)
        }
        .font(.subheadline)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 18)
    }
}

/// Free calculation notes (Panchang's Guide subtab).
struct PanchangGuide: View {
    private let topics: [(String, String, String)] = [
        ("book", "Panchang guide",
         "Tithi measures the angular separation of Moon and Sun in 12° steps. Nakshatra divides the sidereal Moon’s path into 27 parts; each has four padas. Yoga divides the sum of sidereal Sun and Moon longitudes into 27 parts. Karana is half a tithi. Vara is the weekday.\n\nLimb labels are sampled at the selected location’s sunrise, with every subsequent change shown through the next sunrise. Times after local midnight carry a day marker."),
        ("leaf", "Smarta and Vaishnava",
         "Smarta householders fast on the Ekadashi at sunrise. When Ekadashi touches two sunrises and Dwadashi also reaches the next one, the second day is kept; when Ekadashi or the following Dwadashi touches no sunrise, the fast moves to the Dashami day so that Parana falls in Dwadashi. The Gaudiya/ISKCON profile also tests Arunodaya, 96 minutes before sunrise, and Mahadvadashi conditions.\n\nSmarta Parana begins after sunrise and Hari Vasara (the first quarter of Dwadashi), preferably within Pratahkala, the first fifth of the day; if Hari Vasara lasts longer, it moves after Madhyahna. Gaudiya Parana follows the GCAL rules for its special days. A difference between profiles can be intentional. The calculated schedule is a preview while comparisons with independent calendars are completed; existing reminders and fasting history remain on the published schedule."),
        ("globe", "Location and calculation methods",
         "City search and Panchang calculations work offline. City selection supplies coordinates and an IANA timezone, including daylight-saving transitions. GPS is optional and its suggested timezone should be checked.\n\nThe Sun uses the VSOP87 planetary theory and the Moon the ELP 2000-82B lunar theory, with IAU nutation and the Lahiri ayanamsa; positions agree with JPL ephemerides to better than an arcsecond. Rise/set use the apparent upper limb, standard refraction and a sea-level horizon. Mountains, elevation and unusual refraction can change observed times. When there is no complete solar day, sunrise-based periods and fasting recommendations are unavailable.\n\nRitu uses lunar months; Ayana is labelled with the tropical solstice convention. Muhurta labels are traditional timing categories, not guarantees of outcomes."),
        ("info.circle", "Sources and coverage",
         "Astronomy: VSOP87 (Bretagnon & Francou), ELP 2000-82B (Chapront-Touzé & Chapront), IAU 1980 nutation, Meeus, Astronomical Algorithms; checked against Swiss Ephemeris (JPL DE431). Fasting rules: Smarta dates and Parana checked against published Drik Panchang dates; Gaudiya cross-reviewed against the GCAL decision table. Festivals follow the traditional time-window (kala) rules and were checked against public Indian festival lists.\n\nCities: GeoNames (geonames.org), CC BY 4.0. Timezones: IANA database (\(TzDatabase.shared.release)).\n\nRegional festival profiles, personal birth charts, horoscope matching and eclipse calculations are not yet included. This is not a claim of full Drik Panchang equivalence."),
    ]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(topics, id: \.1) { topic in
                DisclosureGroup {
                    Text(topic.2).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                } label: {
                    Label(topic.1, systemImage: topic.0).font(.headline)
                }
                .tint(Theme.teal)
                .padding(16)
                .glassPanel(cornerRadius: 18)
            }
        }
    }
}

/// Premium: a month of calculated observances for the saved location.
struct PanchangFestivalExplorer: View {
    @Environment(AppModel.self) private var model
    @State private var city = PanchangCity.newDelhi
    @State private var month: CivilDate?
    @State private var days: [PanchangDay]?
    @State private var query = ""

    var body: some View {
        Group {
            if !model.premium.isPremium {
                VStack {
                    Spacer()
                    PanchangUpgradeCard().padding(20)
                    Spacer()
                }
            } else {
                List {
                    Section {
                        Text("\(city.label) · \(city.timezoneLabel)").font(.subheadline)
                        HStack {
                            Button { move(-1) } label: { Image(systemName: "chevron.left") }
                                .accessibilityLabel("Previous month")
                            Spacer()
                            Text(month.map { String($0.iso.prefix(7)) } ?? "").font(.headline)
                            Spacer()
                            Button { move(1) } label: { Image(systemName: "chevron.right") }
                                .accessibilityLabel("Next month")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Theme.teal)
                    }
                    .listRowBackground(Color.clear)
                    Section {
                        if let days {
                            let matches = days.filter { day in day.observances.contains { matchesQuery($0) } }
                            if matches.isEmpty {
                                Text("No matching calculated observances this month.")
                            }
                            ForEach(matches, id: \.date) { day in
                                NavigationLink {
                                    PanchangView(initialDate: day.date, initialCity: city)
                                        .background(AppBackground())
                                        .navigationTitle("Panchang")
                                        .navigationBarTitleDisplayMode(.inline)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(day.date.day) · \(day.observances.filter(matchesQuery).map(\.name).joined(separator: " · "))")
                                            .font(.subheadline.weight(.semibold))
                                        Text("\(day.tithi.paksha ?? "") \(day.tithi.name) · \(day.amantaMonth)").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } else {
                            ProgressView().frame(maxWidth: .infinity)
                        }
                    }
                    .listRowBackground(Rectangle().fill(.ultraThinMaterial))
                }
                .scrollContentBackground(.hidden)
                .searchable(text: $query, prompt: "Filter observances")
            }
        }
        .background(AppBackground())
        .navigationTitle("Festival finder")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: month.map { "\($0.iso)|\(city.id)" } ?? "start") { await load() }
    }

    private func matchesQuery(_ event: PanchangObservance) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return q.isEmpty || event.name.lowercased().contains(q)
    }

    private func move(_ months: Int) {
        guard let month else { return }
        self.month = month.adding(months: months).firstOfMonth
    }

    private func load() async {
        guard let month else {
            let saved = PanchangLocationStore(store: model.store).load() ?? .newDelhi
            city = saved
            self.month = saved.today().firstOfMonth
            return
        }
        days = nil
        let city = self.city
        let result = await Task.detached(priority: .userInitiated) {
            (0..<month.daysInMonth).map { PanchangEngine().calculate(month.adding(days: $0), city: city) }
        }.value
        if !Task.isCancelled { days = result }
    }
}
