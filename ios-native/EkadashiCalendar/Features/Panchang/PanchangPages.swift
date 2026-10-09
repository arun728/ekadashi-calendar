import SwiftUI
import EkadashiCore

// MARK: - Key days

/// The month's important days: published Ekadashis (free) and Amavasya,
/// Purnima, Shivaratri, Pradosham, Chaturthi, Sankranti and festivals
/// (Premium, shown with a lock for free users).
struct PanchangKeyDaysView: View {
    @Environment(AppModel.self) private var model
    let month: CivilDate
    let city: PanchangCity
    let onOpen: (CivilDate) -> Void
    @State private var days: [KeyDay]?
    @State private var category: SearchCategory?

    private static let filters = SearchCategory.filters.filter { $0 != .myCalendar }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            chips
            if !model.premium.isPremium { lockedBanner }
            if let days {
                let shown = PanchangKeyDays.filter(days, category: category)
                if shown.isEmpty {
                    Text(model.t("panchang_no_key_days")).font(.subheadline).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(shown) { day in
                            Button { open(day) } label: { row(day) }.buttonStyle(.plain)
                        }
                    }
                    .accessibilityIdentifier("panchang_key_days")
                }
            } else {
                ProgressView().tint(Theme.teal).frame(maxWidth: .infinity, minHeight: 160)
            }
        }
        .task(id: "\(month.iso)|\(city.id)|\(city.latitude)|\(city.longitude)|\(model.language)") { await load() }
    }

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                GlassChip(title: model.t("filter_all"), selected: category == nil) { category = nil }
                ForEach(Self.filters, id: \.self) { type in
                    GlassChip(title: model.t(type.localizationKey), systemImage: type.symbol, color: Theme.hex(type.colorHex),
                              selected: category == type) { category = category == type ? nil : type }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("panchang_key_day_filters")
    }

    private var lockedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill").foregroundStyle(Theme.amber)
            Text(model.t("panchang_key_days_locked")).font(.subheadline)
            Spacer(minLength: 4)
            Button(model.t("panchang_unlock_short")) { model.openPaywall() }
                .font(.subheadline.weight(.semibold))
                .primaryActionStyle()
                .accessibilityIdentifier("panchang_unlock_button")
        }
        .padding(14)
        .glassPanel(cornerRadius: 18, tint: Theme.amber)
    }

    private func locked(_ day: KeyDay) -> Bool { day.requiresPremium && !model.premium.isPremium }

    private func row(_ day: KeyDay) -> some View {
        let type = day.categories.contains(.festival) ? SearchCategory.festival : day.categories.first ?? .festival
        let color = Theme.hex(type.colorHex)
        let isLocked = locked(day)
        return HStack(spacing: 14) {
            VStack(spacing: 0) {
                if isLocked {
                    Image(systemName: "lock.fill").font(.title3).foregroundStyle(Theme.amber)
                } else {
                    Text("\(day.date.day)").font(.title2.weight(.bold)).monospacedDigit()
                    Text(PanchangFormat.weekday(day.date, language: model.language)).font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 54, height: 54)
            .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(day.title).font(.headline).foregroundStyle(.primary).lineLimit(2)
                HStack(spacing: 6) {
                    Text(model.t(type.localizationKey)).font(.caption.weight(.semibold)).foregroundStyle(color)
                    if !isLocked {
                        Text("·").font(.caption).foregroundStyle(.secondary)
                        Text(countdown(day.date)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 4)
            Image(systemName: isLocked ? "lock.fill" : "chevron.right").font(.footnote.weight(.semibold))
                .foregroundStyle(isLocked ? Theme.amber : Color.secondary)
        }
        .padding(12)
        .contentShape(Rectangle())
        .glassPanel(cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("panchang_key_day_\(day.id)")
    }

    private func countdown(_ date: CivilDate) -> String {
        let days = city.today().days(until: date)
        switch days {
        case 0: return model.t("today")
        case 1: return model.t("tomorrow")
        case let n where n > 1: return model.t("in_days", "\(n)")
        default: return model.t("panchang_days_ago", "\(-days)")
        }
    }

    private func open(_ day: KeyDay) {
        if locked(day) { model.openPaywall() } else { onOpen(day.date) }
    }

    private func load() async {
        days = nil
        let observances = await model.panchangObservances(year: month.year, city: city)
        days = PanchangKeyDays.month(month, observances: observances, ekadashis: model.ekadashis, language: model.language)
    }
}

// MARK: - Daily

/// The day at a glance: tithi, sun and moon (free), then the five limbs,
/// good times and times to avoid, observances and details (Premium).
struct PanchangDailyView: View {
    @Environment(AppModel.self) private var model
    let day: PanchangDay

    private var language: String { model.language }
    private var terms: PanchangTerms { .shared }
    private func time(_ instant: Date?) -> String {
        PanchangFormat.time(instant, city: day.city, date: day.date, language: language)
    }
    private func until(_ instant: Date?) -> String? { instant.map { model.t("panchang_until", time($0)) } }

    var body: some View {
        VStack(spacing: 16) {
            hero
            sunAndMoon
            if model.premium.isPremium {
                limbs
                timings
                observances
                details
            } else {
                PanchangUpgradeCard()
            }
        }
    }

    private var hero: some View {
        let majors = day.observances.filter(\.isMajor)
        return VStack(alignment: .leading, spacing: 10) {
            Text(model.t(day.sunrise == nil ? "panchang_tithi_at_six" : "panchang_tithi_at_sunrise").uppercased())
                .font(.caption2.weight(.bold)).foregroundStyle(Theme.teal)
            Text(terms.tithi(paksha: day.tithi.paksha, name: day.tithi.name, language: language))
                .font(.title.weight(.bold))
                .accessibilityIdentifier("panchang_tithi_title")
            if let text = until(day.tithi.endsAt) {
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
            FlowLayout(spacing: 8) {
                StatusPill(text: "\(terms.month(day.amantaMonth, language: language)) · \(model.t("panchang_amanta"))",
                           systemImage: "moon", color: Theme.teal)
                StatusPill(text: terms.translate(day.vara, .vara, language: language), systemImage: "calendar", color: Theme.teal)
                ForEach(Array(majors.prefix(3))) { event in
                    StatusPill(text: terms.observanceName(event, language: language), systemImage: "sparkles",
                               color: Theme.hex(SearchCategory.festival.colorHex))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 24, tint: Theme.teal)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("panchang_daily_overview")
    }

    private var sunAndMoon: some View {
        let tiles: [(String, String, String)] = [
            ("sunrise.fill", model.t("panchang_sunrise"), time(day.sunrise)),
            ("sunset.fill", model.t("panchang_sunset"), time(day.sunset)),
            ("moonrise.fill", model.t("panchang_moonrise"), time(day.moonrise)),
            ("moonset.fill", model.t("panchang_moonset"), time(day.moonset)),
        ]
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(tiles, id: \.0) { tile in
                VStack(alignment: .leading, spacing: 6) {
                    Label(tile.1, systemImage: tile.0).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        .symbolRenderingMode(.multicolor)
                    Text(tile.2).font(.headline).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanel(cornerRadius: 18)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var limbs: some View {
        let rows: [(String, String, String?)] = [
            (model.t("panchang_tithi"), terms.tithi(paksha: day.tithi.paksha, name: day.tithi.name, language: language),
             until(day.tithi.endsAt)),
            (model.t("panchang_nakshatra"), terms.translate(day.nakshatra.name, .nakshatra, language: language),
             until(day.nakshatra.endsAt)),
            (model.t("panchang_yoga"), terms.translate(day.yoga.name, .yoga, language: language), until(day.yoga.endsAt)),
            (model.t("panchang_karana"), terms.translate(day.karana.name, .karana, language: language), until(day.karana.endsAt)),
            (model.t("panchang_vara"), terms.translate(day.vara, .vara, language: language), nil),
        ]
        return PanchangCard(title: model.t("panchang_five_limbs"), symbol: "circle.hexagongrid") {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { Divider() }
                PanchangRow(label: row.0, value: row.1, detail: row.2)
            }
        }
        .accessibilityIdentifier("panchang_limbs")
    }

    private var timings: some View {
        let extra = day.additionalPeriods
        let good = ([day.brahmaMuhurta, day.abhijit] + extra.filter { $0.name == "Amrit Kalam" }).compactMap { $0 }
            .sorted { $0.start < $1.start }
        let avoid = ([day.rahukala, day.yamaganda, day.gulika] + extra.filter { $0.name != "Amrit Kalam" }).compactMap { $0 }
            .sorted { $0.start < $1.start }
        return PanchangCard(title: model.t("panchang_timings"), symbol: "clock") {
            Text(model.t("panchang_good_times")).font(.caption.weight(.bold)).foregroundStyle(Theme.observed)
            ForEach(Array(good.enumerated()), id: \.offset) { _, period in
                PanchangRow(label: terms.period(period.name, language: language),
                            value: PanchangFormat.range(period.start, period.end, city: day.city, date: day.date, language: language),
                            color: Theme.observed)
            }
            Divider()
            Text(model.t("panchang_avoid_times")).font(.caption.weight(.bold)).foregroundStyle(Theme.missed)
            ForEach(Array(avoid.enumerated()), id: \.offset) { _, period in
                PanchangRow(label: terms.period(period.name, language: language),
                            value: PanchangFormat.range(period.start, period.end, city: day.city, date: day.date, language: language),
                            color: Theme.missed)
            }
        }
        .accessibilityIdentifier("panchang_timings")
    }

    @ViewBuilder
    private var observances: some View {
        if !day.observances.isEmpty {
            PanchangCard(title: model.t("panchang_observances"), symbol: "sparkles") {
                ForEach(day.observances) { event in
                    Label(terms.observanceName(event, language: language), systemImage: event.isMajor ? "sparkle" : "circle.fill")
                        .font(event.isMajor ? .subheadline.weight(.semibold) : .subheadline)
                        .imageScale(event.isMajor ? .medium : .small)
                }
            }
        }
    }

    private var details: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                PanchangRow(label: model.t("panchang_amanta"), value: terms.month(day.amantaMonth, language: language))
                PanchangRow(label: model.t("panchang_purnimanta"), value: terms.month(day.purnimantaMonth, language: language))
                PanchangRow(label: model.t("panchang_sun_rashi"), value: terms.translate(day.sunRashi, .rashi, language: language))
                PanchangRow(label: model.t("panchang_moon_rashi"), value: terms.translate(day.moonRashi, .rashi, language: language))
                PanchangRow(label: model.t("panchang_nakshatra_pada"), value: "\(day.nakshatraPada)")
                PanchangRow(label: model.t("panchang_ritu"), value: terms.translate(day.ritu, .ritu, language: language))
                PanchangRow(label: model.t("panchang_ayana"), value: terms.translate(day.ayana, .ayana, language: language))
                PanchangRow(label: model.t("panchang_samvat"),
                            value: model.t("panchang_samvat_value", "\(day.shakaYear)", "\(day.vikramaYear)"))
                PanchangRow(label: model.t("panchang_anandadi"), value: terms.translate(day.anandadiYoga, .anandadi, language: language))
                PanchangRow(label: model.t("panchang_special_yogas"),
                            value: day.specialYogas.isEmpty ? model.t("panchang_none")
                                : day.specialYogas.map { terms.translate($0, .specialYoga, language: language) }.joined(separator: ", "))
                PanchangRow(label: model.t("panchang_ayanamsa"), value: String(format: "%.4f°", day.ayanamsa))
                if day.sunrise == nil || day.sunset == nil {
                    Text(model.t("panchang_no_solar_day")).font(.caption).foregroundStyle(.secondary)
                }
                Divider().padding(.vertical, 4)
                Text(model.t("panchang_transitions")).font(.subheadline.weight(.semibold))
                ForEach(day.limbTimeline, id: \.name) { entry in
                    ForEach(Array(entry.limbs.enumerated()), id: \.offset) { _, limb in
                        PanchangRow(label: model.t("panchang_\(entry.name.lowercased())"), value: limbName(entry.name, limb),
                                    detail: until(limb.endsAt))
                    }
                }
            }
            .padding(.top, 10)
        } label: {
            Label(model.t("panchang_more_details"), systemImage: "list.bullet.rectangle").font(.headline)
        }
        .tint(Theme.teal)
        .padding(16)
        .glassPanel(cornerRadius: 20)
        .accessibilityIdentifier("panchang_more_details")
    }

    private func limbName(_ kind: String, _ limb: PanchangLimb) -> String {
        switch kind {
        case "Tithi": return terms.tithi(paksha: limb.paksha, name: limb.name, language: language)
        case "Nakshatra": return terms.translate(limb.name, .nakshatra, language: language)
        case "Yoga": return terms.translate(limb.name, .yoga, language: language)
        case "Karana": return terms.translate(limb.name, .karana, language: language)
        default: return limb.name
        }
    }
}

// MARK: - Muhurta

/// Choghadiya and Hora by day or night, and Udaya Lagna (Premium).
struct PanchangMuhurtaView: View {
    @Environment(AppModel.self) private var model
    let day: PanchangDay
    @State private var night = false

    private var language: String { model.language }
    private var terms: PanchangTerms { .shared }

    var body: some View {
        VStack(spacing: 16) {
            Picker(model.t("panchang_day"), selection: $night) {
                Text(model.t("panchang_day")).tag(false)
                Text(model.t("panchang_night")).tag(true)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("panchang_day_night")
            let choghadiya = day.choghadiya.filter { $0.name.hasPrefix(night ? "Night" : "Day") }
            PanchangCard(title: model.t("panchang_choghadiya"), symbol: "circle.grid.3x3") {
                Text(model.t("panchang_choghadiya_hint")).font(.caption).foregroundStyle(.secondary)
                if choghadiya.isEmpty { Text(model.t("panchang_unavailable")).font(.subheadline).foregroundStyle(.secondary) }
                ForEach(Array(choghadiya.enumerated()), id: \.offset) { _, period in
                    periodRow(String(period.name.split(separator: "·").last ?? "").trimmingCharacters(in: .whitespaces),
                              kind: .choghadiya, period, color: quality(period.name))
                }
            }
            let hora = Array(day.hora.enumerated().filter { night ? $0.offset >= 12 : $0.offset < 12 }.map(\.element))
            PanchangCard(title: model.t("panchang_hora"), symbol: "clock.arrow.2.circlepath") {
                if hora.isEmpty { Text(model.t("panchang_unavailable")).font(.subheadline).foregroundStyle(.secondary) }
                ForEach(Array(hora.enumerated()), id: \.offset) { _, period in periodRow(period.name, kind: .hora, period) }
            }
            PanchangCard(title: model.t("panchang_lagna"), symbol: "globe.asia.australia") {
                if day.lagna.isEmpty { Text(model.t("panchang_unavailable")).font(.subheadline).foregroundStyle(.secondary) }
                ForEach(Array(day.lagna.enumerated()), id: \.offset) { _, period in periodRow(period.name, kind: .rashi, period) }
            }
        }
    }

    private func periodRow(_ name: String, kind: PanchangTerms.Kind, _ period: PanchangPeriod, color: Color? = nil) -> some View {
        let now = Date()
        let current = period.start <= now && now < period.end
        return HStack {
            PanchangRow(label: terms.translate(name, kind, language: language),
                        value: PanchangFormat.range(period.start, period.end, city: day.city, date: day.date, language: language),
                        color: color)
            if current { StatusPill(text: model.t("panchang_now"), color: Theme.teal) }
        }
    }

    /// Amrit, Shubh and Labh are favourable; Chal neutral; Rog, Kaal and Udveg not.
    private func quality(_ name: String) -> Color {
        if ["Amrit", "Shubh", "Labh"].contains(where: { name.hasSuffix($0) }) { return Theme.observed }
        if name.hasSuffix("Chal") { return .gray }
        return Theme.missed
    }
}

// MARK: - Rashi

struct PanchangRashiView: View {
    @Environment(AppModel.self) private var model
    let day: PanchangDay

    private var language: String { model.language }
    private var terms: PanchangTerms { .shared }
    private func until(_ instant: Date?) -> String? {
        instant.map { model.t("panchang_until", PanchangFormat.time($0, city: day.city, date: day.date, language: language)) }
    }

    var body: some View {
        VStack(spacing: 16) {
            PanchangCard(title: model.t("panchang_sun_rashi"), symbol: "sun.max.fill") {
                PanchangRow(label: model.t("panchang_rashi"), value: terms.translate(day.sunRashi, .rashi, language: language),
                            detail: until(day.sunRashiEndsAt))
            }
            PanchangCard(title: model.t("panchang_moon_rashi"), symbol: "moon.fill") {
                PanchangRow(label: model.t("panchang_rashi"), value: terms.translate(day.moonRashi, .rashi, language: language),
                            detail: until(day.moonRashiEndsAt))
            }
            PanchangCard(title: model.t("panchang_nakshatra"), symbol: "star.fill") {
                PanchangRow(label: model.t("panchang_nakshatra"), value: terms.translate(day.nakshatra.name, .nakshatra, language: language),
                            detail: until(day.nakshatra.endsAt))
                Divider()
                PanchangRow(label: model.t("panchang_nakshatra_pada"), value: "\(day.nakshatraPada)", detail: until(day.padaEndsAt))
            }
            Text(model.t("panchang_rashi_note")).font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
