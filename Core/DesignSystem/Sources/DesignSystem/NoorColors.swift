import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Color tokens from 02-DESIGN-GUIDELINES.md §2.
/// Light = "Mushaf" theme, Dark = "Tahajjud" theme.
public enum NoorColor {
    public static let bgPrimary = dynamic(light: 0xFAF6EE, dark: 0x0F1512)
    public static let bgElevated = dynamic(light: 0xFFFFFF, dark: 0x1A211D)
    public static let inkPrimary = dynamic(light: 0x1F2933, dark: 0xEDE7DA)
    public static let inkSecondary = dynamic(light: 0x5C6670, dark: 0x9AA49E)
    public static let accentPrimary = dynamic(light: 0x0E6B5C, dark: 0x4FB3A0)
    public static let accentGold = dynamic(light: 0xB98A2F, dark: 0xD8B25E)
    public static let stateReciting = dynamic(light: 0x0E6B5C, dark: 0x4FB3A0,
                                              lightAlpha: 0.12, darkAlpha: 0.16)
    public static let stateBookmark = accentGold
    public static let prayerNext = accentPrimary

    // MARK: - Tajweed
    //
    // Hues follow the conventional tajweed-mushaf colouring (Dar al-Maarifah
    // and the palette the quran.com readers use): greens for idghaam/ghunnah,
    // purple for ikhfa, red for qalqalah, a blue ramp for the madd lengths,
    // and neutral grey for letters that are NOT pronounced (hamzat al-wasl,
    // lam shamsiyyah, silent). We follow the convention rather than invent a
    // palette so a reader who learned from a printed tajweed mushaf reads the
    // same colours here.
    //
    // Every value below is at least 4.5:1 against its own background
    // (`bgPrimary` light / dark) AND at least ~30 CIELAB ΔE from the body ink
    // (`inkPrimary`), so a tinted letter reads as tinted and not merely as
    // slightly-off black. The two neutral greys are the tightest: they are
    // deliberately DIMMER than the ink, because "grey" here means the letter
    // is not pronounced at all. The madd ramp deepens with length in "Mushaf"
    // and brightens with length in "Tahajjud" — in both palettes a longer
    // madd is the more emphatic ink.
    // Colour is never the sole cue: the feature is off by default, the legend
    // names every rule, and VoiceOver reads the rule names from the legend.
    public static let tajweedGhunnah = dynamic(light: 0x137A5E, dark: 0x4FD1AC)
    public static let tajweedIdghaamGhunnah = tajweedGhunnah
    public static let tajweedIdghaamNoGhunnah = dynamic(light: 0x2E7D32, dark: 0x7BD97F)
    public static let tajweedIdghaamShafawi = dynamic(light: 0x4F7A00, dark: 0xA8D84A)
    public static let tajweedIdghaamMutajanisayn = dynamic(light: 0x6B6B6B, dark: 0x8D8D8D)
    public static let tajweedIdghaamMutaqaribayn = tajweedIdghaamMutajanisayn
    public static let tajweedIkhfa = dynamic(light: 0x8B1E9C, dark: 0xD98FE6)
    public static let tajweedIkhfaShafawi = dynamic(light: 0xA3007F, dark: 0xF08CD3)
    public static let tajweedIqlab = dynamic(light: 0x0F6FA8, dark: 0x63C8F0)
    public static let tajweedQalqalah = dynamic(light: 0xC1121F, dark: 0xFF8A87)
    public static let tajweedMadd2 = dynamic(light: 0x3B5BDB, dark: 0x7E9AF0)
    public static let tajweedMadd246 = dynamic(light: 0x2F45C5, dark: 0x8FA8FF)
    public static let tajweedMaddMunfasil = dynamic(light: 0x2438B0, dark: 0x9FB6FF)
    public static let tajweedMaddMuttasil = dynamic(light: 0x1B2C97, dark: 0xB0C3FF)
    public static let tajweedMadd6 = dynamic(light: 0x101F7A, dark: 0xC2D2FF)
    public static let tajweedUnpronounced = dynamic(light: 0x77706A, dark: 0x8A8177)
}

private func dynamic(light: UInt32, dark: UInt32,
                     lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
    #if canImport(UIKit)
    return Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(rgb: dark, alpha: darkAlpha)
            : UIColor(rgb: light, alpha: lightAlpha)
    })
    #else
    return Color(NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark ? NSColor(rgb: dark, alpha: darkAlpha)
                      : NSColor(rgb: light, alpha: lightAlpha)
    })
    #endif
}

#if canImport(UIKit)
private extension UIColor {
    convenience init(rgb: UInt32, alpha: CGFloat) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255,
                  alpha: alpha)
    }
}
#else
private extension NSColor {
    convenience init(rgb: UInt32, alpha: CGFloat) {
        self.init(srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255,
                  alpha: alpha)
    }
}
#endif
