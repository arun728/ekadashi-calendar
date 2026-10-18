import SwiftUI
import EkadashiCore

/// Separate from Home and the widget app group; birth data is never geocoded,
/// logged, or sent to a service. Saved results stay readable after expiry.
struct BirthProfileView: View {
    @Environment(AppModel.self) private var model
    @State private var repository = BirthProfileStore(store: ProcessInfo.processInfo.arguments.contains("-ui-testing")
        ? InMemoryKeyValueStore() : UserDefaultsKeyValueStore(defaults: .standard))
    @State private var profile: SavedBirthProfile?
    @State private var editing = false
    @State private var confirmingDelete = false
    @State private var error: BirthError?
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(model.t("ios_birth_title"), systemImage: AppSymbol.nakshatra).font(.title2.bold()).foregroundStyle(Theme.teal)
            Text(model.t("ios_birth_intro")).font(.subheadline).foregroundStyle(.secondary)
            if let error {
                Text(model.t(error.localizationKey)).foregroundStyle(.orange)
                Button(model.t("retry")) { load() }
            }
            if let profile {
                BirthResultsView(profile: profile)
                Button(model.t("ios_birth_edit")) { editing = true }.secondaryActionStyle().accessibilityIdentifier("birth_edit")
            } else if error == nil {
                Button(model.t("ios_birth_create")) { editing = true }.primaryActionStyle().accessibilityIdentifier("birth_create")
            }
            if profile != nil || error != nil {
                Button(model.t("ios_birth_delete"), role: .destructive) { confirmingDelete = true }
                    .accessibilityIdentifier("birth_delete")
            }
            Text(model.t("ios_birth_convention")).font(.footnote).foregroundStyle(.secondary)
            Text(model.t("ios_birth_range")).font(.footnote).foregroundStyle(.secondary)
            Label(model.t("ios_birth_privacy"), systemImage: AppSymbol.lock).font(.footnote).foregroundStyle(.secondary)
            if !model.premium.isPremium {
                Text(model.t("ios_birth_error_premiumRequired")).font(.footnote).foregroundStyle(Theme.amber)
            }
        }
        .sheet(isPresented: $editing) {
            BirthProfileEditor(input: profile?.input, repository: repository) { profile = $0; error = nil }
        }
        .alert(model.t("ios_birth_delete"), isPresented: $confirmingDelete) {
            Button(model.t("cancel"), role: .cancel) {}
            Button(model.t("ios_birth_delete"), role: .destructive) {
                do { try repository.delete(); profile = nil; error = nil } catch { self.error = .storage }
            }
            .accessibilityIdentifier("birth_delete_confirm")
        } message: { Text(model.t("ios_birth_delete_body")) }
        .onAppear { if !loaded { loaded = true; load() } }
    }
    private func load() {
        do { profile = try repository.load(); error = nil } catch { self.error = .corruptStorage }
    }
}

struct BirthProfileEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let input: BirthInput?
    let repository: BirthProfileStore
    let saved: (SavedBirthProfile) -> Void
    @State private var date = CivilDate(2000, 1, 1).utcMidnight
    @State private var time = CivilDate(2000, 1, 1).utcMidnight.addingTimeInterval(43200)
    @State private var known = true
    @State private var city = PanchangCity.chennai
    @State private var choice: Int?
    @State private var pickingPlace = false
    @State private var paywall = false
    @State private var error: BirthError?
    @State private var loaded = false
    private var draft: BirthInput {
        let clock = TzDatabase.shared.location("UTC")!.wallClock(time)
        return BirthInput(date: CivilDate(utc: date), hour: known ? clock.hour : nil, minute: known ? clock.minute : nil,
                          city: city, repeatedChoice: choice)
    }
    private var candidates: [Date] { (try? BirthCalculator.candidates(draft)) ?? [] }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(model.t("ios_birth_date"), selection: $date,
                               in: BirthCalculator.firstDate.utcMidnight...city.today().utcMidnight, displayedComponents: .date)
                        .environment(\.timeZone, TimeZone(identifier: "UTC")!)
                        .accessibilityIdentifier("birth_date")
                    Toggle(model.t("ios_birth_known_time"), isOn: $known).accessibilityIdentifier("birth_known_time")
                    if known {
                        DatePicker(model.t("ios_birth_time"), selection: $time, displayedComponents: .hourAndMinute)
                            .environment(\.timeZone, TimeZone(identifier: "UTC")!)
                            .accessibilityIdentifier("birth_time")
                    } else { Text(model.t("ios_birth_unknown")).font(.caption).foregroundStyle(.secondary) }
                }
                Section(model.t("ios_birth_place")) {
                    Button { pickingPlace = true } label: {
                        Label(PlaceNames.shared.label(city.label, language: model.language), systemImage: AppSymbol.panchangCity)
                    }
                    .accessibilityIdentifier("birth_place")
                    LabeledContent(model.t("ios_birth_timezone"), value: city.timeZoneId).font(.caption)
                    if known, candidates.count == 1, let instant = candidates.first {
                        LabeledContent(model.t("ios_birth_offset"), value: BirthTimeText.offset(instant, city: city, language: model.language)).font(.caption)
                    }
                }
                if known && candidates.count > 1 {
                    Section {
                        Text(model.t("ios_birth_fold"))
                        ForEach(Array(candidates.enumerated()), id: \.element) { index, instant in
                            Button {
                                choice = index; error = nil
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(model.t(index == 0 ? "ios_birth_earlier" : "ios_birth_later"))
                                        Text(BirthTimeText.utc(instant, language: model.language)).font(.caption)
                                        Text(BirthTimeText.offset(instant, city: city, language: model.language)).font(.caption)
                                    }
                                    Spacer()
                                    if choice == index { Image(systemName: AppSymbol.cardObserved) }
                                }
                            }
                            .accessibilityIdentifier("birth_occurrence_\(index)")
                        }
                    }
                }
                Section {
                    if let error { Text(model.t(error.localizationKey)).foregroundStyle(.orange).accessibilityIdentifier("birth_error") }
                    Button(model.t("ios_birth_calculate")) { calculate() }
                        .accessibilityIdentifier("birth_calculate")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.t("ios_birth_convention"))
                        Text(model.t("ios_birth_privacy"))
                    }
                }
            }
            .tint(Theme.teal)
            .environment(\.locale, model.locale)
            .navigationTitle(model.t("ios_birth_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(model.t("cancel")) { dismiss() } } }
            .sheet(isPresented: $pickingPlace) { BirthPlaceSheet(city: city) { city = $0 } }
            .sheet(isPresented: $paywall) { NavigationStack { PremiumView(reason: "ios_birth_error_premiumRequired") } }
            .onChange(of: date) { _, _ in resetChoice() }
            .onChange(of: time) { _, _ in resetChoice() }
            .onChange(of: city) { _, _ in resetChoice() }
            .onChange(of: known) { _, _ in resetChoice() }
            .onAppear(perform: loadDraft)
        }
    }
    private func loadDraft() {
        guard !loaded else { return }; loaded = true
        guard let input else { return }
        date = input.date.utcMidnight
        city = input.city
        known = input.hour != nil
        let hour: Int = input.hour ?? 12
        let minute: Int = input.minute ?? 0
        let seconds: Double = Double(hour * 3600 + minute * 60)
        time = CivilDate(2000, 1, 1).utcMidnight.addingTimeInterval(seconds)
        // Reconfirm a repeated clock time when editing.
    }
    private func resetChoice() { choice = nil; error = nil }
    private func calculate() {
        guard model.premium.isPremium else { paywall = true; return }
        do { saved(try repository.save(draft, premium: model.premium.isPremium)); dismiss() }
        catch let failure as BirthError { error = failure }
        catch { self.error = .storage }
    }
}

struct BirthResultsView: View {
    @Environment(AppModel.self) private var model
    let profile: SavedBirthProfile
    private var reading: BirthReading { profile.reading }
    private var city: PanchangCity { profile.input.city }
    private func names(_ key: String) -> String {
        let values = reading.spans.map(\.values)
        var seen = Set<String>()
        return values.map { BirthTimeText.value($0, key: key, language: model.language) }.filter { seen.insert($0).inserted }.joined(separator: " / ")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PanchangCard(title: model.fullDate(profile.input.date), symbol: AppSymbol.panchangDate) {
                Text(PlaceNames.shared.label(city.label, language: model.language)).font(.subheadline)
                Text(city.timeZoneId).font(.caption).foregroundStyle(.secondary)
                if let instant = reading.instant {
                    Text(model.t("ios_birth_exact")).font(.caption).foregroundStyle(Theme.teal)
                    Text(BirthTimeText.local(instant, city: city, date: profile.input.date, language: model.language)).font(.headline)
                    Text(model.t("ios_birth_utc")).font(.caption).foregroundStyle(.secondary)
                    Text(BirthTimeText.utc(instant, language: model.language)).font(.caption)
                    Text(BirthTimeText.offset(instant, city: city, language: model.language)).font(.caption)
                    if reading.nearBoundary { Text(model.t("ios_birth_boundary")).font(.caption).foregroundStyle(.orange) }
                } else {
                    Text(model.t("ios_birth_unknown")).font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("birth_unknown_summary")
                }
            }
            ForEach(["rashi", "nakshatra", "pada", "tithi"], id: \.self) { key in
                PanchangCard(title: model.t("ios_birth_\(key)")) {
                    Text(names(key)).font(.title3.bold()).foregroundStyle(Theme.teal).fixedSize(horizontal: false, vertical: true)
                    if reading.instant == nil {
                        Text(model.t(stable(key) ? "ios_birth_stable" : "ios_birth_changes")).font(.caption.bold())
                    }
                    Text(model.t("ios_birth_\(key)_help")).font(.caption).foregroundStyle(.secondary)
                }
            }
            if reading.instant == nil {
                PanchangCard(title: model.t("ios_birth_timeline"), symbol: AppSymbol.panchangDate) {
                    ForEach(reading.spans) { span in
                        VStack(alignment: .leading, spacing: 7) {
                            Text("\(BirthTimeText.local(span.start, city: city, date: profile.input.date, language: model.language)) – \(BirthTimeText.local(span.end, city: city, date: profile.input.date, language: model.language))")
                                .font(.subheadline.bold())
                            Text(BirthTimeText.offset(span.start, city: city, language: model.language)).font(.caption2).foregroundStyle(.secondary)
                            Text(["rashi", "nakshatra", "pada", "tithi"].map { "\(model.t("ios_birth_\($0)")): \(BirthTimeText.value(span.values, key: $0, language: model.language))" }.joined(separator: " · "))
                                .font(.caption)
                        }
                        .accessibilityElement(children: .combine)
                        Divider()
                    }
                }
                .accessibilityIdentifier("birth_timeline")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("birth_results")
    }
    private func stable(_ key: String) -> Bool {
        switch key { case "rashi": return reading.stableRashi; case "nakshatra": return reading.stableNakshatra
        case "pada": return reading.stablePada; default: return reading.stableTithi }
    }
}

/// Wall times always use the bundled historical rules, not Foundation's
/// current offset. UTC includes seconds for pre-standard historical offsets.
enum BirthTimeText {
    static func utc(_ instant: Date, language: String) -> String {
        let formatter = DateFormatter(); formatter.locale = Localizer.locale(language)
        formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "EEE, d MMM yyyy · HH:mm:ss"
        return formatter.string(from: instant)
    }
    static func local(_ instant: Date, city: PanchangCity, date: CivilDate, language: String) -> String {
        PanchangFormat.time(instant, city: city, date: date, language: language)
    }
    static func offset(_ instant: Date, city: PanchangCity, language: String) -> String {
        offset(seconds: city.zone.zone(at: instant).offsetSeconds, language: language)
    }
    static func offset(seconds: Int, language: String) -> String {
        let base = Localizer.shared.utcOffset(minutes: seconds / 60, language: language)
        guard seconds % 60 != 0 else { return base }
        let total = abs(seconds)
        let sign = seconds < 0 ? "−" : "+"
        let suffix = String(format: "%02d:%02d", total / 60 % 60, total % 60)
        let value = "\(sign)\(total / 3600):\(suffix)"
        return Localizer.shared.translate("utc_offset", language: language, args: [value])
    }
    static func value(_ value: BirthValues, key: String, language: String) -> String {
        let terms = PanchangTerms.shared
        switch key {
        case "rashi": return terms.translate(value.rashiName, .rashi, language: language)
        case "nakshatra": return terms.translate(value.nakshatraName, .nakshatra, language: language)
        case "pada": return value.pada.formatted(.number.locale(Localizer.locale(language)))
        default: return terms.tithi(paksha: value.paksha, name: value.tithiName, language: language)
        }
    }
}
