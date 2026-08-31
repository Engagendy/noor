import ContentDB
import DesignSystem
import QuranAudio
import SwiftUI
import Tafsir
import Translations

/// Flow-mode reader. Two display modes:
/// - Mushaf (default): one Madani page per screen, swiped horizontally in
///   RTL direction like a printed mushaf — pages load lazily.
/// - Ayah by ayah: lazy vertical list, tap-to-select action chips, optional
///   translation below each ayah.
/// While reciting, the current ayah is tinted and the view follows it.
public struct SurahReaderView: View {
    public enum DisplayMode: String {
        case mushaf, ayah, page
    }

    @State private var viewModel: SurahReaderViewModel
    @AppStorage("reader.fontSize") private var quranFontSize = 26.0
    @AppStorage("reader.mode") private var modeRaw = DisplayMode.mushaf.rawValue
    @AppStorage("reader.showTranslation") private var showTranslation = false
    /// Furthest mushaf page ever reached — drives khatmah progress on Today.
    @AppStorage("khatmah.maxPage") private var khatmahMaxPage = 0
    @State private var selectedAyah: Int?
    @State private var currentPage = 0
    @State private var tafsirVerse: Verse?
    @State private var shareVerse: Verse?
    @State private var actionsPage: SurahReaderViewModel.PageGroup?
    @State private var downloader = SurahDownloader()
    @GestureState private var pinchScale: CGFloat = 1
    @Environment(\.locale) private var locale

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    private let player: QuranAudioPlayer?
    private let translations: TranslationStore?
    private let layout: PageLayoutDatabase?
    private let surahId: Int
    private let scrollToAyah: Int?
    private let bookmarkedAyat: Set<Int>
    private let onToggleBookmark: ((Int) -> Void)?
    @AppStorage("reader.wordByWord") private var wordByWord = false
    @State private var fontStore = PageFontStore()

    public init(
        database: QuranDatabase,
        surahId: Int,
        scrollToAyah: Int? = nil,
        player: QuranAudioPlayer? = nil,
        translations: TranslationStore? = nil,
        layout: PageLayoutDatabase? = nil,
        bookmarkedAyat: Set<Int> = [],
        onToggleBookmark: ((Int) -> Void)? = nil
    ) {
        self.layout = layout
        _viewModel = State(initialValue: SurahReaderViewModel(database: database, surahId: surahId))
        self.surahId = surahId
        self.scrollToAyah = scrollToAyah
        self.player = player
        self.translations = translations
        self.bookmarkedAyat = bookmarkedAyat
        self.onToggleBookmark = onToggleBookmark
    }

    private var mode: DisplayMode { DisplayMode(rawValue: modeRaw) ?? .mushaf }
    private var liveFontSize: CGFloat {
        (quranFontSize * pinchScale).clamped(to: NoorMetrics.quranSizeRange)
    }
    /// The ayah currently being recited in this surah, if any.
    private var recitingAyah: Int? {
        guard let current = player?.current, current.surah == surahId else { return nil }
        return current.ayah
    }

    public var body: some View {
        Group {
            switch mode {
            case .mushaf: mushafPager
            case .ayah: ayahList
            case .page: madaniPager
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .background(NoorColor.bgPrimary)
        .overlay(alignment: .bottom) {
            if let player {
                AudioPillView(player: player)
                    .environment(\.layoutDirection, .leftToRight)
                    .padding(.bottom, 8)
            }
        }
        .simultaneousGesture(pinch)
        .task {
            viewModel.load()
            if let ayah = scrollToAyah, let page = viewModel.page(containing: ayah) {
                currentPage = page
            } else {
                currentPage = viewModel.pages.first?.page ?? 0
            }
            if showTranslation { await translations?.download() }
        }
        .onChange(of: recitingAyah) { _, new in
            guard mode == .mushaf, let new, let page = viewModel.page(containing: new) else { return }
            withAnimation(.easeInOut(duration: 0.3)) { currentPage = page }
        }
        .onChange(of: currentPage) { _, page in
            if page > khatmahMaxPage { khatmahMaxPage = page }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(viewModel.surah?.displayName(arabicUI: isArabicUI) ?? "")
                        .font(isArabicUI ? NoorFont.quran(size: 17) : .system(size: 16, weight: .semibold))
                        .foregroundStyle(NoorColor.inkPrimary)
                    Text(mode == .mushaf && currentPage > 0
                         ? "Juz \(viewModel.juz) · Page \(currentPage)"
                         : "Juz \(viewModel.juz)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(NoorColor.inkSecondary)
                }
            }
            if player != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        startPlayback(from: mode == .mushaf
                            ? (viewModel.pages.first { $0.page == currentPage }?.verses.first?.ayah ?? 1)
                            : 1)
                    } label: {
                        Image(systemName: "play.fill")
                            .foregroundStyle(NoorColor.accentPrimary)
                    }
                    .accessibilityLabel("Play recitation")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                readerMenu
            }
        }
        .sheet(item: $actionsPage) { page in
            AyahActionsSheet(
                verses: page.verses,
                bookmarkedAyat: bookmarkedAyat,
                onPlay: player == nil ? nil : { startPlayback(from: $0.ayah) },
                onTafsir: { verse in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { tafsirVerse = verse }
                },
                onShare: { verse in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shareVerse = verse }
                },
                onToggleBookmark: onToggleBookmark)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $tafsirVerse) { verse in
            TafsirSheetView(surahId: surahId, ayah: verse.ayah, ayahText: verse.text)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $shareVerse) { verse in
            ShareAyahSheet(
                verse: verse,
                surahName: viewModel.surah?.nameTransliterated ?? "",
                translation: showTranslation ? translations?.translation(surah: surahId, ayah: verse.ayah) : nil)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: Madani page mode — pixel-faithful QCF pages

    private var madaniPager: some View {
        TabView(selection: $currentPage) {
            ForEach(viewModel.pages) { page in
                MadaniPageView(page: page.page, layout: layout, fontStore: fontStore) { refs in
                    // Only this surah's ayat on the tapped line.
                    let verses = viewModel.verses.filter { verse in
                        refs.contains { $0.surahId == surahId && $0.ayah == verse.ayah }
                    }
                    guard !verses.isEmpty else { return }
                    actionsPage = SurahReaderViewModel.PageGroup(page: page.page, verses: verses)
                }
                .tag(page.page)
            }
        }
        #if os(iOS)
        .tabViewStyle(.page(indexDisplayMode: .never))
        #endif
    }

    // MARK: Mushaf mode — one page per screen, RTL page turns

    private var mushafPager: some View {
        TabView(selection: $currentPage) {
            ForEach(viewModel.pages) { page in
                mushafPage(page)
                    .tag(page.page)
            }
        }
        #if os(iOS)
        .tabViewStyle(.page(indexDisplayMode: .never))
        #endif
    }

    private func mushafPage(_ page: SurahReaderViewModel.PageGroup) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if page.page == viewModel.pages.first?.page {
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
                }
                tappableFlow(page)
                HStack(spacing: 10) {
                    Rectangle().fill(NoorColor.accentGold.opacity(0.35)).frame(height: 0.5)
                    Text(page.page.arabicIndic)
                        .font(.system(size: 12))
                        .foregroundStyle(NoorColor.accentGold)
                    Rectangle().fill(NoorColor.accentGold.opacity(0.35)).frame(height: 0.5)
                }
                .padding(.top, 10)
                .accessibilityLabel("Page \(page.page)")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            .padding(.bottom, player?.current != nil ? 72 : 0)
        }
    }

    /// Every word is tappable — tap selects ITS ayah (highlight + chips).
    private func tappableFlow(_ page: SurahReaderViewModel.PageGroup) -> some View {
        RTLFlowLayout(horizontalSpacing: liveFontSize * 0.3,
                      verticalSpacing: liveFontSize * NoorMetrics.quranLineSpacingFactor) {
            ForEach(viewModel.flowItems(for: page)) { item in
                let isSelected = selectedAyah == item.ayah
                let isReciting = recitingAyah == item.ayah
                Text(item.text)
                    .font(NoorFont.quran(size: item.kind == .marker ? liveFontSize * 0.62 : liveFontSize))
                    .foregroundStyle(
                        item.kind == .word
                            ? (isReciting ? NoorColor.accentPrimary : NoorColor.inkPrimary)
                            : NoorColor.accentGold)
                    .padding(.horizontal, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(isSelected ? NoorColor.stateReciting : Color.clear)
                    )
                    .contentShape(Rectangle())
                    // Tap = subtle select; long-press = context menu (design 6.2).
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedAyah = isSelected ? nil : item.ayah
                        }
                    }
                    .contextMenu {
                        if let verse = page.verses.first(where: { $0.ayah == item.ayah }) {
                            contextActions(for: verse)
                        }
                    }
            }
        }
        .environment(\.layoutDirection, .leftToRight)  // layout places RTL itself
        .frame(maxWidth: .infinity)
    }

    /// Long-press context menu actions for one ayah.
    @ViewBuilder
    private func contextActions(for verse: Verse) -> some View {
        if player != nil {
            Button {
                startPlayback(from: verse.ayah)
            } label: {
                Label("Play from here", systemImage: "play.fill")
            }
        }
        Button {
            tafsirVerse = verse
        } label: {
            Label("Tafsir", systemImage: "book")
        }
        if let onToggleBookmark {
            Button {
                onToggleBookmark(verse.ayah)
            } label: {
                Label("Bookmark",
                      systemImage: bookmarkedAyat.contains(verse.ayah) ? "bookmark.fill" : "bookmark")
            }
        }
        Button {
            shareVerse = verse
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        Button {
            let text = "\(verse.text) \u{2067}﴿\(verse.ayah.arabicIndic)﴾\u{2069} — \(verse.surahId):\(verse.ayah)"
            #if os(iOS)
            UIPasteboard.general.string = text
            #else
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            #endif
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
    }

    // MARK: Ayah mode — lazy vertical list

    private var ayahList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
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
                    ForEach(viewModel.verses) { verse in
                        ayahBlock(verse).id("a\(verse.ayah)")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .padding(.bottom, player?.current != nil ? 72 : 0)
            }
            .onChange(of: viewModel.verses.count) {
                if let ayah = scrollToAyah { proxy.scrollTo("a\(ayah)", anchor: .top) }
            }
            .onChange(of: recitingAyah) { _, new in
                guard let new else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo("a\(new)", anchor: .center)
                }
            }
        }
    }

    private func ayahBlock(_ verse: Verse) -> some View {
        let isSelected = selectedAyah == verse.ayah
        let isReciting = recitingAyah == verse.ayah
        let sajda = viewModel.sajdaAyat.contains(verse.ayah)
            ? Text(verbatim: " ۩").foregroundStyle(NoorColor.accentGold)
            : Text(verbatim: "")
        return VStack(alignment: .leading, spacing: 10) {
            if wordByWord, let layout {
                WordByWordContainer(
                    layout: layout, surahId: surahId, ayah: verse.ayah, fontSize: liveFontSize,
                    onTapWord: { _ in tafsirVerse = verse })
            } else {
                (Text(verse.text)
                    + sajda
                    + Text(verbatim: "  \u{2067}﴿\(verse.ayah.arabicIndic)﴾\u{2069}")
                        .font(NoorFont.quran(size: liveFontSize * 0.62))
                        .foregroundStyle(NoorColor.accentGold))
                    .font(NoorFont.quran(size: liveFontSize))
                    .foregroundStyle(NoorColor.inkPrimary)
                    .lineSpacing(liveFontSize * NoorMetrics.quranLineSpacingFactor)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if showTranslation, let translation = translations?.translation(surah: surahId, ayah: verse.ayah) {
                Text(translation)
                    .font(NoorFont.translation)
                    .foregroundStyle(NoorColor.inkSecondary)
                    .lineSpacing(4)
                    .environment(\.layoutDirection, .leftToRight)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected || isReciting ? NoorColor.stateReciting : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedAyah = isSelected ? nil : verse.ayah
            }
        }
        .contextMenu { contextActions(for: verse) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ayah \(verse.ayah)")
        .accessibilityValue(verse.text)
    }

    private func startPlayback(from ayah: Int) {
        guard let surah = viewModel.surah else { return }
        // "This page only" mode stops at the end of the page the ayah is on.
        if let page = viewModel.page(containing: ayah),
           let group = viewModel.pages.first(where: { $0.page == page }) {
            player?.pageEndAyah = group.verses.last?.ayah
        }
        player?.play(
            surah: surah.id,
            ayahCount: surah.ayahCount,
            from: ayah,
            title: surah.nameTransliterated,
            pageEndAyah: player?.pageEndAyah)
        withAnimation(.easeInOut(duration: 0.25)) { selectedAyah = nil }
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
            if player != nil {
                Button {
                    startPlayback(from: 1)
                } label: {
                    Label("Play surah", systemImage: "play.fill")
                }
            }
            Picker(selection: $modeRaw) {
                Text("Mushaf (continuous)").tag(DisplayMode.mushaf.rawValue)
                if layout != nil {
                    Text("Page (Madani print)").tag(DisplayMode.page.rawValue)
                }
                Text("Ayah by ayah").tag(DisplayMode.ayah.rawValue)
            } label: {
                Text("Reading mode")
            }
            if translations != nil {
                Toggle(isOn: $showTranslation) {
                    Text("Show translation")
                }
            }
            if layout != nil {
                Toggle(isOn: $wordByWord) {
                    Text("Word by word")
                }
            }
            if let surah = viewModel.surah, let player {
                Button {
                    Task {
                        await downloader.download(
                            reciter: player.reciter, surah: surah.id, ayahCount: surah.ayahCount)
                    }
                } label: {
                    switch downloader.state {
                    case .downloading(let completed, let total):
                        Label("Downloading \(completed)/\(total)…", systemImage: "arrow.down.circle")
                    case .done:
                        Label("Audio downloaded", systemImage: "checkmark.circle")
                    default:
                        if SurahDownloader.isDownloaded(
                            reciter: player.reciter, surah: surah.id, ayahCount: surah.ayahCount) {
                            Label("Audio downloaded", systemImage: "checkmark.circle")
                        } else {
                            Label("Download surah audio", systemImage: "arrow.down.circle")
                        }
                    }
                }
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
        .onChange(of: showTranslation) { _, enabled in
            if enabled {
                modeRaw = DisplayMode.ayah.rawValue
                Task { await translations?.download() }
            }
        }
        .onChange(of: wordByWord) { _, enabled in
            if enabled { modeRaw = DisplayMode.ayah.rawValue }
        }
    }
}

/// Loads one ayah's words off the layout DB and renders the wbw grid.
private struct WordByWordContainer: View {
    let layout: PageLayoutDatabase
    let surahId: Int
    let ayah: Int
    let fontSize: CGFloat
    var onTapWord: ((PageWord) -> Void)?

    @State private var words: [PageWord] = []

    var body: some View {
        WordByWordView(words: words, fontSize: fontSize, onTapWord: onTapWord)
            .task { words = (try? layout.words(surahId: surahId, ayah: ayah)) ?? [] }
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
