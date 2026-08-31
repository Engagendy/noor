import SwiftUI

/// Typography tokens from 02-DESIGN-GUIDELINES.md §3.
public enum NoorFont {
    /// PostScript name of the bundled KFGQPC Uthmanic Hafs font (v22).
    public static let quranFontName = "kfgqpchafsuthmanicscript-Reg"

    /// Quran text: user-adjustable 20–44pt, default 26pt. Line height is set
    /// at the view level (2.0–2.2 — harakat must never clip).
    public static func quran(size: CGFloat = 26) -> Font {
        .custom(quranFontName, size: size)
    }

    /// Translation & tafsir body — serif ("sacred book" feel).
    public static let translation = Font.system(size: 17, design: .serif)
    public static let tafsir = Font.system(size: 16, design: .serif)

    public static let screenTitle = Font.system(size: 28, weight: .semibold)
    public static let sectionHeader = Font.system(size: 20, weight: .semibold)
    public static let caption = Font.system(size: 13)
}

public enum NoorMetrics {
    public static let quranSizeRange: ClosedRange<CGFloat> = 20...44
    public static let quranLineSpacingFactor: CGFloat = 1.0 // ≈2.0 line height
    public static let minTapTarget: CGFloat = 44
}
