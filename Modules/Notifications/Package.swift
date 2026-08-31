// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Notifications",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Notifications", targets: ["Notifications"])
    ],
    dependencies: [
        .package(path: "../PrayerTimes")
    ],
    targets: [
        .target(name: "Notifications", dependencies: ["PrayerTimes"]),
        .testTarget(name: "NotificationsTests", dependencies: ["Notifications"])
    ]
)
