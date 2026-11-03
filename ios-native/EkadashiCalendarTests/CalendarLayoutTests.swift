import XCTest
import SwiftUI
import EkadashiCore
@testable import EkadashiCalendar

@MainActor
final class CalendarLayoutTests: XCTestCase {
    func testEveryEnabledMonthReservesAllItsRowsAtCompactAndTabletWidths() throws {
        let years = EkadashiYears.enabled()
        XCTAssertTrue(years.contains(2027))
        let model = AppModel(store: InMemoryKeyValueStore(["has_launched": true, "language_code": "en"]))
        for year in years {
            for number in 1...12 {
                let month = CivilDate(year, number, 1)
                let rows = (month.weekday % 7 + month.daysInMonth + 6) / 7
                for width in [320.0, 375, 390, 568, 740, 820, 1180] {
                    for type in [DynamicTypeSize.large, .xxLarge] {
                        let grid = MonthGrid(month: month, selected: month, today: month,
                                             firstDay: CivilDate(years.first!, 1, 1),
                                             lastDay: CivilDate(years.last!, 12, 31),
                                             markers: { _ in [.teal] }, select: { _ in })
                            .environment(model)
                            .environment(\.dynamicTypeSize, type)
                            .frame(width: width)
                        let renderer = ImageRenderer(content: grid)
                        renderer.scale = 1
                        let image = try XCTUnwrap(renderer.uiImage)
                        XCTAssertEqual(image.size.height, CGFloat(28 + rows * 48), accuracy: 0.5,
                                       "\(year)-\(number), width \(width), \(type): every date row must contribute its full height")
                    }
                }
            }
        }
    }
}
