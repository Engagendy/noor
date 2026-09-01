import DesignSystem
import SwiftUI

/// All bookmarked hadiths, resolved from the Forty (bundled) and any
/// downloaded Sahih.
struct HadithBookmarksView: View {
    let isArabicUI: Bool
    @State private var bookmarks = HadithBookmarks.shared
    @State private var library = HadithLibrary.shared
    @State private var resolved: [Entry] = []
    @State private var selectedForty: HadithItem?
    @State private var selectedSahih: HadithLibrary.SearchHit?
    @Environment(\.locale) private var locale

    struct Entry: Identifiable {
        let key: String
        let title: String
        let arabic: String
        let forty: HadithItem?
        let sahih: HadithLibrary.SearchHit?
        var id: String { key }
    }

    var body: some View {
        List(resolved) { entry in
            Button {
                if let forty = entry.forty { selectedForty = forty }
                if let sahih = entry.sahih { selectedSahih = sahih }
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: entry.arabic)
                        .font(.system(size: 15))
                        .foregroundStyle(NoorColor.inkPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(verbatim: entry.title)
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.accentGold)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .listRowBackground(Color.clear)
            .swipeActions {
                Button(role: .destructive) {
                    bookmarks.toggle(entry.key)
                    resolved.removeAll { $0.key == entry.key }
                } label: {
                    Image(systemName: "bookmark.slash")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(NoorColor.bgPrimary)
        .environment(\.layoutDirection, .rightToLeft)
        .navigationTitle(Text(verbatim: isArabicUI ? "المحفوظات" : "Bookmarked"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .overlay {
            if resolved.isEmpty { ProgressView() }
        }
        .task { await resolve() }
        .sheet(item: $selectedForty) { hadith in
            HadithDetailView(hadith: hadith, isArabicUI: isArabicUI)
                .environment(\.locale, locale)
                .environment(\.layoutDirection, isArabicUI ? .rightToLeft : .leftToRight)
        }
        .sheet(item: $selectedSahih) { hit in
            LibraryHadithDetail(hadiths: [hit.hadith], initialId: hit.hadith.id,
                                collection: hit.collection,
                                bookTitle: hit.bookTitle, isArabicUI: isArabicUI)
                .environment(\.locale, locale)
                .environment(\.layoutDirection, isArabicUI ? .rightToLeft : .leftToRight)
        }
    }

    private func resolve() async {
        var entries: [Entry] = []
        let forty = HadithStore.load()
        for key in bookmarks.keys.sorted() {
            let parts = key.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let (source, number) = (parts[0], parts[1])
            if let collection = HadithCollectionID(rawValue: source) {
                guard library.states[collection] == .ready,
                      let found = await library.lookup(collection: collection, number: number)
                else { continue }
                let bookTitle = isArabicUI ? found.bookAr : found.bookEn
                entries.append(Entry(
                    key: key,
                    title: isArabicUI
                        ? "\(collection.arabicName) · \(bookTitle) · \(number)"
                        : "\(collection.englishName) · \(bookTitle) · \(number)",
                    arabic: found.hadith.arabic,
                    forty: nil,
                    sahih: HadithLibrary.SearchHit(
                        collection: collection, bookTitle: bookTitle, hadith: found.hadith)))
            } else if let hadith = forty.first(where: {
                $0.collection == source && String($0.number) == number
            }) {
                entries.append(Entry(
                    key: key,
                    title: isArabicUI
                        ? "\(hadith.collectionArabic) · \(number)"
                        : "\(hadith.collectionEnglish) · \(number)",
                    arabic: hadith.arabic,
                    forty: hadith,
                    sahih: nil))
            }
        }
        resolved = entries
    }
}
