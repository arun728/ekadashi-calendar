import Foundation
import SwiftUI
import Observation
import BackgroundTasks
import UserNotifications
import EkadashiCore

enum LocationState: Equatable { case detecting, denied, located(String), unknown }

struct PaywallRequest: Identifiable { let id = UUID(); let reason: String? }

struct GooglePickerRequest: Identifiable {
    let id = UUID()
    let calendars: [GoogleCalendarInfo]
    let saved: [String]
    let email: String?
}

/// App state and the launch flow of main.dart: permissions on first launch,
/// location to choose the published schedule, data for the selected
/// language, reminders, widgets, search and deep links.
@MainActor
@Observable
final class AppModel {
    static let refreshTaskId = "com.applausestudios.ekadashi-calendar.refresh"

    @ObservationIgnored let store: KeyValueStore
    @ObservationIgnored let repository: CalendarRepository?
    /// Ekadashi dates and times from the Panchang engine for the chosen city
    /// and tradition (docs/EKADASHI_ENGINE_SCHEDULE.md).
    @ObservationIgnored let schedule: EkadashiSchedule?
    @ObservationIgnored private var loadGeneration = 0
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    /// UI tests cannot answer the system permission alert, so they run as if allowed.
    @ObservationIgnored let notifications = NotificationService(
        assumeAuthorized: ProcessInfo.processInfo.arguments.contains("-ui-testing"))
    @ObservationIgnored let location = LocationService()
    @ObservationIgnored let recents: RecentSearches
    @ObservationIgnored let entries: CalendarEntryStore
    @ObservationIgnored let google = GoogleSignInGateway()
    @ObservationIgnored let registry: FreeSyncRegistry?
    @ObservationIgnored private var coordinatorStorage: GoogleSyncCoordinator?
    @ObservationIgnored private var paywallContinuation: CheckedContinuation<Bool, Never>?
    @ObservationIgnored private var pickerContinuation: CheckedContinuation<GoogleCalendarPickerResult, Never>?
    @ObservationIgnored private var started = false
    @ObservationIgnored private var pendingRoute: AppRoute?
    @ObservationIgnored private var observanceCache: [String: [DatedObservance]] = [:]
    @ObservationIgnored private var schedulingTask: Task<Void, Never>?

    let premium: StoreKitPremiumService
    let vrat: VratStore

    private(set) var language: String
    private(set) var isDarkMode: Bool
    private(set) var locationState: LocationState = .unknown
    /// Where Home and Calendar calculate Ekadashis: the place the user set,
    /// else the last detected one, else Chennai.
    private(set) var ekadashiCity: PanchangCity
    /// True once the user picked a city; detection no longer replaces it.
    private(set) var ekadashiCityIsManual: Bool
    private(set) var tradition: EkadashiTradition
    /// The year Home lists and Calendar opens on.
    private(set) var selectedYear: Int
    let enabledYears = EkadashiYears.enabled()
    /// Every enabled year's Ekadashis at [ekadashiCity] for [tradition]:
    /// reminders, widgets, Vrat, search and the Calendar markers use these.
    private(set) var ekadashis: [EkadashiOccurrence] = []
    /// True while a city, tradition or year is being calculated.
    private(set) var isCalculating = false
    private(set) var loadError: String?
    private(set) var isLoading = true
    private(set) var reminderSettings: ReminderSettings
    private(set) var eventReminders: EventReminderSettings
    private(set) var entriesRevision = 0
    var selectedTab: AppTab = .today
    var showSearch = false
    /// The way back to a search whose result opened a tab or calendar day.
    private(set) var searchReturn = SearchReturn()
    /// The search to show again when it reopens from that way back.
    var restoredSearch: SearchSession?
    var homeIndex = 0
    var calendarFocus: CivilDate?
    /// A day to open in Panchang (from an event reminder).
    var panchangFocus: CivilDate?
    var toast: ToastMessage?
    var paywall: PaywallRequest?
    var googlePicker: GooglePickerRequest?
    var unlockQueue: [Achievement] = []

    init() {
        let group = Bundle.main.object(forInfoDictionaryKey: "EkadashiAppGroup") as? String ?? ""
        // UI tests start from a clean, already-launched English state.
        let store: KeyValueStore = ProcessInfo.processInfo.arguments.contains("-ui-testing")
            ? InMemoryKeyValueStore(["has_launched": true, "language_code": "en"])
            : UserDefaultsKeyValueStore(defaults: UserDefaults(suiteName: group) ?? .standard)
        let premium = StoreKitPremiumService()
        let snapshot = premium.snapshot
        self.store = store
        self.premium = premium
        repository = try? CalendarRepository.bundled()
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ekadashi_schedule", isDirectory: true)
        schedule = repository.map { EkadashiSchedule(repository: $0, cacheDirectory: caches) }
        language = store.string(forKey: "language_code").flatMap { Localizer.languages.contains($0) ? $0 : nil } ?? Self.systemLanguage
        isDarkMode = store.bool(forKey: "is_dark_mode") ?? true
        ekadashiCity = Self.loadCity(store) ?? Self.defaultCity
        ekadashiCityIsManual = store.bool(forKey: Self.manualCityKey) ?? false
        tradition = store.string(forKey: Self.traditionKey).flatMap(EkadashiTradition.init(rawValue:)) ?? .smarta
        let years = EkadashiYears.enabled()
        selectedYear = store.string(forKey: Self.yearKey).flatMap(Int.init).flatMap { years.contains($0) ? $0 : nil }
            ?? EkadashiYears.defaultYear(today: CivilDate.today(), enabled: years)
        reminderSettings = ReminderSettings.load(from: store)
        eventReminders = EventReminderSettings.load(from: store)
        recents = RecentSearches(store: store)
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        entries = (try? FileCalendarEntryStore(url: support.appendingPathComponent("calendar_entries.json")))
            ?? InMemoryCalendarEntryStore()
        registry = FirestoreFreeSyncRegistry.fromConfiguration(
            apiKey: Bundle.main.object(forInfoDictionaryKey: "EkadashiFirebaseApiKey") as? String,
            projectId: Bundle.main.object(forInfoDictionaryKey: "EkadashiFirebaseProjectId") as? String)
        vrat = VratStore(store: store, premium: { snapshot.state.isPremium })
    }

    static var systemLanguage: String {
        let code = Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "en"
        return Localizer.languages.contains(code) ? code : "en"
    }

    // MARK: Strings and formatting

    func t(_ key: String) -> String { Localizer.shared.translate(key, language: language) }
    func t(_ key: String, _ args: String...) -> String { Localizer.shared.translate(key, language: language, args: args) }
    var locale: Locale { Localizer.locale(language) }
    /// Time pickers use the 24-hour clock outside English, since iOS writes
    /// AM and PM in Latin letters for most Indian languages.
    var timePickerLocale: Locale {
        // Built once per language: a new Locale on every redraw kept the
        // time wheel re-laying itself out (an observation feedback loop).
        if let cached = timePickerLocales[language] { return cached }
        let value = language == "en" ? locale : Locale(identifier: "\(locale.identifier)@hours=h23")
        timePickerLocales[language] = value
        return value
    }
    @ObservationIgnored private var timePickerLocales: [String: Locale] = [:]

    /// The one way every tab shows a date: weekday, date, month and year
    /// ("Thu, 8 Oct 2026"), as AppStrings.fullDate on Android.
    func fullDate(_ date: CivilDate) -> String { PanchangFormat.date(date, language: language) }

    func format(_ date: CivilDate, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = pattern
        return formatter.string(from: date.utcMidnight)
    }

    var scheduleZone: TzLocation { ekadashiCity.zone }
    var today: CivilDate { scheduleZone.wallClock(Date()).date }
    var locationName: String { if case .located(let city) = locationState { return city }; return "" }

    /// The detected place in the app language: the shared table first, then
    /// Apple's geocoder in that language, then the English name.
    private(set) var geocodedCityNames: [String: String] = [:]
    @ObservationIgnored private var cityLookups: Set<String> = []
    @ObservationIgnored private var lastCoordinate: (Double, Double)?

    func cityLabel(_ city: String) -> String {
        let table = PlaceNames.shared.place(city, language: language)
        guard language != "en", table == city else { return table }
        let key = "\(language)|\(city)"
        if let known = geocodedCityNames[key] { return known }
        if let coordinate = lastCoordinate, !cityLookups.contains(key) {
            cityLookups.insert(key)
            let language = self.language
            Task { [weak self] in
                // Only a name in the language's own script replaces English.
                guard let name = await self?.location.localizedName(latitude: coordinate.0, longitude: coordinate.1,
                                                                    language: language),
                      name.range(of: "[A-Za-z]", options: .regularExpression) == nil else { return }
                self?.geocodedCityNames[key] = name
            }
        }
        return city
    }

    /// The Ekadashi city's time zone in the app language ("भारतीय समय" for
    /// IST, the UTC offset in the language's script elsewhere).
    var timeZoneLabel: String {
        ekadashiCity.timeZoneId == "Asia/Kolkata"
            ? Localizer.shared.timeZoneName("IST", language: language)
            : ekadashiCity.timeZoneLabel(language: language)
    }

    /// The Ekadashi city in the app language ("Chennai (IN)" from the catalog,
    /// the geocoded place name for a detected location).
    var ekadashiCityName: String {
        let label = PlaceNames.shared.label(ekadashiCity.label, language: language)
        if ekadashiCity.id == Self.detectedCityId { return cityLabel(ekadashiCity.label) }
        return label
    }

    /// Home lists the selected year's Ekadashis.
    var homeEkadashis: [EkadashiOccurrence] { ekadashis.filter { $0.date.year == selectedYear } }

    func traditionName(_ value: EkadashiTradition) -> String { t(value == .smarta ? "panchang_smarta" : "panchang_gaudiya") }

    // MARK: Launch

    /// True while the app only hosts the unit tests: no launch flow or
    /// permission prompts then.
    static var isHostingUnitTests: Bool { ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil }

    func start() async {
        guard !started, !Self.isHostingUnitTests else { return }
        started = true
        reload(scrollToNext: true)
        await premium.start()
        premium.startRecheck()
        if store.bool(forKey: "has_launched") != true {
            store.set(true, forKey: "has_launched")
            await requestPermissionsOnFirstLaunch()
        } else {
            await handleLocation()
        }
        removeLapsedPremiumImports()
        scheduleBackgroundRefresh()
    }

    private func requestPermissionsOnFirstLaunch() async {
        locationState = .detecting
        if await notifications.requestAuthorization() {
            var settings = ReminderSettings()
            settings.enabled = true
            updateReminders(settings)
        }
        _ = await location.requestPermission()
        await handleLocation()
    }

    /// A detected place becomes the Ekadashi city unless the user chose one;
    /// without a fix the last known (or chosen) city stays, else Chennai.
    func handleLocation() async {
        locationState = .detecting
        var fix = await location.currentFix(store: store)
        if fix == nil, location.hasPermission { fix = location.cachedFix(store: store) }
        if let fix {
            lastCoordinate = (fix.latitude, fix.longitude)
            locationState = .located(fix.city)
            if !ekadashiCityIsManual { useDetected(fix) }
        } else {
            locationState = location.isDenied ? .denied : .unknown
        }
        reload(scrollToNext: true)
    }

    private func useDetected(_ fix: LocationService.Fix) {
        let zone = fix.zoneIdentifier
            ?? PanchangCityCatalog.shared.nearest(latitude: fix.latitude, longitude: fix.longitude)?.timeZoneId
            ?? TimeZone.current.identifier
        // Rounded to about a kilometre (sunrise moves by well under a second),
        // so small GPS drift reuses the cached schedule.
        func rounded(_ value: Double) -> Double { (value * 100).rounded() / 100 }
        let city = PanchangCity(id: Self.detectedCityId, label: fix.city.isEmpty ? "—" : fix.city,
                                latitude: rounded(fix.latitude), longitude: rounded(fix.longitude), timeZoneId: zone)
        guard (try? city.validate()) != nil else { return }
        saveCity(city, manual: false)
        // The Panchang tab starts from the detected place until one is set there.
        let panchang = PanchangLocationStore(store: store)
        if panchang.load() == nil { try? panchang.save(city) }
    }

    /// The user picked a city on Home: Ekadashis follow it, detection no
    /// longer replaces it, and the Panchang tab moves there too (not the
    /// other way round).
    func chooseEkadashiCity(_ city: PanchangCity) {
        guard (try? city.validate()) != nil else { return }
        saveCity(city, manual: true)
        try? PanchangLocationStore(store: store).save(city)
        reload(scrollToNext: true)
    }

    /// "Use current location" on Home: detection decides again.
    func useCurrentLocationForEkadashis() async {
        ekadashiCityIsManual = false
        store.set(false, forKey: Self.manualCityKey)
        _ = await location.requestPermission()
        await handleLocation()
        // Setting the location on Home also sets it on the Panchang tab.
        if ekadashiCity.id == Self.detectedCityId { try? PanchangLocationStore(store: store).save(ekadashiCity) }
    }

    private func saveCity(_ city: PanchangCity, manual: Bool) {
        ekadashiCity = city
        ekadashiCityIsManual = manual
        if let data = try? JSONEncoder().encode(city) { store.set(String(decoding: data, as: UTF8.self), forKey: Self.cityKey) }
        store.set(manual, forKey: Self.manualCityKey)
    }

    func setTradition(_ value: EkadashiTradition) {
        guard value != tradition else { return }
        tradition = value
        store.set(value.rawValue, forKey: Self.traditionKey)
        reload(scrollToNext: true)
    }

    /// Home's year menu; Calendar opens on the chosen year.
    func setYear(_ year: Int) {
        guard enabledYears.contains(year), year != selectedYear else { return }
        selectedYear = year
        store.set(String(year), forKey: Self.yearKey)
        homeIndex = HomeSelection.index(of: homeEkadashis, now: Date(), zone: scheduleZone, includeParana: true)
        calendarFocus = year == today.year ? today : CivilDate(year, 1, 1)
    }

    /// Calendar moved into another year: Home follows.
    func calendarShowsYear(_ year: Int) {
        guard enabledYears.contains(year), year != selectedYear else { return }
        selectedYear = year
        store.set(String(year), forKey: Self.yearKey)
        homeIndex = HomeSelection.index(of: homeEkadashis, now: Date(), zone: scheduleZone, includeParana: true)
    }

    static let cityKey = "ekadashi_city"
    static let manualCityKey = "ekadashi_city_manual"
    static let traditionKey = "ekadashi_tradition"
    static let yearKey = "ekadashi_year"
    static let detectedCityId = "detected"
    static let defaultCity = PanchangCity(id: "geonames-1264527", label: "Chennai (IN)", latitude: 13.08784,
                                          longitude: 80.27847, timeZoneId: "Asia/Kolkata")

    static func loadCity(_ store: KeyValueStore) -> PanchangCity? {
        guard let raw = store.string(forKey: cityKey),
              let city = try? JSONDecoder().decode(PanchangCity.self, from: Data(raw.utf8)),
              (try? city.validate()) != nil else { return nil }
        return city
    }

    /// Tapping "Location Denied": iOS asks only once, so after a denial the
    /// app's Settings page opens instead.
    func requestLocationAgain() async {
        if location.isDenied {
            if let url = URL(string: UIApplication.openSettingsURLString) { await UIApplication.shared.open(url) }
            return
        }
        _ = await location.requestPermission()
        await handleLocation()
    }

    // MARK: Data

    /// Loads the Ekadashis for the city, tradition and language, keeping the
    /// card on screen unless [scrollToNext]. A city or tradition not yet
    /// calculated is calculated off the main thread (then cached on disk).
    func reload(scrollToNext: Bool = false) {
        guard let schedule else {
            loadError = t("failed_load")
            isLoading = false
            return
        }
        loadGeneration += 1
        let generation = loadGeneration
        let city = ekadashiCity, tradition = self.tradition, language = self.language, years = enabledYears
        let cached = years.allSatisfy { schedule.isCached(EkadashiScheduleKey(city: city, tradition: tradition, year: $0)) }
        if cached, let list = try? schedule.ekadashis(city: city, tradition: tradition, language: language, years: years) {
            apply(list, scrollToNext: scrollToNext)
            return
        }
        isCalculating = true
        loadTask = Task {
            let list = await Task.detached(priority: .userInitiated) {
                try? schedule.ekadashis(city: city, tradition: tradition, language: language, years: years)
            }.value
            guard generation == loadGeneration else { return }
            isCalculating = false
            if let list { apply(list, scrollToNext: scrollToNext) } else {
                loadError = t("failed_load")
                isLoading = false
            }
        }
    }

    /// Waits for a calculation started by [reload] (tests, background refresh).
    func waitForLoad() async { await loadTask?.value }

    private func apply(_ list: [EkadashiOccurrence], scrollToNext: Bool) {
        let shown = homeEkadashis
        let current = shown.indices.contains(homeIndex) ? shown[homeIndex].occurrenceUid : nil
        ekadashis = list
        loadError = nil
        isLoading = false
        isCalculating = false
        if !vrat.isEnabled { vrat.load(ekadashis) } else { announce(vrat.refreshAchievements(ekadashis)) }
        let home = homeEkadashis
        if !scrollToNext, let current, let index = home.firstIndex(where: { $0.occurrenceUid == current }) {
            homeIndex = index
        } else {
            homeIndex = HomeSelection.index(of: home, now: Date(), zone: scheduleZone, includeParana: true)
        }
        syncWidgets()
        Task { await scheduleReminders() }
        if let route = pendingRoute {
            pendingRoute = nil
            open(route)
        }
    }

    func setLanguage(_ code: String) {
        guard Localizer.languages.contains(code), code != language else { return }
        language = code
        store.set(code, forKey: "language_code")
        reload()
    }

    func setDarkMode(_ on: Bool) {
        isDarkMode = on
        store.set(on, forKey: "is_dark_mode")
    }

    // MARK: Reminders and widgets

    /// The Ekadashi switches; the master switch also covers event reminders.
    func updateReminders(_ settings: ReminderSettings) {
        reminderSettings = settings
        settings.save(to: store)
        eventReminders.enabled = settings.enabled
        Task { await scheduleReminders() }
    }

    /// Festival, Panchang and calendar reminders (docs/ROADMAP.md Phase 7).
    func updateEventReminders(_ settings: EventReminderSettings) {
        eventReminders = settings
        settings.save(to: store)
        Task { await scheduleReminders() }
    }

    /// Plans every reminder again, one run at a time so a slower run cannot
    /// leave its older plan behind.
    func scheduleReminders() async {
        let previous = schedulingTask
        let task = Task { @MainActor in
            await previous?.value
            await scheduleRemindersNow()
        }
        schedulingTask = task
        await task.value
    }

    private func scheduleRemindersNow() async {
        let settings = ReminderSettings.load(from: store)
        guard settings.enabled, await notifications.isAuthorized() else {
            await notifications.cancelAll()
            return
        }
        let language = self.language, now = Date()
        let fasts = ReminderPlanner.plan(occurrences: ekadashis, settings: settings,
                                         texts: { Localizer.shared.translate($0, language: language) }, now: now)
        let events = EventReminderSettings.load(from: store)
        let premium = self.premium.isPremium
        let city = panchangCity
        var observances: [DatedObservance] = []
        if premium && events.reminders.contains(where: \.target.requiresPremium) {
            let year = city.today().year
            observances = await panchangObservances(year: year, city: city)
            // Near the year's end the next year's festivals are within reach.
            if city.today().month >= 11 { observances += await panchangObservances(year: year + 1, city: city) }
        }
        let planned = EventReminderPlanner.plan(
            settings: events, observances: observances, entries: (try? entries.all()) ?? [],
            observanceZone: TimeZone(identifier: city.timeZoneId) ?? .current, entryZone: .current,
            language: language, premium: premium, now: now)
        await notifications.schedule(PendingNotification.merge(ekadashi: fasts, events: planned))
    }

    func syncWidgets() {
        guard !ekadashis.isEmpty else { return }
        WidgetBridge.publish(WidgetSnapshot.build(occurrences: ekadashis, timezone: ekadashiCity.timeZoneId,
                                                  locationName: ekadashiCityName, language: language, now: Date(),
                                                  tradition: tradition.rawValue))
    }

    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskId)
        request.earliestBeginDate = Date().addingTimeInterval(6 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Background App Refresh: keep reminders and widgets current.
    func backgroundRefresh() async {
        reload()
        await waitForLoad()
        await premium.refresh()
        removeLapsedPremiumImports()
        await scheduleReminders()
        scheduleBackgroundRefresh()
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .active:
            Task {
                await premium.refresh()
                removeLapsedPremiumImports()
            }
            premium.startRecheck()
            syncWidgets()
        case .background:
            premium.stopRecheck()
            scheduleBackgroundRefresh()
        default:
            break
        }
    }

    // MARK: Navigation

    func open(_ url: URL) {
        guard let route = AppRoute(url: url) else { return }
        open(route)
    }

    func open(_ route: AppRoute) {
        guard !isLoading else {
            pendingRoute = route
            return
        }
        searchReturn.clear()
        switch route {
        case .search:
            restoredSearch = nil
            showSearch = true
        case .tab(let tab):
            showSearch = false
            selectedTab = tab
            if tab == .today { homeIndex = HomeSelection.index(of: homeEkadashis, now: Date(), zone: scheduleZone, includeParana: true) }
        case .calendar(let date):
            showSearch = false
            selectedTab = .calendar
            calendarFocus = date
        case .panchang(let date):
            showSearch = false
            selectedTab = .panchang
            panchangFocus = date
        }
    }

    /// A search result that opens a tab or calendar day; that screen's top
    /// bar can go back to the same search.
    func open(_ route: AppRoute, from session: SearchSession) {
        open(route)
        searchReturn.opened(route, from: session)
    }

    func returnToSearch() {
        guard let session = searchReturn.goBack() else { return }
        restoredSearch = session
        showSearch = true
    }

    /// The user chose a tab in the tab bar.
    func select(_ tab: AppTab) {
        searchReturn.selected(tab)
        if tab == selectedTab { reselect(tab) }
        selectedTab = tab
    }

    /// Tapping the selected tab again: Today skips to the strictly next
    /// Ekadashi; Calendar returns to today.
    func reselect(_ tab: AppTab) {
        if tab == .today {
            homeIndex = HomeSelection.index(of: homeEkadashis, now: Date(), zone: scheduleZone, includeParana: false)
        } else if tab == .calendar {
            calendarFocus = today
        }
    }

    // MARK: Vrat

    /// Queues unlock dialogs. After a sheet closes, waits for its dismissal
    /// so the dialog is not presented over a closing sheet.
    func announce(_ achievements: [Achievement], afterDismissal: Bool = false) {
        guard !achievements.isEmpty else { return }
        guard afterDismissal else {
            unlockQueue.append(contentsOf: achievements)
            return
        }
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            unlockQueue.append(contentsOf: achievements)
        }
    }

    /// Recording opens once the fast has happened (Parana started, or the
    /// day after); an existing record stays editable.
    func canRecord(_ event: EkadashiOccurrence) -> Bool {
        vrat.record(for: event.occurrenceUid) != nil || VratRecording.isOpen(event, now: Date(), zone: scheduleZone)
    }

    // MARK: Premium paywall

    /// Opens the paywall and waits until it closes; true when premium now.
    func presentPaywall(reason: String?) async -> Bool {
        await withCheckedContinuation { continuation in
            paywallContinuation?.resume(returning: premium.isPremium)
            paywallContinuation = continuation
            paywall = PaywallRequest(reason: reason)
        }
    }

    func openPaywall(reason: String? = nil) { paywall = PaywallRequest(reason: reason) }

    func paywallClosed() {
        paywall = nil
        paywallContinuation?.resume(returning: premium.isPremium)
        paywallContinuation = nil
        announce(vrat.refreshAchievements(ekadashis), afterDismissal: true)
    }

    // MARK: Google Calendar

    var coordinator: GoogleSyncCoordinator {
        if let coordinatorStorage { return coordinatorStorage }
        let made = GoogleSyncCoordinator(
            importer: GoogleCalendarImporter(auth: google, store: entries), registry: registry, preferences: store,
            premium: { [snapshot = premium.snapshot] in snapshot.state },
            refreshPremium: { [weak self] in
                guard let self else { return PremiumState() }
                await self.premium.refresh()
                return await MainActor.run { self.premium.state }
            },
            presentPaywall: { [weak self] reason in await self?.presentPaywall(reason: reason) ?? false },
            pickCalendars: { [weak self] calendars, saved, email in
                await self?.pickCalendars(calendars, saved, email) ?? .cancelled
            },
            message: { [weak self] key, args, upsell in
                Task { @MainActor in self?.show(key, args: args, upsell: upsell) }
            })
        coordinatorStorage = made
        return made
    }

    private func pickCalendars(_ calendars: [GoogleCalendarInfo], _ saved: [String], _ email: String?) async -> GoogleCalendarPickerResult {
        await withCheckedContinuation { continuation in
            pickerContinuation?.resume(returning: .cancelled)
            pickerContinuation = continuation
            googlePicker = GooglePickerRequest(calendars: calendars, saved: saved, email: email)
        }
    }

    func pickerFinished(_ result: GoogleCalendarPickerResult) {
        googlePicker = nil
        pickerContinuation?.resume(returning: result)
        pickerContinuation = nil
    }

    func entriesChanged() {
        entriesRevision += 1
        if eventReminders.reminders.contains(where: { !$0.target.requiresPremium }) { Task { await scheduleReminders() } }
    }

    func removeLapsedPremiumImports() {
        if (try? coordinator.removeLapsedPremiumSync()) == true {
            entriesChanged()
            show("google_premium_events_removed")
        }
    }

    // MARK: Messages

    func show(_ key: String, args: [String] = [], upsell: Bool = false) {
        let text = Localizer.shared.translate(key, language: language, args: args)
        toast = ToastMessage(text: text, actionTitle: upsell ? t("premium_upgrade") : nil,
                             action: upsell ? { [weak self] in self?.openPaywall() } : nil)
    }

    // MARK: Search

    /// The saved Panchang location; festival dates in search follow it.
    var panchangCity: PanchangCity { PanchangLocationStore(store: store).load() ?? .newDelhi }

    /// Saves the Panchang tab's own location (it does not move the Ekadashi city).
    func savePanchangCity(_ city: PanchangCity) { try? PanchangLocationStore(store: store).save(city) }

    /// Search over Ekadashis, entries and screens, plus [observances].
    func searchIndex(observances: [DatedObservance] = []) -> UnifiedSearch {
        let schedule = schedule
        let city = ekadashiCity, tradition = self.tradition, years = enabledYears
        let items = SearchCorpus.build(
            ekadashis: { language in
                // Only what is already calculated: search never calculates on the main thread.
                guard let schedule, years.allSatisfy({
                    schedule.isCached(EkadashiScheduleKey(city: city, tradition: tradition, year: $0))
                }) else { return [] }
                return (try? schedule.ekadashis(city: city, tradition: tradition, language: language, years: years)) ?? []
            },
            observances: observances,
            entries: (try? entries.all()) ?? [], timeZone: .current, language: language)
        return UnifiedSearch(items: items)
    }

    /// Panchang observances for every data year at the Panchang location.
    func searchObservances() async -> [DatedObservance] {
        let city = panchangCity
        var result: [DatedObservance] = []
        for year in enabledYears { result += await panchangObservances(year: year, city: city) }
        return result
    }

    /// A year of observances at [city], calculated off the main thread and
    /// kept for the session (Key days and search share it).
    func panchangObservances(year: Int, city: PanchangCity) async -> [DatedObservance] {
        let key = "\(city.id)|\(city.latitude)|\(city.longitude)|\(city.timeZoneId)|\(year)"
        if let cached = observanceCache[key] { return cached }
        let calculated = await Task.detached(priority: .userInitiated) {
            PanchangEngine().observanceCalendar(year: year, city: city)
        }.value
        observanceCache[key] = calculated
        return calculated
    }

    var calendarYears: ClosedRange<Int>? {
        guard let first = enabledYears.first, let last = enabledYears.last else { return nil }
        return first...last
    }
}
