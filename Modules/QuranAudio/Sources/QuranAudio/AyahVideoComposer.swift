import DesignSystem
import Foundation
import ShareVideo

/// The ayah flavour of "Share as video": which reciter, which MP3, what the
/// button's sub-line says. The composing itself is `ShareVideoComposer` in
/// `Core/ShareVideo` — Athkar shares the same machinery from its own module,
/// and feature modules never import each other.
public enum AyahVideoComposer {
    /// Ready-made "Share as video" option for `NoorShareSheet`: resolves the
    /// current reciter, fetches the ayah MP3 (cache → download) and composes.
    @MainActor
    public static func shareOption(surah: Int, ayah: Int, arabicUI: Bool) -> NoorShareVideoOption {
        shareOption(surah: surah, ayat: [ayah], arabicUI: arabicUI)
    }

    /// Several consecutive ayat in one video: their recitations are fetched in
    /// order and played back to back over the single card.
    @MainActor
    public static func shareOption(surah: Int, ayat: [Int], arabicUI: Bool) -> NoorShareVideoOption {
        let reciter = Reciter(rawValue: UserDefaults.standard.string(forKey: "audio.reciter") ?? "") ?? .alafasy
        let name = reciter.displayName(arabicUI: arabicUI)
        // Not String(localized:): it resolves in the PROCESS language, while the
        // app switches language through the environment — pick by arabicUI.
        let caption = arabicUI ? "بصوت \(name)" : "with \(name)'s recitation"
        let ayat = ayat.isEmpty ? [1] : ayat
        return NoorShareVideoOption(caption: caption) { card in
            var audio: [URL] = []
            for ayah in ayat {
                // Sequential, not concurrent: one ayah at a time keeps the
                // failure honest (we know which one is missing) and the
                // download polite on a weak connection.
                guard let url = await AudioCache.ensureLocal(
                    reciter: reciter, surah: surah, ayah: ayah)
                else { throw ShareVideoError.audioUnavailable }
                try Task.checkCancellation()
                audio.append(url)
            }
            let span = ayat.count == 1 ? "\(ayat[0])" : "\(ayat[0])-\(ayat[ayat.count - 1])"
            return try await ShareVideoComposer.makeVideo(
                card: card, audioURLs: audio,
                baseName: "noor-ayah-\(surah)-\(span)-\(reciter.rawValue)")
        }
    }
}
