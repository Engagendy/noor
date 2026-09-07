// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Learn",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Learn", targets: ["Learn"])
    ],
    dependencies: [
        .package(path: "../../Core/DesignSystem"),
        // Core only (CLAUDE.md §4): the shared Arabic search folding/ranking.
        .package(path: "../../Core/ContentDB")
    ],
    targets: [
        .target(
            name: "Learn",
            dependencies: ["DesignSystem", "ContentDB"],
            resources: [
                .copy("Resources/matn-tuhfat-al-atfal.json"),
                .copy("Resources/matn-bayquniyyah.json"),
            ]
        )
    ]
)
