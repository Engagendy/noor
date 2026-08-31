import ContentDB
import DesignSystem
import SwiftUI

/// Surah index per design 1g: search, segmented tabs, diamond number badge,
/// Arabic calligraphic name trailing. (Juz view and bookmarks fill in with
/// the Library module.)
public struct SurahListView: View {
    enum IndexTab: String, CaseIterable, Identifiable {
        case surah, bookmarks
        var id: String { rawValue }
    }

    let surahs: [Surah]
    @Binding var selection: Int?
    @State private var searchText = ""
    @State private var tab: IndexTab = .surah

    public init(surahs: [Surah], selection: Binding<Int?>) {
        self.surahs = surahs
        _selection = selection
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
            SurahListView(surahs: surahs, selection: .constant(1))
        }
    }
}

#Preview("Surah index — AR RTL dark") {
    if let db = try? QuranDatabase(), let surahs = try? db.allSurahs() {
        NavigationStack {
            SurahListView(surahs: surahs, selection: .constant(1))
        }
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
    }
}
