import DesignSystem
import SwiftUI

/// The Hadith tab: the two Sahihs (offline packs) + the Forty collections.
struct HadithTab: View {
    @State private var library = HadithLibrary()
    @State private var forty: [HadithItem] = []
    @State private var selected: HadithItem?
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
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(NoorColor.bgPrimary)
        .environment(\.layoutDirection, .rightToLeft)
        .navigationTitle(Text("Hadith"))
        .task {
            if forty.isEmpty { forty = HadithStore.load() }
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
        .environment(\.layoutDirection, .rightToLeft)
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
