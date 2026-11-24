import Foundation
import XCTest

/// The App Store privacy manifest must match the App Privacy answers: the free
/// Google import signs in to Firebase Authentication, which keeps the account's
/// User ID and email address for App Functionality, linked and not for tracking.
final class PrivacyManifestTests: XCTestCase {
    private func collectedTypes() throws -> [[String: Any]] {
        let data = try Repo.data("ios-native/EkadashiCalendar/Resources/PrivacyInfo.xcprivacy")
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(plist["NSPrivacyTracking"] as? Bool, false)
        return try XCTUnwrap(plist["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
    }

    func testDeclaresUserIDAndEmailForAppFunctionalityOnly() throws {
        let types = try collectedTypes()
        for kind in ["NSPrivacyCollectedDataTypeUserID", "NSPrivacyCollectedDataTypeEmailAddress"] {
            let entry = try XCTUnwrap(types.first { $0["NSPrivacyCollectedDataType"] as? String == kind }, "\(kind) missing")
            XCTAssertEqual(entry["NSPrivacyCollectedDataTypeLinked"] as? Bool, true, kind)
            XCTAssertEqual(entry["NSPrivacyCollectedDataTypeTracking"] as? Bool, false, kind)
            XCTAssertEqual(entry["NSPrivacyCollectedDataTypePurposes"] as? [String],
                           ["NSPrivacyCollectedDataTypePurposeAppFunctionality"], kind)
        }
        XCTAssertEqual(types.count, 2, "Only User ID and Email Address are collected")
    }
}
