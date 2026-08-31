import ContentDB
import DesignSystem
import SwiftUI

/// Surah index (plan §6.3). Searchable by name, transliteration, or number.
public struct SurahListView: View {
    let surahs: [Surah]
    @Binding var selection: Int?
    @State private var searchText = ""

    public init(surahs: [Surah], selection: Binding<Int?>) {
        self.surahs = surahs
        _selection = selection
    }

    private var filtered: [Surah] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return surahs }
        if let number = Int(query) {
            return surahs.filter { $0.id == number }
        }
        return surahs.filter {
            $0.nameTransliterated.localizedCaseInsensitiveContains(query)
                || $0.nameEnglish.localizedCaseInsensitiveContains(query)
                || $0.nameArabic.contains(query)
        }
    }

    public var body: some View {
        List(filtered, selection: $selection) { surah in
            SurahRow(surah: surah)
                .tag(surah.id)
        }
        .searchable(text: $searchText, prompt: Text("Surah name or number"))
        .navigationTitle(Text("Quran"))
        .scrollContentBackground(.hidden)
        .background(NoorColor.bgPrimary)
    }
}

struct SurahRow: View {
    let surah: Surah

    var body: some View {
        HStack(spacing: 12) {
            Text("\(surah.id)")
                .font(NoorFont.caption.monospacedDigit())
                .foregroundStyle(NoorColor.inkSecondary)
                .frame(width: 32, height: 32)
                .overlay(Circle().stroke(NoorColor.accentGold.opacity(0.5), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(surah.nameTransliterated)
                    .foregroundStyle(NoorColor.inkPrimary)
                Text("\(surah.nameEnglish) · \(surah.ayahCount) ayat · \(surah.isMeccan ? String(localized: "Makki") : String(localized: "Madani"))")
                    .font(NoorFont.caption)
                    .foregroundStyle(NoorColor.inkSecondary)
            }

            Spacer()

            Text(surah.nameArabic)
                .font(NoorFont.quran(size: 20))
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

#Preview("Surah index — AR RTL") {
    if let db = try? QuranDatabase(), let surahs = try? db.allSurahs() {
        NavigationStack {
            SurahListView(surahs: surahs, selection: .constant(1))
        }
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
    }
}
