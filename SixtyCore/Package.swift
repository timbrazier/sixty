// swift-tools-version:5.9
import PackageDescription

// Plain Foundation logic shared by the app: calendar days, completion,
// streaks, CSV and notification copy. No UI, so it can be unit-tested
// on its own.
let package = Package(
    name: "SixtyCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SixtyCore", targets: ["SixtyCore"]),
    ],
    targets: [
        .target(name: "SixtyCore"),
        .testTarget(name: "SixtyCoreTests", dependencies: ["SixtyCore"]),
    ]
)
