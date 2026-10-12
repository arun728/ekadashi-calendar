import Foundation

public enum AppTab: Int, CaseIterable, Sendable {
    case today, calendar, vrat, panchang, settings
}

/// `ekadashi://` links from widgets and notifications (main.dart handleDeepLink).
public enum AppRoute: Equatable, Sendable {
    case tab(AppTab)
    case calendar(CivilDate?)
    /// A day in Panchang (event reminders).
    case panchang(CivilDate)
    case search

    public init?(url: URL) {
        guard url.scheme == "ekadashi", let host = url.host else { return nil }
        switch host {
        case "search": self = .search
        case "dashboard", "today", "parana": self = .tab(.today)
        case "calendar":
            let date = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                .first { $0.name == "date" }?.value.flatMap(CivilDate.init(iso:))
            self = .calendar(date)
        case "vrat": self = .tab(.vrat)
        // PR #12's More tab lives inside Panchang.
        case "panchang", "more":
            let date = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                .first { $0.name == "date" }?.value.flatMap(CivilDate.init(iso:))
            self = date.map(AppRoute.panchang) ?? .tab(.panchang)
        case "settings": self = .tab(.settings)
        default: return nil
        }
    }

    public static let dashboardURL = URL(string: "ekadashi://dashboard")!
    public static let paranaURL = URL(string: "ekadashi://dashboard?action=parana")!
    public static let todayURL = URL(string: "ekadashi://today")!
    public static func calendarURL(_ date: CivilDate) -> URL { URL(string: "ekadashi://calendar?date=\(date.iso)")! }
    public static func panchangURL(_ date: CivilDate) -> URL { URL(string: "ekadashi://panchang?date=\(date.iso)")! }
}
