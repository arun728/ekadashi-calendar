import Foundation

/// What a search showed: the text, the type page and the year.
public struct SearchSession: Equatable, Sendable {
    public var query: String
    public var category: SearchCategory?
    public var year: Int?

    public init(query: String, category: SearchCategory?, year: Int?) {
        self.query = query
        self.category = category
        self.year = year
    }
}

/// A search result that opens a tab or a calendar day leaves the search;
/// that screen's top bar then goes back to the same results, as a back
/// button would. Another tab, a deep link or a new search forgets it.
public struct SearchReturn: Equatable, Sendable {
    private var session: SearchSession?
    private var tab: AppTab?

    public init() {}

    /// A result opened [route] from [session].
    public mutating func opened(_ route: AppRoute, from session: SearchSession) {
        guard let tab = route.tab else { return clear() }
        self.session = session
        self.tab = tab
    }

    /// Whether [tab]'s top bar offers the way back.
    public func showsBack(on tab: AppTab) -> Bool { session != nil && self.tab == tab }

    /// The search to reopen; the way back is used up.
    public mutating func goBack() -> SearchSession? {
        defer { clear() }
        return session
    }

    /// The user chose [tab] in the tab bar.
    public mutating func selected(_ tab: AppTab) {
        if tab != self.tab { clear() }
    }

    public mutating func clear() {
        session = nil
        tab = nil
    }
}

public extension AppRoute {
    /// The tab the route opens; nil for search.
    var tab: AppTab? {
        switch self {
        case .tab(let tab): return tab
        case .calendar: return .calendar
        case .panchang: return .panchang
        case .search: return nil
        }
    }
}

public extension SearchCategory {
    /// The search pages, in chip order: All (nil), then each type.
    static let pages: [SearchCategory?] = [nil] + filters.map { Optional($0) }
}
