// swift-tools-version: 5.10
// Platform-independent core of the native iOS app: the Panchang engine and
// Ekadashi rules, published calendar data, Vrat tracker, premium policy,
// Google Calendar import, search, reminders and widget snapshots. It builds
// and tests on Linux (swift test) as well as in Xcode.
import PackageDescription

let package = Package(
    name: "EkadashiCore",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "EkadashiCore", targets: ["EkadashiCore"])],
    targets: [
        // Copy each data directory without placing a reserved Resources/
        // directory at the flat iOS bundle root, which codesign rejects.
        .target(name: "EkadashiCore", resources: [
            .copy("Resources/calendar"),
            .copy("Resources/l10n"),
            .copy("Resources/panchang"),
            .copy("Resources/search"),
            .copy("Resources/tz"),
        ]),
        .testTarget(name: "EkadashiCoreTests", dependencies: ["EkadashiCore"]),
    ]
)
