// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Tafsir",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Tafsir", targets: ["Tafsir"])
    ],
    dependencies: [
        .package(path: "../../Core/DesignSystem"),
        // Core only (CLAUDE.md §4): the browser needs the surah list.
        .package(path: "../../Core/ContentDB")
    ],
    targets: [
        .target(name: "Tafsir", dependencies: ["DesignSystem", "ContentDB"]),
        .testTarget(name: "TafsirTests", dependencies: ["Tafsir"])
    ]
)
