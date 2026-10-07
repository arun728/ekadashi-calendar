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
        .target(name: "EkadashiCore", resources: [.copy("Resources")]),
        .testTarget(name: "EkadashiCoreTests", dependencies: ["EkadashiCore"]),
    ]
)
