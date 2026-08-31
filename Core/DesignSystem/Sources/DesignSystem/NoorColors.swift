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
