import Foundation
import XCTest
@testable import EkadashiCore

/// Locates files in the repository so the Swift tests share the Flutter app's
/// fixtures and assets instead of keeping copies.
enum Repo {
    static let root: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // EkadashiCoreTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // EkadashiCore
        .deletingLastPathComponent() // ios-native
        .deletingLastPathComponent() // repository

    static func url(_ path: String) -> URL { root.appendingPathComponent(path) }

    static func data(_ path: String) throws -> Data { try Data(contentsOf: url(path)) }

    static func json(_ path: String) throws -> Any {
        try JSONSerialization.jsonObject(with: data(path))
    }
}

/// Parses the ISO 8601 instants used in fixtures ("Z" or an explicit offset).
func instant(_ text: String, file: StaticString = #filePath, line: UInt = #line) -> Date {
    guard let date = ISO8601.instant(text) else {
        XCTFail("Not an ISO 8601 instant: \(text)", file: file, line: line)
        return Date(timeIntervalSince1970: 0)
    }
    return date
}

func utc(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0) -> Date {
    CivilDate(year, month, day).utcMidnight.addingTimeInterval(Double(hour * 3600 + minute * 60 + second))
}

func secondsBetween(_ a: Date?, _ b: Date?) -> Double {
    guard let a, let b else { return .infinity }
    return abs(a.timeIntervalSince(b))
}

extension Dictionary where Key == String, Value == Any {
    func string(_ key: String) -> String? { self[key] as? String }
    func double(_ key: String) -> Double? { (self[key] as? NSNumber)?.doubleValue }
    func int(_ key: String) -> Int? { (self[key] as? NSNumber)?.intValue }
    func dict(_ key: String) -> [String: Any]? { self[key] as? [String: Any] }
    func array(_ key: String) -> [Any]? { self[key] as? [Any] }
}
