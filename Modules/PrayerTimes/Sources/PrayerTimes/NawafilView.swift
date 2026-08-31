import DesignSystem
import SwiftUI

/// Reference guide to the voluntary prayers (النوافل): what, how many
/// rak'ahs, when, and the evidence — purely informational.
struct NawafilItem: Identifiable {
    let icon: String
    let nameArabic: String
    let nameEnglish: String
    let rakahsArabic: String
    let rakahsEnglish: String
    let timeArabic: String
    let timeEnglish: String
    let noteArabic: String
    let noteEnglish: String

    var id: String { nameEnglish }

    static let all: [NawafilItem] = [
        NawafilItem(icon: "sun.and.horizon",
            nameArabic: "السنن الرواتب", nameEnglish: "Sunan ar-Rawatib",
            rakahsArabic: "١٢ ركعة", rakahsEnglish: "12 rak'ahs",
            timeArabic: "٢ قبل الفجر · ٤ قبل الظهر و٢ بعدها · ٢ بعد المغرب · ٢ بعد العشاء",
            timeEnglish: "2 before Fajr · 4 before and 2 after Dhuhr · 2 after Maghrib · 2 after Isha",
            noteArabic: "«من صلى اثنتي عشرة ركعة في يوم وليلة بُني له بهن بيت في الجنة» — رواه مسلم. وأوكدها ركعتا الفجر.",
            noteEnglish: "\"Whoever prays twelve rak'ahs in a day and night, a house is built for him in Paradise\" (Muslim). The two before Fajr are the most emphasized."),
        NawafilItem(icon: "sunrise",
            nameArabic: "صلاة الضحى", nameEnglish: "Duha",
            rakahsArabic: "٢ إلى ٨ ركعات", rakahsEnglish: "2 to 8 rak'ahs",
            timeArabic: "من ارتفاع الشمس (بعد الشروق بربع ساعة تقريبًا) إلى قبيل الظهر",
            timeEnglish: "From when the sun has risen (about 15 minutes after sunrise) until shortly before Dhuhr",
            noteArabic: "أوصى بها النبي ﷺ أبا هريرة، وقال: «يصبح على كل سُلامى من أحدكم صدقة… ويجزئ من ذلك ركعتان يركعهما من الضحى» — رواه مسلم. وأفضل وقتها اشتداد الحر.",
            noteEnglish: "The Prophet ﷺ counseled Abu Hurayrah to keep it, saying two rak'ahs of Duha suffice as charity for every joint of the body (Muslim). Its best time is when the heat intensifies."),
        NawafilItem(icon: "moon.zzz",
            nameArabic: "قيام الليل (التهجد)", nameEnglish: "Qiyam al-Layl (Tahajjud)",
            rakahsArabic: "مثنى مثنى، بلا حد", rakahsEnglish: "Two by two, no fixed limit",
            timeArabic: "بعد العشاء إلى الفجر، وأفضله الثلث الأخير من الليل",
            timeEnglish: "After Isha until Fajr — best in the last third of the night",
            noteArabic: "«أفضل الصلاة بعد الفريضة صلاة الليل» — رواه مسلم. وينزل ربنا في الثلث الأخير فيجيب الداعي ويعطي السائل ويغفر للمستغفر.",
            noteEnglish: "\"The best prayer after the obligatory is the night prayer\" (Muslim). In the last third of the night our Lord answers the supplicant, gives the asker, and forgives the one seeking forgiveness."),
        NawafilItem(icon: "star",
            nameArabic: "الوتر", nameEnglish: "Witr",
            rakahsArabic: "١ إلى ١١ ركعة (أقله واحدة)", rakahsEnglish: "1 to 11 rak'ahs (minimum one)",
            timeArabic: "بعد العشاء إلى طلوع الفجر، ويُجعل آخر صلاة الليل",
            timeEnglish: "After Isha until dawn — made the last prayer of the night",
            noteArabic: "«اجعلوا آخر صلاتكم بالليل وترًا» — متفق عليه. ومن خاف ألا يقوم آخر الليل أوتر أوله.",
            noteEnglish: "\"Make the last of your night prayers Witr\" (agreed upon). Whoever fears missing the end of the night prays it early."),
        NawafilItem(icon: "door.left.hand.open",
            nameArabic: "تحية المسجد", nameEnglish: "Tahiyyat al-Masjid",
            rakahsArabic: "ركعتان", rakahsEnglish: "2 rak'ahs",
            timeArabic: "عند دخول المسجد قبل الجلوس",
            timeEnglish: "Upon entering the mosque, before sitting",
            noteArabic: "«إذا دخل أحدكم المسجد فلا يجلس حتى يصلي ركعتين» — متفق عليه.",
            noteEnglish: "\"When one of you enters the mosque, let him not sit until he prays two rak'ahs\" (agreed upon)."),
        NawafilItem(icon: "drop",
            nameArabic: "سنة الوضوء", nameEnglish: "After Wudu",
            rakahsArabic: "ركعتان", rakahsEnglish: "2 rak'ahs",
            timeArabic: "عقب الوضوء",
            timeEnglish: "Right after performing wudu",
            noteArabic: "شهد النبي ﷺ لبلال بمكانته في الجنة بسبب محافظته على ركعتين بعد كل وضوء — متفق عليه.",
            noteEnglish: "The Prophet ﷺ attested to Bilal's rank in Paradise for keeping two rak'ahs after every wudu (agreed upon)."),
    ]

    static let avoidArabic = "أوقات النهي: بعد صلاة الفجر حتى ترتفع الشمس، وعند قيامها في كبد السماء حتى تزول، وبعد صلاة العصر حتى تغرب — إلا ذوات الأسباب."
    static let avoidEnglish = "Times to avoid voluntary prayer: after Fajr until the sun has risen, when it is at its zenith until it passes, and after Asr until sunset — except prayers with a specific cause."
}

struct NawafilView: View {
    let isArabicUI: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(NawafilItem.all) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(NoorColor.accentGold)
                                    .frame(width: 26)
                                Text(verbatim: isArabicUI ? item.nameArabic : item.nameEnglish)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(NoorColor.inkPrimary)
                                Spacer()
                                Text(verbatim: isArabicUI ? item.rakahsArabic : item.rakahsEnglish)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(NoorColor.accentPrimary)
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.system(size: 11))
                                Text(verbatim: isArabicUI ? item.timeArabic : item.timeEnglish)
                                    .font(.noorScaled(14))
                                    .multilineTextAlignment(.leading)
                            }
                            .foregroundStyle(NoorColor.inkSecondary)
                            Text(verbatim: isArabicUI ? item.noteArabic : item.noteEnglish)
                                .font(.noorScaled(14.5))
                                .foregroundStyle(NoorColor.inkPrimary.opacity(0.85))
                                .lineSpacing(6)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(16)
                        .noorCard()
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 13))
                            .foregroundStyle(NoorColor.accentGold)
                        Text(verbatim: isArabicUI ? NawafilItem.avoidArabic : NawafilItem.avoidEnglish)
                            .font(.system(size: 13.5))
                            .foregroundStyle(NoorColor.inkSecondary)
                            .lineSpacing(5)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(NoorColor.accentGold.opacity(0.08))
                    )
                }
                .padding(16)
            }
            .background(NoorColor.bgPrimary)
            .navigationTitle(Text("Nawafil"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NawafilView(isArabicUI: true)
        .environment(\.layoutDirection, .rightToLeft)
}


#Preview("Nawafil EN-LTR") {
    NawafilView(isArabicUI: false)
}
