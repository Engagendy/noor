// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PrayerTimes",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PrayerTimes", targets: ["PrayerTimes"])
    ],
    dependencies: [
        .package(url: "https://github.com/batoulapps/adhan-swift.git", from: "1.4.0"),
        .package(path: "../../Core/DesignSystem"),
        .package(path: "../../Core/ContentDB")
    ],
    targets: [
        .target(
            name: "PrayerTimes",
            dependencies: [
                .product(name: "Adhan", package: "adhan-swift"),
                "DesignSystem",
                "ContentDB"
            ]
        ),
        .testTarget(
            name: "PrayerTimesTests",
            dependencies: ["PrayerTimes"]
        )
    ]
)
