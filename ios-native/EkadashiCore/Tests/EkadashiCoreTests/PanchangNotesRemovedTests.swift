import Foundation
import XCTest

/// The Panchang tab shows no warnings, notes or calculation methods: no
/// near-boundary warning, "calculated preview" footer, Rashi or Choghadiya
/// note, Ekadashi rule or Parana reason, or ayanamsa row
/// (panchang_ios_parity_test.dart checks the Android screens the same way).
final class PanchangNotesRemovedTests: XCTestCase {
    func testPanchangScreensNoLongerShowTheRemovedNotes() throws {
        let folder = Repo.url("ios-native/EkadashiCalendar/Features/Panchang")
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasSuffix(".swift") }
        XCTAssertFalse(files.isEmpty)
        for file in files {
            let source = try String(contentsOf: folder.appendingPathComponent(file), encoding: .utf8)
            for text in ["panchang_near_boundary", "panchang_calculated_preview", "panchang_rashi_note",
                         "panchang_choghadiya_hint", "\"panchang_rule\"", "panchang_calculation_details",
                         "panchang_ayanamsa", "paranaReason"] {
                XCTAssertFalse(source.contains(text), "\(file): \(text)")
            }
        }
    }
}
