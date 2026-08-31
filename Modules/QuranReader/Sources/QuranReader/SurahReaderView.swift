import ContentDB
import DesignSystem
import SwiftUI

/// Phase 0: raw flow-mode rendering of a surah from the bundled database.
/// The mushaf is ALWAYS right-to-left regardless of UI language.
public struct SurahReaderView: View {
    @State private var viewModel: SurahReaderViewModel
    @State private var quranFontSize: CGFloat = 26

    public init(database: QuranDatabase, surahId: Int) {
        _viewModel = State(initialValue: SurahReaderViewModel(database: database, surahId: surahId))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 28) {
                if let surah = viewModel.surah {
                    surahHeader(surah)
                }
                ForEach(viewModel.verses) { verse in
                    Text(verse.text)
                        .font(NoorFont.quran(size: quranFontSize))
                        .foregroundStyle(NoorColor.inkPrimary)
                        .lineSpacing(quranFontSize * NoorMetrics.quranLineSpacingFactor)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityLabel("Ayah \(verse.ayah)")
                        .accessibilityValue(verse.text)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .background(NoorColor.bgPrimary)
        .task { viewModel.load() }
    }

    private func surahHeader(_ surah: Surah) -> some View {
        VStack(spacing: 8) {
            Text(surah.nameArabic)
                .font(NoorFont.quran(size: 30))
                .foregroundStyle(NoorColor.accentGold)
            Text(surah.nameTransliterated)
                .font(NoorFont.caption)
                .foregroundStyle(NoorColor.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(NoorColor.accentGold, lineWidth: 1)
        )
    }
}

#Preview("Al-Fatiha — EN LTR chrome") {
    if let db = try? QuranDatabase() {
        SurahReaderView(database: db, surahId: 1)
    }
}

#Preview("Al-Fatiha — AR RTL") {
    if let db = try? QuranDatabase() {
        SurahReaderView(database: db, surahId: 1)
            .environment(\.locale, Locale(identifier: "ar"))
            .environment(\.layoutDirection, .rightToLeft)
    }
}
