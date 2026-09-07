// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Learn",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Learn", targets: ["Learn"])
    ],
    dependencies: [
        .package(path: "../../Core/DesignSystem")
    ],
    targets: [
        .target(
            name: "Learn",
            dependencies: ["DesignSystem"],
            resources: [.copy("Resources/matn-tuhfat-al-atfal.json")]
        )
    ]
)
