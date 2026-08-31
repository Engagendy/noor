import Foundation

/// "On this day" in Islamic history, keyed by Hijri (day, month).
/// Curated, well-attested dates; entries whose day is historically debated
/// say "على المشهور" (per the well-known account).
struct IslamicEvent {
    let day: Int
    let month: Int   // 1 = Muharram … 12 = Dhul-Hijjah
    let yearHijri: Int?
    let arabic: String
    let english: String

    static func events(day: Int, month: Int) -> [IslamicEvent] {
        all.filter { $0.day == day && $0.month == month }
    }

    static let all: [IslamicEvent] = [
        // Muharram
        IslamicEvent(day: 1, month: 1, yearHijri: 17,
            arabic: "اعتماد التقويم الهجري في عهد أمير المؤمنين عمر بن الخطاب رضي الله عنه.",
            english: "The Hijri calendar was adopted during the caliphate of Umar ibn al-Khattab."),
        IslamicEvent(day: 10, month: 1, yearHijri: nil,
            arabic: "يوم عاشوراء: نجّى الله موسى عليه السلام وقومه من فرعون، ويُسنّ صيامه.",
            english: "Ashura: Allah saved Musa (peace be upon him) and his people from Pharaoh; fasting this day is Sunnah."),
        IslamicEvent(day: 10, month: 1, yearHijri: 61,
            arabic: "استشهاد الحسين بن علي رضي الله عنهما في كربلاء.",
            english: "The martyrdom of al-Husayn ibn Ali (may Allah be pleased with them) at Karbala."),
        // Safar
        IslamicEvent(day: 27, month: 2, yearHijri: nil,
            arabic: "خروج النبي ﷺ من مكة مهاجرًا إلى المدينة (على المشهور).",
            english: "The Prophet ﷺ departed Makkah beginning the Hijra to Madinah (per the well-known account)."),
        IslamicEvent(day: 27, month: 2, yearHijri: 589,
            arabic: "وفاة السلطان صلاح الدين الأيوبي، محرر القدس.",
            english: "The death of Sultan Salah ad-Din al-Ayyubi, liberator of Jerusalem."),
        // Rabi al-Awwal
        IslamicEvent(day: 8, month: 3, yearHijri: nil,
            arabic: "وصول النبي ﷺ إلى قباء وتأسيس أول مسجد في الإسلام.",
            english: "The Prophet ﷺ arrived at Quba, where the first mosque in Islam was founded."),
        IslamicEvent(day: 12, month: 3, yearHijri: nil,
            arabic: "مولد النبي محمد ﷺ (على المشهور).",
            english: "The birth of Prophet Muhammad ﷺ (per the well-known account)."),
        IslamicEvent(day: 12, month: 3, yearHijri: 11,
            arabic: "وفاة النبي محمد ﷺ في المدينة المنورة.",
            english: "The passing of Prophet Muhammad ﷺ in Madinah."),
        // Rabi al-Thani
        IslamicEvent(day: 25, month: 4, yearHijri: 583,
            arabic: "معركة حطين: انتصار صلاح الدين ومهّدت لتحرير القدس.",
            english: "The Battle of Hattin: Salah ad-Din's victory that paved the way to liberating Jerusalem."),
        // Jumada al-Ula
        IslamicEvent(day: 20, month: 5, yearHijri: 857,
            arabic: "فتح القسطنطينية على يد السلطان محمد الفاتح.",
            english: "The conquest of Constantinople by Sultan Muhammad al-Fatih."),
        // Jumada al-Akhirah
        IslamicEvent(day: 20, month: 6, yearHijri: nil,
            arabic: "ولادة فاطمة الزهراء بنت النبي ﷺ رضي الله عنها (على المشهور).",
            english: "The birth of Fatimah az-Zahra, daughter of the Prophet ﷺ (per the well-known account)."),
        IslamicEvent(day: 22, month: 6, yearHijri: 13,
            arabic: "وفاة الخليفة أبي بكر الصديق رضي الله عنه.",
            english: "The death of Caliph Abu Bakr as-Siddiq (may Allah be pleased with him)."),
        // Rajab
        IslamicEvent(day: 5, month: 7, yearHijri: 15,
            arabic: "معركة اليرموك: انتصار المسلمين بقيادة خالد بن الوليد على الروم.",
            english: "The Battle of Yarmouk: the Muslims' victory over the Byzantines under Khalid ibn al-Walid."),
        IslamicEvent(day: 27, month: 7, yearHijri: nil,
            arabic: "الإسراء والمعراج (على المشهور).",
            english: "Al-Isra wal-Mi'raj — the Night Journey (per the well-known account)."),
        IslamicEvent(day: 27, month: 7, yearHijri: 583,
            arabic: "استعادة صلاح الدين للقدس ودخوله المسجد الأقصى.",
            english: "Salah ad-Din restored Jerusalem and entered al-Masjid al-Aqsa."),
        IslamicEvent(day: 28, month: 7, yearHijri: 1342,
            arabic: "إلغاء الخلافة العثمانية، آخر خلافة إسلامية.",
            english: "The abolition of the Ottoman Caliphate, the last Islamic caliphate."),
        // Sha'ban
        IslamicEvent(day: 15, month: 8, yearHijri: 2,
            arabic: "تحويل القبلة من بيت المقدس إلى المسجد الحرام (على قولٍ مشهور).",
            english: "The Qibla changed from Jerusalem to the Sacred Mosque in Makkah (per a well-known account)."),
        // Ramadan
        IslamicEvent(day: 10, month: 9, yearHijri: nil,
            arabic: "وفاة أم المؤمنين خديجة بنت خويلد رضي الله عنها في عام الحزن.",
            english: "The death of the Mother of the Believers Khadijah bint Khuwaylid in the Year of Sorrow."),
        IslamicEvent(day: 15, month: 9, yearHijri: 3,
            arabic: "ولادة الحسن بن علي رضي الله عنهما، سبط النبي ﷺ.",
            english: "The birth of al-Hasan ibn Ali, grandson of the Prophet ﷺ."),
        IslamicEvent(day: 17, month: 9, yearHijri: 2,
            arabic: "غزوة بدر الكبرى: الفرقان الذي أعزّ الله به الإسلام.",
            english: "The great Battle of Badr — the Criterion by which Allah honored Islam."),
        IslamicEvent(day: 17, month: 9, yearHijri: 58,
            arabic: "وفاة أم المؤمنين عائشة رضي الله عنها.",
            english: "The death of the Mother of the Believers Aisha (may Allah be pleased with her)."),
        IslamicEvent(day: 20, month: 9, yearHijri: 8,
            arabic: "فتح مكة: دخل النبي ﷺ مكة وحطّم الأصنام حول الكعبة.",
            english: "The Conquest of Makkah: the Prophet ﷺ entered Makkah and the idols around the Kaaba were removed."),
        IslamicEvent(day: 21, month: 9, yearHijri: 40,
            arabic: "استشهاد الخليفة علي بن أبي طالب رضي الله عنه.",
            english: "The martyrdom of Caliph Ali ibn Abi Talib (may Allah be pleased with him)."),
        IslamicEvent(day: 25, month: 9, yearHijri: 658,
            arabic: "معركة عين جالوت: انتصار المسلمين على المغول.",
            english: "The Battle of Ain Jalut: the Muslims' victory over the Mongols."),
        IslamicEvent(day: 28, month: 9, yearHijri: 92,
            arabic: "بدء فتح الأندلس بقيادة طارق بن زياد.",
            english: "The opening of al-Andalus began under Tariq ibn Ziyad."),
        // Shawwal
        IslamicEvent(day: 1, month: 10, yearHijri: nil,
            arabic: "عيد الفطر المبارك، تقبّل الله منا ومنكم.",
            english: "Eid al-Fitr — may Allah accept from us and from you."),
        IslamicEvent(day: 7, month: 10, yearHijri: 3,
            arabic: "غزوة أُحد ودرسها الخالد في الثبات على أمر النبي ﷺ.",
            english: "The Battle of Uhud and its lasting lesson in holding to the Prophet's ﷺ command."),
        // Dhul-Hijjah
        IslamicEvent(day: 9, month: 12, yearHijri: 10,
            arabic: "يوم عرفة: خطبة الوداع ونزول ﴿الْيَوْمَ أَكْمَلْتُ لَكُمْ دِينَكُمْ﴾.",
            english: "The Day of Arafah: the Farewell Sermon and the revelation 'This day I have perfected your religion for you.'"),
        IslamicEvent(day: 10, month: 12, yearHijri: nil,
            arabic: "عيد الأضحى المبارك، تقبّل الله منا ومنكم.",
            english: "Eid al-Adha — may Allah accept from us and from you."),
        IslamicEvent(day: 18, month: 12, yearHijri: 35,
            arabic: "استشهاد الخليفة عثمان بن عفان رضي الله عنه.",
            english: "The martyrdom of Caliph Uthman ibn Affan (may Allah be pleased with him)."),
        IslamicEvent(day: 26, month: 12, yearHijri: 23,
            arabic: "طعن الخليفة عمر بن الخطاب رضي الله عنه وهو يصلي الفجر.",
            english: "Caliph Umar ibn al-Khattab was stabbed while leading the Fajr prayer."),
    ]
}
