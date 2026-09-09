import CoreText
import Foundation

public enum FontRegistrar {
    private static var registered = false

    /// Registers the bundled Quran fonts at runtime (works on both iOS and
    /// macOS without Info.plist font keys). Call once at launch.
    /// - Amiri Quran: flow-mode text (KFGQPC text fonts have broken Quranic
    ///   mark anchors under Apple's shaper — e.g. U+06DF draws a dotted
    ///   circle; clipped/broken harakat are a release blocker per design §3).
    /// - KFGQPC Uthmanic Hafs: surah-name headers and ornaments.
    public static func registerQuranFont() {
        guard !registered else { return }
        registered = true
        for name in ["UthmanicHafs", "AmiriQuran"] {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf") else {
                assertionFailure("Missing bundled font \(name)")
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        registerInterfaceFonts()
    }

    private static var interfaceFontsRegistered = false

    /// Registers all five interface families (Settings → App font) and the
    /// script faces. All of them, not just the selected one, because the
    /// Settings picker draws every row in its own family. The files are memory-mapped, so this is
    /// cheap; see LICENSES.md — they are bundled unmodified.
    public static func registerInterfaceFonts() {
        guard !interfaceFontsRegistered else { return }
        interfaceFontsRegistered = true
        let files = NoorAppFont.allCases.flatMap(\.fileNames)
            // Plus the script faces the app selects itself — Nastaliq for
            // the Urdu interface. Not picker rows, but registered the same.
            + NoorAppFont.scriptFontFileNames
        let urls = files.compactMap {
            Bundle.module.url(forResource: $0, withExtension: "ttf", subdirectory: "UIFonts")
        }
        assert(urls.count == files.count, "Missing bundled interface font file(s)")
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
