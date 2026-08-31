import DesignSystem
import SwiftUI

/// Reference guide: mushaf pause marks (علامات الوقف), other mushaf symbols,
/// and the core tajweed letter rules. Educational content — bilingual.
public struct TajweedGuideView: View {
    public init() {}

    @Environment(\.locale) private var locale
    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    private struct Mark: Identifiable {
        let symbol: String
        let nameArabic: String
        let nameEnglish: String
        let meaningArabic: String
        let meaningEnglish: String
        var id: String { symbol + nameArabic }
    }

    private let pauseMarks: [Mark] = [
        Mark(symbol: "ۘ", nameArabic: "مـ — الوقف اللازم", nameEnglish: "Meem — compulsory stop",
             meaningArabic: "يجب الوقوف هنا؛ الوصل قد يغيّر المعنى.",
             meaningEnglish: "You must stop here; continuing could change the meaning."),
        Mark(symbol: "ۙ", nameArabic: "لا — لا تقف", nameEnglish: "Lā — do not stop",
             meaningArabic: "لا يصح الوقوف هنا؛ صِلْ القراءة.",
             meaningEnglish: "Do not stop here; continue reading."),
        Mark(symbol: "ۚ", nameArabic: "ج — الوقف الجائز", nameEnglish: "Jeem — permissible stop",
             meaningArabic: "يجوز الوقف والوصل على السواء.",
             meaningEnglish: "Stopping and continuing are equally fine."),
        Mark(symbol: "ۖ", nameArabic: "صلى — الوصل أولى", nameEnglish: "Ṣalā — continuing preferred",
             meaningArabic: "يجوز الوقف، والوصل أفضل.",
             meaningEnglish: "You may stop, but continuing is better."),
        Mark(symbol: "ۗ", nameArabic: "قلى — الوقف أولى", nameEnglish: "Qalā — stopping preferred",
             meaningArabic: "يجوز الوصل، والوقف أفضل.",
             meaningEnglish: "You may continue, but stopping is better."),
        Mark(symbol: "ۛ ۛ", nameArabic: "المعانقة", nameEnglish: "Muʿānaqah — paired dots",
             meaningArabic: "قف عند إحدى العلامتين لا كلتيهما.",
             meaningEnglish: "Stop at one of the two marks, not both."),
        Mark(symbol: "ۜ", nameArabic: "س — السكتة", nameEnglish: "Seen — brief pause (saktah)",
             meaningArabic: "سكتة لطيفة دون تنفّس.",
             meaningEnglish: "A brief pause without taking a breath."),
    ]

    private let otherMarks: [Mark] = [
        Mark(symbol: "۩", nameArabic: "السجدة", nameEnglish: "Sajdah",
             meaningArabic: "موضع سجود التلاوة.",
             meaningEnglish: "A place of prostration of recitation."),
        Mark(symbol: "۞", nameArabic: "ربع الحزب", nameEnglish: "Rubʿ al-hizb",
             meaningArabic: "بداية ربع الحزب من أحزاب القرآن.",
             meaningEnglish: "Marks the start of a quarter-hizb division."),
        Mark(symbol: "ٓ", nameArabic: "علامة المد", nameEnglish: "Madd sign",
             meaningArabic: "إطالة الصوت بالحرف ست حركات غالبًا.",
             meaningEnglish: "Lengthen the vowel (typically six counts)."),
        Mark(symbol: "ۢ", nameArabic: "ميم الإقلاب الصغيرة", nameEnglish: "Small meem (iqlāb)",
             meaningArabic: "تُقلب النون الساكنة أو التنوين ميمًا قبل الباء.",
             meaningEnglish: "Noon sākinah/tanween becomes 'm' before the letter bā."),
    ]

    private let rules: [Mark] = [
        Mark(symbol: "ء هـ ع ح غ خ", nameArabic: "الإظهار الحلقي", nameEnglish: "Iẓhār (clear pronunciation)",
             meaningArabic: "تُنطق النون الساكنة والتنوين بوضوح قبل حروف الحلق الستة.",
             meaningEnglish: "Noon sākinah/tanween is pronounced clearly before the six throat letters."),
        Mark(symbol: "ي ن م و", nameArabic: "الإدغام بغنة", nameEnglish: "Idghām with ghunnah",
             meaningArabic: "تُدغم النون في هذه الحروف مع غنة مقدارها حركتان.",
             meaningEnglish: "Noon merges into these letters with a two-count nasal sound."),
        Mark(symbol: "ل ر", nameArabic: "الإدغام بغير غنة", nameEnglish: "Idghām without ghunnah",
             meaningArabic: "تُدغم النون في اللام والراء دون غنة.",
             meaningEnglish: "Noon merges into lām and rā with no nasal sound."),
        Mark(symbol: "ب", nameArabic: "الإقلاب", nameEnglish: "Iqlāb",
             meaningArabic: "تُقلب النون الساكنة والتنوين ميمًا مخفاة قبل الباء.",
             meaningEnglish: "Noon sākinah/tanween turns into a hidden meem before bā."),
        Mark(symbol: "باقي الحروف", nameArabic: "الإخفاء الحقيقي", nameEnglish: "Ikhfāʾ (hiding)",
             meaningArabic: "تُخفى النون مع غنة قبل الحروف الخمسة عشر الباقية.",
             meaningEnglish: "Noon is hidden with a nasal sound before the remaining fifteen letters."),
        Mark(symbol: "ق ط ب ج د", nameArabic: "القلقلة", nameEnglish: "Qalqalah (echoing)",
             meaningArabic: "اهتزاز الصوت عند سكون هذه الحروف الخمسة.",
             meaningEnglish: "A bouncing echo when these five letters carry sukūn."),
    ]

    public var body: some View {
        List {
            section(title: "Pause marks (علامات الوقف)", marks: pauseMarks, quranFont: true)
            section(title: "Mushaf symbols", marks: otherMarks, quranFont: true)
            section(title: "Tajweed rules (أحكام التجويد)", marks: rules, quranFont: false)
        }
        .scrollContentBackground(.hidden)
        .background(NoorColor.bgPrimary)
        .navigationTitle(Text("Tajweed Guide"))
    }

    private func section(title: LocalizedStringKey, marks: [Mark], quranFont: Bool) -> some View {
        Section(header: Text(title).foregroundStyle(NoorColor.inkSecondary)) {
            ForEach(marks) { mark in
                HStack(alignment: .top, spacing: 14) {
                    Text(mark.symbol)
                        .font(quranFont ? NoorFont.quran(size: 26) : .system(size: 17, weight: .semibold))
                        .foregroundStyle(NoorColor.accentGold)
                        .frame(minWidth: 56, alignment: .center)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(isArabicUI ? mark.nameArabic : mark.nameEnglish)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(NoorColor.inkPrimary)
                        Text(isArabicUI ? mark.meaningArabic : mark.meaningEnglish)
                            .font(.system(size: 13.5))
                            .foregroundStyle(NoorColor.inkSecondary)
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.clear)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

#Preview {
    NavigationStack { TajweedGuideView() }
}

#Preview("AR") {
    NavigationStack { TajweedGuideView() }
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}
