import Foundation

public enum WidgetDeepLinks {
    public static let scheme = "ekadashi"
    public static let hostDashboard = "dashboard"
    public static let hostToday = "today"
    public static let hostCalendar = "calendar"

    public static let paramAction = "action"
    public static let paramDate = "date"
    public static let actionParana = "parana"

    /// Small Widget Destination: ekadashi://dashboard
    public static var dashboardURL: URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = hostDashboard
        return components.url ?? URL(string: "ekadashi://dashboard")!
    }

    /// Medium Widget (Parana active): ekadashi://dashboard?action=parana
    public static var paranaActiveURL: URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = hostDashboard
        components.queryItems = [URLQueryItem(name: paramAction, value: actionParana)]
        return components.url ?? URL(string: "ekadashi://dashboard?action=parana")!
    }

    /// Medium Widget (Other states): ekadashi://today
    public static var todayURL: URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = hostToday
        return components.url ?? URL(string: "ekadashi://today")!
    }

    /// Large Widget item link: ekadashi://calendar?date={iso_date}
    public static func calendarDateURL(isoDate: String) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = hostCalendar
        components.queryItems = [URLQueryItem(name: paramDate, value: isoDate)]
        return components.url ?? URL(string: "ekadashi://calendar?date=\(isoDate)")!
    }
}
