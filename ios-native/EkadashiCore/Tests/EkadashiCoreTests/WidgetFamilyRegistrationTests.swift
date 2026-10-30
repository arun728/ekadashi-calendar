import XCTest

final class WidgetFamilyRegistrationTests: XCTestCase {
    func testOnlyUpcomingRegistersTheLargeFamily() throws {
        let source = String(decoding: try Repo.data("ios-native/EkadashiWidgets/EkadashiWidgets.swift"), as: UTF8.self)
        let single = try XCTUnwrap(source.components(separatedBy: "struct EkadashiWidget: Widget").last?.components(separatedBy: "struct UpcomingEkadashiWidget: Widget").first)
        let upcoming = try XCTUnwrap(source.components(separatedBy: "struct UpcomingEkadashiWidget: Widget").last)
        XCTAssertTrue(single.contains(".supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])"))
        XCTAssertFalse(single.contains(".systemLarge"))
        XCTAssertTrue(upcoming.contains(".supportedFamilies([.systemMedium, .systemLarge])"))
    }
}
