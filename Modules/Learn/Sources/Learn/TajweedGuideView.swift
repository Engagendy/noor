import ContentDB
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

        /// Names taken from the shared `TajweedRule` so this guide and the
        /// reader's tajweed colour legend can never describe the same rule
        /// two different ways. `TajweedGuideRuleNamesTests` locks that in.
        init(rule: TajweedRule, symbol: String,
             meaningArabic: String, meaningEnglish: String) {
            self.symbol = symbol
            self.nameArabic = rule.nameArabic
            self.nameEnglish = rule.nameEnglish
            self.meaningArabic = meaningArabic
            self.meaningEnglish = meaningEnglish
        }

        /// For marks that are not annotated rules (pause marks, symbols, and
        /// izhar — which is the ABSENCE of a rule and so is never coloured).
        init(symbol: String, nameArabic: String, nameEnglish: String,
             meaningArabic: String, meaningEnglish: String) {
            self.symbol = symbol
            self.nameArabic = nameArabic
            self.nameEnglish = nameEnglish
            self.meaningArabic = meaningArabic
            self.meaningEnglish = meaningEnglish
        }
    }

    private let pauseMarks: [Mark] = [
        Mark(symbol: "\u{0640}\u{06D8}", nameArabic: "مـ — الوقف اللازم", nameEnglish: "Meem — compulsory stop",
             meaningArabic: "يجب الوقوف هنا؛ الوصل قد يغيّر المعنى.",
             meaningEnglish: "You must stop here; continuing could change the meaning."),
        Mark(symbol: "\u{0640}\u{06D9}", nameArabic: "لا — لا تقف", nameEnglish: "Lā — do not stop",
             meaningArabic: "لا يصح الوقوف هنا؛ صِلْ القراءة.",
             meaningEnglish: "Do not stop here; continue reading."),
        Mark(symbol: "\u{0640}\u{06DA}", nameArabic: "ج — الوقف الجائز", nameEnglish: "Jeem — permissible stop",
             meaningArabic: "يجوز الوقف والوصل على السواء.",
             meaningEnglish: "Stopping and continuing are equally fine."),
        Mark(symbol: "\u{0640}\u{06D6}", nameArabic: "صلى — الوصل أولى", nameEnglish: "Ṣalā — continuing preferred",
             meaningArabic: "يجوز الوقف، والوصل أفضل.",
             meaningEnglish: "You may stop, but continuing is better."),
        Mark(symbol: "\u{0640}\u{06D7}", nameArabic: "قلى — الوقف أولى", nameEnglish: "Qalā — stopping preferred",
             meaningArabic: "يجوز الوصل، والوقف أفضل.",
             meaningEnglish: "You may continue, but stopping is better."),
        Mark(symbol: "\u{0640}\u{06DB} \u{0640}\u{06DB}", nameArabic: "المعانقة", nameEnglish: "Muʿānaqah — paired dots",
             meaningArabic: "قف عند إحدى العلامتين لا كلتيهما.",
             meaningEnglish: "Stop at one of the two marks, not both."),
        Mark(symbol: "\u{0640}\u{06DC}", nameArabic: "س — السكتة", nameEnglish: "Seen — brief pause (saktah)",
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
        Mark(symbol: "\u{0640}\u{0653}", nameArabic: "علامة المد", nameEnglish: "Madd sign",
             meaningArabic: "إطالة الصوت بالحرف ست حركات غالبًا.",
             meaningEnglish: "Lengthen the vowel (typically six counts)."),
        Mark(symbol: "\u{0640}\u{06E2}", nameArabic: "ميم الإقلاب الصغيرة", nameEnglish: "Small meem (iqlāb)",
             meaningArabic: "تُقلب النون الساكنة أو التنوين ميمًا قبل الباء.",
             meaningEnglish: "Noon sākinah/tanween becomes 'm' before the letter bā."),
    ]

    private let rules: [Mark] = [
        Mark(symbol: "ء هـ ع ح غ خ", nameArabic: "الإظهار الحلقي", nameEnglish: "Iẓhār (clear pronunciation)",
             meaningArabic: "تُنطق النون الساكنة والتنوين بوضوح قبل حروف الحلق الستة.",
             meaningEnglish: "Noon sākinah/tanween is pronounced clearly before the six throat letters."),
        Mark(rule: .idghaamGhunnah, symbol: "ي ن م و",
             meaningArabic: "تُدغم النون في هذه الحروف مع غنة مقدارها حركتان.",
             meaningEnglish: "Noon merges into these letters with a two-count nasal sound."),
        Mark(rule: .idghaamNoGhunnah, symbol: "ل ر",
             meaningArabic: "تُدغم النون في اللام والراء دون غنة.",
             meaningEnglish: "Noon merges into lām and rā with no nasal sound."),
        Mark(rule: .iqlab, symbol: "ب",
             meaningArabic: "تُقلب النون الساكنة والتنوين ميمًا مخفاة قبل الباء.",
             meaningEnglish: "Noon sākinah/tanween turns into a hidden meem before bā."),
        Mark(rule: .ikhfa, symbol: "باقي الحروف",
             meaningArabic: "تُخفى النون مع غنة قبل الحروف الخمسة عشر الباقية.",
             meaningEnglish: "Noon is hidden with a nasal sound before the remaining fifteen letters."),
        Mark(rule: .qalqalah, symbol: "ق ط ب ج د",
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
        // Inline, like the rest of the learning area: pushed into the Quran
        // tab's stack the large title drew straight over the first section
        // header.
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func section(title: LocalizedStringKey, marks: [Mark], quranFont: Bool) -> some View {
        Section(header: Text(title).foregroundStyle(NoorColor.inkSecondary)) {
            ForEach(marks) { mark in
                HStack(alignment: .top, spacing: 14) {
                    Text(verbatim: mark.symbol)
                        .font(quranFont ? NoorFont.quran(size: 26) : .system(size: 17, weight: .semibold))
                        .foregroundStyle(NoorColor.accentGold)
                        .frame(minWidth: 56, alignment: .center)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: isArabicUI ? mark.nameArabic : mark.nameEnglish)
                            .font(.noorScaled(15, weight: .semibold))
                            .foregroundStyle(NoorColor.inkPrimary)
                        Text(verbatim: isArabicUI ? mark.meaningArabic : mark.meaningEnglish)
                            .font(.noorScaled(13.5))
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
