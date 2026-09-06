// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DesignSystem",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"])
    ],
    targets: [
        .target(
            name: "DesignSystem",
            resources: [
                .copy("Resources/UthmanicHafs.ttf"),
                .copy("Resources/AmiriQuran.ttf"),
                // The five interface families (Settings → App font).
                // Copied verbatim: OFL 1.1 forbids a modified file keeping
                // its Reserved Font Name, so nothing is subset or renamed.
                .copy("Resources/UIFonts")
            ]
        )
    ]
)
