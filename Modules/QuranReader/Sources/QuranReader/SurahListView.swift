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
    /// Word search over the Quran text (diacritic-insensitive).
    let searchVerses: (_ query: String) -> [SearchHit]
    /// Saved bookmarks (provided by the app layer from the Library store).
    let bookmarks: [BookmarkRef]
    let onRemoveBookmark: ((BookmarkRef) -> Void)?

    @State private var searchText = ""
    @State private var tab: IndexTab = .surah
    @Environment(\.locale) private var locale

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    public init(
        surahs: [Surah],
        structure: QuranStructure?,
        selection: Binding<Int?>,
        openReference: @escaping (_ surahId: Int, _ ayah: Int?) -> Void,
        searchVerses: @escaping (_ query: String) -> [SearchHit] = { _ in [] },
        bookmarks: [BookmarkRef] = [],
        onRemoveBookmark: ((BookmarkRef) -> Void)? = nil
    ) {
        self.surahs = surahs
        self.structure = structure
        _selection = selection
        self.openReference = openReference
        self.searchVerses = searchVerses
        self.bookmarks = bookmarks
        self.onRemoveBookmark = onRemoveBookmark
    }

    private var filtered: [Surah] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return surahs }
        // "2:255"-style reference: jump by surah number.
        let reference = query.split(separator: ":")
        if let first = reference.first, let number = Int(first) {
            return surahs.filter { $0.id == number }
        }
        return surahs.filter {
            $0.nameTransliterated.localizedCaseInsensitiveContains(query)
                || $0.nameEnglish.localizedCaseInsensitiveContains(query)
                || $0.nameArabic.contains(query)
        }
    }

    public var body: some View {
        Group {
            switch tab {
            case .surah:
                List(selection: $selection) {
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
                    // Word search: matching ayat below the surah matches.
                    let hits = searchText.count >= 2 ? searchVerses(searchText) : []
                    if !hits.isEmpty {
                        Section(header: Text("Ayat").foregroundStyle(NoorColor.inkSecondary)) {
                            ForEach(hits) { hit in
                                Button {
                                    openReference(hit.surahId, hit.ayah)
                                } label: {
                                    // Inside forced RTL, .leading == the
                                    // right edge — ayat start from the right.
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(hit.text)
                                            .font(NoorFont.quran(size: 17))
                                            .foregroundStyle(NoorColor.inkPrimary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text(verbatim: "\u{200F}\(surahName(hit.surahId)) · \(hit.surahId):\(hit.ayah)")
                                            .font(NoorFont.caption)
                                            .foregroundStyle(NoorColor.inkSecondary)
                                    }
                                    .environment(\.layoutDirection, .rightToLeft)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.borderless)
                                .listRowBackground(Color.clear)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .searchable(text: $searchText, prompt: Text("Surah, word, or 2:255"))
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
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(NoorColor.inkPrimary)
                                        Text(bookmark.createdAt.formatted(date: .abbreviated, time: .omitted))
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
            Picker(selection: $tab) {
                Text("Surah").tag(IndexTab.surah)
                Text("Juz").tag(IndexTab.juz)
                Text("Bookmarks").tag(IndexTab.bookmarks)
            } label: {
                Text("Section")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(NoorColor.bgPrimary)
        }
        .navigationTitle(Text("Quran"))
        .scrollContentBackground(.hidden)
        .background(NoorColor.bgPrimary)
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
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(NoorColor.inkPrimary)
                        Text(referenceLabel(juz))
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
                    .font(.system(size: 15))
                    .foregroundStyle(NoorColor.accentGold)
                Text(quarterName(position.quarterInHizb))
                    .font(.system(size: 14))
                    .foregroundStyle(NoorColor.inkPrimary)
                Text("Hizb \(position.hizb)")
                    .font(NoorFont.caption)
                    .foregroundStyle(NoorColor.inkSecondary)
                Spacer()
                Text(referenceLabel(quarter))
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
                    Text(surah.nameArabic)
                        .font(NoorFont.quran(size: 18))
                        .foregroundStyle(NoorColor.inkPrimary)
                    Text(verbatim: "\(surah.ayahCount.arabicIndic) آية · \(surah.isMeccan ? "مكية" : "مدنية")")
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.inkSecondary)
                } else {
                    Text(surah.nameTransliterated)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(NoorColor.inkPrimary)
                    Text("\(surah.nameEnglish) · \(surah.ayahCount) ayat · \(surah.isMeccan ? String(localized: "Makki") : String(localized: "Madani"))")
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.inkSecondary)
                }
            }

            Spacer()

            if !isArabicUI {
                Text(surah.nameArabic)
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
