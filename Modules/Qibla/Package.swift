// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Qibla",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Qibla", targets: ["Qibla"])
    ],
    dependencies: [
        .package(path: "../../Core/DesignSystem"),
        .package(path: "../PrayerTimes")
    ],
    targets: [
        .target(name: "Qibla", dependencies: ["DesignSystem", "PrayerTimes"]),
        .testTarget(name: "QiblaTests", dependencies: ["Qibla"])
    ]
)
