import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Typography tokens from 02-DESIGN-GUIDELINES.md §3.
public enum NoorFont {
    /// Arabic interface and non-Quran Arabic text (SIL OFL 1.1).
    public static let arabicUIFontName = "Cairo"
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
            Font.custom(arabicUIFontName, size: size, relativeTo: textStyle)
        } else {
            Font.custom(arabicUIFontName, fixedSize: size)
        }
        return font.weight(weight)
    }

    /// Translation & tafsir body — serif ("sacred book" feel). UI text
    /// follows Dynamic Type (design §3); only the Quran font has its own
    /// in-reader size control.
    public static let translation = Font.system(.body, design: .serif)
    public static let tafsir = Font.system(.callout, design: .serif)

    @available(*, deprecated, message: "Use View.noorFont(.screenTitle) instead")
    public static let screenTitle = Font.system(.title, design: .default).weight(.semibold)
    @available(*, deprecated, message: "Use View.noorFont(.sectionHeader) instead")
    public static let sectionHeader = Font.system(.title3, design: .default).weight(.semibold)
    @available(*, deprecated, message: "Use View.noorFont(.caption) instead")
    public static let caption = Font.system(.footnote)

    static func usesArabicInterfaceFont(locale: Locale) -> Bool {
        locale.language.languageCode?.identifier == "ar"
    }

    fileprivate static func interface(
        size: CGFloat,
        weight: Font.Weight,
        design: Font.Design,
        locale: Locale
    ) -> Font {
        if usesArabicInterfaceFont(locale: locale) {
            return arabicText(size: size, weight: weight)
        }
        return Font.system(
            size: size,
            weight: weight,
            design: design
        )
    }
}

/// Semantic interface roles from the Noor type scale. Use these before a
/// one-off size so typography decisions remain centralized and locale-aware.
public enum NoorTextStyle {
    case body
    case screenTitle
    case sectionHeader
    case caption

    fileprivate var specification: NoorFontSpecification {
        switch self {
        case .body:
            NoorFontSpecification(size: 17, relativeTo: .body)
        case .screenTitle:
            NoorFontSpecification(
                size: 28,
                weight: .semibold,
                relativeTo: .title
            )
        case .sectionHeader:
            NoorFontSpecification(
                size: 20,
                weight: .semibold,
                relativeTo: .title3
            )
        case .caption:
            NoorFontSpecification(size: 13, relativeTo: .footnote)
        }
    }
}

fileprivate struct NoorFontSpecification {
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    let relativeTo: Font.TextStyle

    init(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo: Font.TextStyle
    ) {
        self.size = size
        self.weight = weight
        self.design = design
        self.relativeTo = relativeTo
    }
}

public enum NoorMetrics {
    public static let quranSizeRange: ClosedRange<CGFloat> = 20...44
    public static let quranLineSpacingFactor: CGFloat = 1.0 // ≈2.0 line height
    public static let minTapTarget: CGFloat = 44
}

private struct NoorInterfaceFontModifier: ViewModifier {
    @Environment(\.locale) private var locale
    @ScaledMetric private var scaledSize: CGFloat

    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    let textStyle: Font.TextStyle?
    let monospacedDigits: Bool

    init(
        size: CGFloat,
        weight: Font.Weight,
        design: Font.Design,
        textStyle: Font.TextStyle?,
        monospacedDigits: Bool
    ) {
        self.size = size
        self.weight = weight
        self.design = design
        self.textStyle = textStyle
        self.monospacedDigits = monospacedDigits
        _scaledSize = ScaledMetric(
            wrappedValue: size,
            relativeTo: textStyle ?? .body
        )
    }

    func body(content: Content) -> some View {
        // Font.system(textStyle:) discards a caller's base size. Scale the
        // supplied size explicitly so 15pt body-relative text remains 15pt
        // at the default content-size category on both font paths.
        let resolvedSize = textStyle == nil ? size : scaledSize
        let font = NoorFont.interface(
            size: resolvedSize,
            weight: weight,
            design: design,
            locale: locale
        )
        content.font(monospacedDigits ? font.monospacedDigit() : font)
    }
}

public extension View {
    /// Applies a semantic, locale-aware Noor interface style.
    func noorFont(
        _ style: NoorTextStyle,
        monospacedDigits: Bool = false
    ) -> some View {
        let specification = style.specification
        return noorFont(
            size: specification.size,
            weight: specification.weight,
            design: specification.design,
            relativeTo: specification.relativeTo,
            monospacedDigits: monospacedDigits
        )
    }

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

    /// Uses Cairo for Arabic content whose language does not follow the UI,
    /// such as hadith and dhikr shown while the interface is English.
    func noorArabicFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo textStyle: Font.TextStyle? = nil,
        monospacedDigits: Bool = false
    ) -> some View {
        let font = NoorFont.arabicText(
            size: size,
            weight: weight,
            relativeTo: textStyle
        )
        return self.font(monospacedDigits ? font.monospacedDigit() : font)
    }

    /// Uses a semantic Noor style with Cairo regardless of interface locale.
    func noorArabicFont(
        _ style: NoorTextStyle,
        monospacedDigits: Bool = false
    ) -> some View {
        let specification = style.specification
        return noorArabicFont(
            size: specification.size,
            weight: specification.weight,
            relativeTo: specification.relativeTo,
            monospacedDigits: monospacedDigits
        )
    }
}

public extension Font {
    /// Compatibility shim for callers that have not moved to the
    /// locale-aware `View.noorFont` API yet.
    @available(*, deprecated, message: "Use View.noorFont(size:relativeTo:) instead")
    static func noorScaled(
        _ size: CGFloat,
        weight: Font.Weight = .regular
    ) -> Font {
        #if canImport(UIKit)
        let scaled = UIFontMetrics(forTextStyle: .body).scaledValue(for: size)
        return .system(size: scaled, weight: weight)
        #else
        return .system(size: size, weight: weight)
        #endif
    }
}
