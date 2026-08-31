// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Translations",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Translations", targets: ["Translations"])
    ],
    targets: [
        .target(name: "Translations"),
        .testTarget(name: "TranslationsTests", dependencies: ["Translations"])
    ]
)
