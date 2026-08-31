// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "QuranReader",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "QuranReader", targets: ["QuranReader"])
    ],
    dependencies: [
        .package(path: "../../Core/ContentDB"),
        .package(path: "../../Core/DesignSystem")
    ],
    targets: [
        .target(
            name: "QuranReader",
            dependencies: ["ContentDB", "DesignSystem"]
        )
    ]
)
