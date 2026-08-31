import ContentDB
import DesignSystem
import SwiftUI

/// Flow-mode reader. Two display modes:
/// - Mushaf (default): ayat flow continuously like a printed mushaf, grouped
///   by real Madani page boundaries, with ﴿n﴾ ayah markers and ۞ at each
///   hizb-quarter start.
/// - Ayah by ayah: one block per ayah with tap-to-select action chips.
public struct SurahReaderView: View {
    public enum DisplayMode: String {
        case mushaf, ayah
    }

    @State private var viewModel: SurahReaderViewModel
    @AppStorage("reader.fontSize") private var quranFontSize = 26.0
    @AppStorage("reader.mode") private var modeRaw = DisplayMode.mushaf.rawValue
    @State private var selectedAyah: Int?
    @GestureState private var pinchScale: CGFloat = 1

    private let scrollToAyah: Int?

    public init(database: QuranDatabase, surahId: Int, scrollToAyah: Int? = nil) {
        _viewModel = State(initialValue: SurahReaderViewModel(database: database, surahId: surahId))
        self.scrollToAyah = scrollToAyah
    }

    private var mode: DisplayMode { DisplayMode(rawValue: modeRaw) ?? .mushaf }
    private var liveFontSize: CGFloat {
        (quranFontSize * pinchScale).clamped(to: NoorMetrics.quranSizeRange)
    }

    public var body: some View {
        ScrollViewReader { proxy in
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
                            .font(NoorFont.quran(size: liveFontSize * 0.92))
                            .foregroundStyle(NoorColor.inkPrimary)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 14)
                    }
                    switch mode {
                    case .mushaf:
                        ForEach(viewModel.pages) { page in
                            mushafPage(page)
                        }
                    case .ayah:
                        ForEach(viewModel.verses) { verse in
                            ayahBlock(verse).id("a\(verse.ayah)")
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
            .onChange(of: viewModel.pages.count) {
                guard let ayah = scrollToAyah else { return }
                if mode == .mushaf, let page = viewModel.page(containing: ayah) {
                    proxy.scrollTo("p\(page)", anchor: .top)
                } else {
                    proxy.scrollTo("a\(ayah)", anchor: .top)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .background(NoorColor.bgPrimary)
        .simultaneousGesture(pinch)
        .task { viewModel.load() }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(viewModel.surah?.nameTransliterated ?? "")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(NoorColor.inkPrimary)
                    Text("Juz \(viewModel.juz)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(NoorColor.inkSecondary)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                readerMenu
            }
        }
    }

    // MARK: Mushaf mode

    private func mushafPage(_ page: SurahReaderViewModel.PageGroup) -> some View {
        VStack(spacing: 14) {
            continuousText(page.verses)
                .lineSpacing(liveFontSize * NoorMetrics.quranLineSpacingFactor)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 10) {
                Rectangle().fill(NoorColor.accentGold.opacity(0.35)).frame(height: 0.5)
                Text(page.page.arabicIndic)
                    .font(.system(size: 12))
                    .foregroundStyle(NoorColor.accentGold)
                Rectangle().fill(NoorColor.accentGold.opacity(0.35)).frame(height: 0.5)
            }
            .accessibilityLabel("Page \(page.page)")
        }
        .id("p\(page.page)")
        .padding(.bottom, 12)
    }

    /// One flowing Text per page: ayah ﴿n﴾ ayah ﴿n﴾ … with ۞ before each
    /// hizb-quarter start, exactly as in a printed mushaf.
    private func continuousText(_ verses: [Verse]) -> Text {
        verses.reduce(Text(verbatim: "")) { result, verse in
            var piece = Text(verbatim: "")
            if viewModel.quarterStarts[verse.ayah] != nil {
                piece = piece + Text(verbatim: "۞ ")
                    .foregroundStyle(NoorColor.accentGold)
            }
            piece = piece + Text(verse.text)
                + Text(verbatim: " ﴿\(verse.ayah.arabicIndic)﴾ ")
                    .font(NoorFont.quran(size: liveFontSize * 0.62))
                    .foregroundStyle(NoorColor.accentGold)
            return result + piece
        }
        .font(NoorFont.quran(size: liveFontSize))
        .foregroundStyle(NoorColor.inkPrimary)
    }

    // MARK: Ayah mode

    private func ayahBlock(_ verse: Verse) -> some View {
        let isSelected = selectedAyah == verse.ayah
        return VStack(alignment: .leading, spacing: 10) {
            (Text(verse.text)
                + Text(verbatim: "  ﴿\(verse.ayah.arabicIndic)﴾")
                    .font(NoorFont.quran(size: liveFontSize * 0.62))
                    .foregroundStyle(NoorColor.accentGold))
                .font(NoorFont.quran(size: liveFontSize))
                .foregroundStyle(NoorColor.inkPrimary)
                .lineSpacing(liveFontSize * NoorMetrics.quranLineSpacingFactor)
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

    // MARK: Controls

    private var pinch: some Gesture {
        MagnificationGesture()
            .updating($pinchScale) { value, state, _ in state = value }
            .onEnded { value in
                quranFontSize = (quranFontSize * value).clamped(to: NoorMetrics.quranSizeRange)
            }
    }

    private var readerMenu: some View {
        Menu {
            Picker(selection: $modeRaw) {
                Text("Mushaf (continuous)").tag(DisplayMode.mushaf.rawValue)
                Text("Ayah by ayah").tag(DisplayMode.ayah.rawValue)
            } label: {
                Text("Reading mode")
            }
            Divider()
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
        .accessibilityLabel("Reader options")
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
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
