import DesignSystem
import SwiftUI

/// The app's learning area: the memorisation matns (classical didactic
/// poems) and the tajweed reference guide, in one place reachable from the
/// Quran tab.
///
/// The matn list is driven by `MatnStore`, so a second matn (al-Jazariyyah,
/// once a vowelled source is verified) appears here by adding its JSON — no
/// UI change needed.
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
                Text("Classical poems memorised by students of tajweed.")
                    .font(NoorFont.caption)
                    .foregroundStyle(NoorColor.inkSecondary)
            }

            Section {
                NavigationLink(value: LearnRoute.tajweed) {
                    HStack(spacing: 12) {
                        Image(systemName: "character.book.closed")
                            .font(.system(size: 17))
                            .foregroundStyle(NoorColor.accentGold)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tajweed Guide")
                                .font(.noorScaled(16, weight: .semibold))
                                .foregroundStyle(NoorColor.inkPrimary)
                            Text("Pause marks, mushaf symbols and the letter rules.")
                                .font(NoorFont.caption)
                                .foregroundStyle(NoorColor.inkSecondary)
                        }
                    }
                    .frame(minHeight: 44)
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
    NavigationStack { LearnView().learnDestinations() }
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Learn — EN LTR") {
    NavigationStack { LearnView().learnDestinations() }
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.layoutDirection, .leftToRight)
}
