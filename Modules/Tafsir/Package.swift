// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Tafsir",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Tafsir", targets: ["Tafsir"])
    ],
    dependencies: [
        .package(path: "../../Core/DesignSystem")
    ],
    targets: [
        .target(name: "Tafsir", dependencies: ["DesignSystem"]),
        .testTarget(name: "TafsirTests", dependencies: ["Tafsir"])
    ]
)
