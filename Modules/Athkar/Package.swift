// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Athkar",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Athkar", targets: ["Athkar"])
    ],
    dependencies: [
        .package(path: "../../Core/DesignSystem"),
        .package(path: "../../Core/ContentDB")
    ],
    targets: [
        .target(
            name: "Athkar",
            dependencies: ["DesignSystem", "ContentDB"],
            resources: [.copy("Resources/athkar.json")]
        ),
        .testTarget(name: "AthkarTests", dependencies: ["Athkar"])
    ]
)
