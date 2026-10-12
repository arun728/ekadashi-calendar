import XCTest
@testable import EkadashiCore

/// Every tab and sub-tab shows a date the same way, with the weekday, date,
/// month and year ("Thu, 8 Oct 2026"), as on Android
/// (test/unit/date_format_consistency_test.dart).
final class DateConsistencyTests: XCTestCase {
    func testTheFullDateHasWeekdayDateMonthAndYear() {
        XCTAssertEqual(PanchangFormat.date(CivilDate(2026, 10, 8), language: "en"), "Thu, 8 Oct 2026")
    }

    /// Month steps (Calendar and Panchang's monthly sub-tabs) keep the day
    /// of the month, or the last day of a shorter month.
    func testAMonthStepKeepsTheDayOfTheMonth() {
        XCTAssertEqual(CivilDate(2026, 10, 8).steppingMonths(1), CivilDate(2026, 11, 8))
        XCTAssertEqual(CivilDate(2026, 10, 31).steppingMonths(1), CivilDate(2026, 11, 30))
        XCTAssertEqual(CivilDate(2026, 3, 31).steppingMonths(-1), CivilDate(2026, 2, 28))
        XCTAssertEqual(CivilDate(2026, 12, 5).steppingMonths(1), CivilDate(2027, 1, 5))
    }

    func testNoScreenFormatsADateAnotherWay() throws {
        let other = try NSRegularExpression(
            pattern: #""(MMM dd, yyyy|EEEE, d MMMM yyyy|EEEE|LLLL yyyy|MMMM yyyy|d MMMM yyyy)"|PanchangFormat\.monthTitle\("#)
        let features = Repo.url("ios-native/EkadashiCalendar/Features")
        var offenders: [String] = []
        let files = FileManager.default.enumerator(at: features, includingPropertiesForKeys: nil)!
        for case let file as URL in files where file.pathExtension == "swift" {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
            for (index, line) in lines.enumerated()
            where other.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil {
                offenders.append("\(file.lastPathComponent):\(index + 1)")
            }
        }
        XCTAssertEqual(offenders, [])
    }
}
