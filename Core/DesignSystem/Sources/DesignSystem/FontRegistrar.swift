import CoreText
import Foundation

public enum FontRegistrar {
    private static var registered = false

    /// Registers the bundled KFGQPC Uthmanic Hafs font at runtime (works on
    /// both iOS and macOS without Info.plist font keys). Call once at launch.
    public static func registerQuranFont() {
        guard !registered,
              let url = Bundle.module.url(forResource: "UthmanicHafs", withExtension: "ttf")
        else { return }
        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            registered = true
        } else if let error = error?.takeRetainedValue() {
            // Already-registered errors are fine; anything else is a bundle bug.
            assertionFailure("Font registration failed: \(error)")
        }
    }
}
