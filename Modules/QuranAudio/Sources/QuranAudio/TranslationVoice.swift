import Foundation

/// Translated readings from EveryAyah.com (see LICENSES.md): after each
/// Arabic ayah the player reads the same ayah in the chosen language.
public enum TranslationVoice: String, CaseIterable, Identifiable, Codable {
    case none
    case english
    case urdu
    case persian
    case bosnian
    case azerbaijani

    /// UserDefaults key shared by the player and the Settings screen.
    public static let defaultsKey = "audio.translation"

    public var id: String { rawValue }

    /// Currently selected voice (Settings / player mirror).
    public static var stored: TranslationVoice {
        TranslationVoice(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .none
    }

    public var englishName: String {
        switch self {
        case .none: "Off"
        case .english: "English · Ibrahim Walk"
        case .urdu: "Urdu · Shamshad Ali Khan"
        case .persian: "Persian · Fooladvand"
        case .bosnian: "Bosnian · Besim Korkut"
        case .azerbaijani: "Azerbaijani · Balayev"
        }
    }

    public var arabicName: String {
        switch self {
        case .none: "إيقاف"
        case .english: "الإنجليزية · إبراهيم ووك"
        case .urdu: "الأردية · شمشاد علي خان"
        case .persian: "الفارسية · فولادوند"
        case .bosnian: "البوسنية · بسيم كوركوت"
        case .azerbaijani: "الأذربيجانية · بالاييف"
        }
    }

    public func displayName(arabicUI: Bool) -> String {
        arabicUI ? arabicName : englishName
    }

    /// Language only ("English" / "الإنجليزية"); "Off" is already short.
    /// Used where the full "language · voice" pair would not fit, e.g. the
    /// pinned summary row at the top of the reciter sheet.
    public func shortName(arabicUI: Bool) -> String {
        let full = displayName(arabicUI: arabicUI)
        return full.components(separatedBy: " · ").first ?? full
    }

    /// EveryAyah folder (verified 2026-09-02 for 001001, 002286, 114006).
    var folder: String? {
        switch self {
        case .none: nil
        case .english: "English/Sahih_Intnl_Ibrahim_Walk_192kbps"
        case .urdu: "translations/urdu_shamshad_ali_khan_46kbps"
        case .persian: "translations/Fooladvand_Hedayatfar_40Kbps"
        case .bosnian: "translations/besim_korkut_ajet_po_ajet"
        case .azerbaijani: "translations/azerbaijani/balayev"
        }
    }

    /// On-disk sub-folder inside the recitations cache — the EveryAyah
    /// folder with every "/" replaced so it stays a single path component.
    var cacheFolder: String? {
        folder?.replacingOccurrences(of: "/", with: "_")
    }

    /// Candidate sources in order (same hosts as `Reciter.urls`); empty for `.none`.
    public func urls(surah: Int, ayah: Int) -> [URL] {
        guard let folder else { return [] }
        return Reciter.everyAyahURLs(folder: folder, surah: surah, ayah: ayah)
    }

    public func url(surah: Int, ayah: Int) -> URL? {
        urls(surah: surah, ayah: ayah).first
    }
}
