// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "QuranAudio",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "QuranAudio", targets: ["QuranAudio"])
    ],
    dependencies: [
        .package(path: "../../Core/DesignSystem")
    ],
    targets: [
        .target(name: "QuranAudio", dependencies: ["DesignSystem"]),
        .testTarget(name: "QuranAudioTests", dependencies: ["QuranAudio"])
    ]
)
