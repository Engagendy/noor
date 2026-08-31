import GRDB

public struct Surah: Codable, Identifiable, Hashable, FetchableRecord, TableRecord {
    public static let databaseTableName = "surah"

    public let id: Int
    public let nameArabic: String
    public let nameTransliterated: String
    public let nameEnglish: String
    public let ayahCount: Int
    public let revelationType: String
    public let revelationOrder: Int

    public var isMeccan: Bool { revelationType == "Meccan" }

    enum CodingKeys: String, CodingKey {
        case id
        case nameArabic = "name_arabic"
        case nameTransliterated = "name_transliterated"
        case nameEnglish = "name_english"
        case ayahCount = "ayah_count"
        case revelationType = "revelation_type"
        case revelationOrder = "revelation_order"
    }
}

public struct Verse: Codable, Hashable, Identifiable, FetchableRecord, TableRecord {
    public static let databaseTableName = "verse"

    public let surahId: Int
    public let ayah: Int
    public let text: String

    public var id: String { "\(surahId):\(ayah)" }

    enum CodingKeys: String, CodingKey {
        case surahId = "surah_id"
        case ayah
        case text
    }
}
