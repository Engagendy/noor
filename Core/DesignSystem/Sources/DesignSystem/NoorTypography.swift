import SwiftUI

/// Typography tokens from 02-DESIGN-GUIDELINES.md §3.
public enum NoorFont {
    /// Flow-mode Quran text: Amiri Quran (SIL OFL) — the KFGQPC text fonts
    /// mis-render Quranic marks (U+06DF et al.) under Apple's text engine.
    /// Page mode remains pixel-perfect KFGQPC via the QCF page fonts.
    public static let quranFontName = "Amiri Quran"
    /// KFGQPC Uthmanic Hafs — kept for surah-name headers/ornaments.
    public static let hafsFontName = "kfgqpchafsuthmanicscript-Reg"

    /// Quran text: user-adjustable 20–44pt, default 26pt. Line height is set
    /// at the view level (2.0–2.2 — harakat must never clip).
    public static func quran(size: CGFloat = 26) -> Font {
        .custom(quranFontName, size: size)
    }

    /// Translation & tafsir body — serif ("sacred book" feel). UI text
    /// follows Dynamic Type (design §3); only the Quran font has its own
    /// in-reader size control.
    public static let translation = Font.system(.body, design: .serif)
    public static let tafsir = Font.system(.callout, design: .serif)

    public static let screenTitle = Font.system(.title, design: .default).weight(.semibold)
    public static let sectionHeader = Font.system(.title3, design: .default).weight(.semibold)
    public static let caption = Font.system(.footnote)
}

public enum NoorMetrics {
    public static let quranSizeRange: ClosedRange<CGFloat> = 20...44
    public static let quranLineSpacingFactor: CGFloat = 1.0 // ≈2.0 line height
    public static let minTapTarget: CGFloat = 44
}
