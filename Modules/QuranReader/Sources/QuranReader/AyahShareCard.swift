import ContentDB
import DesignSystem
import QuranAudio
import SwiftUI

/// Verse convenience used by the reader.
///
/// Shares the tapped ayah, or a run starting at it: a single short ayah makes
/// a video of a second or two, which is not worth posting — extending the run
/// fills a status without leaving the passage.
struct ShareAyahSheet: View {
    let verse: Verse
    let surahName: String
    /// Verses of this surah from the tapped ayah onwards, capped at `count`.
    let run: (Int) -> [Verse]
    /// Ayat available after the tapped one (the run can never leave the surah).
    let available: Int
    let translation: (Verse) -> String?
    @State private var count = 1
    @Environment(\.locale) private var locale

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    /// Ayat that are really there — `run` is the source of truth, so a short
    /// surah can never produce an empty tail.
    private var verses: [Verse] {
        let found = run(count)
        return found.isEmpty ? [verse] : found
    }

    /// Verbatim DB text per ayah, joined by the ayah-number marker the reader
    /// already draws between verses (`QuranFlow`). Nothing Quranic is built,
    /// reshaped or typed here — only stored texts placed end to end.
    private var arabicText: String {
        let items = verses
        guard items.count > 1 else { return items[0].text }
        return items
            .map { "\($0.text) \u{2067}﴿\($0.ayah.arabicIndic)﴾\u{2069}" }
            .joined(separator: " ")
    }

    private var joinedTranslation: String? {
        let items = verses
        let lines = items.compactMap { verse -> String? in
            guard let line = translation(verse) else { return nil }
            return items.count > 1 ? "(\(verse.ayah)) \(line)" : line
        }
        return lines.isEmpty ? nil : lines.joined(separator: " ")
    }

    private var reference: String {
        let items = verses
        guard let first = items.first, let last = items.last else { return surahName }
        return first.ayah == last.ayah
            ? "\(surahName) · \(verse.surahId):\(first.ayah)"
            : "\(surahName) · \(verse.surahId):\(first.ayah)-\(last.ayah)"
    }

    var body: some View {
        VStack(spacing: 0) {
            if available > 1 { rangePicker }
            NoorShareSheet(
                arabicText: arabicText,
                translation: joinedTranslation,
                reference: reference,
                attribution: "نور Noor · Quran text: Tanzil.net",
                useQuranFont: true,
                videoOption: AyahVideoComposer.shareOption(
                    surah: verse.surahId, ayat: verses.map(\.ayah),
                    arabicUI: isArabicUI))
                // A new selection is a different card and a different
                // recitation: rebuild rather than leave a stale render or a
                // half-composed video behind.
                .id(count)
        }
        .background(NoorColor.bgPrimary)
    }

    /// Intrinsically sized and centred — NOT edge-anchored with a `Spacer`.
    /// The sheet's column is as wide as the un-scaled preview card (620pt, the
    /// `scaleEffect` being cosmetic), which is wider than the screen, so
    /// anything pushed to its edges lands outside the visible sheet.
    private var rangePicker: some View {
        VStack(spacing: 8) {
            Text("Ayat to share")
                .font(.noorScaled(13, weight: .medium))
                .foregroundStyle(NoorColor.inkSecondary)
            HStack(spacing: 10) {
                stepButton("minus", enabled: count > 1) { count -= 1 }
                Text(verbatim: isArabicUI ? count.arabicIndic : "\(count)")
                    .font(.noorScaled(19, weight: .semibold))
                    .foregroundStyle(NoorColor.inkPrimary)
                    .frame(minWidth: 46)
                    .contentTransition(.numericText())
                stepButton("plus", enabled: count < available) { count += 1 }
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 2)
    }

    private func stepButton(_ icon: String, enabled: Bool,
                            action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { action() }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(enabled ? NoorColor.accentPrimary : NoorColor.inkSecondary.opacity(0.4))
                .frame(width: 44, height: 44)
                .background(Circle().fill(NoorColor.bgElevated))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(icon == "plus" ? "Add an ayah" : "Remove an ayah")
    }
}
