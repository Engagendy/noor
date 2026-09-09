// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "QuranAudio",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "QuranAudio", targets: ["QuranAudio"])
    ],
    dependencies: [
        .package(path: "../../Core/DesignSystem"),
        .package(path: "../../Core/ShareVideo")
    ],
    targets: [
        .target(name: "QuranAudio", dependencies: ["DesignSystem", "ShareVideo"]),
        .testTarget(name: "QuranAudioTests", dependencies: ["QuranAudio"])
    ]
)
