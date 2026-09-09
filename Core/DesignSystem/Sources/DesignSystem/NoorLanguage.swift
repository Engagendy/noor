import Foundation
import SwiftUI

/// Every interface language the app offers, and everything that follows from
/// the choice: the endonym for the picker, the writing direction, the face
/// the interface is drawn in, and the locale the app formats with.
///
/// This is the single place that knows "Arabic is right-to-left". Before the
/// eight new languages the app asked `languageCode == "ar"` in about thirty
/// places, which is the same question only while Arabic is the only RTL
/// language on the list — Urdu and Persian make it wrong. Ask
/// `NoorLanguage.interfaceDirection` (or `.noorInterfaceDirection()` on a
/// view) instead of comparing language codes.
///
/// Note the deliberate *non*-generalisation: `isArabicUI` at the call sites
/// that pick **content** (the Arabic hadith text vs its English translation,
/// an Arabic surah name vs its transliteration) still means Arabic and only
/// Arabic. A Bengali interface reads the English translation; it does not
/// suddenly read Arabic because Bengali happens to be non-Latin.
///
/// Raw values are the BCP-47 codes used by the string catalog, by
/// `project.yml`'s `knownRegions`, and — verbatim — by the Android app.
public enum NoorLanguage: String, CaseIterable, Sendable {
    case ar
    case en
    case id
    case ur
    case fa
    case tr
    case ms
    case bn
    case fr
    case es

    /// UserDefaults key. `"system"` (the default) is not a case: it means
    /// "resolve against the device", which `current` does.
    public static let defaultsKey = "app.language"
    public static let systemValue = "system"

    /// The language's own name, in its own language and script. A language
    /// picker that lists "Bengali" to a Bengali speaker who cannot read the
    /// current interface language is useless, so these are NEVER localised
    /// and never routed through the string catalog.
    public var endonym: String {
        switch self {
        case .ar: "العربية"
        case .en: "English"
        case .id: "Bahasa Indonesia"
        case .ur: "اردو"
        case .fa: "فارسی"
        case .tr: "Türkçe"
        case .ms: "Bahasa Melayu"
        case .bn: "বাংলা"
        case .fr: "Français"
        case .es: "Español"
        }
    }

    /// Right-to-left languages. Arabic script (ar, ur, fa) here; Bengali,
    /// like the Latin-script languages, is left-to-right.
    public var isRTL: Bool {
        switch self {
        case .ar, .ur, .fa: true
        default: false
        }
    }

    public var layoutDirection: LayoutDirection { isRTL ? .rightToLeft : .leftToRight }

    /// Scripts that are cursive or that stack marks, where Latin letter
    /// tracking damages the word rather than opening it up (see
    /// `noorTracking`).
    public var usesLatinScript: Bool {
        switch self {
        case .ar, .ur, .fa, .bn: false
        default: true
        }
    }

    /// The locale the app formats dates, times and numbers with.
    ///
    /// Urdu and Bengali are the two places we override CLDR, which defaults
    /// both to Western digits: an Urdu reader expects the eastern
    /// Arabic-Indic forms (۱۲۳ — the set Persian uses), and a Bengali reader
    /// expects Bengali digits (১২৩), which is also what the Bengali strings
    /// themselves are written with. Asking through the Unicode `nu`
    /// extension keeps every formatter in the app — prayer times, dates,
    /// counters — in the same digits as the text beside them; the
    /// alternative is one screen with two numeral systems on it, which
    /// reads as a rendering bug.
    ///
    /// Arabic (٠١٢) and Persian (۰۱۲) already get theirs from CLDR, and the
    /// Latin-script languages get Western digits, with no code of ours in
    /// the way.
    /// Note what is NOT here: Arabic. CLDR gives `ar` Western digits, and
    /// the app has always compensated with explicit `.arabicIndic` calls on
    /// the Arabic strings themselves. Switching `ar` to the `arab` numbering
    /// system would change every time and date on the shipped Arabic
    /// screens, which is a separate, reviewable change — not a side effect
    /// of adding eight languages.
    public var locale: Locale {
        guard let numberingSystem else { return Locale(identifier: rawValue) }
        // Built through `Locale.Components`: the BCP-47 spelling
        // `bn-u-nu-beng` is silently mangled to `bn-u-NU` by Foundation's
        // identifier parser and the numbering system is lost.
        var components = Locale.Components(identifier: rawValue)
        components.numberingSystem = numberingSystem
        return Locale(components: components)
    }

    private var numberingSystem: Locale.NumberingSystem? {
        switch self {
        case .ur: Locale.NumberingSystem("arabext")
        case .bn: Locale.NumberingSystem("beng")
        default: nil
        }
    }

    /// Zero of the digit set this language writes numbers in — for the few
    /// places that build a numeral by hand rather than through a formatter.
    /// `nil` means Western digits (no transformation).
    public var digitZero: Unicode.Scalar? {
        switch self {
        case .ar: Unicode.Scalar(0x0660)!         // ٠ Arabic-Indic
        case .ur, .fa: Unicode.Scalar(0x06F0)!    // ۰ eastern Arabic-Indic
        case .bn: Unicode.Scalar(0x09E6)!         // ০ Bengali
        default: nil
        }
    }

    // MARK: - The language the app is currently drawn in

    /// The stored preference: a raw value, or `"system"`.
    ///
    /// `NOOR_LANG` overrides it, the same screenshot/UI-test hook `RootView`
    /// uses — the two must agree or the direction and the strings disagree.
    public static var stored: String {
        ProcessInfo.processInfo.environment["NOOR_LANG"]
            ?? UserDefaults.standard.string(forKey: defaultsKey)
            ?? systemValue
    }

    /// The resolved language, never `"system"`.
    ///
    /// Read behind a cache because this is hit once per `Text` per layout
    /// pass; the cache is dropped on any defaults change, exactly as
    /// `NoorAppFont.current` does, so Settings needs no extra plumbing.
    public static var current: NoorLanguage {
        if let cached { return cached }
        let value = resolve(stored)
        cached = value
        startObservingIfNeeded()
        return value
    }

    /// Resolves a stored value (`"system"`, `"ar"`, `"pt-BR"`, …) to one of
    /// our languages. `"system"` and anything unknown fall back to the best
    /// match among the device's preferred languages, then to English.
    public static func resolve(_ stored: String) -> NoorLanguage {
        if stored != systemValue, let exact = NoorLanguage(rawValue: stored) { return exact }
        if stored != systemValue,
           let code = Locale(identifier: stored).language.languageCode?.identifier,
           let match = NoorLanguage(rawValue: code) {
            return match
        }
        for preferred in Locale.preferredLanguages {
            if let code = Locale(identifier: preferred).language.languageCode?.identifier,
               let match = NoorLanguage(rawValue: code) {
                return match
            }
        }
        return .en
    }

    /// The direction the *interface* is laid out in.
    public static var interfaceDirection: LayoutDirection { current.layoutDirection }

    private nonisolated(unsafe) static var cached: NoorLanguage?
    private nonisolated(unsafe) static var observer: NSObjectProtocol?

    private static func startObservingIfNeeded() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: nil
        ) { _ in cached = nil }
    }

    /// Test/preview hook — forget the cached language.
    public static func invalidateCache() { cached = nil }
}

public extension View {
    /// Re-applies the interface writing direction.
    ///
    /// Needed because a sheet, a popover or a `fullScreenCover` starts a new
    /// presentation and does not inherit `\.layoutDirection` from the view
    /// that presented it — the app would otherwise open an Urdu sheet
    /// left-to-right. Reads the stored language rather than the environment
    /// locale precisely because the environment is what is missing there.
    func noorInterfaceDirection() -> some View {
        environment(\.layoutDirection, NoorLanguage.interfaceDirection)
    }
}

public extension Int {
    /// This number written in `language`'s own digits.
    ///
    /// Formatters (`Text(_:format:)`, `Date.FormatStyle`) already do this
    /// from the locale; use this only where a numeral is being pasted into a
    /// hand-built string.
    func noorDigits(_ language: NoorLanguage = .current) -> String {
        guard let zero = language.digitZero else { return String(self) }
        return String(String(self).map { character in
            guard let digit = character.wholeNumberValue, (0...9).contains(digit) else {
                return character
            }
            return Character(Unicode.Scalar(zero.value + UInt32(digit))!)
        })
    }
}
