import SwiftUI

/// Typography tokens from 02-DESIGN-GUIDELINES.md §3.
///
/// Every *interface* token routes through `NoorAppFont.current`, the family
/// the user picked in Settings (default Readex Pro). The Quran tokens below
/// are deliberately untouched by that setting: Quran rendering is fixed to
/// its verified fonts (hard rule 1).
public enum NoorFont {
    /// Flow-mode Quran text: Amiri Quran (SIL OFL) — the KFGQPC text fonts
    /// mis-render Quranic marks (U+06DF et al.) under Apple's text engine.
    /// Page mode remains pixel-perfect KFGQPC via the QCF page fonts.
    public static let quranFontName = "Amiri Quran"
    /// KFGQPC Uthmanic Hafs — kept for surah-name headers/ornaments.
    public static let hafsFontName = "kfgqpchafsuthmanicscript-Reg"

    /// Quran text: user-adjustable 20–44pt, default 26pt. Line height is set
    /// at the view level (2.0–2.2 — harakat must never clip).
    /// NEVER routed through the interface-font setting.
    public static func quran(size: CGFloat = 26) -> Font {
        .custom(quranFontName, size: size)
    }

    /// The app-wide default face, pushed into `\.font` at the root so that
    /// text which sets no font of its own still follows the setting.
    public static var body: Font { NoorAppFont.current.scaled(17, relativeTo: .body) }

    /// Translation & tafsir body. UI text follows Dynamic Type (design §3);
    /// only the Quran font has its own in-reader size control.
    public static var translation: Font { NoorAppFont.current.scaled(17, relativeTo: .body) }
    public static var tafsir: Font { NoorAppFont.current.scaled(16, relativeTo: .callout) }

    public static var screenTitle: Font {
        NoorAppFont.current.scaled(28, weight: .semibold, relativeTo: .title)
    }
    public static var sectionHeader: Font {
        NoorAppFont.current.scaled(20, weight: .semibold, relativeTo: .title3)
    }
    public static var caption: Font {
        NoorAppFont.current.scaled(13, relativeTo: .footnote)
    }
}

public enum NoorMetrics {
    public static let quranSizeRange: ClosedRange<CGFloat> = 20...44
    public static let quranLineSpacingFactor: CGFloat = 1.0 // ≈2.0 line height
    public static let minTapTarget: CGFloat = 44
}


#if canImport(UIKit)
import UIKit
#endif

extension Font {
    /// Interface text in the user's chosen family, scaling with Dynamic Type
    /// (`Font.custom(_:size:relativeTo:)` scales; `custom(_:fixedSize:)`
    /// does not). This is the single token every UI `.font(...)` call goes
    /// through — do not reach for `.system(size:)` directly.
    public static func noorScaled(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        NoorAppFont.current.scaled(size, weight: weight)
    }

    /// Escape hatch for text that must stay in the system face regardless of
    /// the interface-font setting — SF Symbols sized by point, and digits
    /// that need the system's monospaced figures.
    public static func noorSystemScaled(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        #if canImport(UIKit)
        let scaled = UIFontMetrics(forTextStyle: .body).scaledValue(for: size)
        return .system(size: scaled, weight: weight)
        #else
        return .system(size: size, weight: weight)
        #endif
    }
}
