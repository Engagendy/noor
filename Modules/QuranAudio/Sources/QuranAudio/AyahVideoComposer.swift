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
        let reciter = Reciter(rawValue: UserDefaults.standard.string(forKey: "audio.reciter") ?? "") ?? .alafasy
        let name = reciter.displayName(arabicUI: arabicUI)
        // Not String(localized:): it resolves in the PROCESS language, while the
        // app switches language through the environment — pick by arabicUI.
        let caption = arabicUI ? "بصوت \(name)" : "with \(name)'s recitation"
        return NoorShareVideoOption(caption: caption) { card in
            guard let audio = await AudioCache.ensureLocal(reciter: reciter, surah: surah, ayah: ayah)
            else { throw ShareVideoError.audioUnavailable }
            try Task.checkCancellation()
            return try await ShareVideoComposer.makeVideo(
                card: card, audioURL: audio,
                baseName: "noor-ayah-\(surah)-\(ayah)-\(reciter.rawValue)")
        }
    }
}
