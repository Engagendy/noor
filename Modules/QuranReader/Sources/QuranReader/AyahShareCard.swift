import ContentDB
import DesignSystem
import QuranAudio
import SwiftUI

/// Verse convenience used by the reader.
struct ShareAyahSheet: View {
    let verse: Verse
    let surahName: String
    let translation: String?
    @Environment(\.locale) private var locale

    var body: some View {
        NoorShareSheet(
            arabicText: verse.text,
            translation: translation,
            reference: "\(surahName) · \(verse.surahId):\(verse.ayah)",
            attribution: "نور Noor · Quran text: Tanzil.net",
            useQuranFont: true,
            videoOption: AyahVideoComposer.shareOption(
                surah: verse.surahId, ayah: verse.ayah,
                arabicUI: locale.language.languageCode?.identifier == "ar"))
    }
}
