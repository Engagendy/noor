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
        case .muaiqly: "MaherAlMuaiqly128kbps"
        case .shuraym: "Saood_ash-Shuraym_128kbps"
        case .ayyoub: "Muhammad_Ayyoub_128kbps"
        case .shatri: "Abu_Bakr_Ash-Shaatree_128kbps"
        case .rifai: "Hani_Rifai_192kbps"
        }
    }

    /// Remote URL for one ayah, e.g. .../Alafasy_128kbps/001001.mp3
    public func url(surah: Int, ayah: Int) -> URL {
        URL(string: "https://everyayah.com/data/\(folder)/\(Self.fileName(surah: surah, ayah: ayah))")!
    }

    public static func fileName(surah: Int, ayah: Int) -> String {
        String(format: "%03d%03d.mp3", surah, ayah)
    }
}
