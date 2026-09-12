import ContentDB
import DesignSystem
import SwiftUI

/// The shared `SearchResultRow` (DesignSystem, a leaf module that cannot see
/// ContentDB) taking the shared `ArabicSearch.Snippet` directly.
extension SearchResultRow {
    init(snippet: ArabicSearch.Snippet, reference: String,
         isArabic: Bool = true, font: Font = .noorScaled(16)) {
        self.init(before: snippet.before, match: snippet.match, after: snippet.after,
                  truncatedStart: snippet.truncatedStart, truncatedEnd: snippet.truncatedEnd,
                  reference: reference, isArabic: isArabic, font: font)
    }
}

/// Browse tafsir by surah, from the Learn hub — until now tafsir was
/// reachable only by tapping a single ayah in the reader, which is no way to
/// read a surah through.
///
/// It adds NO network path and NO cache of its own: everything goes through
/// `TafsirService.loadSurah`, which reads the same per-ayah cache the ayah
/// sheet fills and, when a surah is missing, fetches the same per-surah CDN
/// bundle the offline pack download already uses.
///
/// Searching (the reason غريب القرآن exists as its own entry — you remember
/// the word, not the ayah) runs over what is CACHED, and says so: an
/// offline-first app must not turn a keystroke into a download, so the
/// screen states its coverage and offers the one existing pack download.
public struct TafsirBrowserView: View {
    /// `nil` — the tafsir browser: the edition is the user's, chosen here and
    /// remembered in the same `tafsir.edition` default the ayah sheet uses.
    /// Non-nil — a single-purpose entry (the hub's word meanings), which
    /// never shows a picker and never touches that default.
    private let fixedEdition: TafsirEdition?

    public init(edition: TafsirEdition? = nil) {
        self.fixedEdition = edition
    }

    @AppStorage("tafsir.edition") private var editionSlug = TafsirEdition.all[0].slug
    @Environment(\.locale) private var locale
    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    @State private var surahs: [Surah] = []
    /// Long-lived so a pack download survives the search field being cleared.
    @State private var service = TafsirService()
    /// Screenshot/UI-test hook: NOOR_TAFSIR_SEARCH=<query> fills the field.
    @State private var searchText = ProcessInfo.processInfo.environment["NOOR_TAFSIR_SEARCH"] ?? ""
    @State private var index: TafsirSearchIndex?
    @State private var results: [TafsirSearchIndex.Hit] = []
    @State private var isIndexing = false
    /// Screenshot/UI-test hook, same family as NOOR_ATHKAR_HIT: opens the
    /// first result of NOOR_TAFSIR_SEARCH so the jump can be captured.
    @State private var pushedHit: TafsirSurahRoute?

    private var edition: TafsirEdition { fixedEdition ?? TafsirEdition.named(editionSlug) }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var body: some View {
        List {
            Section {
                NoorSearchField(text: $searchText,
                                placeholder: fixedEdition == nil
                                    ? Text("Search the tafsir you have")
                                    : Text("Search the word meanings you have"))
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }

            if isSearching {
                coverageSection
                resultsSection
            } else {
                if fixedEdition == nil { editionSection }
                surahSection
            }
        }
        .scrollContentBackground(.hidden)
        .background(NoorColor.bgPrimary)
        .navigationTitle(fixedEdition == nil ? Text("Tafsir") : Text("Quranic word meanings"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(for: TafsirSurahRoute.self) { route in
            // The screen looks its own surah up rather than reading this
            // view's `surahs`: a deep link can push the route before the
            // list has loaded, and that rendered a blank screen.
            TafsirSurahView(surahId: route.surahId, edition: TafsirEdition.named(route.slug),
                            isWordMeanings: fixedEdition != nil, highlightAyah: route.ayah)
        }
        .onAppear {
            if surahs.isEmpty {
                surahs = (try? QuranDatabase().allSurahs()) ?? []
            }
        }
        // Rebuilt when the edition changes and after a pack download lands,
        // so the coverage line and the corpus never lag behind the cache.
        .task(id: indexKey) { await buildIndex() }
        .task(id: searchText) {
            guard isSearching else { results = []; return }
            // Debounced exactly as the Quran search is: one query per pause.
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            results = index?.search(searchText) ?? []
            openFirstHitHook()
        }
        .navigationDestination(item: $pushedHit) { route in
            TafsirSurahView(surahId: route.surahId, edition: TafsirEdition.named(route.slug),
                            isWordMeanings: fixedEdition != nil, highlightAyah: route.ayah)
        }
    }

    private func openFirstHitHook() {
        guard ProcessInfo.processInfo.environment["NOOR_TAFSIR_HIT"] == "1",
              pushedHit == nil, let first = results.first
        else { return }
        pushedHit = TafsirSurahRoute(surahId: first.ref.surah, slug: edition.slug,
                                     ayah: first.ref.ayah)
    }

    /// Identity of the corpus on disk: the edition plus the pack state, whose
    /// transition to `.done` means there is more to index.
    private var indexKey: String {
        "\(edition.slug)#\(service.packState == .done)"
    }

    /// Reads and folds every cached surah of the edition. That is hundreds of
    /// small files and, for a full edition, megabytes of Arabic prose — so it
    /// runs off the main actor and the folded form is kept, never refolded
    /// per keystroke.
    private func buildIndex() async {
        isIndexing = true
        let edition = edition
        let built = await Task.detached(priority: .userInitiated) {
            TafsirSearchIndex.build(edition: edition)
        }.value
        guard !Task.isCancelled else { return }
        index = built
        isIndexing = false
        if isSearching { results = built.search(searchText) }
    }

    // MARK: - Sections

    private var editionSection: some View {
        Section {
            Picker(selection: $editionSlug) {
                ForEach(TafsirEdition.all) { candidate in
                    Text(verbatim: candidate.displayName).tag(candidate.slug)
                }
            } label: {
                Text("Tafsir edition")
            }
            .listRowBackground(Color.clear)
        } footer: {
            Text("Your choice is remembered, and is the same one the ayah sheet uses.")
                .font(NoorFont.caption)
                .foregroundStyle(NoorColor.inkSecondary)
        }
    }

    private var surahSection: some View {
        Section {
            ForEach(surahs) { surah in
                NavigationLink(value: TafsirSurahRoute(surahId: surah.id, slug: edition.slug)) {
                    surahRow(surah)
                }
                .listRowBackground(Color.clear)
            }
        } header: {
            Text("Choose a surah").foregroundStyle(NoorColor.inkSecondary)
        }
    }

    /// How much of the edition the search can actually see, and the one way
    /// to widen it. This is deliberately ABOVE the results: partial coverage
    /// is not a footnote, it is the difference between "this word is not in
    /// the book" and "you have not downloaded that surah yet".
    @ViewBuilder
    private var coverageSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                if let coverage = index?.coverage {
                    Label {
                        Text(verbatim: coverage.summary(arabicUI: isArabicUI))
                    } icon: {
                        Image(systemName: coverage.isComplete
                              ? "checkmark.circle" : "arrow.down.circle.dotted")
                    }
                    .font(NoorFont.caption)
                    .foregroundStyle(coverage.isComplete ? NoorColor.accentPrimary
                                                         : NoorColor.inkSecondary)
                    if !coverage.isComplete {
                        TafsirPackRow(edition: edition, service: service, forSearch: true)
                    }
                } else if isIndexing {
                    Label {
                        Text("Preparing the search…")
                    } icon: {
                        ProgressView()
                    }
                    .font(NoorFont.caption)
                    .foregroundStyle(NoorColor.inkSecondary)
                }
            }
            // `.leading` only — already direction-aware.
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        Section {
            if results.isEmpty, !isIndexing {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No matches")
                        .font(.noorScaled(15, weight: .semibold))
                        .foregroundStyle(NoorColor.inkPrimary)
                    // Never let "nothing found" imply "nothing exists".
                    if index?.coverage.isComplete == false {
                        Text("Only the surahs you have downloaded were searched — the word may still be in the rest.")
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.inkSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }
            ForEach(results) { hit in
                NavigationLink(value: TafsirSurahRoute(surahId: hit.ref.surah,
                                                       slug: edition.slug,
                                                       ayah: hit.ref.ayah)) {
                    SearchResultRow(snippet: hit.snippet,
                                    reference: reference(hit.ref),
                                    isArabic: edition.isArabic)
                }
                .listRowBackground(Color.clear)
            }
        } header: {
            HStack {
                Text("Results").foregroundStyle(NoorColor.inkSecondary)
                Spacer()
                Text(verbatim: isArabicUI ? results.count.arabicIndic : "\(results.count)")
                    .foregroundStyle(NoorColor.inkSecondary)
            }
        }
    }

    /// "سورة البقرة · 2:255" — RLM-prefixed so the mixed Arabic/digits line
    /// lays out as one right-to-left paragraph (as the Quran search does).
    private func reference(_ ref: TafsirRef) -> String {
        let name = surahs.first { $0.id == ref.surah }?.displayName(arabicUI: isArabicUI) ?? ""
        if isArabicUI {
            return "\u{200F}\(name) · \(ref.surah.arabicIndic):\(ref.ayah.arabicIndic)"
        }
        return "\(name) · \(ref.surah):\(ref.ayah)"
    }

    private func surahRow(_ surah: Surah) -> some View {
        HStack(spacing: 12) {
            Text(verbatim: isArabicUI ? surah.id.arabicIndic : "\(surah.id)")
                .font(NoorFont.caption.monospacedDigit())
                .foregroundStyle(NoorColor.accentGold)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: surah.displayName(arabicUI: isArabicUI))
                    .font(.noorScaled(16, weight: .semibold))
                    .foregroundStyle(NoorColor.inkPrimary)
                if isArabicUI {
                    Text(verbatim: "\(surah.ayahCount.arabicIndic) آية")
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.inkSecondary)
                } else {
                    Text("\(surah.ayahCount) ayat")
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.inkSecondary)
                }
            }
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

/// Pushed destination inside the browser. It carries the edition slug so the
/// open surah keeps the edition it was opened with even if the picker moves,
/// and optionally the ayah a search result pointed at.
public struct TafsirSurahRoute: Hashable, Sendable {
    let surahId: Int
    let slug: String
    let ayah: Int?

    /// Public so a host can deep-link straight into one surah (the
    /// screenshot hook does; a "tafsir of this surah" link could later).
    public init(surahId: Int, slug: String, ayah: Int? = nil) {
        self.surahId = surahId
        self.slug = slug
        self.ayah = ayah
    }
}

/// One surah's tafsir, ayah after ayah, as a continuous screen.
///
/// Public so the Learn hub's search can push straight at one ayah of one
/// edition without going through the surah list first.
public struct TafsirSurahView: View {
    let surahId: Int
    let edition: TafsirEdition
    /// Word-meaning editions gloss only the ayat that need it, so their gaps
    /// are expected and the screen says so instead of looking broken.
    let isWordMeanings: Bool
    /// Ayah to scroll to on open — where a search result landed.
    let highlightAyah: Int?

    public init(surahId: Int, edition: TafsirEdition, isWordMeanings: Bool = false,
                highlightAyah: Int? = nil) {
        self.surahId = surahId
        self.edition = edition
        self.isWordMeanings = isWordMeanings
        self.highlightAyah = highlightAyah
    }

    @Environment(\.locale) private var locale
    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    @State private var service = TafsirService()
    @State private var surah: Surah?
    /// Screenshot/UI-test hook: NOOR_TAFSIR_SURAH_SEARCH=<query> opens the
    /// within-surah field already filled.
    @State private var searchText =
        ProcessInfo.processInfo.environment["NOOR_TAFSIR_SURAH_SEARCH"] ?? ""
    @State private var showSearch =
        ProcessInfo.processInfo.environment["NOOR_TAFSIR_SURAH_SEARCH"] != nil
    /// This surah's entries, folded once when they load — searching inside
    /// one surah never refolds per keystroke.
    @State private var corpus = FoldedCorpus<Int>()
    @State private var matches: [Int: ArabicSearch.Snippet] = [:]
    @State private var order: [Int] = []
    @State private var flashedAyah: Int?
    @State private var didScrollToHighlight = false

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    content(proxy: proxy)
                }
                .padding(20)
                // A 13-inch iPad would otherwise run tafsir prose edge to
                // edge; the column stays a readable measure and centres.
                .noorReadableWidth()
                // Clears the floating tab bar the Quran tab draws over the page.
                .padding(.bottom, 80)
            }
            // The jump waits for the entries: scrolling before they exist
            // targets a row that has not been built, which silently left the
            // screen at the top of the surah.
            .onChange(of: service.surahState, initial: true) { _, state in
                guard case .ready = state, let ayah = highlightAyah,
                      !didScrollToHighlight else { return }
                didScrollToHighlight = true
                flashedAyah = ayah
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    withAnimation { proxy.scrollTo(ayah, anchor: .top) }
                }
            }
        }
        .background(NoorColor.bgPrimary)
        .safeAreaInset(edge: .top) {
            if showSearch {
                NoorSearchField(text: $searchText, placeholder: Text("Search this surah"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(NoorColor.bgPrimary)
            }
        }
        .navigationTitle(Text(verbatim: surah?.displayName(arabicUI: isArabicUI) ?? ""))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showSearch.toggle()
                    if !showSearch { searchText = "" }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Search this surah")
            }
        }
        .onAppear {
            if surah == nil {
                surah = (try? QuranDatabase().allSurahs())?.first { $0.id == surahId }
            }
        }
        .task(id: edition.slug) {
            await service.loadSurah(edition: edition, surah: surahId)
        }
        .onChange(of: service.surahState) { _, state in
            guard case .ready(let entries) = state else { return }
            corpus = FoldedCorpus(documents: entries.map {
                FoldedCorpus<Int>.Document(key: $0.ayah, text: $0.text)
            })
        }
        .task(id: searchText) {
            guard isSearching else { matches = [:]; order = []; return }
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            let hits = corpus.search(searchText, limit: 300)
            matches = Dictionary(hits.map { ($0.key, $0.snippet) }, uniquingKeysWith: { first, _ in first })
            order = hits.map(\.key)
        }
    }

    @ViewBuilder
    private func content(proxy: ScrollViewProxy) -> some View {
        switch service.surahState {
        case .idle:
            ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
        case .downloading:
            VStack(spacing: 10) {
                ProgressView()
                Text("Downloading this surah's tafsir…")
                    .font(NoorFont.caption)
                    .foregroundStyle(NoorColor.inkSecondary)
                Text("It is kept on the device, so this surah opens offline next time.")
                    .font(NoorFont.caption)
                    .foregroundStyle(NoorColor.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        case .ready(let entries) where entries.isEmpty:
            ContentUnavailableView {
                Label("Tafsir", systemImage: "text.book.closed")
            } description: {
                Text("This edition has nothing for this surah.")
            }
            .padding(.top, 30)
        case .ready(let entries):
            if isSearching {
                searchResults(entries: entries, proxy: proxy)
            } else {
                if isWordMeanings {
                    Text("Only the ayat with words worth glossing appear here.")
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.inkSecondary)
                }
                LazyVStack(alignment: .leading, spacing: 22) {
                    ForEach(entries) { entry in
                        entryView(entry).id(entry.ayah)
                    }
                }
                footer(count: entries.count)
            }
        case .failed(let message):
            ContentUnavailableView {
                Label("Tafsir unavailable", systemImage: "wifi.slash")
            } description: {
                Text("Check your connection and try again. (\(message))")
            }
            .padding(.top, 30)
        }
    }

    /// Matching ayat of THIS surah — the whole surah is on the device, so
    /// there is no coverage caveat here; the caveat belongs to the
    /// edition-wide search, which can only see downloaded surahs.
    @ViewBuilder
    private func searchResults(entries: [TafsirService.Entry], proxy: ScrollViewProxy) -> some View {
        if order.isEmpty {
            Text("No matches in this surah")
                .font(NoorFont.caption)
                .foregroundStyle(NoorColor.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 20)
        } else {
            countLine(order.count, of: entries.count)
                .font(NoorFont.caption)
                .foregroundStyle(NoorColor.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(order, id: \.self) { ayah in
                    if let snippet = matches[ayah] {
                        Button {
                            searchText = ""
                            showSearch = false
                            flashedAyah = ayah
                            withAnimation { proxy.scrollTo(ayah, anchor: .top) }
                        } label: {
                            SearchResultRow(snippet: snippet,
                                            reference: ayahReference(ayah),
                                            isArabic: edition.isArabic)
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(NoorColor.inkPrimary.opacity(0.06))
                    }
                }
            }
        }
    }

    /// Arabic-Indic numerals in the Arabic interface, as everywhere else.
    @ViewBuilder
    private func countLine(_ found: Int, of total: Int) -> some View {
        if isArabicUI {
            Text(verbatim: "\(found.arabicIndic) من \(total.arabicIndic) آية")
        } else {
            Text("\(found) of \(total) ayat")
        }
    }

    private func ayahReference(_ ayah: Int) -> String {
        isArabicUI ? "\u{200F}\(surahId.arabicIndic):\(ayah.arabicIndic)" : "\(surahId):\(ayah)"
    }

    private func entryView(_ entry: TafsirService.Entry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            entryHeader(entry)

            // One Text per paragraph: a single multi-thousand-character
            // Arabic string hits a SwiftUI layout path that drops shaping
            // and bidi (seen with Ibn Kathir 3:7).
            ForEach(Array(paragraphs(of: entry.text).enumerated()), id: \.offset) { _, paragraph in
                paragraphView(paragraph)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(flashedAyah == entry.ayah
                    ? NoorColor.accentPrimary.opacity(0.10) : Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Ayah \(entry.ayah)"))
    }

    /// The ayah marker labels the prose under it, so it takes the EDITION's
    /// direction, never the interface's: an Arabic edition is an
    /// `arabicBlock` (right-anchored whatever the UI language), and a plain
    /// `.leading` header stranded the marker against the LEFT edge in the
    /// English interface above right-aligned Arabic tafsir — verified on a
    /// 13-inch iPad. `arabicBlock` is the right tool here (its doc says so
    /// for exactly this badge-beside-Arabic case); `isArabicUI ? .trailing
    /// : .leading` is NOT — inside an RTL environment it flips twice.
    @ViewBuilder
    private func entryHeader(_ entry: TafsirService.Entry) -> some View {
        let row = HStack(spacing: 8) {
            AyahEndMarker(entry.ayah, size: 26)
            Text(verbatim: ayahReference(entry.ayah))
                .font(NoorFont.caption.monospacedDigit())
                .foregroundStyle(NoorColor.inkSecondary)
        }
        if edition.isArabic {
            row.arabicBlock()
        } else {
            row.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The deliberate serif of `NoorFont.tafsir` (design §3) in both scripts;
    /// Arabic is an `arabicBlock` so it stays right-anchored even in the
    /// English interface, and is `Text(verbatim:)` — tafsir must never go
    /// through a localisation lookup.
    @ViewBuilder
    private func paragraphView(_ paragraph: String) -> some View {
        if edition.isArabic {
            Text(verbatim: paragraph)
                .font(NoorFont.tafsir)
                .foregroundStyle(NoorColor.inkPrimary)
                .lineSpacing(9)
                .textSelection(.enabled)
                .arabicBlock()
        } else {
            Text(verbatim: paragraph)
                .font(NoorFont.tafsir)
                .foregroundStyle(NoorColor.inkPrimary)
                .lineSpacing(6)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    private func paragraphs(of text: String) -> [String] {
        let parts = text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? [text] : parts
    }

    @ViewBuilder
    private func footer(count: Int) -> some View {
        VStack(spacing: 4) {
            Label("Available offline", systemImage: "checkmark.circle")
                .font(NoorFont.caption)
                .foregroundStyle(NoorColor.accentPrimary)
            if isArabicUI {
                Text(verbatim: "\(edition.displayName) · \(count.arabicIndic)")
            } else {
                Text(verbatim: "\(edition.displayName) · \(count)")
            }
        }
        .font(NoorFont.caption)
        .foregroundStyle(NoorColor.inkSecondary)
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }
}

#Preview("Tafsir browser — AR RTL") {
    NavigationStack { TafsirBrowserView() }
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Word meanings — EN LTR") {
    NavigationStack { TafsirBrowserView(edition: .gharib) }
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.layoutDirection, .leftToRight)
}
