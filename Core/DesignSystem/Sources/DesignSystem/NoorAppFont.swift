import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// The five interface font families the user can pick in Settings → App font.
///
/// All five are SIL Open Font License 1.1 and are bundled **unmodified** — see
/// `LICENSES.md`. The OFL forbids a modified copy from keeping its Reserved
/// Font Name (IBM reserves "Plex"), so we never subset, rename or re-generate
/// the files; Readex Pro and Cairo ship as their upstream *variable* files and
/// we address each weight by the PostScript name of the font's own named
/// instance, which CoreText exposes on registration.
///
/// Raw values are shared verbatim with the Android app (`ui.font`).
public enum NoorAppFont: String, CaseIterable, Sendable {
    case readexPro
    case ibmPlexSansArabic
    case tajawal
    case almarai
    case cairo

    /// UserDefaults key — identical on iOS and Android.
    public static let defaultsKey = "ui.font"
    /// New default for everyone, including existing installs (intended).
    public static let fallback = NoorAppFont.readexPro

    /// Font names are proper nouns: never localised, never translated.
    public var displayName: String {
        switch self {
        case .readexPro: "Readex Pro"
        case .ibmPlexSansArabic: "IBM Plex Sans Arabic"
        case .tajawal: "Tajawal"
        case .almarai: "Almarai"
        case .cairo: "Cairo"
        }
    }

    /// Arabic sample used for the picker row so the reader can judge the
    /// family's Arabic shaping. Deliberately NOT Quranic text (hard rule 1) —
    /// it is the family's own name written in Arabic.
    public var arabicSample: String {
        switch self {
        case .readexPro: "ريدكس برو"
        case .ibmPlexSansArabic: "آي بي إم بلكس"
        case .tajawal: "تجوال"
        case .almarai: "المراعي"
        case .cairo: "القاهرة"
        }
    }

    /// Bundled files, in the DesignSystem resource bundle under `UIFonts/`.
    var fileNames: [String] {
        switch self {
        case .readexPro: ["ReadexPro[HEXP,wght]"]
        case .ibmPlexSansArabic: [
            "IBMPlexSansArabic-Regular", "IBMPlexSansArabic-Medium",
            "IBMPlexSansArabic-SemiBold", "IBMPlexSansArabic-Bold"
        ]
        case .tajawal: ["Tajawal-Regular", "Tajawal-Medium", "Tajawal-Bold"]
        case .almarai: [
            "Almarai-Light", "Almarai-Regular", "Almarai-Bold", "Almarai-ExtraBold"
        ]
        case .cairo: ["Cairo[slnt,wght]"]
        }
    }

    /// Coarse buckets — the families do not all ship every weight, and
    /// `Font.weight(_:)` on a custom face is unreliable (it either does
    /// nothing or synthesises a smear), so we always resolve to a real face.
    private enum Cut { case light, regular, medium, semibold, bold, heavy }

    private static func cut(_ weight: Font.Weight) -> Cut {
        switch weight {
        case .ultraLight, .thin, .light: .light
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy, .black: .heavy
        default: .regular
        }
    }

    /// PostScript name of the face to use for `weight`.
    public func fontName(for weight: Font.Weight = .regular) -> String {
        switch self {
        case .readexPro:
            switch Self.cut(weight) {
            case .light: "ReadexPro-Light"
            case .regular: "ReadexPro-Regular"
            case .medium: "ReadexPro-Medium"
            case .semibold: "ReadexPro-SemiBold"
            case .bold, .heavy: "ReadexPro-Bold"
            }
        case .ibmPlexSansArabic:
            switch Self.cut(weight) {
            case .light, .regular: "IBMPlexSansArabic-Regular"
            case .medium: "IBMPlexSansArabic-Medium"
            case .semibold: "IBMPlexSansArabic-SemiBold"
            case .bold, .heavy: "IBMPlexSansArabic-Bold"
            }
        case .tajawal:
            // Tajawal ships 400/500/700 here: semibold rounds up to Bold so
            // emphasis stays legible against the 500.
            switch Self.cut(weight) {
            case .light, .regular: "Tajawal-Regular"
            case .medium: "Tajawal-Medium"
            case .semibold, .bold, .heavy: "Tajawal-Bold"
            }
        case .almarai:
            switch Self.cut(weight) {
            case .light: "Almarai-Light"
            case .regular, .medium: "Almarai-Regular"
            case .semibold, .bold: "Almarai-Bold"
            case .heavy: "Almarai-ExtraBold"
            }
        case .cairo:
            // Named instances of the variable file; CoreText prefixes them
            // with the default instance's PostScript name.
            switch Self.cut(weight) {
            case .light: "Cairo-Regular_Light"
            case .regular: "Cairo-Regular"
            case .medium: "Cairo-Regular_Medium"
            case .semibold: "Cairo-Regular_SemiBold"
            case .bold, .heavy: "Cairo-Regular_Bold"
            }
        }
    }

    /// A Dynamic-Type-scaling font in this family.
    ///
    /// `Font.custom(_:size:relativeTo:)` scales with the user's text size;
    /// `Font.custom(_:fixedSize:)` does not — UI text must always use this.
    public func scaled(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo style: Font.TextStyle = .body
    ) -> Font {
        .custom(fontName(for: weight), size: size, relativeTo: style)
    }

    #if canImport(UIKit)
    /// UIKit face for the chrome (nav bar / tab bar) that SwiftUI's
    /// `\.font` environment does not reach. Scaled for Dynamic Type here
    /// because UIKit appearance fonts are not auto-scaling.
    public func uiFont(size: CGFloat, weight: Font.Weight = .regular,
                       textStyle: UIFont.TextStyle = .body) -> UIFont? {
        guard let base = UIFont(name: fontName(for: weight), size: size) else { return nil }
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base)
    }

    /// Text attributes for UIKit chrome (tab-bar item titles, nav-bar
    /// titles), with the line box pinned to the system face's.
    ///
    /// Arabic faces reserve far more vertical room than SF does — the marks
    /// they must clear live above the letters. Measured at 10pt: SF's line
    /// box is 11.8pt, Readex Pro 12.5, Tajawal 12.0, Almarai 11.2, IBM Plex
    /// 15.0 and Cairo **18.7** (1.59×). UIKit lays a tab-bar item out from
    /// that line box, so with Cairo (and, less visibly, IBM Plex) the label
    /// grew upwards into its icon. The fix has to be the LINE BOX, not the
    /// point size: the extra height is empty padding, not bigger glyphs, so
    /// shrinking Cairo to a system-sized line box would render it at ~6pt
    /// while the collision is fully cured by clamping the box. Legibility
    /// and family stay intact; the glyphs are unchanged.
    public func chromeAttributes(size: CGFloat, weight: Font.Weight = .regular,
                                 textStyle: UIFont.TextStyle = .body)
        -> [NSAttributedString.Key: Any]? {
        guard let font = uiFont(size: size, weight: weight, textStyle: textStyle) else { return nil }
        let systemLine = UIFontMetrics(forTextStyle: textStyle)
            .scaledFont(for: .systemFont(ofSize: size)).lineHeight
        guard font.lineHeight > systemLine else { return [.font: font] }
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = systemLine
        style.maximumLineHeight = systemLine
        style.alignment = .center
        return [
            .font: font,
            .paragraphStyle: style,
            // Clamping the box drops the text towards the baseline of the
            // shorter box; lift it back so the glyphs stay centred in it.
            .baselineOffset: (systemLine - font.lineHeight) / 4,
        ]
    }
    #endif

    /// The family the app is currently drawn in.
    ///
    /// Read straight off `UserDefaults` behind a cache, because this is hit
    /// once per `Text` per layout pass. The cache is dropped whenever any
    /// default changes, so `@AppStorage` writes from Settings are picked up
    /// without any explicit plumbing.
    public static var current: NoorAppFont {
        if let cached { return cached }
        let value = NoorAppFont(
            rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? ""
        ) ?? fallback
        cached = value
        startObservingIfNeeded()
        return value
    }

    private nonisolated(unsafe) static var cached: NoorAppFont?
    private nonisolated(unsafe) static var observer: NSObjectProtocol?

    private static func startObservingIfNeeded() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: nil
        ) { _ in cached = nil }
    }

    /// Test/preview hook — forget the cached family.
    public static func invalidateCache() { cached = nil }

    /// Pushes the chosen family into the UIKit chrome that SwiftUI's
    /// `\.font` environment cannot reach: navigation-bar titles and tab-bar
    /// item labels. Safe to call repeatedly; a no-op on macOS.
    public static func applyChromeAppearance() {
        #if canImport(UIKit) && !os(macOS)
        let font = current
        let bar = UINavigationBarAppearance()
        bar.configureWithDefaultBackground()
        // Same line-box clamp as the tab bar: a nav-bar title is a
        // fixed-height slot too (44pt inline), so a 1.6× line box pushes the
        // title off centre and can clip it.
        if let large = font.chromeAttributes(size: 34, weight: .bold, textStyle: .largeTitle) {
            bar.largeTitleTextAttributes.merge(large) { _, new in new }
        }
        if let inline = font.chromeAttributes(size: 17, weight: .semibold, textStyle: .headline) {
            bar.titleTextAttributes.merge(inline) { _, new in new }
        }
        UINavigationBar.appearance().standardAppearance = bar
        UINavigationBar.appearance().compactAppearance = bar
        UINavigationBar.appearance().scrollEdgeAppearance = bar

        if let tabAttributes = font.chromeAttributes(size: 10, weight: .medium,
                                                     textStyle: .caption2) {
            let tab = UITabBarAppearance()
            tab.configureWithDefaultBackground()
            for item in [tab.stackedLayoutAppearance,
                         tab.inlineLayoutAppearance,
                         tab.compactInlineLayoutAppearance] {
                item.normal.titleTextAttributes.merge(tabAttributes) { _, new in new }
                item.selected.titleTextAttributes.merge(tabAttributes) { _, new in new }
            }
            UITabBar.appearance().standardAppearance = tab
            UITabBar.appearance().scrollEdgeAppearance = tab
        }
        #endif
    }
}
