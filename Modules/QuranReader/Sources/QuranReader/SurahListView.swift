import ContentDB
import DesignSystem
import SwiftUI

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
    /// Opens the reader at an exact reference (used by the Juz tab).
    let openReference: (_ surahId: Int, _ ayah: Int) -> Void

    @State private var searchText = ""
    @State private var tab: IndexTab = .surah

    public init(
        surahs: [Surah],
        structure: QuranStructure?,
        selection: Binding<Int?>,
        openReference: @escaping (_ surahId: Int, _ ayah: Int) -> Void
    ) {
        self.surahs = surahs
        self.structure = structure
        _selection = selection
        self.openReference = openReference
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
                List(filtered, selection: $selection) { surah in
                    SurahRow(surah: surah)
                        .tag(surah.id)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .searchable(text: $searchText, prompt: Text("Surah name or 2:255"))
            case .juz:
                juzList
            case .bookmarks:
                ContentUnavailableView {
                    Label("Bookmarks", systemImage: "bookmark")
                        .foregroundStyle(NoorColor.inkSecondary)
                } description: {
                    Text("Your bookmarks will gather here.")
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

    private func referenceLabel(_ start: DivisionStart) -> String {
        let name = surahs.first { $0.id == start.surahId }?.nameTransliterated ?? "\(start.surahId)"
        return "\(name) · \(start.surahId):\(start.ayah)"
    }
}

struct SurahRow: View {
    let surah: Surah

    var body: some View {
        HStack(spacing: 12) {
            SurahNumberBadge(surah.id)

            VStack(alignment: .leading, spacing: 2) {
                Text(surah.nameTransliterated)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NoorColor.inkPrimary)
                Text("\(surah.nameEnglish) · \(surah.ayahCount) ayat · \(surah.isMeccan ? String(localized: "Makki") : String(localized: "Madani"))")
                    .font(NoorFont.caption)
                    .foregroundStyle(NoorColor.inkSecondary)
            }

            Spacer()

            Text(surah.nameArabic)
                .font(NoorFont.quran(size: 19))
                .foregroundStyle(NoorColor.inkPrimary)
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
