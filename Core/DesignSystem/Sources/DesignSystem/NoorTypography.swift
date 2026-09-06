import Foundation
import SwiftUI

/// Typography tokens from 02-DESIGN-GUIDELINES.md §3.
public enum NoorFont {
    /// Arabic interface and non-Quran Arabic text (SIL OFL 1.1).
    public static let arabicUiFontName = "Cairo"
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

    /// Cairo for Arabic content that is independent of the current UI locale,
    /// such as a non-Quran Arabic share card or an Arabic tafsir edition.
    public static func arabicText(
        size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo textStyle: Font.TextStyle? = nil
    ) -> Font {
        FontRegistrar.registerBundledFonts()
        let font = if let textStyle {
            Font.custom(arabicUiFontName, size: size, relativeTo: textStyle)
        } else {
            Font.custom(arabicUiFontName, fixedSize: size)
        }
        return font.weight(weight)
    }

    /// Translation & tafsir body — serif ("sacred book" feel). UI text
    /// follows Dynamic Type (design §3); only the Quran font has its own
    /// in-reader size control.
    public static let translation = Font.system(.body, design: .serif)
    public static let tafsir = Font.system(.callout, design: .serif)

    public static let screenTitle = Font.system(.title, design: .default).weight(.semibold)
    public static let sectionHeader = Font.system(.title3, design: .default).weight(.semibold)
    public static let caption = Font.system(.footnote)

    static func usesArabicInterfaceFont(locale: Locale) -> Bool {
        locale.language.languageCode?.identifier == "ar"
    }

    fileprivate static func interface(
        size: CGFloat,
        weight: Font.Weight,
        design: Font.Design,
        relativeTo textStyle: Font.TextStyle?,
        locale: Locale
    ) -> Font {
        if usesArabicInterfaceFont(locale: locale) {
            return arabicText(
                size: size,
                weight: weight,
                relativeTo: textStyle
            )
        }
        if let textStyle {
            return Font.system(textStyle, design: design).weight(weight)
        }
        return Font.system(
            size: size,
            weight: weight,
            design: design
        )
    }
}

public enum NoorMetrics {
    public static let quranSizeRange: ClosedRange<CGFloat> = 20...44
    public static let quranLineSpacingFactor: CGFloat = 1.0 // ≈2.0 line height
    public static let minTapTarget: CGFloat = 44
}


private struct NoorInterfaceFontModifier: ViewModifier {
    @Environment(\.locale) private var locale

    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    let textStyle: Font.TextStyle?
    let monospacedDigits: Bool

    func body(content: Content) -> some View {
        let font = NoorFont.interface(
            size: size,
            weight: weight,
            design: design,
            relativeTo: textStyle,
            locale: locale
        )
        content.font(monospacedDigits ? font.monospacedDigit() : font)
    }
}

public extension View {
    /// Uses Cairo when the active SwiftUI locale is Arabic and preserves the
    /// platform system font for every other interface language.
    func noorFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo textStyle: Font.TextStyle? = nil,
        monospacedDigits: Bool = false
    ) -> some View {
        modifier(
            NoorInterfaceFontModifier(
                size: size,
                weight: weight,
                design: design,
                textStyle: textStyle,
                monospacedDigits: monospacedDigits
            )
        )
    }
}
