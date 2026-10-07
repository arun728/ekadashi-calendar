import Foundation

public enum GoogleCalendarPickerResult: Equatable, Sendable {
    case cancelled
    case switchAccount
    case chosen([String])
}

public enum GoogleSyncOutcome: Equatable, Sendable {
    case imported(count: Int, premium: Bool)
    case paywallDeclined
    case cancelled
    case noCalendars
    case failed
}

/// What Premium imported, so it can be removed once the App Store confirms
/// the subscription has ended (Android key `google_premium_sync_v1`).
public struct PremiumSyncRecord: Codable, Equatable, Sendable {
    public let account: String
    public let calendars: [String]
    public let start: Date
    public let end: Date
}

/// The Calendar tab's Google import rules (calendar_screen.dart `_syncYear`):
///
/// - Free users get exactly one import, of the month being viewed. It is
///   recorded on the phone and, per Google account, in the free Firestore
///   registry, so a reinstall or another phone cannot reuse it. Closing the
///   picker or a failed import keeps it; an unreachable registry hands
///   nothing out and offers Premium instead.
/// - Premium (re-checked with the App Store at every import): subscriptions
///   import the subscription year; lifetime imports every year the app has.
/// - Once the App Store confirms Premium ended (never on a store or network
///   error), the events Premium imported are removed; the free month stays.
public final class GoogleSyncCoordinator {
    public static let freeSyncUsedKey = "google_free_sync_used"
    public static let freeSyncMonthKey = "google_free_sync_month"
    public static let premiumSyncKey = "google_premium_sync_v1"
    static func selectedCalendarsKey(_ account: String) -> String { "google_sync_calendar_ids:\(account)" }

    public let importer: GoogleCalendarImporter
    let registry: FreeSyncRegistry?
    let preferences: KeyValueStore
    let calendar: Calendar
    let premium: () -> PremiumState
    let refreshPremium: () async -> PremiumState
    let presentPaywall: (String) async -> Bool
    let pickCalendars: ([GoogleCalendarInfo], [String], String?) async -> GoogleCalendarPickerResult
    let message: (String, [String], Bool) -> Void

    public init(importer: GoogleCalendarImporter, registry: FreeSyncRegistry?, preferences: KeyValueStore,
                calendar: Calendar = .current, premium: @escaping () -> PremiumState,
                refreshPremium: @escaping () async -> PremiumState,
                presentPaywall: @escaping (String) async -> Bool,
                pickCalendars: @escaping ([GoogleCalendarInfo], [String], String?) async -> GoogleCalendarPickerResult,
                message: @escaping (_ key: String, _ args: [String], _ upsell: Bool) -> Void) {
        self.importer = importer
        self.registry = registry
        self.preferences = preferences
        self.calendar = calendar
        self.premium = premium
        self.refreshPremium = refreshPremium
        self.presentPaywall = presentPaywall
        self.pickCalendars = pickCalendars
        self.message = message
    }

    var auth: GoogleAuthGateway { importer.auth }

    public func sync(viewedMonth: CivilDate, now: Date, calendarYears: ClosedRange<Int>?) async -> GoogleSyncOutcome {
        let month = viewedMonth.firstOfMonth
        var isPremium = await refreshPremium().isPremium
        if !isPremium && preferences.bool(forKey: Self.freeSyncUsedKey) == true {
            // Continue straight into the import after a successful purchase.
            guard await presentPaywall("google_free_sync_used") else { return .paywallDeclined }
            isPremium = true
        }
        do {
            let signedIn: Bool
            do {
                if await auth.isSignedIn() { signedIn = true } else { signedIn = try await auth.signIn() }
            } catch {
                message("google_sign_in_failed", [], false)
                return .failed
            }
            guard signedIn else {
                message("sign_in_cancelled", [], false)
                return .cancelled
            }
            var googleIdToken: String?
            if !isPremium, registry != nil {
                googleIdToken = try await auth.idToken()
                if googleIdToken == nil { throw CoreError.invalidData("No Google ID token") }
            }
            if !isPremium, let registry, let token = googleIdToken {
                var reason: String?
                do {
                    if try await registry.isUsed(googleIdToken: token) {
                        // This Google account used its free sync before.
                        preferences.set(true, forKey: Self.freeSyncUsedKey)
                        reason = "google_free_sync_used"
                    }
                } catch {
                    // The free sync cannot be confirmed: none is handed out,
                    // and it stays available.
                    reason = "free_sync_unverified"
                }
                if let reason {
                    guard await presentPaywall(reason) else { return .paywallDeclined }
                    isPremium = true
                }
            }
            let window: DateInterval
            if isPremium {
                guard let premiumWindow = premium().syncWindow(now: now, calendarYears: calendarYears, calendar: calendar) else {
                    return .paywallDeclined
                }
                window = premiumWindow
            } else {
                window = DateInterval(start: date(month), end: date(month.adding(months: 1)))
            }
            guard let account = await auth.accountId() else { throw CoreError.invalidData("No Google account") }
            let calendars = try await auth.listCalendars()
            guard !calendars.isEmpty else {
                message("no_google_calendars", [], false)
                return .noCalendars
            }
            let saved = preferences.stringArray(forKey: Self.selectedCalendarsKey(account)) ?? ["primary"]
            switch await pickCalendars(calendars, saved, await auth.accountEmail()) {
            case .cancelled:
                return .cancelled
            case .switchAccount:
                // Forget the account so the next sign-in shows Google's chooser.
                // The old account's imported events are kept.
                await auth.signOut()
                return await sync(viewedMonth: viewedMonth, now: now, calendarYears: calendarYears)
            case .chosen(let chosen):
                guard !chosen.isEmpty else { return .cancelled }
                // The window was fixed before the picker opened.
                let count = try await importer.syncImport(from: window.start, to: window.end, calendarIds: chosen)
                preferences.set(chosen, forKey: Self.selectedCalendarsKey(account))
                if isPremium {
                    rememberPremiumSync(account: account, calendars: chosen, start: window.start, end: window.end)
                    message("imported_google_range", ["\(count)", Self.monthLabel(window.start, calendar),
                                                      Self.monthLabel(calendar.date(byAdding: .month, value: -1, to: window.end)!, calendar)],
                            false)
                } else {
                    preferences.set(true, forKey: Self.freeSyncUsedKey)
                    preferences.set(String(month.iso.prefix(7)), forKey: Self.freeSyncMonthKey)
                    if let registry, let token = googleIdToken {
                        // Best effort: this phone already remembers the free sync.
                        try? await registry.record(googleIdToken: token, month: month)
                    }
                    message("google_free_sync_used", [], true)
                }
                return .imported(count: count, premium: isPremium)
            }
        } catch {
            message("google_sync_failed", [], false)
            return .failed
        }
    }

    /// Disconnects Google; Premium belongs to the App Store purchase and is unaffected.
    public func disconnect() async throws { try await importer.signOut() }

    public func premiumSyncRecord() -> PremiumSyncRecord? {
        preferences.string(forKey: Self.premiumSyncKey).flatMap { try? JSONDecoder.iso.decode(PremiumSyncRecord.self, from: Data($0.utf8)) }
    }

    /// Merges a premium import into the record used for removal after a lapse.
    public func rememberPremiumSync(account: String, calendars: [String], start: Date, end: Date) {
        var start = start, end = end, calendars = calendars
        if let old = premiumSyncRecord(), old.account == account {
            start = min(start, old.start)
            end = max(end, old.end)
            calendars = Array(Set(old.calendars).union(calendars)).sorted()
        }
        let record = PremiumSyncRecord(account: account, calendars: calendars, start: start, end: end)
        if let data = try? JSONEncoder.iso.encode(record) {
            preferences.set(String(decoding: data, as: UTF8.self), forKey: Self.premiumSyncKey)
        }
    }

    /// Removes Premium-imported events once the store confirms Premium ended,
    /// keeping the free month. Returns whether anything was removed.
    @discardableResult
    public func removeLapsedPremiumSync() throws -> Bool {
        guard premium().lapsed, let record = premiumSyncRecord() else { return false }
        var ranges = [(record.start, record.end)]
        if let freeMonth = preferences.string(forKey: Self.freeSyncMonthKey), let keep = CivilDate(iso: freeMonth + "-01") {
            let keepStart = date(keep), keepEnd = date(keep.adding(months: 1))
            if record.start < keepEnd && record.end > keepStart {
                ranges = []
                if record.start < keepStart { ranges.append((record.start, keepStart)) }
                if record.end > keepEnd { ranges.append((keepEnd, record.end)) }
            }
        }
        for (from, to) in ranges {
            try importer.store.replaceGoogleWindow(accountId: record.account, calendarIds: record.calendars, from: from, to: to, entries: [])
        }
        preferences.remove(Self.premiumSyncKey)
        return true
    }

    private func date(_ day: CivilDate) -> Date {
        calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day))!
    }

    static func monthLabel(_ date: Date, _ calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? Locale(identifier: "en_US")
        formatter.setLocalizedDateFormatFromTemplate("yMMM")
        return formatter.string(from: date)
    }
}
