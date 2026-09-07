import ContentDB
import DesignSystem
import SwiftUI

/// App-layer bookmark value (QuranReader must not import the Library module).
public struct BookmarkRef: Identifiable, Hashable, Sendable {
    public let surahId: Int
    public let ayah: Int
    public let createdAt: Date

    public var id: String { "\(surahId):\(ayah)" }

    public init(surahId: Int, ayah: Int, createdAt: Date) {
        self.surahId = surahId
        self.ayah = ayah
        self.createdAt = createdAt
    }
}

/// Surah index per design 1g: search, segmented Surah/Juz/Bookmarks tabs,
/// diamond number badge, Arabic calligraphic name trailing.
public struct SurahListView: View {
    enum IndexTab: String, CaseIterable, Identifiable {
        case surah, juz, bookmarks
        var id: String { rawValue }
    }

    let surahs: [Surah]
    let structure: QuranStructure?
    @Binding var selection: Int?
    /// Opens the reader at an exact reference (Juz tab + word search).
    let openReference: (_ surahId: Int, _ ayah: Int?) -> Void
    /// Word search over the Quran text (diacritic-insensitive, ranked).
    let searchVerses: (_ query: String) -> VerseSearchResults
    /// Saved bookmarks (provided by the app layer from the Library store).
    let bookmarks: [BookmarkRef]
    let onRemoveBookmark: ((BookmarkRef) -> Void)?
    /// Opens the learning area (matns + tajweed guide). The app layer owns
    /// the destination — QuranReader must not import another feature module.
    let onOpenLearn: (() -> Void)?

    /// Screenshot/UI-test hook: NOOR_SEARCH=<query> opens with the field filled.
    @State private var searchText = ProcessInfo.processInfo.environment["NOOR_SEARCH"] ?? ""
    @State private var tab: IndexTab = .surah
    /// Ranked ayah hits for the current query (recomputed off the keystroke
    /// path by the debounced `.task` below, never inside `body`).
    @State private var verseResults = VerseSearchResults.empty
    /// How many hits are on screen; "Show more" reveals the next page rather
    /// than dropping the rest on the floor.
    @State private var shownHits = Self.hitPage
    private static let hitPage = 40
    @Environment(\.locale) private var locale

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    public init(
        surahs: [Surah],
        structure: QuranStructure?,
        selection: Binding<Int?>,
        openReference: @escaping (_ surahId: Int, _ ayah: Int?) -> Void,
        searchVerses: @escaping (_ query: String) -> VerseSearchResults = { _ in .empty },
        bookmarks: [BookmarkRef] = [],
        onRemoveBookmark: ((BookmarkRef) -> Void)? = nil,
        onOpenLearn: (() -> Void)? = nil
    ) {
        self.surahs = surahs
        self.structure = structure
        _selection = selection
        self.openReference = openReference
        self.searchVerses = searchVerses
        self.bookmarks = bookmarks
        self.onRemoveBookmark = onRemoveBookmark
        self.onOpenLearn = onOpenLearn
    }

    /// Preview seam: opens with the search field already filled.
    init(surahs: [Surah], structure: QuranStructure?,
         searchVerses: @escaping (_ query: String) -> VerseSearchResults,
         query: String) {
        self.init(surahs: surahs, structure: structure, selection: .constant(nil),
                  openReference: { _, _ in }, searchVerses: searchVerses)
        _searchText = State(initialValue: query)
    }

    private var query: String { searchText.trimmingCharacters(in: .whitespaces) }

    /// "2:255", "2 255", "٢:٢٥٥"… — a reference, not a name search.
    private var reference: QuranReference? {
        guard let parsed = QuranReference.parse(query, surahCount: surahs.count),
              let surah = surahs.first(where: { $0.id == parsed.surahId })
        else { return nil }
        guard let ayah = parsed.ayah else { return parsed }
        // An out-of-range ayah still opens the surah.
        return ayah <= surah.ayahCount ? parsed : QuranReference(surahId: parsed.surahId, ayah: nil)
    }

    /// Surahs matching the query by Arabic name, transliteration, English
    /// meaning or number — best matches first (see `SurahSearch`).
    private var filtered: [Surah] {
        SurahSearch.matches(surahs, query: query)
    }

    public var body: some View {
        Group {
            switch tab {
            case .surah:
                List(selection: $selection) {
                    // "2:255" typed in full: one row that opens that ayah.
                    if let reference, let ayah = reference.ayah {
                        Button {
                            openReference(reference.surahId, ayah)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.turn.down.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(NoorColor.accentPrimary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Go to ayah")
                                        .font(.noorScaled(15, weight: .semibold))
                                        .foregroundStyle(NoorColor.inkPrimary)
                                    Text(verbatim: "\(surahName(reference.surahId)) · \(reference.surahId):\(ayah)")
                                        .font(NoorFont.caption)
                                        .foregroundStyle(NoorColor.inkSecondary)
                                }
                                Spacer()
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .listRowBackground(Color.clear)
                    }
                    ForEach(filtered) { surah in
                        Button {
                            openReference(surah.id, nil)
                        } label: {
                            SurahRow(surah: surah)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .tag(surah.id)
                        .listRowBackground(Color.clear)
                    }
                    ayatSection
                }
                .listStyle(.plain)
            case .juz:
                juzList
            case .bookmarks:
                if bookmarks.isEmpty {
                    ContentUnavailableView {
                        Label("Bookmarks", systemImage: "bookmark")
                            .foregroundStyle(NoorColor.inkSecondary)
                    } description: {
                        Text("Your bookmarks will gather here.")
                    }
                } else {
                    List {
                        ForEach(bookmarks) { bookmark in
                            Button {
                                openReference(bookmark.surahId, bookmark.ayah)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "bookmark.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(NoorColor.accentGold)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(verbatim: "\(surahName(bookmark.surahId)) · \(bookmark.surahId):\(bookmark.ayah)")
                                            .font(.noorScaled(15, weight: .semibold))
                                            .foregroundStyle(NoorColor.inkPrimary)
                                        Text(verbatim: bookmark.createdAt.formatted(date: .abbreviated, time: .omitted))
                                            .font(NoorFont.caption)
                                            .foregroundStyle(NoorColor.inkSecondary)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .listRowBackground(Color.clear)
                        }
                        .onDelete { offsets in
                            for offset in offsets { onRemoveBookmark?(bookmarks[offset]) }
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
            // Custom heading: the system large title never renders above a
            // top safe-area inset in a compact stack.
            HStack(alignment: .firstTextBaseline) {
                Text("Quran")
                    .font(NoorFont.screenTitle)
                    .foregroundStyle(NoorColor.inkPrimary)
                Spacer(minLength: 8)
                // Entry to the learning area. A labelled pill beside the
                // title, not a fourth segment: the segmented control is an
                // *index of the mushaf* (Surah / Juz / Bookmarks) and a
                // "Learn" tab there would neither be an index nor survive
                // the Arabic label widths.
                if let onOpenLearn {
                    Button(action: onOpenLearn) {
                        HStack(spacing: 6) {
                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Learn")
                                .font(.noorScaled(14, weight: .semibold))
                        }
                        .foregroundStyle(NoorColor.accentPrimary)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 34)
                        .background(
                            Capsule().fill(NoorColor.accentPrimary.opacity(0.12)))
                        .frame(minHeight: 44)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Learn")
                    .accessibilityHint("Tajweed guide and memorisation texts")
                }
            }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            // Our own search field — the system one lives in the (hidden)
            // navigation bar and caused overlay/back-button conflicts.
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundStyle(NoorColor.inkSecondary)
                // Custom placeholder: the system one anchors to the
                // process language and ignores the RTL environment.
                TextField("", text: $searchText)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .leading) {
                        if searchText.isEmpty {
                            Text("Surah, word, or 2:255")
                                .foregroundStyle(NoorColor.inkSecondary.opacity(0.8))
                                .allowsHitTesting(false)
                        }
                    }
                    .accessibilityLabel("Search")
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(NoorColor.inkSecondary)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 12).fill(NoorColor.bgElevated))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(NoorColor.inkPrimary.opacity(0.08), lineWidth: 1))
            .padding(.horizontal, 16)
            Picker(selection: $tab) {
                Text("Surah").tag(IndexTab.surah)
                Text("Juz").tag(IndexTab.juz)
                Text("Bookmarks").tag(IndexTab.bookmarks)
            } label: {
                Text("Section")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            }
            .padding(.bottom, 8)
            .background(NoorColor.bgPrimary)
        }
        .scrollContentBackground(.hidden)
        .background(NoorColor.bgPrimary)
        // Debounced so a fast typist runs one query, not one per keystroke.
        .task(id: searchText) {
            shownHits = Self.hitPage
            guard query.count >= 2, reference == nil else {
                verseResults = .empty
                return
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            verseResults = searchVerses(query)
        }
    }

    /// Ranked ayah hits: whole-word matches first, then word-prefix, then
    /// mid-word, mushaf order inside each tier. Each row shows the ayah
    /// windowed on the match with the matched run emphasised.
    @ViewBuilder
    private var ayatSection: some View {
        if !verseResults.hits.isEmpty {
            Section {
                ForEach(verseResults.hits.prefix(shownHits)) { hit in
                    Button {
                        openReference(hit.surahId, hit.ayah)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            if let snippet = hit.snippet {
                                HighlightedSnippet(
                                    before: snippet.before,
                                    match: snippet.match,
                                    after: snippet.after,
                                    truncatedStart: snippet.truncatedStart,
                                    truncatedEnd: snippet.truncatedEnd,
                                    font: NoorFont.quran(size: 17))
                                    .lineLimit(2)
                                    .arabicBlock()
                            } else {
                                Text(verbatim: hit.text)
                                    .font(NoorFont.quran(size: 17))
                                    .foregroundStyle(NoorColor.inkPrimary)
                                    .lineLimit(2)
                                    .arabicBlock()
                            }
                            Text(verbatim: "\u{200F}\(surahName(hit.surahId)) · \(hit.surahId):\(hit.ayah)")
                                .font(NoorFont.caption)
                                .foregroundStyle(NoorColor.inkSecondary)
                        }
                        .arabicBlock()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .listRowBackground(Color.clear)
                }
                // Nothing is dropped silently: the rest is one tap away, and
                // if the DB cap was reached we say so.
                if verseResults.hits.count > shownHits {
                    Button {
                        shownHits += Self.hitPage
                    } label: {
                        Text("Show more results")
                            .font(.noorScaled(15, weight: .semibold))
                            .foregroundStyle(NoorColor.accentPrimary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .listRowBackground(Color.clear)
                } else if verseResults.truncated {
                    Text("Showing the first \(verseResults.cap) matches — refine your search.")
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                }
            } header: {
                HStack {
                    Text("Ayat").foregroundStyle(NoorColor.inkSecondary)
                    Spacer()
                    Text(verbatim: "\(verseResults.hits.count)\(verseResults.truncated ? "+" : "")")
                        .foregroundStyle(NoorColor.inkSecondary)
                }
            }
        }
    }

    @State private var expandedJuz: Set<Int> = []

    /// 30 ajza, each expandable to its 8 hizb quarters (ربع الحزب).
    /// Tapping the row opens the reader; the chevron expands the quarters.
    private var juzList: some View {
        List {
            if let structure {
                ForEach(structure.juzStarts, id: \.idx) { juz in
                    juzRow(juz)
                        .listRowBackground(Color.clear)
                    if expandedJuz.contains(juz.idx) {
                        ForEach(quarters(inJuz: juz.idx, structure: structure), id: \.idx) { quarter in
                            quarterRow(quarter)
                                .listRowBackground(Color.clear)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func quarters(inJuz juz: Int, structure: QuranStructure) -> [DivisionStart] {
        let range = ((juz - 1) * 8 + 1)...(juz * 8)
        return structure.quarterStarts.filter { range.contains($0.idx) }
    }

    private func juzRow(_ juz: DivisionStart) -> some View {
        HStack(spacing: 12) {
            Button {
                openReference(juz.surahId, juz.ayah)
            } label: {
                HStack(spacing: 12) {
                    SurahNumberBadge(juz.idx)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Juz \(juz.idx)")
                            .font(.noorScaled(16, weight: .semibold))
                            .foregroundStyle(NoorColor.inkPrimary)
                        Text(verbatim: referenceLabel(juz))
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.inkSecondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if expandedJuz.contains(juz.idx) {
                        expandedJuz.remove(juz.idx)
                    } else {
                        expandedJuz.insert(juz.idx)
                    }
                }
            } label: {
                Image(systemName: expandedJuz.contains(juz.idx) ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NoorColor.accentPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Hizb quarters")
        }
    }

    private func quarterRow(_ quarter: DivisionStart) -> some View {
        let position = QuranStructure.quarterDescription(quarter.idx)
        return Button {
            openReference(quarter.surahId, quarter.ayah)
        } label: {
            HStack(spacing: 10) {
                Text(verbatim: "۞")
                    .font(.noorScaled(15))
                    .foregroundStyle(NoorColor.accentGold)
                Text(quarterName(position.quarterInHizb))
                    .font(.noorScaled(14))
                    .foregroundStyle(NoorColor.inkPrimary)
                Text("Hizb \(position.hizb)")
                    .font(NoorFont.caption)
                    .foregroundStyle(NoorColor.inkSecondary)
                Spacer()
                Text(verbatim: referenceLabel(quarter))
                    .font(NoorFont.caption)
                    .foregroundStyle(NoorColor.inkSecondary)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }

    private func quarterName(_ quarterInHizb: Int) -> LocalizedStringKey {
        switch quarterInHizb {
        case 2: "¼ Hizb"
        case 3: "½ Hizb"
        case 4: "¾ Hizb"
        default: "Hizb start"
        }
    }

    private func surahName(_ id: Int) -> String {
        surahs.first { $0.id == id }?.displayName(arabicUI: isArabicUI) ?? "\(id)"
    }

    private func referenceLabel(_ start: DivisionStart) -> String {
        "\(surahName(start.surahId)) · \(start.surahId):\(start.ayah)"
    }
}

struct SurahRow: View {
    let surah: Surah
    @Environment(\.locale) private var locale

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    var body: some View {
        HStack(spacing: 12) {
            SurahNumberBadge(surah.id)

            VStack(alignment: .leading, spacing: 2) {
                if isArabicUI {
                    Text(verbatim: surah.nameArabic)
                        .font(NoorFont.quran(size: 18))
                        .foregroundStyle(NoorColor.inkPrimary)
                    Text(verbatim: "\(surah.ayahCount.arabicIndic) آية · \(surah.isMeccan ? "مكية" : "مدنية")")
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.inkSecondary)
                } else {
                    Text(verbatim: surah.nameTransliterated)
                        .font(.noorScaled(16, weight: .semibold))
                        .foregroundStyle(NoorColor.inkPrimary)
                    Text("\(surah.nameEnglish) · \(surah.ayahCount) ayat · \(surah.isMeccan ? String(localized: "Makki", locale: locale) : String(localized: "Madani", locale: locale))")
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.inkSecondary)
                }
            }

            Spacer()

            if !isArabicUI {
                Text(verbatim: surah.nameArabic)
                    .font(NoorFont.quran(size: 19))
                    .foregroundStyle(NoorColor.inkPrimary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(surah.id), \(surah.nameTransliterated), \(surah.ayahCount) ayat")
    }
}

#Preview("Surah index") {
    if let db = try? QuranDatabase(), let surahs = try? db.allSurahs() {
        NavigationStack {
            SurahListView(
                surahs: surahs,
                structure: try? db.structure(),
                selection: .constant(1),
                openReference: { _, _ in })
        }
    }
}

#Preview("Surah index — EN LTR, ayah search") {
    if let db = try? QuranDatabase(), let surahs = try? db.allSurahs() {
        NavigationStack {
            SurahListView(
                surahs: surahs,
                structure: try? db.structure(),
                selection: .constant(1),
                openReference: { _, _ in })
        }
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.layoutDirection, .leftToRight)
    }
}

#Preview("Surah search — EN LTR, ranked word hits") {
    if let db = try? QuranDatabase(), let surahs = try? db.allSurahs() {
        NavigationStack {
            SurahListView(
                surahs: surahs,
                structure: try? db.structure(),
                searchVerses: { (try? db.searchVerseResults($0)) ?? .empty },
                query: "Cow")
        }
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.layoutDirection, .leftToRight)
    }
}

#Preview("Surah search — AR RTL, reference") {
    if let db = try? QuranDatabase(), let surahs = try? db.allSurahs() {
        NavigationStack {
            SurahListView(
                surahs: surahs,
                structure: try? db.structure(),
                searchVerses: { (try? db.searchVerseResults($0)) ?? .empty },
                query: "٢:٢٥٥")
        }
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
    }
}

#Preview("Surah index — AR RTL dark") {
    if let db = try? QuranDatabase(), let surahs = try? db.allSurahs() {
        NavigationStack {
            SurahListView(
                surahs: surahs,
                structure: try? db.structure(),
                selection: .constant(1),
                openReference: { _, _ in })
        }
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
    }
}
