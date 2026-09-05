// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ContentDB",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ContentDB", targets: ["ContentDB"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.0")
    ],
    targets: [
        .target(
            name: "ContentDB",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")],
            resources: [
                .copy("Resources/quran.sqlite"),
                .copy("Resources/page_layout.sqlite"),
                .copy("Resources/cities.sqlite")
            ]
        ),
        .testTarget(
            name: "ContentDBTests",
            dependencies: ["ContentDB"]
        )
    ]
)
