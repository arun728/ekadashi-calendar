import XCTest
@testable import EkadashiCore

/// A search result that opens a tab or a calendar day leaves the search, so
/// that screen's top bar offers to go back to the same results.
final class SearchReturnTests: XCTestCase {
    private let session = SearchSession(query: "settings", category: .screen, year: 2027)

    func testAScreenOpenedFromSearchGoesBackToTheSameSearch() {
        var back = SearchReturn()
        back.opened(.tab(.settings), from: session)
        XCTAssertTrue(back.showsBack(on: .settings))
        XCTAssertFalse(back.showsBack(on: .calendar), "only the screen the result opened")
        XCTAssertEqual(back.goBack(), session)
        XCTAssertFalse(back.showsBack(on: .settings), "going back uses the return up")
        XCTAssertNil(back.goBack())
    }

    func testCalendarEntriesAndPanchangDaysReturnFromTheirTabs() {
        var back = SearchReturn()
        back.opened(.calendar(CivilDate(2027, 1, 14)), from: session)
        XCTAssertTrue(back.showsBack(on: .calendar))
        back.opened(.panchang(CivilDate(2027, 1, 14)), from: session)
        XCTAssertTrue(back.showsBack(on: .panchang))
        XCTAssertFalse(back.showsBack(on: .calendar), "a newer result replaces the older one")
        back.opened(.search, from: session)
        XCTAssertFalse(AppTab.allCases.contains { back.showsBack(on: $0) }, "search itself needs no way back")
    }

    func testChoosingAnotherTabOrANewSearchForgetsTheReturn() {
        var back = SearchReturn()
        back.opened(.tab(.vrat), from: session)
        back.selected(.vrat)
        XCTAssertTrue(back.showsBack(on: .vrat), "re-selecting the same tab keeps it")
        back.selected(.today)
        XCTAssertFalse(back.showsBack(on: .vrat))
        XCTAssertNil(back.goBack())

        back.opened(.tab(.vrat), from: session)
        back.clear()
        XCTAssertNil(back.goBack())
    }

    func testRoutesNameTheirTab() {
        XCTAssertEqual(AppRoute.tab(.vrat).tab, .vrat)
        XCTAssertEqual(AppRoute.calendar(nil).tab, .calendar)
        XCTAssertEqual(AppRoute.panchang(CivilDate(2027, 1, 1)).tab, .panchang)
        XCTAssertNil(AppRoute.search.tab)
    }

    /// The search pages, in the order the chips show them: All, then each type.
    func testSearchPagesStartWithAll() {
        XCTAssertEqual(SearchCategory.pages.first, .some(nil))
        XCTAssertEqual(Array(SearchCategory.pages.dropFirst()), SearchCategory.filters.map { Optional($0) })
    }
}
