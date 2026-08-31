// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Library",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Library", targets: ["Library"])
    ],
    targets: [
        .target(name: "Library"),
        .testTarget(name: "LibraryTests", dependencies: ["Library"])
    ]
)
