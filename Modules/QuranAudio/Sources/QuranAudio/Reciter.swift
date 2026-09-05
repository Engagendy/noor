import Foundation

/// Ayah-by-ayah recitations from EveryAyah.com (see LICENSES.md).
public enum Reciter: String, CaseIterable, Identifiable, Codable {
    case alafasy
    case husary
    case minshawi
    case abdulBasit
    case ghamdi
    case sudais
    case muaiqly
    case shuraym
    case ayyoub
    case shatri
    case rifai
    case hudhaify
    case jibreel
    case dussary
    case basfar
    case sowaid
    case tablawi
    case abdulBasitMujawwad
    case minshawiMujawwad
    case salamah
    case qatami
    case faresAbbad
    case ajamy
    case muhsinQasim
    case juhany
    case bukhatir
    case budair
    case aliJaber
    case banna
    case matroud
    case abdulKareem

    case husaryMuallim, mustafaIsmail, khalidQahtani, sahlYassin, suesy, neana, alaqimy, tunaiji, akhdar, alili
    public var id: String { rawValue }

    public var englishName: String {
        switch self {
        case .alafasy: "Mishary Alafasy"
        case .husary: "Mahmoud Al-Husary"
        case .minshawi: "Mohamed Al-Minshawi"
        case .abdulBasit: "Abdul Basit (Murattal)"
        case .ghamdi: "Saad Al-Ghamdi"
        case .sudais: "Abdurrahman As-Sudais"
        case .muaiqly: "Maher Al-Muaiqly"
        case .shuraym: "Saud Ash-Shuraym"
        case .ayyoub: "Muhammad Ayyoub"
        case .shatri: "Abu Bakr Ash-Shatri"
        case .rifai: "Hani Ar-Rifai"
        case .hudhaify: "Ali Al-Hudhaify"
        case .jibreel: "Muhammad Jibreel"
        case .dussary: "Yasser Ad-Dussary"
        case .basfar: "Abdullah Basfar"
        case .sowaid: "Ayman Sowaid"
        case .tablawi: "Mohammad At-Tablawi"
        case .abdulBasitMujawwad: "Abdul Basit (Mujawwad)"
        case .minshawiMujawwad: "Al-Minshawi (Mujawwad)"
        case .salamah: "Yaser Salamah"
        case .qatami: "Nasser Al-Qatami"
        case .faresAbbad: "Fares Abbad"
        case .ajamy: "Ahmed Al-Ajmi"
        case .muhsinQasim: "Muhsin Al-Qasim"
        case .juhany: "Abdullah Al-Juhany"
        case .bukhatir: "Salah Bukhatir"
        case .budair: "Salah Al-Budair"
        case .aliJaber: "Ali Jaber"
        case .banna: "Mahmoud Ali Al-Banna"
        case .matroud: "Abdullah Al-Matroud"
        case .abdulKareem: "Muhammad Abdul-Kareem"
        case .husaryMuallim: "Al-Husary (Muallim)"
        case .mustafaIsmail: "Mustafa Ismail"
        case .khalidQahtani: "Khalid Al-Qahtani"
        case .sahlYassin: "Sahl Yassin"
        case .suesy: "Ali Hajjaj Al-Suesy"
        case .neana: "Ahmed Neana"
        case .alaqimy: "Akram Al-Alaqimy"
        case .tunaiji: "Khalifa Al-Tunaiji"
        case .akhdar: "Ibrahim Al-Akhdar"
        case .alili: "Aziz Alili"
        }
    }

    public var arabicName: String {
        switch self {
        case .alafasy: "مشاري العفاسي"
        case .husary: "محمود خليل الحصري"
        case .minshawi: "محمد صديق المنشاوي"
        case .abdulBasit: "عبد الباسط عبد الصمد"
        case .ghamdi: "سعد الغامدي"
        case .sudais: "عبد الرحمن السديس"
        case .muaiqly: "ماهر المعيقلي"
        case .shuraym: "سعود الشريم"
        case .ayyoub: "محمد أيوب"
        case .shatri: "أبو بكر الشاطري"
        case .rifai: "هاني الرفاعي"
        case .hudhaify: "علي الحذيفي"
        case .jibreel: "محمد جبريل"
        case .dussary: "ياسر الدوسري"
        case .basfar: "عبد الله بصفر"
        case .sowaid: "أيمن سويد"
        case .tablawi: "محمد الطبلاوي"
        case .abdulBasitMujawwad: "عبد الباسط (مجوّد)"
        case .minshawiMujawwad: "المنشاوي (مجوّد)"
        case .salamah: "ياسر سلامة"
        case .qatami: "ناصر القطامي"
        case .faresAbbad: "فارس عباد"
        case .ajamy: "أحمد العجمي"
        case .muhsinQasim: "محسن القاسم"
        case .juhany: "عبد الله الجهني"
        case .bukhatir: "صلاح بوخاطر"
        case .budair: "صلاح البدير"
        case .aliJaber: "علي جابر"
        case .banna: "محمود علي البنا"
        case .matroud: "عبد الله المطرود"
        case .abdulKareem: "محمد عبد الكريم"
        case .husaryMuallim: "الحصري (المعلّم)"
        case .mustafaIsmail: "مصطفى إسماعيل"
        case .khalidQahtani: "خالد القحطاني"
        case .sahlYassin: "سهل ياسين"
        case .suesy: "علي حجاج السويسي"
        case .neana: "أحمد نعينع"
        case .alaqimy: "أكرم العلاقمي"
        case .tunaiji: "خليفة الطنيجي"
        case .akhdar: "إبراهيم الأخضر"
        case .alili: "عزيز عليلي"
        }
    }

    /// Country flag emoji (reciter's homeland); empty when not certain.
    public var flag: String {
        switch self {
        case .alafasy: "🇰🇼"
        case .husary, .minshawi, .abdulBasit, .abdulBasitMujawwad,
             .minshawiMujawwad, .tablawi, .banna, .jibreel, .salamah: "🇪🇬"
        case .ghamdi, .sudais, .muaiqly, .shuraym, .ayyoub, .shatri, .rifai,
             .hudhaify, .dussary, .basfar, .qatami, .ajamy, .muhsinQasim,
             .juhany, .budair, .aliJaber, .matroud: "🇸🇦"
        case .sowaid: "🇸🇾"
        case .faresAbbad: "🇾🇪"
        case .bukhatir: "🇦🇪"
        case .abdulKareem: ""
        case .husaryMuallim: "🇪🇬"
        case .mustafaIsmail: "🇪🇬"
        case .khalidQahtani: "🇸🇦"
        case .sahlYassin: "🇸🇦"
        case .suesy: "🇪🇬"
        case .neana: "🇪🇬"
        case .alaqimy: "🇾🇪"
        case .tunaiji: "🇦🇪"
        case .akhdar: "🇸🇦"
        case .alili: "🇧🇦"
        }
    }

    /// Quran Foundation recitation id with word-level timing segments
    /// (verified 2026-09-01); nil = follow-along unavailable.
    public var qfTimingId: Int? {
        switch self {
        case .alafasy: 7
        case .husary: 6
        case .minshawi: 9
        case .abdulBasit: 2
        case .shatri: 4
        case .sudais: 3
        case .shuraym: 10
        case .rifai: 5
        case .dussary: 97
        default: nil
        }
    }

    /// Legacy accessor (English).
    public var displayName: String { englishName }

    public func displayName(arabicUI: Bool) -> String {
        arabicUI ? arabicName : englishName
    }

    /// EveryAyah folder name.
    var folder: String {
        switch self {
        case .alafasy: "Alafasy_128kbps"
        case .husary: "Husary_128kbps"
        case .minshawi: "Minshawy_Murattal_128kbps"
        case .abdulBasit: "Abdul_Basit_Murattal_192kbps"
        case .ghamdi: "Ghamadi_40kbps"
        case .sudais: "Abdurrahmaan_As-Sudais_192kbps"
        case .muaiqly: "Maher_AlMuaiqly_64kbps"
        case .shuraym: "Saood_ash-Shuraym_128kbps"
        case .ayyoub: "Muhammad_Ayyoub_128kbps"
        case .shatri: "Abu_Bakr_Ash-Shaatree_128kbps"
        case .rifai: "Hani_Rifai_192kbps"
        // Folders below verified reachable on BOTH hosts (2026-08-31).
        case .hudhaify: "Hudhaify_128kbps"
        case .jibreel: "Muhammad_Jibreel_128kbps"
        case .dussary: "Yasser_Ad-Dussary_128kbps"
        case .basfar: "Abdullah_Basfar_192kbps"
        case .sowaid: "Ayman_Sowaid_64kbps"
        case .tablawi: "Mohammad_al_Tablaway_128kbps"
        case .abdulBasitMujawwad: "Abdul_Basit_Mujawwad_128kbps"
        case .minshawiMujawwad: "Minshawy_Mujawwad_192kbps"
        // Below: verified on everyayah.com 2026-08-31; salamah also on the
        // mirror. The rest rely on the local cache once played.
        case .salamah: "Yaser_Salamah_128kbps"
        case .qatami: "Nasser_Alqatami_128kbps"
        case .faresAbbad: "Fares_Abbad_64kbps"
        case .ajamy: "Ahmed_ibn_Ali_al-Ajamy_64kbps_QuranExplorer.Com"
        case .muhsinQasim: "Muhsin_Al_Qasim_192kbps"
        case .juhany: "Abdullaah_3awwaad_Al-Juhaynee_128kbps"
        case .bukhatir: "Salaah_AbdulRahman_Bukhatir_128kbps"
        case .budair: "Salah_Al_Budair_128kbps"
        case .aliJaber: "Ali_Jaber_64kbps"
        case .banna: "mahmoud_ali_al_banna_32kbps"
        case .matroud: "Abdullah_Matroud_128kbps"
        case .abdulKareem: "Muhammad_AbdulKareem_128kbps"
        case .husaryMuallim: "Husary_Muallim_128kbps"
        case .mustafaIsmail: "Mustafa_Ismail_48kbps"
        case .khalidQahtani: "Khaalid_Abdullaah_al-Qahtaanee_192kbps"
        case .sahlYassin: "Sahl_Yassin_128kbps"
        case .suesy: "Ali_Hajjaj_AlSuesy_128kbps"
        case .neana: "Ahmed_Neana_128kbps"
        case .alaqimy: "Akram_AlAlaqimy_128kbps"
        case .tunaiji: "khalefa_al_tunaiji_64kbps"
        case .akhdar: "Ibrahim_Akhdar_32kbps"
        case .alili: "aziz_alili_128kbps"
        }
    }

    /// Remote URL for one ayah, e.g. .../Alafasy_128kbps/001001.mp3
    public func url(surah: Int, ayah: Int) -> URL {
        urls(surah: surah, ayah: ayah)[0]
    }

    /// Candidate sources in order — EveryAyah, then the quranicaudio mirror
    /// (identical layout). Playback falls through automatically.
    public func urls(surah: Int, ayah: Int) -> [URL] {
        let file = "\(folder)/\(Self.fileName(surah: surah, ayah: ayah))"
        return [
            URL(string: "https://everyayah.com/data/\(file)")!,
            URL(string: "https://mirrors.quranicaudio.com/everyayah/\(file)")!,
        ]
    }

    public static func fileName(surah: Int, ayah: Int) -> String {
        String(format: "%03d%03d.mp3", surah, ayah)
    }
}
