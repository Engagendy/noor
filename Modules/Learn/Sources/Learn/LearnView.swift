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

    public var body: some View {
        List {
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
        .scrollContentBackground(.hidden)
        .background(NoorColor.bgPrimary)
        .navigationTitle(Text("Learn"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            if matns.isEmpty { matns = MatnStore.load() }
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
