import ContentDB
import DesignSystem
import SwiftUI

/// The app's learning area: the memorisation matns (classical didactic
/// poems) and the tajweed reference guide, in one place reachable from the
/// Quran tab.
///
/// The matn list is driven by `MatnStore`, so another matn (al-Jazariyyah,
/// once a vowelled source is verified) appears here by adding its JSON — no
/// UI change needed. Two ship today: Tuhfat al-Atfal (tajweed) and
/// al-Bayquniyyah (hadith terminology, the companion to the Hadith tab).
public struct LearnView: View {
    public init() {}

    @Environment(\.locale) private var locale
    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    @State private var matns: [Matn] = []

    /// One search over everything the learning area holds. The matns are
    /// bundled and tiny, so they are folded here; tafsir and غريب القرآن are
    /// cached per surah and live in another module, so the host supplies
    /// them through `learnSearchProvider` (CLAUDE.md §4 — features never
    /// import each other).
    @Environment(\.learnSearchProvider) private var searchProvider
    /// Screenshot/UI-test hook: NOOR_LEARN_SEARCH=<query> fills the field.
    @State private var searchText = ProcessInfo.processInfo.environment["NOOR_LEARN_SEARCH"] ?? ""
    @State private var matnIndexes: [(matn: Matn, index: MatnSearchIndex)] = []
    @State private var groups: [LearnSearchGroup] = []
    @State private var isSearchingNow = false

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var body: some View {
        List {
            Section {
                NoorSearchField(text: $searchText,
                                placeholder: Text("Search everything in Learn"))
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
            if isSearching {
                resultGroups
            } else {
                browseSections
            }
        }
        .scrollContentBackground(.hidden)
        .background(NoorColor.bgPrimary)
        .navigationTitle(Text("Learn"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            if matns.isEmpty { matns = MatnStore.load() }
            if matnIndexes.isEmpty {
                matnIndexes = matns.map { ($0, MatnSearchIndex(matn: $0)) }
            }
        }
        .task(id: searchText) {
            guard isSearching else { groups = []; return }
            // Debounced like the Quran search: one query per pause.
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            isSearchingNow = true
            var built = matnGroups(searchText)
            // The provider reads only what is cached — a keystroke never
            // downloads anything (offline-first; widening the corpus is the
            // user's explicit choice, offered inside the group).
            if let searchProvider {
                built += await searchProvider.groups(for: searchText, arabicUI: isArabicUI)
            }
            guard !Task.isCancelled else { return }
            groups = built
            isSearchingNow = false
        }
    }

    /// Matn hits, one group per poem. Bundled whole, so these groups are
    /// complete and carry no coverage caveat.
    private func matnGroups(_ query: String) -> [LearnSearchGroup] {
        matnIndexes.compactMap { entry in
            let hits = entry.index.search(query)
            guard !hits.isEmpty else { return nil }
            return LearnSearchGroup(
                id: "matn.\(entry.matn.id)",
                title: entry.matn.displayTitle(arabicUI: isArabicUI),
                hits: hits.prefix(20).map { hit in
                    LearnSearchHit(
                        id: "\(entry.matn.id)#\(hit.line.number)",
                        snippet: hit.snippet,
                        reference: isArabicUI ? "البيت \(hit.line.number.arabicIndic)"
                                              : "Line \(hit.line.number)",
                        route: .matnLine(id: entry.matn.id, line: hit.line.number))
                },
                totalHits: hits.count)
        }
    }

    /// Results grouped by the work they came from, so it is never a mystery
    /// which book a line is from.
    @ViewBuilder
    private var resultGroups: some View {
        if groups.isEmpty, !isSearchingNow {
            Section {
                Text("No matches in the learning texts")
                    .font(NoorFont.caption)
                    .foregroundStyle(NoorColor.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 20)
                    .listRowBackground(Color.clear)
            }
        }
        ForEach(groups) { group in
            Section {
                if let coverage = group.coverage {
                    Label {
                        Text(verbatim: coverage)
                    } icon: {
                        Image(systemName: group.isComplete
                              ? "checkmark.circle" : "arrow.down.circle.dotted")
                    }
                    .font(NoorFont.caption)
                    .foregroundStyle(group.isComplete ? NoorColor.accentPrimary
                                                      : NoorColor.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowBackground(Color.clear)
                }
                ForEach(group.hits) { hit in
                    if let route = hit.route {
                        NavigationLink(value: route) {
                            SearchResultRow(snippet: hit.snippet, reference: hit.reference,
                                            isArabic: hit.isArabic)
                        }
                        .listRowBackground(Color.clear)
                    } else {
                        SearchResultRow(snippet: hit.snippet, reference: hit.reference,
                                        isArabic: hit.isArabic)
                            .listRowBackground(Color.clear)
                    }
                }
                if group.totalHits > group.hits.count {
                    moreRow(shown: group.hits.count, total: group.totalHits)
                }
                if let footer = group.footer {
                    footer()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowBackground(Color.clear)
                }
            } header: {
                HStack {
                    Text(verbatim: group.title).foregroundStyle(NoorColor.inkSecondary)
                    Spacer()
                    Text(verbatim: isArabicUI ? group.totalHits.arabicIndic
                                              : "\(group.totalHits)")
                        .foregroundStyle(NoorColor.inkSecondary)
                }
            }
        }
    }

    /// Nothing is dropped silently — the group says how many it is showing.
    private func moreRow(shown: Int, total: Int) -> some View {
        Group {
            if isArabicUI {
                Text(verbatim: "تعرض \(shown.arabicIndic) من \(total.arabicIndic) — تابع البحث داخل النص")
            } else {
                Text("Showing \(shown) of \(total) — open the text to see the rest")
            }
        }
        .font(NoorFont.caption)
        .foregroundStyle(NoorColor.inkSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var browseSections: some View {
            Section {
                ForEach(matns) { matn in
                    NavigationLink(value: LearnRoute.matn(matn.id)) {
                        matnRow(matn)
                    }
                    .listRowBackground(Color.clear)
                }
            } header: {
                Text("Memorisation texts").foregroundStyle(NoorColor.inkSecondary)
            } footer: {
                Text("Classical poems students memorise: tajweed, and the terms of hadith.")
                    .font(NoorFont.caption)
                    .foregroundStyle(NoorColor.inkSecondary)
            }

            Section {
                NavigationLink(value: LearnRoute.tajweed) {
                    referenceRow(icon: "character.book.closed",
                                 title: Text("Tajweed Guide"),
                                 subtitle: Text("Pause marks, mushaf symbols and the letter rules."))
                }
                .listRowBackground(Color.clear)
                // Tafsir used to be reachable only by tapping one ayah in the
                // reader — no way to read a surah through.
                NavigationLink(value: LearnRoute.tafsir(.browse)) {
                    referenceRow(icon: "book.pages",
                                 title: Text("Tafsir by surah"),
                                 subtitle: Text("Pick a surah and read its tafsir ayah by ayah."))
                }
                .listRowBackground(Color.clear)
                // Its own entry, not an edition buried in a picker: this is
                // what someone wants when a word in the ayah is the problem.
                NavigationLink(value: LearnRoute.tafsir(.wordMeanings)) {
                    referenceRow(icon: "text.magnifyingglass",
                                 title: Text("Quranic word meanings"),
                                 subtitle: Text("The words in the Quran that are hard to understand."))
                }
                .listRowBackground(Color.clear)
            } header: {
                Text("Reference").foregroundStyle(NoorColor.inkSecondary)
            }
    }

    private func referenceRow(icon: String, title: Text, subtitle: Text) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(NoorColor.accentGold)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(.noorScaled(16, weight: .semibold))
                    .foregroundStyle(NoorColor.inkPrimary)
                subtitle
                    .font(NoorFont.caption)
                    .foregroundStyle(NoorColor.inkSecondary)
            }
        }
        .frame(minHeight: 44)
    }

    @ViewBuilder
    private func lineCount(_ count: Int) -> some View {
        if isArabicUI {
            Text(verbatim: "\(count.arabicIndic) بيتًا")
        } else {
            Text("\(count) lines")
        }
    }

    private func matnRow(_ matn: Matn) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 17))
                .foregroundStyle(NoorColor.accentPrimary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: matn.displayTitle(arabicUI: isArabicUI))
                    .font(.noorScaled(16, weight: .semibold))
                    .foregroundStyle(NoorColor.inkPrimary)
                Text(verbatim: matn.displayAuthor(arabicUI: isArabicUI))
                    .font(NoorFont.caption)
                    .foregroundStyle(NoorColor.inkSecondary)
                // Arabic-Indic numerals in the Arabic interface, as
                // everywhere else in the app (see `SurahRow`).
                lineCount(matn.lines.count)
                    .font(NoorFont.caption)
                    .foregroundStyle(NoorColor.inkSecondary)
            }
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Learn — AR RTL") {
    // The host supplies the tafsir screens (see `learnDestinations`).
    NavigationStack { LearnView().learnDestinations { _ in Text(verbatim: "Tafsir") } }
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Learn — EN LTR") {
    NavigationStack { LearnView().learnDestinations { _ in Text(verbatim: "Tafsir") } }
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.layoutDirection, .leftToRight)
}
