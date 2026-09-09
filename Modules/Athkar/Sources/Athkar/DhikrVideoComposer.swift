import DesignSystem
import Foundation
import ShareVideo

/// The dhikr flavour of "Share as video": the same card-plus-equaliser MP4 the
/// Quran reader offers for an ayah, with Hamad Al-Duraihim's Hisn al-Muslim
/// recording as its soundtrack. The composing lives in `Core/ShareVideo`, so
/// Athkar needs no dependency on the Quran audio module.
public enum DhikrVideoComposer {
    /// Reciter of every athkar recording (see LICENSES.md).
    public static let reciterArabic = "حمد الدريهم"
    public static let reciterEnglish = "Hamad Al-Duraihim"

    /// Sub-line under the "Share as video" button.
    ///
    /// Not `String(localized:)`: that resolves in the PROCESS language, while
    /// the app switches language through the environment — pick by `arabicUI`.
    public static func caption(arabicUI: Bool) -> String {
        arabicUI ? "بصوت \(reciterArabic)" : "with \(reciterEnglish)'s recitation"
    }

    /// A "Share as video" option for `NoorShareSheet`, or nil when this dhikr
    /// has no recording — the sheet then shows no video button at all rather
    /// than a dead one.
    ///
    /// The whole recording is used, never a trimmed clip: cutting someone's
    /// dhikr short is not ours to do. The files are short anyway — the median
    /// is ~17 s and 83% are under 30 s (measured over all 267, 2026-09).
    public static func shareOption(for dhikr: Dhikr, arabicUI: Bool) -> NoorShareVideoOption? {
        guard let file = dhikr.audio else { return nil }
        return NoorShareVideoOption(caption: caption(arabicUI: arabicUI)) { card in
            // Cache first, download if needed — the sheet shows its spinner
            // for the whole closure, so a first-time fetch reads as progress.
            guard let audio = await AthkarAudioStore.ensureLocal(file: file)
            else { throw ShareVideoError.audioUnavailable }
            try Task.checkCancellation()
            return try await ShareVideoComposer.makeVideo(
                card: card, audioURL: audio, baseName: "noor-dhikr-\(baseName(file: file))")
        }
    }

    /// File name without its extension, stripped to characters that are safe
    /// in a path (the chapter recordings carry long underscored names).
    public static func baseName(file: String) -> String {
        let stem = (file as NSString).deletingPathExtension
        let safe = stem.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" }
        return String(String.UnicodeScalarView(safe))
    }
}
