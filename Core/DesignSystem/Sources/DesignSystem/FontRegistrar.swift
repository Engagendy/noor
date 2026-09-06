import CoreText
import Foundation

public enum FontRegistrar {
    /// Swift's lazy static initialization is thread-safe, which also covers
    /// WidgetKit processes that first touch Cairo while rendering a timeline.
    private static let registerBundledFontsOnce: Void = {
        for name in ["UthmanicHafs", "AmiriQuran", "Cairo"] {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf") else {
                assertionFailure("Missing bundled font \(name)")
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    /// Registers the bundled fonts at runtime (works in the app and widgets
    /// on both iOS and macOS without Info.plist font keys). Call at launch;
    /// subsequent calls are no-ops.
    /// - Amiri Quran: flow-mode text (KFGQPC text fonts have broken Quranic
    ///   mark anchors under Apple's shaper — e.g. U+06DF draws a dotted
    ///   circle; clipped/broken harakat are a release blocker per design §3).
    /// - KFGQPC Uthmanic Hafs: surah-name headers and ornaments.
    /// - Cairo: Arabic interface and non-Quran Arabic text.
    public static func registerBundledFonts() {
        _ = registerBundledFontsOnce
    }

    /// Source-compatible entry point retained for existing package clients.
    @available(*, deprecated, renamed: "registerBundledFonts")
    public static func registerQuranFont() {
        registerBundledFonts()
    }
}
