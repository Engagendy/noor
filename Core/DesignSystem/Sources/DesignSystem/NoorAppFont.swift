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

    /// Files the app bundles that are NOT user-choosable families: the
    /// script faces it selects on its own (see `scriptFontName`). Registered
    /// with the five, never listed in the picker.
    static let scriptFontFileNames = ["NotoNastaliqUrdu[wght]"]

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

    /// The face the interface must be drawn in for `language`, whatever
    /// family is chosen in Settings — or `nil` when the choice stands.
    ///
    /// Urdu is the only case: it is written in NASTALIQ, and all five
    /// families are Naskh Arabic faces. They render Urdu — the letters are
    /// the same — but sloped-baseline Nastaliq is what an Urdu reader
    /// expects, and Naskh Urdu reads to them roughly the way blackletter
    /// English reads to us. Noto Nastaliq Urdu (SIL OFL, bundled unmodified,
    /// see LICENSES.md) is used instead.
    ///
    /// Only the *interface* is affected: Quran text keeps its verified fonts
    /// (hard rule 1), and the Settings font picker still draws each family
    /// in its own face so the choice remains meaningful — it is what the
    /// user gets back in every other language.
    ///
    /// Bengali deliberately has no entry: the system face covers Bengali
    /// well, and `Font.custom` falls back to it per-glyph anyway.
    public static func scriptFontName(for language: NoorLanguage) -> String? {
        // The variable file exposes Medium/SemiBold/Bold named instances but
        // publishes no PostScript name for them, so CoreText's synthesised
        // names are the only handle — and a name that fails to resolve
        // silently drops the whole interface to the system face. Nastaliq
        // does not signal emphasis by weight anyway, so we stay on the one
        // face we can name for certain.
        language == .ur ? "NotoNastaliqUrdu-Regular" : nil
    }

    /// The PostScript name interface text is actually drawn in: the chosen
    /// family, unless the interface language overrides it.
    public static func interfaceFontName(for weight: Font.Weight = .regular) -> String {
        scriptFontName(for: .current) ?? current.fontName(for: weight)
    }

    /// Point-size correction for the script face.
    ///
    /// Noto Nastaliq Urdu's line box is 2.5em (Readex Pro's is ~1.3em):
    /// the letters hang from a sloped baseline and need the room. At an
    /// unchanged point size every fixed-height row in the app — buttons,
    /// onboarding cards, list rows — has to hold a line box twice as tall as
    /// the one it was measured for. Shrinking the *box* is not an option
    /// here (unlike the chrome, where the extra height is padding): in
    /// Nastaliq it is where the glyphs live, and clamping it clips them. So
    /// the point size comes down instead, which keeps the whole line inside
    /// the row it was designed for.
    public static func interfaceSize(_ size: CGFloat) -> CGFloat {
        scriptFontName(for: .current) == nil ? size : size * 0.72
    }

    /// A font that can set `language`'s own name — for a language picker,
    /// whose whole point is that every row is written in its own script and
    /// is legible to someone who cannot read the current interface language.
    /// The Urdu row is Nastaliq even while the app is in English.
    public static func font(showing language: NoorLanguage, size: CGFloat = 17,
                            weight: Font.Weight = .regular) -> Font {
        if let script = scriptFontName(for: language) {
            // A gentler cut than `interfaceSize`: a picker row is not a
            // fixed-height chrome slot, and the endonym has to be as
            // readable as the Latin rows beside it.
            return .custom(script, size: size * 0.85, relativeTo: .body)
        }
        return current.scaled(size, weight: weight)
    }

    /// A Dynamic-Type-scaling interface font: the family the user picked, or
    /// the script face their language needs. Every UI token goes through it.
    public static func interfaceScaled(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo style: Font.TextStyle = .body
    ) -> Font {
        .custom(interfaceFontName(for: weight),
                size: interfaceSize(size), relativeTo: style)
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
        Self.uiFont(named: fontName(for: weight), size: size, textStyle: textStyle)
    }

    public static func uiFont(named name: String, size: CGFloat,
                              textStyle: UIFont.TextStyle) -> UIFont? {
        guard let base = UIFont(name: name, size: size) else { return nil }
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
        Self.chromeAttributes(named: fontName(for: weight), size: size, textStyle: textStyle)
    }

    /// The same clamp for the face the interface is actually drawn in —
    /// which for Urdu is the Nastaliq script face, whose 2.5em line box
    /// would otherwise push a tab-bar label straight through its icon.
    public static func interfaceChromeAttributes(
        size: CGFloat, weight: Font.Weight = .regular,
        textStyle: UIFont.TextStyle = .body
    ) -> [NSAttributedString.Key: Any]? {
        chromeAttributes(named: interfaceFontName(for: weight),
                         size: interfaceSize(size), textStyle: textStyle)
    }

    public static func chromeAttributes(named name: String, size: CGFloat,
                                        textStyle: UIFont.TextStyle)
        -> [NSAttributedString.Key: Any]? {
        guard let font = uiFont(named: name, size: size, textStyle: textStyle) else { return nil }
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
        let bar = UINavigationBarAppearance()
        bar.configureWithDefaultBackground()
        // Same line-box clamp as the tab bar: a nav-bar title is a
        // fixed-height slot too (44pt inline), so a 1.6× line box pushes the
        // title off centre and can clip it.
        if let large = interfaceChromeAttributes(size: 34, weight: .bold, textStyle: .largeTitle) {
            bar.largeTitleTextAttributes.merge(large) { _, new in new }
        }
        if let inline = interfaceChromeAttributes(size: 17, weight: .semibold, textStyle: .headline) {
            bar.titleTextAttributes.merge(inline) { _, new in new }
        }
        UINavigationBar.appearance().standardAppearance = bar
        UINavigationBar.appearance().compactAppearance = bar
        UINavigationBar.appearance().scrollEdgeAppearance = bar

        if let tabAttributes = interfaceChromeAttributes(size: 10, weight: .medium,
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
