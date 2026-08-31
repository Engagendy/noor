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
    }
}
