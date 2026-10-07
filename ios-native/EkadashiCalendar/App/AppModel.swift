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
    @ObservationIgnored let notifications = NotificationService()
    @ObservationIgnored let location = LocationService()
    @ObservationIgnored let searchIndex: SearchIndex
    @ObservationIgnored let recents: RecentSearches
    @ObservationIgnored let entries: CalendarEntryStore
    @ObservationIgnored let google = GoogleSignInGateway()
    @ObservationIgnored let registry: FreeSyncRegistry?
    @ObservationIgnored private var coordinatorStorage: GoogleSyncCoordinator?
    @ObservationIgnored private var paywallContinuation: CheckedContinuation<Bool, Never>?
    @ObservationIgnored private var pickerContinuation: CheckedContinuation<GoogleCalendarPickerResult, Never>?
    @ObservationIgnored private var started = false
    @ObservationIgnored private var pendingRoute: AppRoute?

    let premium: StoreKitPremiumService
    let vrat: VratStore

    private(set) var language: String
    private(set) var isDarkMode: Bool
    private(set) var timezone: AppTimezone
    private(set) var locationState: LocationState = .unknown
    private(set) var ekadashis: [EkadashiOccurrence] = []
    private(set) var loadError: String?
    private(set) var isLoading = true
    private(set) var reminderSettings: ReminderSettings
    private(set) var entriesRevision = 0
    var selectedTab: AppTab = .today
    var showSearch = false
    var homeIndex = 0
    var calendarFocus: CivilDate?
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
        language = store.string(forKey: "language_code").flatMap { Localizer.languages.contains($0) ? $0 : nil } ?? Self.systemLanguage
        isDarkMode = store.bool(forKey: "is_dark_mode") ?? true
        timezone = store.string(forKey: "app_timezone").flatMap(AppTimezone.init(rawValue:))
            ?? AppTimezone.matching(deviceIdentifier: TimeZone.current.identifier)
        reminderSettings = ReminderSettings.load(from: store)
        recents = RecentSearches(store: store)
        searchIndex = SearchIndex(downloaded: Set(store.stringArray(forKey: "ec2_downloaded_content_ids") ?? []))
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

    func format(_ date: CivilDate, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = pattern
        return formatter.string(from: date.utcMidnight)
    }

    var scheduleZone: TzLocation { timezone.location }
    var today: CivilDate { scheduleZone.wallClock(Date()).date }
    var locationName: String { if case .located(let city) = locationState { return city }; return "" }

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

    /// Location chooses the schedule; without it the device time zone does.
    func handleLocation() async {
        locationState = .detecting
        if let fix = await location.currentFix(store: store) {
            setTimezone(fix.timezone)
            locationState = .located(fix.city)
        } else if location.isDenied {
            setTimezone(AppTimezone.matching(deviceIdentifier: TimeZone.current.identifier))
            locationState = .denied
        } else if !location.hasPermission {
            // Not asked yet (or restricted to ask later): use the device
            // time zone; tapping the location asks for permission.
            setTimezone(AppTimezone.matching(deviceIdentifier: TimeZone.current.identifier))
            locationState = .unknown
        } else if let cached = location.cachedFix(store: store) {
            setTimezone(cached.timezone)
            locationState = .located(cached.city)
        } else {
            setTimezone(AppTimezone.matching(deviceIdentifier: TimeZone.current.identifier))
            locationState = .unknown
        }
        reload(scrollToNext: true)
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

    private func setTimezone(_ zone: AppTimezone) {
        timezone = zone
        store.set(zone.rawValue, forKey: "app_timezone")
    }

    // MARK: Data

    /// Loads the schedule for the language and time zone, keeping the card
    /// on screen unless [scrollToNext].
    func reload(scrollToNext: Bool = false) {
        guard let repository else {
            loadError = t("failed_load")
            isLoading = false
            return
        }
        let current = ekadashis.indices.contains(homeIndex) ? ekadashis[homeIndex].id : nil
        ekadashis = repository.ekadashis(timezone: timezone.rawValue, language: language)
        loadError = nil
        isLoading = false
        if !vrat.isEnabled { vrat.load(ekadashis) } else { announce(vrat.refreshAchievements(ekadashis)) }
        if !scrollToNext, let current, let index = ekadashis.firstIndex(where: { $0.id == current }) {
            homeIndex = index
        } else {
            homeIndex = HomeSelection.index(of: ekadashis, now: Date(), zone: scheduleZone, includeParana: true)
        }
        searchIndex.build(ekadashis: ekadashis, language: language)
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

    func updateReminders(_ settings: ReminderSettings) {
        reminderSettings = settings
        settings.save(to: store)
        Task { await scheduleReminders() }
    }

    func scheduleReminders() async {
        let settings = ReminderSettings.load(from: store)
        guard settings.enabled, await notifications.isAuthorized() else {
            await notifications.cancelAll()
            return
        }
        let language = self.language
        let plan = ReminderPlanner.plan(occurrences: ekadashis, settings: settings,
                                        texts: { Localizer.shared.translate($0, language: language) }, now: Date())
        await notifications.schedule(plan)
    }

    func syncWidgets() {
        guard !ekadashis.isEmpty else { return }
        WidgetBridge.publish(WidgetSnapshot.build(occurrences: ekadashis, timezone: timezone.rawValue,
                                                  locationName: locationName, language: language, now: Date()))
    }

    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskId)
        request.earliestBeginDate = Date().addingTimeInterval(6 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Background App Refresh: keep reminders and widgets current.
    func backgroundRefresh() async {
        reload()
        await scheduleReminders()
        await premium.refresh()
        removeLapsedPremiumImports()
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
        switch route {
        case .search:
            showSearch = true
        case .tab(let tab):
            showSearch = false
            selectedTab = tab
            if tab == .today { homeIndex = HomeSelection.index(of: ekadashis, now: Date(), zone: scheduleZone, includeParana: true) }
        case .calendar(let date):
            showSearch = false
            selectedTab = .calendar
            calendarFocus = date
        }
    }

    /// Tapping the selected tab again: Today skips to the strictly next
    /// Ekadashi; Calendar returns to today.
    func reselect(_ tab: AppTab) {
        if tab == .today {
            homeIndex = HomeSelection.index(of: ekadashis, now: Date(), zone: scheduleZone, includeParana: false)
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

    func entriesChanged() { entriesRevision += 1 }

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

    func markDownloaded(_ id: String) {
        searchIndex.markDownloaded(id)
        var ids = Set(store.stringArray(forKey: "ec2_downloaded_content_ids") ?? [])
        ids.insert(id)
        store.set(ids.sorted(), forKey: "ec2_downloaded_content_ids")
    }

    var calendarYears: ClosedRange<Int>? {
        guard let first = repository?.availableYears.first, let last = repository?.availableYears.last else { return nil }
        return first...last
    }
}
