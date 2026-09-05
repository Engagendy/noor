import DesignSystem
import SwiftUI

/// The Hadith tab: the two Sahihs (offline packs) + the Forty collections.
struct HadithTab: View {
    @State private var library = HadithLibrary.shared
    @State private var bookmarks = HadithBookmarks.shared
    @State private var forty: [HadithItem] = []
    @State private var selected: HadithItem?
    @State private var searchText = ""
    @State private var results: [HadithLibrary.SearchHit] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedHit: HadithLibrary.SearchHit?
    @Environment(\.locale) private var locale

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    private var fortyGroups: [(key: String, title: String, items: [HadithItem])] {
        Dictionary(grouping: forty, by: \.collection)
            .map { (key: $0.key,
                    title: isArabicUI ? $0.value[0].collectionArabic : $0.value[0].collectionEnglish,
                    items: $0.value.sorted { $0.number < $1.number }) }
            .sorted { $0.key > $1.key }
    }

    var body: some View {
        List {
            if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                searchResults
            } else {
            bookmarksSection
            Section {
                ForEach(HadithCollectionID.allCases) { collection in
                    collectionRow(collection)
                        .listRowBackground(Color.clear)
                }
            } header: {
                Text(verbatim: isArabicUI ? "الصحيحان" : "The two Sahihs")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NoorColor.accentPrimary)
            }

            Section {
                ForEach(fortyGroups, id: \.key) { group in
                    NavigationLink {
                        FortyList(title: group.title, items: group.items, isArabicUI: isArabicUI)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "text.book.closed")
                                .font(.system(size: 18))
                                .foregroundStyle(NoorColor.accentGold)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: group.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(NoorColor.inkPrimary)
                                Text(verbatim: isArabicUI
                                     ? "\(group.items.count.arabicIndic) حديثًا"
                                     : "\(group.items.count) hadiths")
                                    .font(NoorFont.caption)
                                    .foregroundStyle(NoorColor.inkSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.clear)
                }
            } header: {
                Text(verbatim: isArabicUI ? "الأربعينات" : "The Forty collections")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NoorColor.accentPrimary)
            }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(NoorColor.bgPrimary)
        .navigationTitle(Text("Hadith"))
        .searchable(text: $searchText,
                    prompt: Text(verbatim: isArabicUI ? "ابحث في كل الأحاديث" : "Search all hadiths"))
        .onChange(of: searchText) { _, query in
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                results = await library.search(query, isArabicUI: isArabicUI)
            }
        }
        .sheet(item: $selectedHit) { hit in
            LibraryHadithDetail(hadiths: [hit.hadith], initialId: hit.hadith.id,
                                collection: hit.collection,
                                bookTitle: hit.bookTitle, isArabicUI: isArabicUI)
                .environment(\.locale, locale)
                .environment(\.layoutDirection, isArabicUI ? .rightToLeft : .leftToRight)
        }
        .task {
            if forty.isEmpty { forty = HadithStore.load() }
        }
    }

    /// Global results across every downloaded collection.
    @ViewBuilder
    private var searchResults: some View {
        Section {
            if results.isEmpty {
                Text(verbatim: isArabicUI
                     ? "لا نتائج — نزّل الصحيحين للبحث فيهما"
                     : "No results — download the Sahihs to search them")
                    .font(.system(size: 14))
                    .foregroundStyle(NoorColor.inkSecondary)
                    .listRowBackground(Color.clear)
            }
            ForEach(results) { hit in
                Button {
                    selectedHit = hit
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: hit.hadith.arabic)
                            .font(.system(size: 15))
                            .foregroundStyle(NoorColor.inkPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .environment(\.layoutDirection, .rightToLeft)
                        Text(verbatim: isArabicUI
                             ? "\(hit.collection.arabicName) · \(hit.bookTitle) · \(hit.hadith.number)"
                             : "\(hit.collection.englishName) · \(hit.bookTitle) · \(hit.hadith.number)")
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.accentGold)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .listRowBackground(Color.clear)
            }
        }
    }

    /// Saved hadiths (any source), resolved lazily against loaded data.
    @ViewBuilder
    private var bookmarksSection: some View {
        if !bookmarks.keys.isEmpty {
            Section {
                NavigationLink {
                    HadithBookmarksView(isArabicUI: isArabicUI)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(NoorColor.accentGold)
                            .frame(width: 30)
                        Text(verbatim: isArabicUI ? "المحفوظات" : "Bookmarked")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(NoorColor.inkPrimary)
                        Spacer()
                        Text(verbatim: isArabicUI
                             ? bookmarks.keys.count.arabicIndic : "\(bookmarks.keys.count)")
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.inkSecondary)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)
            }
        }
    }

    @ViewBuilder
    private func collectionRow(_ collection: HadithCollectionID) -> some View {
        let state = library.states[collection] ?? .notDownloaded
        if state == .ready {
            NavigationLink {
                HadithBooksView(collection: collection, library: library, isArabicUI: isArabicUI)
            } label: {
                sahihRow(collection, state: state)
            }
        } else {
            sahihRow(collection, state: state)
        }
    }

    private func sahihRow(_ collection: HadithCollectionID,
                          state: HadithLibrary.PackState) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.system(size: 19))
                .foregroundStyle(NoorColor.accentGold)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: isArabicUI ? collection.arabicName : collection.englishName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NoorColor.inkPrimary)
                if state != .ready {
                    Text(verbatim: collection.sizeLabel)
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.inkSecondary)
                }
            }
            Spacer()
            switch state {
            case .ready:
                EmptyView()
            case .downloading:
                ProgressView().controlSize(.small)
            case .notDownloaded, .failed:
                Button {
                    Task { await library.download(collection) }
                } label: {
                    Image(systemName: state == .failed ? "arrow.clockwise.circle" : "arrow.down.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(NoorColor.accentPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Download")
            }
        }
        .padding(.vertical, 6)
    }
}

/// One Forty collection pushed inside the tab (no nested stacks).
struct FortyList: View {
    let title: String
    let items: [HadithItem]
    let isArabicUI: Bool
    @State private var selected: HadithItem?
    @Environment(\.locale) private var locale

    var body: some View {
        List(items) { hadith in
            Button {
                selected = hadith
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(verbatim: isArabicUI ? hadith.number.arabicIndic : "\(hadith.number)")
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(NoorColor.accentGold)
                        .frame(width: 30, alignment: .center)
                    Text(verbatim: hadith.arabic)
                        .font(.system(size: 15))
                        .foregroundStyle(NoorColor.inkPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                            .environment(\.layoutDirection, .rightToLeft)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(NoorColor.bgPrimary)
        .navigationTitle(Text(verbatim: title))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(item: $selected) { hadith in
            HadithDetailView(hadith: hadith, isArabicUI: isArabicUI, items: items)
                .environment(\.locale, locale)
                .environment(\.layoutDirection, isArabicUI ? .rightToLeft : .leftToRight)
        }
    }
}
