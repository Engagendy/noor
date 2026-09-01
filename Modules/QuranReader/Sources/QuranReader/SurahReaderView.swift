import ContentDB
import DesignSystem
import QuranAudio
import SwiftUI
import Tafsir
import Translations

/// The reader. Mushaf and Madani-print modes page through the WHOLE mushaf
/// (1…604) — swiping past a surah's end continues into the next, with the
/// ornament header and basmala appearing inline, like a printed mushaf.
/// Ayah-by-ayah mode stays scoped to the opened surah.
public struct SurahReaderView: View {
    public enum DisplayMode: String {
        case mushaf, ayah, page
    }

    @State private var viewModel: SurahReaderViewModel
    @AppStorage("reader.fontSize") private var quranFontSize = 26.0
    @AppStorage("reader.mode") private var modeRaw = DisplayMode.mushaf.rawValue
    @AppStorage("reader.showTranslation") private var showTranslation = false
    @AppStorage("reader.wordByWord") private var wordByWord = false
    /// Hifz practice: ayah text hidden until tapped (ayah-list mode).
    @AppStorage("reader.hifz") private var hifzMode = false
    @State private var revealedKeys: Set<Int> = []
    @State private var selectedKey: Int?          // surah*1000 + ayah
    @State private var showOptions =
        ProcessInfo.processInfo.environment["NOOR_SHOWOPTIONS"] == "1"
    @State private var currentPage = 0
    @State private var tafsirVerse: Verse?
    @State private var shareVerse: Verse?
    @State private var actionVerses: SurahReaderViewModel.PageGroup?
    @State private var chromeVisible = true
    @State private var didAutoHide = false
    @State private var downloader = SurahDownloader()
    @State private var fontStore = PageFontStore()
    @GestureState private var pinchScale: CGFloat = 1
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var appDirection
    @Environment(\.dismiss) private var dismiss

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    private let player: QuranAudioPlayer?
    private let translations: TranslationStore?
    private let layout: PageLayoutDatabase?
    private let surahId: Int
    private let scrollToAyah: Int?
    private let bookmarkedRefs: Set<String>       // "surah:ayah"
    private let onToggleBookmark: ((Int, Int) -> Void)?

    public init(
        database: QuranDatabase,
        surahId: Int,
        scrollToAyah: Int? = nil,
        player: QuranAudioPlayer? = nil,
        translations: TranslationStore? = nil,
        layout: PageLayoutDatabase? = nil,
        bookmarkedRefs: Set<String> = [],
        onToggleBookmark: ((Int, Int) -> Void)? = nil
    ) {
        self.layout = layout
        _viewModel = State(initialValue: SurahReaderViewModel(database: database, surahId: surahId))
        self.surahId = surahId
        self.scrollToAyah = scrollToAyah
        self.player = player
        self.translations = translations
        self.bookmarkedRefs = bookmarkedRefs
        self.onToggleBookmark = onToggleBookmark
        // Position the pager before the first frame — no page-1 flash.
        _currentPage = State(initialValue: SurahReaderViewModel.initialPage(
            database: database, surahId: surahId, ayah: scrollToAyah))
        // Arriving at a specific ayah (search/juz/bookmark): highlight it.
        if let ayah = scrollToAyah {
            _selectedKey = State(initialValue: surahId * 1000 + ayah)
        }
    }

    private var mode: DisplayMode { DisplayMode(rawValue: modeRaw) ?? .mushaf }
    private var liveFontSize: CGFloat {
        (quranFontSize * pinchScale).clamped(to: NoorMetrics.quranSizeRange)
    }
    /// Current word (1-based) if follow-along is reciting this exact ayah.
    private func recitingWordPosition(surahId: Int, ayah: Int) -> Int? {
        guard let key = player?.recitingWordKey,
              key / 1_000_000 == surahId, (key / 1_000) % 1_000 == ayah else { return nil }
        return key % 1_000
    }

    private var recitingKey: Int? {
        guard let current = player?.current else { return nil }
        return current.surah * 1000 + current.ayah
    }
    private var titleSurah: Surah? {
        mode == .ayah ? viewModel.surah : viewModel.surah(forPage: currentPage)
    }

    /// Background tap: close the options panel, else toggle chrome.
    /// Attached to page CONTENT (the horizontal pager consumes container taps).
    private func backgroundTapped() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if showOptions { showOptions = false } else { chromeVisible.toggle() }
        }
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
        // Constant-height top strip: content never reflows — the two rows
        // just cross-fade (full controls ↔ surah·time·juz).
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .overlay(alignment: .top) {
            if showOptions {
                // Scrim first: any tap outside the panel dismisses it, in
                // every reading mode (content taps don't reach here in the
                // list/flow modes, so the panel needs its own catcher).
                ZStack(alignment: .top) {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture { backgroundTapped() }
                    optionsPanel
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // Inset, not overlay: Madani pages have no scroll and must
            // shrink above the pill rather than be covered by it.
            if let player, player.current != nil {
                AudioPillView(player: player)
                    .environment(\.layoutDirection, .leftToRight)
                    .padding(.bottom, 6)
                    .padding(.top, 2)
            }
        }
        #if os(iOS)
        // Reader: fully immersive — no system bars, ever.
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .statusBarHidden(!chromeVisible)
        #endif
        .simultaneousGesture(pinch)
        .task {
            viewModel.load()
            if !didAutoHide {
                didAutoHide = true
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation(.easeInOut(duration: 0.35)) { chromeVisible = false }
            }
            if showTranslation { await translations?.download() }
        }
        .onChange(of: recitingKey) { _, new in
            guard mode != .ayah, let new,
                  let page = viewModel.page(surahId: new / 1000, ayah: new % 1000)
            else { return }
            withAnimation(.easeInOut(duration: 0.3)) { currentPage = page }
        }
        .onChange(of: currentPage) { _, page in
            guard page > 0, mode != .ayah else { return }
            // Direct defaults writes: the reader must NOT observe these via
            // @AppStorage or every swipe re-renders the whole pager.
            let defaults = UserDefaults.standard
            if page > defaults.integer(forKey: "khatmah.maxPage") {
                defaults.set(page, forKey: "khatmah.maxPage")
            }
            defaults.set(page, forKey: "reader.lastPage")
            // Khatmah frontier: only SEQUENTIAL reading advances the plan —
            // viewing the next-unread page marks it read. Jumping around
            // (search, bookmarks, browsing) never inflates progress.
            let frontier = defaults.integer(forKey: "khatmah.page")
            if frontier > 0, page == frontier {
                defaults.set(page + 1, forKey: "khatmah.page")
            }
        }
        .sheet(item: $actionVerses) { group in
            AyahActionsSheet(
                verses: group.verses,
                bookmarkedRefs: bookmarkedRefs,
                onPlay: player == nil ? nil : { startPlayback(from: $0) },
                onTafsir: { verse in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { tafsirVerse = verse }
                },
                onShare: { verse in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shareVerse = verse }
                },
                onToggleBookmark: onToggleBookmark)
                .presentationDetents([.medium, .large])
                .environment(\.locale, locale)
                .environment(\.layoutDirection, appDirection)
        }
        .sheet(item: $tafsirVerse) { verse in
            TafsirSheetView(surahId: verse.surahId, ayah: verse.ayah, ayahText: verse.text)
                .presentationDetents([.medium, .large])
                .environment(\.locale, locale)
                .environment(\.layoutDirection, appDirection)
        }
        .sheet(item: $shareVerse) { verse in
            ShareAyahSheet(
                verse: verse,
                surahName: viewModel.surahInfo(verse.surahId)?.nameTransliterated ?? "",
                translation: showTranslation ? translations?.translation(surah: verse.surahId, ayah: verse.ayah) : nil)
                .presentationDetents([.medium, .large])
                .environment(\.locale, locale)
                .environment(\.layoutDirection, appDirection)
        }
    }

    /// Fixed-height strip: full controls ↔ minimal line, pure cross-fade.
    private var topBar: some View {
        ZStack {
            // Full chrome row
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(NoorColor.accentPrimary)
                        .frame(width: 38, height: 38)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(NoorColor.bgElevated)
                                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                Spacer()
                VStack(spacing: 0) {
                    Text(titleSurah?.displayName(arabicUI: isArabicUI) ?? "")
                        .font(isArabicUI ? NoorFont.quran(size: 16) : .system(size: 15, weight: .semibold))
                        .foregroundStyle(NoorColor.inkPrimary)
                        .lineLimit(1)
                    Text(mode != .ayah && currentPage > 0
                         ? "Juz \(viewModel.juz(forPage: currentPage)) · Page \(currentPage)"
                         : "Juz \(viewModel.juz)")
                        .font(.system(size: 11))
                        .foregroundStyle(NoorColor.inkSecondary)
                }
                Spacer()
                if player != nil {
                    Button {
                        if mode == .ayah {
                            if let first = viewModel.verses.first { startPlayback(from: first) }
                        } else if let first = viewModel.sections(forPage: currentPage).first?.verses.first {
                            startPlayback(from: first)
                        }
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(NoorColor.accentPrimary)
                            .frame(width: 36, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Play recitation")
                }
                readerMenu
                    .frame(width: 40, height: 40)
            }
            .opacity(chromeVisible ? 1 : 0)

            // Minimal reading row
            TimelineView(.everyMinute) { context in
                HStack {
                    Text(titleSurah?.displayName(arabicUI: true) ?? "")
                        .font(NoorFont.quran(size: 15))
                    Spacer()
                    Text(context.date, format: .dateTime.hour().minute())
                        .font(.system(size: 12).monospacedDigit())
                    Spacer()
                    Text(mode != .ayah && currentPage > 0
                         ? "Juz \(viewModel.juz(forPage: currentPage)) · Page \(currentPage)"
                         : "Juz \(viewModel.juz)")
                        .font(.system(size: 12))
                }
                .foregroundStyle(NoorColor.inkSecondary)
            }
            .opacity(chromeVisible ? 0 : 1)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(NoorColor.bgPrimary.opacity(0.92))
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) { chromeVisible.toggle() }
        }
    }

    /// Lazy native pager: only visible pages (±1) ever materialize — a
    /// 604-child TabView re-diffs everything per swipe and stutters.
    private var pagePosition: Binding<Int?> {
        Binding(
            get: { currentPage },
            set: { if let page = $0 { currentPage = page } })
    }

    private func lazyPager<Content: View>(
        @ViewBuilder content: @escaping (Int) -> Content
    ) -> some View {
        // Measured size, NOT containerRelativeFrame: the latter ignores the
        // top-strip safe-area inset, making pages taller than the viewport.
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(1...604, id: \.self) { page in
                        content(page)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .id(page)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: pagePosition)
            .scrollIndicators(.hidden)
        }
    }

    // MARK: Madani page mode — the whole mushaf, pixel-faithful

    private var madaniPager: some View {
        lazyPager { page in
            MadaniPageView(
                page: page, layout: layout, fontStore: fontStore,
                surahName: { viewModel.surahInfo($0)?.nameArabic ?? "" },
                basmala: viewModel.basmalaForAnySurah,
                highlightKey: selectedKey ?? recitingKey,
                onTap: backgroundTapped
            ) { refs in
                let verses = viewModel.sections(forPage: page)
                    .flatMap(\.verses)
                    .filter { verse in refs.contains { $0.surahId == verse.surahId && $0.ayah == verse.ayah } }
                guard !verses.isEmpty else { return }
                actionVerses = SurahReaderViewModel.PageGroup(page: page, verses: verses)
            }
        }
    }

    // MARK: Mushaf mode — the whole mushaf, flowing text

    private var mushafPager: some View {
        lazyPager { page in
            mushafPage(page)
        }
    }

    private func mushafPage(_ page: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(viewModel.sections(forPage: page)) { section in
                    // Surah name lives in the top bar — pages show only the
                    // basmala at a surah start (At-Tawbah has none).
                    if section.headerSurah != nil && section.basmala == nil {
                        Rectangle()
                            .fill(NoorColor.accentGold.opacity(0.35))
                            .frame(height: 0.7)
                            .padding(.vertical, 10)
                    }
                    if let basmala = section.basmala {
                        Text(basmala)
                            .font(NoorFont.quran(size: liveFontSize * 0.92))
                            .foregroundStyle(NoorColor.inkPrimary)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 12)
                    }
                    tappableFlow(section: section, page: page)
                }
                HStack(spacing: 10) {
                    Rectangle().fill(NoorColor.accentGold.opacity(0.35)).frame(height: 0.5)
                    Text(page.arabicIndic)
                        .font(.system(size: 12))
                        .foregroundStyle(NoorColor.accentGold)
                    Rectangle().fill(NoorColor.accentGold.opacity(0.35)).frame(height: 0.5)
                }
                .padding(.top, 10)
                .accessibilityLabel("Page \(page)")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 18)
            .contentShape(Rectangle())
            .onTapGesture(perform: backgroundTapped)
        }
    }

    /// Every word is tappable — tap selects ITS ayah; long-press = actions.
    private func tappableFlow(section: SurahReaderViewModel.PageSection, page: Int) -> some View {
        RTLFlowLayout(horizontalSpacing: liveFontSize * 0.3,
                      verticalSpacing: liveFontSize * NoorMetrics.quranLineSpacingFactor) {
            ForEach(viewModel.flowItems(section: section, page: page)) { item in
                let key = item.surahId * 1000 + item.ayah
                let isSelected = selectedKey == key
                Text(item.text)
                    .font(NoorFont.quran(size: item.kind == .marker ? liveFontSize * 0.62 : liveFontSize))
                    .foregroundStyle(
                        item.kind == .word
                            ? (recitingKey == key ? NoorColor.accentPrimary : NoorColor.inkPrimary)
                            : NoorColor.accentGold)
                    .padding(.horizontal, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(isSelected ? NoorColor.stateReciting : Color.clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedKey = isSelected ? nil : key
                        }
                    }
                    .contextMenu {
                        if let verse = section.verses.first(where: {
                            $0.surahId == item.surahId && $0.ayah == item.ayah
                        }) {
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
                startPlayback(from: verse)
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
                onToggleBookmark(verse.surahId, verse.ayah)
            } label: {
                Label("Bookmark",
                      systemImage: bookmarkedRefs.contains(verse.id) ? "bookmark.fill" : "bookmark")
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

    // MARK: Ayah mode — lazy vertical list (opened surah)

    private var ayahList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
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
                .padding(.horizontal, 14)
                .padding(.vertical, 18)
                .contentShape(Rectangle())
                .onTapGesture(perform: backgroundTapped)
            }
            .onChange(of: viewModel.verses.count) {
                if let ayah = scrollToAyah { proxy.scrollTo("a\(ayah)", anchor: .top) }
            }
            .onChange(of: recitingKey) { _, new in
                guard let new, new / 1000 == surahId else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo("a\(new % 1000)", anchor: .center)
                }
            }
        }
    }

    private func ayahBlock(_ verse: Verse) -> some View {
        let key = verse.surahId * 1000 + verse.ayah
        let isSelected = selectedKey == key
        let isReciting = recitingKey == key
        let sajda = viewModel.sajdaKeys.contains(key)
            ? Text(verbatim: " ۩").foregroundStyle(NoorColor.accentGold)
            : Text(verbatim: "")
        return VStack(alignment: .leading, spacing: 10) {
            if wordByWord, let layout {
                WordByWordContainer(
                    layout: layout, surahId: verse.surahId, ayah: verse.ayah, fontSize: liveFontSize,
                    highlightPosition: recitingWordPosition(surahId: verse.surahId, ayah: verse.ayah),
                    onTapWord: { _ in tafsirVerse = verse })
            } else {
                (Text(verse.text)
                    + sajda
                    + Text(verbatim: "  \u{2067}﴿\(verse.ayah.arabicIndic)﴾\u{2069}")
                        .font(NoorFont.quran(size: liveFontSize * 0.62))
                        .foregroundStyle(NoorColor.accentGold))
                    .font(NoorFont.quran(size: liveFontSize))
                    .foregroundStyle(isReciting ? NoorColor.accentPrimary : NoorColor.inkPrimary)
                    .lineSpacing(liveFontSize * NoorMetrics.quranLineSpacingFactor)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if showTranslation,
               let translation = translations?.translation(surah: verse.surahId, ayah: verse.ayah) {
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
        .blur(radius: hifzMode && !revealedKeys.contains(key) && !isReciting ? 7 : 0)
        .animation(.easeInOut(duration: 0.25), value: revealedKeys)
        .onTapGesture {
            if hifzMode && !revealedKeys.contains(key) {
                revealedKeys.insert(key)   // first tap: reveal for checking
                return
            }
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedKey = isSelected ? nil : key
            }
        }
        .contextMenu { contextActions(for: verse) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ayah \(verse.ayah)")
        .accessibilityValue(verse.text)
    }

    private func startPlayback(from verse: Verse) {
        guard let surah = viewModel.surahInfo(verse.surahId) else { return }
        // Continuous playback flows into the next surah.
        player?.surahAdvance = { [weak viewModel] surahId in
            guard let next = viewModel?.surahInfo(surahId) else { return nil }
            return (ayahCount: next.ayahCount,
                    title: next.displayName(arabicUI: isArabicUI),
                    arabicTitle: next.nameArabic)
        }
        if let page = viewModel.page(surahId: verse.surahId, ayah: verse.ayah),
           let last = viewModel.sections(forPage: page).flatMap(\.verses).last {
            player?.pageEndAyah = last.surahId == verse.surahId ? last.ayah : surah.ayahCount
        }
        // Word-by-word + Alafasy: gapless follow-along with word tracking
        // (timings are recorded against this reciter's murattal).
        if wordByWord, player?.reciter == .alafasy, let player {
            let title = surah.displayName(arabicUI: isArabicUI)
            Task {
                let ok = await player.playFollowAlong(
                    surah: surah.id, ayahCount: surah.ayahCount, from: verse.ayah,
                    title: title, arabicTitle: surah.nameArabic)
                if !ok {
                    player.play(surah: surah.id, ayahCount: surah.ayahCount, from: verse.ayah,
                                title: title, arabicTitle: surah.nameArabic,
                                pageEndAyah: player.pageEndAyah)
                }
            }
        } else {
            player?.play(
                surah: surah.id,
                ayahCount: surah.ayahCount,
                from: verse.ayah,
                title: surah.displayName(arabicUI: isArabicUI),
                arabicTitle: surah.nameArabic,
                pageEndAyah: player?.pageEndAyah)
        }
        withAnimation(.easeInOut(duration: 0.25)) { selectedKey = nil }
    }

    // MARK: Controls

    private var pinch: some Gesture {
        MagnificationGesture()
            .updating($pinchScale) { value, state, _ in state = value }
            .onEnded { value in
                quranFontSize = (quranFontSize * value).clamped(to: NoorMetrics.quranSizeRange)
            }
    }

    /// The Aa button toggles a custom dropdown panel (SwiftUI-owned, so it
    /// honors RTL — the system Menu follows the process language and can't).
    private var readerMenu: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { showOptions.toggle() }
        } label: {
            Text(verbatim: "Aa")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(showOptions ? NoorColor.accentGold : NoorColor.accentPrimary)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reader options")
        .onChange(of: showTranslation) { _, enabled in
            if enabled {
                modeRaw = DisplayMode.ayah.rawValue
                Task { await translations?.download() }
            }
        }
        .onChange(of: hifzMode) { _, _ in revealedKeys = [] }
        .onChange(of: wordByWord) { _, enabled in
            if enabled { modeRaw = DisplayMode.ayah.rawValue }
        }
    }

    /// Writes deferred one tick: selecting a mode swaps the whole pager —
    /// synchronous writes from inside the picker abort with
    /// "AttributeGraph: setting value during update".
    private func deferred<V>(_ binding: Binding<V>) -> Binding<V> {
        Binding(
            get: { binding.wrappedValue },
            set: { newValue in
                Task { @MainActor in binding.wrappedValue = newValue }
            })
    }

    /// RTL-correct options panel shown under the top strip.
    private var optionsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker(selection: deferred($modeRaw)) {
                Text("Mushaf").tag(DisplayMode.mushaf.rawValue)
                if layout != nil {
                    Text("Madani").tag(DisplayMode.page.rawValue)
                }
                Text("Ayah by ayah").tag(DisplayMode.ayah.rawValue)
            } label: {
                Text("Reading mode")
            }
            .pickerStyle(.segmented)

            if translations != nil {
                Toggle(isOn: deferred($showTranslation)) {
                    Text("Show translation")
                }
                .tint(NoorColor.accentPrimary)
            }
            if layout != nil {
                Toggle(isOn: deferred($wordByWord)) {
                    Text("Word by word")
                }
                .tint(NoorColor.accentPrimary)
            }
            Toggle(isOn: deferred($hifzMode)) {
                Text("Hifz mode (hide text)")
            }
            .tint(NoorColor.accentPrimary)
            if let surah = viewModel.surah, let player {
                Button {
                    Task {
                        await downloader.download(
                            reciter: player.reciter, surah: surah.id, ayahCount: surah.ayahCount)
                    }
                } label: {
                    Group {
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
                    .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(NoorColor.accentPrimary)
            }

            HStack(spacing: 12) {
                Text("Quran text size")
                    .font(.system(size: 14))
                    .foregroundStyle(NoorColor.inkSecondary)
                Spacer()
                Button {
                    quranFontSize = max(NoorMetrics.quranSizeRange.lowerBound, quranFontSize - 2)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 22))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Smaller")
                Text(verbatim: "\(Int(quranFontSize))")
                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
                    .frame(minWidth: 30)
                Button {
                    quranFontSize = min(NoorMetrics.quranSizeRange.upperBound, quranFontSize + 2)
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 22))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Larger")
            }
            .foregroundStyle(NoorColor.accentPrimary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(NoorColor.bgElevated)
                .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
        )
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .environment(\.layoutDirection, appDirection)
        .environment(\.locale, locale)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

/// Loads one ayah's words off the layout DB and renders the wbw grid.
private struct WordByWordContainer: View {
    let layout: PageLayoutDatabase
    let surahId: Int
    let ayah: Int
    let fontSize: CGFloat
    var highlightPosition: Int?
    var onTapWord: ((PageWord) -> Void)?

    @State private var words: [PageWord] = []

    var body: some View {
        WordByWordView(words: words, fontSize: fontSize,
                       highlightPosition: highlightPosition, onTapWord: onTapWord)
            .task { words = (try? layout.words(surahId: surahId, ayah: ayah)) ?? [] }
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
