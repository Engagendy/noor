import DesignSystem
import SwiftUI

/// أسماء الله الحسنى — the 99 Beautiful Names, with meanings.
struct DivineName: Identifiable {
    let number: Int
    let arabic: String
    let transliteration: String
    let meaningEnglish: String
    let meaningArabic: String

    var id: Int { number }

    static let all: [DivineName] = {
        let raw: [(String, String, String, String)] = [
            ("الرحمن", "Ar-Rahman", "The Most Merciful", "ذو الرحمة الواسعة لجميع الخلق"),
            ("الرحيم", "Ar-Raheem", "The Bestower of Mercy", "الموصل رحمته لعباده المؤمنين"),
            ("الملك", "Al-Malik", "The King", "المالك المتصرف في ملكه"),
            ("القدوس", "Al-Quddus", "The Most Holy", "المنزّه عن كل نقص"),
            ("السلام", "As-Salam", "The Source of Peace", "السالم من كل عيب، ومسلّم عباده"),
            ("المؤمن", "Al-Mu'min", "The Granter of Security", "المصدّق رسله والمؤمّن خلقه"),
            ("المهيمن", "Al-Muhaymin", "The Guardian", "الرقيب الحافظ على كل شيء"),
            ("العزيز", "Al-Aziz", "The Almighty", "الغالب الذي لا يُقهر"),
            ("الجبار", "Al-Jabbar", "The Compeller", "القاهر لخلقه، الجابر للكسير"),
            ("المتكبر", "Al-Mutakabbir", "The Supreme", "المتعالي عن صفات الخلق"),
            ("الخالق", "Al-Khaliq", "The Creator", "الموجد للأشياء من العدم"),
            ("البارئ", "Al-Bari", "The Originator", "المبدع الخلق بلا مثال"),
            ("المصور", "Al-Musawwir", "The Fashioner", "المعطي كل مخلوق صورته"),
            ("الغفار", "Al-Ghaffar", "The All-Forgiving", "الساتر لذنوب عباده مرة بعد مرة"),
            ("القهار", "Al-Qahhar", "The Subduer", "الغالب الذي خضع له كل شيء"),
            ("الوهاب", "Al-Wahhab", "The Bestower", "المعطي بلا عوض"),
            ("الرزاق", "Ar-Razzaq", "The Provider", "المتكفل بأرزاق العباد"),
            ("الفتاح", "Al-Fattah", "The Opener", "الحاكم الفاتح لأبواب الرحمة"),
            ("العليم", "Al-Aleem", "The All-Knowing", "المحيط علمه بكل شيء"),
            ("القابض", "Al-Qabid", "The Withholder", "يقبض الرزق والأرواح بحكمته"),
            ("الباسط", "Al-Basit", "The Extender", "يبسط الرزق لمن يشاء"),
            ("الخافض", "Al-Khafid", "The Abaser", "يخفض أهل الباطل والمتكبرين"),
            ("الرافع", "Ar-Rafi", "The Exalter", "يرفع أولياءه بالطاعة"),
            ("المعز", "Al-Mu'izz", "The Giver of Honor", "يهب العز لمن يشاء"),
            ("المذل", "Al-Mudhill", "The Giver of Dishonor", "يذل من يشاء بعدله"),
            ("السميع", "As-Samee", "The All-Hearing", "المدرك للأصوات كلها"),
            ("البصير", "Al-Baseer", "The All-Seeing", "المدرك للمرئيات كلها"),
            ("الحكم", "Al-Hakam", "The Judge", "الفاصل بين عباده بالحق"),
            ("العدل", "Al-Adl", "The Just", "المنزّه عن الظلم"),
            ("اللطيف", "Al-Lateef", "The Subtle, The Kind", "البَرّ بعباده الخبير بدقائق الأمور"),
            ("الخبير", "Al-Khabeer", "The All-Aware", "العالم ببواطن الأمور"),
            ("الحليم", "Al-Haleem", "The Forbearing", "لا يعاجل العصاة بالعقوبة"),
            ("العظيم", "Al-Azeem", "The Magnificent", "ذو العظمة في كل شيء"),
            ("الغفور", "Al-Ghafoor", "The Forgiving", "الكثير المغفرة"),
            ("الشكور", "Ash-Shakoor", "The Appreciative", "يجزي على القليل بالكثير"),
            ("العلي", "Al-Ali", "The Most High", "العالي فوق خلقه قدرًا وقهرًا"),
            ("الكبير", "Al-Kabeer", "The Grand", "الأكبر من كل شيء"),
            ("الحفيظ", "Al-Hafeedh", "The Preserver", "الحافظ لكل شيء عن الزوال"),
            ("المقيت", "Al-Muqeet", "The Sustainer", "المتكفل بالأقوات، المقتدر"),
            ("الحسيب", "Al-Haseeb", "The Reckoner", "الكافي عباده، المحاسب"),
            ("الجليل", "Al-Jaleel", "The Majestic", "ذو الجلال والصفات العظيمة"),
            ("الكريم", "Al-Kareem", "The Generous", "الكثير الخير والعطاء"),
            ("الرقيب", "Ar-Raqeeb", "The Watchful", "المطلع الذي لا يغيب عنه شيء"),
            ("المجيب", "Al-Mujeeb", "The Responsive", "يجيب دعاء من دعاه"),
            ("الواسع", "Al-Wasi", "The All-Encompassing", "وسع كل شيء رحمة وعلمًا"),
            ("الحكيم", "Al-Hakeem", "The Wise", "يضع الأمور في مواضعها"),
            ("الودود", "Al-Wadood", "The Loving", "المحب لعباده الصالحين المحبوب"),
            ("المجيد", "Al-Majeed", "The Glorious", "العظيم الكريم الجميل الأفعال"),
            ("الباعث", "Al-Ba'ith", "The Resurrector", "يبعث الخلق يوم القيامة"),
            ("الشهيد", "Ash-Shaheed", "The Witness", "المطلع على كل شيء شهادةً"),
            ("الحق", "Al-Haqq", "The Truth", "الثابت الذي لا يزول"),
            ("الوكيل", "Al-Wakeel", "The Trustee", "المتكفل بأمور من توكل عليه"),
            ("القوي", "Al-Qawiyy", "The Strong", "كامل القوة لا يعجزه شيء"),
            ("المتين", "Al-Mateen", "The Firm", "الشديد القوة الذي لا يمسه لغوب"),
            ("الولي", "Al-Waliyy", "The Protecting Friend", "الناصر المتولي أمور عباده"),
            ("الحميد", "Al-Hameed", "The Praiseworthy", "المستحق للحمد في ذاته وأفعاله"),
            ("المحصي", "Al-Muhsi", "The Enumerator", "أحاط بكل شيء عددًا"),
            ("المبدئ", "Al-Mubdi", "The Initiator", "بدأ الخلق أول مرة"),
            ("المعيد", "Al-Mu'eed", "The Restorer", "يعيد الخلق بعد الموت"),
            ("المحيي", "Al-Muhyi", "The Giver of Life", "يهب الحياة لمن يشاء"),
            ("المميت", "Al-Mumeet", "The Bringer of Death", "المقدّر للموت على خلقه"),
            ("الحي", "Al-Hayy", "The Ever-Living", "له الحياة الكاملة الدائمة"),
            ("القيوم", "Al-Qayyum", "The Sustainer of All", "القائم بنفسه المقيم لغيره"),
            ("الواجد", "Al-Wajid", "The Finder", "الذي لا يعوزه شيء"),
            ("الماجد", "Al-Majid", "The Noble", "ذو المجد والسعة في الكرم"),
            ("الواحد", "Al-Wahid", "The One", "المنفرد بلا شريك"),
            ("الأحد", "Al-Ahad", "The Unique", "المتوحد في ذاته وصفاته"),
            ("الصمد", "As-Samad", "The Eternal Refuge", "المقصود في الحوائج الغني عن الكل"),
            ("القادر", "Al-Qadir", "The Capable", "ذو القدرة التامة"),
            ("المقتدر", "Al-Muqtadir", "The Omnipotent", "البالغ القدرة لا يمتنع عليه شيء"),
            ("المقدم", "Al-Muqaddim", "The Expediter", "يقدّم من يشاء بحكمته"),
            ("المؤخر", "Al-Mu'akhkhir", "The Delayer", "يؤخر من يشاء بحكمته"),
            ("الأول", "Al-Awwal", "The First", "الذي ليس قبله شيء"),
            ("الآخر", "Al-Akhir", "The Last", "الذي ليس بعده شيء"),
            ("الظاهر", "Adh-Dhahir", "The Manifest", "الذي ليس فوقه شيء"),
            ("الباطن", "Al-Batin", "The Hidden", "الذي ليس دونه شيء، العالم بالخفايا"),
            ("الوالي", "Al-Wali", "The Governor", "المتولي تدبير الأمور"),
            ("المتعالي", "Al-Muta'ali", "The Most Exalted", "المرتفع عن كل نقص"),
            ("البر", "Al-Barr", "The Source of Goodness", "الواسع البر والإحسان"),
            ("التواب", "At-Tawwab", "The Acceptor of Repentance", "يقبل التوبة ويوفق إليها"),
            ("المنتقم", "Al-Muntaqim", "The Avenger", "ينتقم من المصرّين على العناد بعدله"),
            ("العفو", "Al-Afuww", "The Pardoner", "الكثير العفو والمحو للذنوب"),
            ("الرؤوف", "Ar-Ra'oof", "The Compassionate", "شديد الرحمة والرأفة"),
            ("مالك الملك", "Malik-ul-Mulk", "Owner of the Kingdom", "يؤتي الملك من يشاء وينزعه"),
            ("ذو الجلال والإكرام", "Dhul-Jalali wal-Ikram", "Lord of Majesty and Honor", "المستحق للتعظيم والإكرام"),
            ("المقسط", "Al-Muqsit", "The Equitable", "العادل في حكمه"),
            ("الجامع", "Al-Jami", "The Gatherer", "يجمع الخلق ليوم لا ريب فيه"),
            ("الغني", "Al-Ghaniyy", "The Self-Sufficient", "المستغني عن كل ما سواه"),
            ("المغني", "Al-Mughni", "The Enricher", "يغني من يشاء من عباده"),
            ("المانع", "Al-Mani", "The Preventer", "يمنع العطاء والبلاء بحكمته"),
            ("الضار", "Ad-Darr", "The Distresser", "يقدّر الضر بحكمته وعدله"),
            ("النافع", "An-Nafi", "The Benefactor", "يوصل النفع لمن يشاء"),
            ("النور", "An-Noor", "The Light", "نور السماوات والأرض، الهادي"),
            ("الهادي", "Al-Hadi", "The Guide", "يهدي من يشاء إلى الحق"),
            ("البديع", "Al-Badee", "The Incomparable Originator", "المبدع للخلق بلا مثال سابق"),
            ("الباقي", "Al-Baqi", "The Everlasting", "الدائم الذي لا يفنى"),
            ("الوارث", "Al-Warith", "The Inheritor", "الباقي بعد فناء الخلق"),
            ("الرشيد", "Ar-Rasheed", "The Guide to the Right Path", "المرشد لعباده إلى مصالحهم"),
            ("الصبور", "As-Saboor", "The Patient", "لا يعاجل العصاة بالعقوبة"),
        ]
        return raw.enumerated().map { index, entry in
            DivineName(number: index + 1, arabic: entry.0, transliteration: entry.1,
                       meaningEnglish: entry.2, meaningArabic: entry.3)
        }
    }()
}

/// The 99 Names screen: calm two-column grid, tap → detail with share.
public struct AsmaulHusnaView: View {
    @Environment(\.locale) private var locale
    @State private var selected: DivineName?

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    public init() {}

    public var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(DivineName.all) { name in
                    Button {
                        selected = name
                    } label: {
                        VStack(spacing: 5) {
                            Text(verbatim: name.arabic)
                                .font(NoorFont.quran(size: 22))
                                .foregroundStyle(NoorColor.inkPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            Text(verbatim: isArabicUI ? name.number.arabicIndic : name.transliteration)
                                .font(NoorFont.caption)
                                .foregroundStyle(NoorColor.inkSecondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .noorCard()
                }
            }
            .padding(16)
        }
        .background(NoorColor.bgPrimary)
        .navigationTitle(Text("Names of Allah"))
        .sheet(item: $selected) { name in
            DivineNameDetail(name: name, isArabicUI: isArabicUI)
                .environment(\.locale, locale)
                .environment(\.layoutDirection, isArabicUI ? .rightToLeft : .leftToRight)
                .presentationDetents([.medium])
        }
    }
}

struct DivineNameDetail: View {
    let name: DivineName
    let isArabicUI: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var sharing = false

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(NoorColor.inkSecondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
            Spacer()
            Text(verbatim: name.arabic)
                .font(NoorFont.quran(size: 46))
                .foregroundStyle(NoorColor.accentPrimary)
            Text(verbatim: name.transliteration)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(NoorColor.accentGold)
            Text(verbatim: isArabicUI ? name.meaningArabic : name.meaningEnglish)
                .font(.system(size: 17))
                .foregroundStyle(NoorColor.inkPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
            Button {
                sharing = true
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NoorColor.bgPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(NoorColor.accentPrimary))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(NoorColor.bgPrimary)
        .sheet(isPresented: $sharing) {
            NoorShareSheet(
                arabicText: name.arabic,
                translation: isArabicUI ? name.meaningArabic : "\(name.transliteration) — \(name.meaningEnglish)",
                reference: isArabicUI ? "من أسماء الله الحسنى" : "Among the Beautiful Names of Allah",
                attribution: "نور Noor",
                useQuranFont: false)
                .presentationDetents([.medium, .large])
        }
    }
}

#Preview {
    NavigationStack { AsmaulHusnaView() }
}
