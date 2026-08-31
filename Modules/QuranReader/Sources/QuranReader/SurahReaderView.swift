import ContentDB
import DesignSystem
import SwiftUI

/// Flow-mode reader implementing design 1b (classic flow, Mushaf/Tahajjud):
/// ornament surah header, basmala, per-ayah blocks with gold end markers,
/// tap-to-select with action chips. Translation rows arrive with the
/// translation download phase.
public struct SurahReaderView: View {
    @State private var viewModel: SurahReaderViewModel
    @AppStorage("reader.fontSize") private var quranFontSize = 26.0
    @State private var selectedAyah: Int?

    public init(database: QuranDatabase, surahId: Int) {
        _viewModel = State(initialValue: SurahReaderViewModel(database: database, surahId: surahId))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if let surah = viewModel.surah {
                    SurahOrnamentFrame {
                        Text(surah.nameArabic)
                            .font(NoorFont.quran(size: 24))
                            .foregroundStyle(NoorColor.inkPrimary)
                    }
                    .padding(.bottom, 10)
                }
                if let basmala = viewModel.basmala {
                    Text(basmala)
                        .font(NoorFont.quran(size: quranFontSize * 0.92))
                        .foregroundStyle(NoorColor.inkPrimary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 14)
                }
                ForEach(viewModel.verses) { verse in
                    ayahBlock(verse)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .background(NoorColor.bgPrimary)
        .task { viewModel.load() }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationTitle(viewModel.surah?.nameTransliterated ?? "")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                fontSizeMenu
            }
        }
    }

    private func ayahBlock(_ verse: Verse) -> some View {
        let isSelected = selectedAyah == verse.ayah
        return VStack(alignment: .leading, spacing: 10) {
            (Text(verse.text)
                + Text("  ﴿\(verse.ayah.arabicIndic)﴾")
                    .font(NoorFont.quran(size: quranFontSize * 0.62))
                    .foregroundStyle(NoorColor.accentGold))
                .font(NoorFont.quran(size: quranFontSize))
                .foregroundStyle(NoorColor.inkPrimary)
                .lineSpacing(quranFontSize * NoorMetrics.quranLineSpacingFactor)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            if isSelected {
                actionChips
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? NoorColor.stateReciting : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedAyah = isSelected ? nil : verse.ayah
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ayah \(verse.ayah)")
        .accessibilityValue(verse.text)
    }

    /// Play / Tafsir / Bookmark arrive in later phases — chips are the
    /// design's affordance, disabled until wired.
    private var actionChips: some View {
        HStack(spacing: 6) {
            Label("Play from here", systemImage: "play.fill")
                .chipStyle(filled: true)
            Text("Tafsir").chipStyle()
            Text("Bookmark").chipStyle()
        }
        .disabled(true)
        .opacity(0.55)
    }

    private var fontSizeMenu: some View {
        Menu {
            Button {
                quranFontSize = min(NoorMetrics.quranSizeRange.upperBound, quranFontSize + 2)
            } label: {
                Label("Larger", systemImage: "plus")
            }
            Button {
                quranFontSize = max(NoorMetrics.quranSizeRange.lowerBound, quranFontSize - 2)
            } label: {
                Label("Smaller", systemImage: "minus")
            }
            Button("Reset") { quranFontSize = 26 }
        } label: {
            Text(verbatim: "Aa")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(NoorColor.accentPrimary)
        }
        .accessibilityLabel("Quran text size")
    }
}

private extension View {
    func chipStyle(filled: Bool = false) -> some View {
        font(.system(size: 12, weight: .semibold))
            .foregroundStyle(filled ? NoorColor.bgPrimary : NoorColor.accentPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(filled ? NoorColor.accentPrimary : NoorColor.accentPrimary.opacity(0.12)))
    }
}

#Preview("Al-Fatiha — Mushaf light") {
    if let db = try? QuranDatabase() {
        NavigationStack { SurahReaderView(database: db, surahId: 1) }
    }
}

#Preview("Al-Baqarah — Tahajjud dark, AR RTL") {
    if let db = try? QuranDatabase() {
        NavigationStack { SurahReaderView(database: db, surahId: 2) }
            .environment(\.locale, Locale(identifier: "ar"))
            .environment(\.layoutDirection, .rightToLeft)
            .preferredColorScheme(.dark)
    }
}
