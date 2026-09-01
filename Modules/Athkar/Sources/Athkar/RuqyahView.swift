import ContentDB
import DesignSystem
import SwiftUI

/// الرقية الشرعية: the Quranic ayat are LOADED from the verified database
/// by reference (never typed — CLAUDE.md rule 1); the prophetic formulas
/// are hadith texts.
struct RuqyahPassage: Identifiable {
    let surahId: Int
    let range: ClosedRange<Int>
    var id: String { "\(surahId)-\(range.lowerBound)" }

    static let all: [RuqyahPassage] = [
        RuqyahPassage(surahId: 1, range: 1...7),
        RuqyahPassage(surahId: 2, range: 1...5),
        RuqyahPassage(surahId: 2, range: 102...102),
        RuqyahPassage(surahId: 2, range: 163...164),
        RuqyahPassage(surahId: 2, range: 255...257),
        RuqyahPassage(surahId: 2, range: 285...286),
        RuqyahPassage(surahId: 3, range: 18...19),
        RuqyahPassage(surahId: 7, range: 117...122),
        RuqyahPassage(surahId: 10, range: 81...82),
        RuqyahPassage(surahId: 20, range: 69...69),
        RuqyahPassage(surahId: 23, range: 115...118),
        RuqyahPassage(surahId: 37, range: 1...10),
        RuqyahPassage(surahId: 59, range: 21...24),
        RuqyahPassage(surahId: 112, range: 1...4),
        RuqyahPassage(surahId: 113, range: 1...5),
        RuqyahPassage(surahId: 114, range: 1...6),
    ]
}

struct RuqyahProphetic: Identifiable {
    let text: String
    let source: String
    var id: String { String(text.prefix(24)) }

    static let all: [RuqyahProphetic] = [
        RuqyahProphetic(
            text: "بِسْمِ اللهِ أَرْقِيكَ، مِنْ كُلِّ شَيْءٍ يُؤْذِيكَ، مِنْ شَرِّ كُلِّ نَفْسٍ أَوْ عَيْنِ حَاسِدٍ، اللهُ يَشْفِيكَ، بِسْمِ اللهِ أَرْقِيكَ.",
            source: "رواه مسلم"),
        RuqyahProphetic(
            text: "اللَّهُمَّ رَبَّ النَّاسِ، أَذْهِبِ الْبَأْسَ، اشْفِ وَأَنْتَ الشَّافِي، لَا شِفَاءَ إِلَّا شِفَاؤُكَ، شِفَاءً لَا يُغَادِرُ سَقَمًا.",
            source: "متفق عليه"),
        RuqyahProphetic(
            text: "أَعُوذُ بِكَلِمَاتِ اللهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ.",
            source: "رواه مسلم"),
        RuqyahProphetic(
            text: "أَعُوذُ بِكَلِمَاتِ اللهِ التَّامَّةِ مِنْ كُلِّ شَيْطَانٍ وَهَامَّةٍ، وَمِنْ كُلِّ عَيْنٍ لَامَّةٍ.",
            source: "رواه البخاري"),
        RuqyahProphetic(
            text: "أَسْأَلُ اللهَ الْعَظِيمَ رَبَّ الْعَرْشِ الْعَظِيمِ أَنْ يَشْفِيَكَ. (سبع مرات)",
            source: "رواه أبو داود والترمذي"),
    ]
}

struct RuqyahView: View {
    @State private var database = try? QuranDatabase()
    @State private var passages: [(passage: RuqyahPassage, verses: [Verse], surahName: String)] = []
    @Environment(\.locale) private var locale

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Text(isArabicUI
                     ? "آيات الرقية تُقرأ بتدبر مع النفث، ثلاثًا أو أكثر. النصوص من المصحف المعتمد."
                     : "The ruqyah ayat are recited with reflection. Texts come from the verified mushaf database.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(NoorColor.inkSecondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(passages, id: \.passage.id) { item in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(verbatim: item.passage.range.count == 1
                             ? "\(item.surahName) · \(item.passage.range.lowerBound.arabicIndic)"
                             : "\(item.surahName) · \(item.passage.range.lowerBound.arabicIndic)–\(item.passage.range.upperBound.arabicIndic)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(NoorColor.accentGold)
                        Text(verbatim: item.verses.map {
                            $0.text + " \u{2067}﴿\($0.ayah.arabicIndic)﴾\u{2069}"
                        }.joined(separator: " "))
                            .font(NoorFont.quran(size: 20))
                            .foregroundStyle(NoorColor.inkPrimary)
                            .lineSpacing(14)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    .noorCard()
                }

                Text(isArabicUI ? "الأدعية النبوية" : "Prophetic supplications")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NoorColor.accentPrimary)
                    .padding(.top, 6)
                ForEach(RuqyahProphetic.all) { dua in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verbatim: dua.text)
                            .font(.system(size: 17))
                            .foregroundStyle(NoorColor.inkPrimary)
                            .lineSpacing(8)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(verbatim: dua.source)
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.accentGold)
                    }
                    .padding(16)
                    .noorCard()
                }
            }
            .padding(16)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .background(NoorColor.bgPrimary)
        .navigationTitle(Text("Ruqyah"))
        .task {
            guard passages.isEmpty, let database else { return }
            passages = RuqyahPassage.all.compactMap { passage in
                guard let verses = try? database.verses(surahId: passage.surahId) else { return nil }
                let slice = verses.filter { passage.range.contains($0.ayah) }
                guard !slice.isEmpty else { return nil }
                let surahs = (try? database.allSurahs()) ?? []
                let name = surahs.first { $0.id == passage.surahId }?.nameArabic ?? ""
                return (passage, slice, name)
            }
        }
    }
}
