import ContentDB
import DesignSystem
import SwiftUI

/// Curated duas: Quranic ones are LOADED from the verified mushaf DB by
/// reference (rule 1); prophetic ones are hadith texts with sources.
struct QuranicDua: Identifiable {
    let surahId: Int
    let range: ClosedRange<Int>
    var id: String { "\(surahId):\(range.lowerBound)" }

    static let all: [QuranicDua] = [
        QuranicDua(surahId: 2, range: 201...201),
        QuranicDua(surahId: 2, range: 286...286),
        QuranicDua(surahId: 3, range: 8...8),
        QuranicDua(surahId: 3, range: 16...16),
        QuranicDua(surahId: 3, range: 193...194),
        QuranicDua(surahId: 14, range: 40...41),
        QuranicDua(surahId: 18, range: 10...10),
        QuranicDua(surahId: 20, range: 25...28),
        QuranicDua(surahId: 21, range: 87...87),
        QuranicDua(surahId: 23, range: 97...98),
        QuranicDua(surahId: 25, range: 74...74),
        QuranicDua(surahId: 59, range: 10...10),
        QuranicDua(surahId: 66, range: 8...8),
    ]
}

struct PropheticDua: Identifiable {
    let title: String
    let text: String
    let source: String
    var id: String { title }

    static let all: [PropheticDua] = [
        PropheticDua(
            title: "دعاء الاستخارة",
            text: "اللَّهُمَّ إِنِّي أَسْتَخِيرُكَ بِعِلْمِكَ، وَأَسْتَقْدِرُكَ بِقُدْرَتِكَ، وَأَسْأَلُكَ مِنْ فَضْلِكَ الْعَظِيمِ، فَإِنَّكَ تَقْدِرُ وَلَا أَقْدِرُ، وَتَعْلَمُ وَلَا أَعْلَمُ، وَأَنْتَ عَلَّامُ الْغُيُوبِ. اللَّهُمَّ إِنْ كُنْتَ تَعْلَمُ أَنَّ هَذَا الْأَمْرَ خَيْرٌ لِي فِي دِينِي وَمَعَاشِي وَعَاقِبَةِ أَمْرِي فَاقْدُرْهُ لِي وَيَسِّرْهُ لِي ثُمَّ بَارِكْ لِي فِيهِ، وَإِنْ كُنْتَ تَعْلَمُ أَنَّ هَذَا الْأَمْرَ شَرٌّ لِي فِي دِينِي وَمَعَاشِي وَعَاقِبَةِ أَمْرِي فَاصْرِفْهُ عَنِّي وَاصْرِفْنِي عَنْهُ، وَاقْدُرْ لِيَ الْخَيْرَ حَيْثُ كَانَ ثُمَّ أَرْضِنِي بِهِ. (ويسمي حاجته)",
            source: "رواه البخاري"),
        PropheticDua(
            title: "دعاء الكرب",
            text: "لَا إِلَهَ إِلَّا اللهُ الْعَظِيمُ الْحَلِيمُ، لَا إِلَهَ إِلَّا اللهُ رَبُّ الْعَرْشِ الْعَظِيمِ، لَا إِلَهَ إِلَّا اللهُ رَبُّ السَّمَاوَاتِ وَرَبُّ الْأَرْضِ وَرَبُّ الْعَرْشِ الْكَرِيمِ.",
            source: "متفق عليه"),
        PropheticDua(
            title: "دعاء الهم والحزن",
            text: "اللَّهُمَّ إِنِّي عَبْدُكَ، ابْنُ عَبْدِكَ، ابْنُ أَمَتِكَ، نَاصِيَتِي بِيَدِكَ، مَاضٍ فِيَّ حُكْمُكَ، عَدْلٌ فِيَّ قَضَاؤُكَ، أَسْأَلُكَ بِكُلِّ اسْمٍ هُوَ لَكَ سَمَّيْتَ بِهِ نَفْسَكَ أَنْ تَجْعَلَ الْقُرْآنَ رَبِيعَ قَلْبِي، وَنُورَ صَدْرِي، وَجَلَاءَ حُزْنِي، وَذَهَابَ هَمِّي.",
            source: "رواه أحمد"),
        PropheticDua(
            title: "دعاء السفر",
            text: "اللهُ أَكْبَرُ، اللهُ أَكْبَرُ، اللهُ أَكْبَرُ، سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ وَإِنَّا إِلَى رَبِّنَا لَمُنْقَلِبُونَ. اللَّهُمَّ إِنَّا نَسْأَلُكَ فِي سَفَرِنَا هَذَا الْبِرَّ وَالتَّقْوَى، وَمِنَ الْعَمَلِ مَا تَرْضَى.",
            source: "رواه مسلم"),
        PropheticDua(
            title: "دعاء نزول المطر",
            text: "اللَّهُمَّ صَيِّبًا نَافِعًا.",
            source: "رواه البخاري"),
        PropheticDua(
            title: "جوامع الدعاء",
            text: "اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي الدُّنْيَا وَالْآخِرَةِ. يَا مُقَلِّبَ الْقُلُوبِ ثَبِّتْ قَلْبِي عَلَى دِينِكَ. اللَّهُمَّ أَصْلِحْ لِي دِينِيَ الَّذِي هُوَ عِصْمَةُ أَمْرِي، وَأَصْلِحْ لِي دُنْيَايَ الَّتِي فِيهَا مَعَاشِي، وَأَصْلِحْ لِي آخِرَتِيَ الَّتِي فِيهَا مَعَادِي.",
            source: "رواه مسلم والترمذي"),
    ]
}

struct SelectedDuasView: View {
    @State private var database = try? QuranDatabase()
    @State private var quranic: [(dua: QuranicDua, text: String, reference: String)] = []
    @Environment(\.locale) private var locale

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Text(isArabicUI ? "أدعية من القرآن" : "Duas from the Quran")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NoorColor.accentPrimary)
                ForEach(quranic, id: \.dua.id) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verbatim: item.text)
                            .font(NoorFont.quran(size: 19))
                            .foregroundStyle(NoorColor.inkPrimary)
                            .lineSpacing(12)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(verbatim: item.reference)
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.accentGold)
                    }
                    .padding(16)
                    .noorCard()
                }

                Text(isArabicUI ? "أدعية من السنة" : "Duas from the Sunnah")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NoorColor.accentPrimary)
                    .padding(.top, 6)
                ForEach(PropheticDua.all) { dua in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verbatim: dua.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(NoorColor.accentGold)
                        Text(verbatim: dua.text)
                            .font(.system(size: 17))
                            .foregroundStyle(NoorColor.inkPrimary)
                            .lineSpacing(8)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(verbatim: dua.source)
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.inkSecondary)
                    }
                    .padding(16)
                    .noorCard()
                }
            }
            .padding(16)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .background(NoorColor.bgPrimary)
        .navigationTitle(Text("Selected duas"))
        .task {
            guard quranic.isEmpty, let database else { return }
            let surahs = (try? database.allSurahs()) ?? []
            quranic = QuranicDua.all.compactMap { dua in
                guard let verses = try? database.verses(surahId: dua.surahId) else { return nil }
                let slice = verses.filter { dua.range.contains($0.ayah) }
                guard !slice.isEmpty else { return nil }
                let text = slice.map { $0.text + " \u{2067}﴿\($0.ayah.arabicIndic)﴾\u{2069}" }
                    .joined(separator: " ")
                let name = surahs.first { $0.id == dua.surahId }?.nameArabic ?? ""
                return (dua, text, "\(name) · \(dua.range.lowerBound.arabicIndic)")
            }
        }
    }
}
