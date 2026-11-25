import XCTest
@testable import EkadashiCore

/// The billing and Journey copy Arun approved on 25 Nov 2026
/// (test/fixtures/billing_copy.json). Both apps read the same fixture:
/// shared keys match exactly and store keys differ only in the store name.
/// No billing string shows a date; Google Play and the App Store show them.
final class BillingCopyTests: XCTestCase {
    private func fixture() throws -> [String: Any] {
        try Repo.json("test/fixtures/billing_copy.json") as! [String: Any]
    }

    func testIOSShowsTheApprovedCopyInEveryLanguage() throws {
        let copy = try fixture()
        for language in Localizer.languages {
            let rows = try XCTUnwrap(copy[language] as? [String: [String: String]], language)
            for (key, row) in rows {
                let expected = try XCTUnwrap(row["both"] ?? row["ios"], "\(language) \(key)")
                XCTAssertEqual(Localizer.shared.translate(key, language: language), expected, "\(language) \(key)")
            }
        }
    }

    func testDatedBillingStringsAreGone() throws {
        let removed = try XCTUnwrap(try fixture()["removed_keys"] as? [String])
        for language in Localizer.languages {
            let keys = Set(Localizer.shared.keys(language: language) + Localizer.shared.overrideKeys(language: language))
            for key in removed { XCTAssertFalse(keys.contains(key), "\(language) still has \(key)") }
        }
    }

    func testNoIOSBillingStringNamesGooglePlay() {
        let google = ["Google", "गूगल", "கூகுள்", "గూగుల్", "ગૂગલ", "গুগল"]
        for language in Localizer.languages {
            for key in ["premium_renewal_in_play", "premium_monthly_switch_scheduled", "premium_cancelled_body",
                        "premium_switch_at_renewal_body", "premium_manage", "premium_monthly_terms", "premium_yearly_terms"] {
                let text = Localizer.shared.translate(key, language: language)
                XCTAssertFalse(google.contains { text.contains($0) }, "\(language) \(key): \(text)")
            }
        }
    }
}
