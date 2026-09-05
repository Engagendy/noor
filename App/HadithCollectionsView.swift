import DesignSystem
import SwiftUI

/// The major collections: download rows → books → hadiths → detail.
struct HadithCollectionsView: View {
    let isArabicUI: Bool
    @State private var library = HadithLibrary()
    @Environment(\.locale) private var locale

    var body: some View {
        List {
            Section {
                ForEach(HadithCollectionID.allCases) { collection in
                    collectionRow(collection)
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(NoorColor.bgPrimary)
        .navigationTitle(Text("Hadith library"))
    }

    @ViewBuilder
    private func collectionRow(_ collection: HadithCollectionID) -> some View {
        let state = library.states[collection] ?? .notDownloaded
        if state == .ready {
            NavigationLink {
                HadithBooksView(collection: collection, library: library, isArabicUI: isArabicUI)
            } label: {
                rowContent(collection, state: state)
            }
        } else {
            rowContent(collection, state: state)
        }
    }

    private func rowContent(_ collection: HadithCollectionID,
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

/// The books (كتب) of one collection.
struct HadithBooksView: View {
    let collection: HadithCollectionID
    let library: HadithLibrary
    let isArabicUI: Bool
    @State private var books: [HadithBook] = []
    @State private var searchText = ""

    private var filtered: [HadithBook] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return books }
        return books.filter {
            $0.arabicTitle.contains(query)
                || $0.englishTitle.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        List(filtered) { book in
            NavigationLink {
                HadithBookView(book: book, collection: collection, isArabicUI: isArabicUI)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(verbatim: isArabicUI ? book.index.arabicIndic : "\(book.index)")
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                        .foregroundStyle(NoorColor.accentGold)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: isArabicUI ? book.arabicTitle : book.englishTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(NoorColor.inkPrimary)
                            .multilineTextAlignment(.leading)
                        Text(verbatim: isArabicUI
                             ? "\(book.count.arabicIndic) حديثًا"
                             : "\(book.count) hadiths")
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.inkSecondary)
                    }
                }
                .padding(.vertical, 2)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(NoorColor.bgPrimary)
        .searchable(text: $searchText, prompt: Text(verbatim: isArabicUI ? "ابحث في الكتب" : "Search books"))
        .navigationTitle(Text(verbatim: isArabicUI ? collection.arabicName : collection.englishName))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .overlay {
            if books.isEmpty { ProgressView() }
        }
        .task {
            books = await library.books(for: collection)
        }
    }
}

/// The hadiths of one book, searchable within.
struct HadithBookView: View {
    let book: HadithBook
    let collection: HadithCollectionID
    let isArabicUI: Bool
    @State private var hadithList: [LibraryHadith] = []
    @State private var searchText = ""
    @State private var selected: LibraryHadith?
    @Environment(\.locale) private var locale

    private var filtered: [LibraryHadith] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return hadithList }
        return hadithList.filter {
            $0.arabic.contains(query)
                || $0.english.localizedCaseInsensitiveContains(query)
                || $0.number == query
        }
    }

    var body: some View {
        List(filtered) { hadith in
            Button {
                selected = hadith
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(verbatim: isArabicUI
                         ? (Int(hadith.number).map(\.arabicIndic) ?? hadith.number)
                         : hadith.number)
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(NoorColor.accentGold)
                        .frame(minWidth: 30, alignment: .center)
                    Text(verbatim: hadith.arabic)
                        .font(.system(size: 15))
                        .foregroundStyle(NoorColor.inkPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: isArabicUI ? .leading : .trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
        .searchable(text: $searchText, prompt: Text(verbatim: isArabicUI ? "ابحث في الأحاديث" : "Search hadiths"))
        .navigationTitle(Text(verbatim: isArabicUI ? book.arabicTitle : book.englishTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            hadithList = await HadithLibrary.shared.hadiths(
                collection: collection, book: book.index)
        }
        .sheet(item: $selected) { hadith in
            LibraryHadithDetail(hadiths: hadithList, initialId: hadith.id,
                                collection: collection,
                                bookTitle: isArabicUI ? book.arabicTitle : book.englishTitle,
                                isArabicUI: isArabicUI)
                .environment(\.locale, locale)
                .environment(\.layoutDirection, isArabicUI ? .rightToLeft : .leftToRight)
        }
    }
}

/// Full text + translation + share; swipe for the previous/next hadith.
struct LibraryHadithDetail: View {
    let hadiths: [LibraryHadith]
    let collection: HadithCollectionID
    let bookTitle: String
    let isArabicUI: Bool
    @State private var index: Int
    @Environment(\.dismiss) private var dismiss
    @State private var sharing = false

    init(hadiths: [LibraryHadith], initialId: String, collection: HadithCollectionID,
         bookTitle: String, isArabicUI: Bool) {
        self.hadiths = hadiths
        self.collection = collection
        self.bookTitle = bookTitle
        self.isArabicUI = isArabicUI
        _index = State(initialValue: hadiths.firstIndex { $0.id == initialId } ?? 0)
    }

    private var hadith: LibraryHadith { hadiths[index] }

    private var reference: String {
        isArabicUI
            ? "\(collection.arabicName) · \(hadith.number)"
            : "\(collection.englishName) · \(hadith.number)"
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $index) {
                ForEach(Array(hadiths.enumerated()), id: \.offset) { i, item in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(verbatim: item.arabic)
                                .font(.noorScaled(18))
                                .foregroundStyle(NoorColor.inkPrimary)
                                .lineSpacing(10)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .environment(\.layoutDirection, .rightToLeft)
                            if !isArabicUI && !item.english.isEmpty {
                                Rectangle()
                                    .fill(NoorColor.accentGold.opacity(0.3))
                                    .frame(height: 0.7)
                                Text(verbatim: item.english)
                                    .font(.noorScaled(15.5))
                                    .foregroundStyle(NoorColor.inkPrimary.opacity(0.9))
                                    .lineSpacing(7)
                            }
                            Text(verbatim: isArabicUI
                                 ? "\(collection.arabicName) · \(item.number) · \(bookTitle)"
                                 : "\(collection.englishName) · \(item.number) · \(bookTitle)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(NoorColor.accentGold)
                        }
                        .padding(20)
                    }
                    .tag(i)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
            .background(NoorColor.bgPrimary)
            .navigationTitle(Text("Hadith"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        sharing = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share")
                }
                ToolbarItem(placement: .primaryAction) {
                    let key = HadithBookmarks.key(
                        collection: collection.rawValue, number: hadith.number)
                    Button {
                        HadithBookmarks.shared.toggle(key)
                    } label: {
                        Image(systemName: HadithBookmarks.shared.isBookmarked(key)
                              ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(NoorColor.accentGold)
                    }
                    .accessibilityLabel("Bookmark")
                }
            }
            .sheet(isPresented: $sharing) {
                NoorShareSheet(
                    arabicText: hadith.arabic,
                    translation: isArabicUI ? nil : (hadith.english.isEmpty ? nil : hadith.english),
                    reference: reference,
                    attribution: "نور Noor",
                    useQuranFont: false)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}
