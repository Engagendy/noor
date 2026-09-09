// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ShareVideo",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ShareVideo", targets: ["ShareVideo"])
    ],
    targets: [
        .target(name: "ShareVideo"),
        .testTarget(name: "ShareVideoTests", dependencies: ["ShareVideo"])
    ]
)
