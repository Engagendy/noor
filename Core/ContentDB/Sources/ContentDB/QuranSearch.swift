import Foundation
import GRDB

public struct SearchHit: Identifiable, Hashable {
    public let surahId: Int
    public let ayah: Int
    public let text: String
    public var id: String { "\(surahId):\(ayah)" }
}

extension QuranDatabase {
    /// Search normalization ONLY (must mirror Tools/build_quran_db.py):
    /// strips tashkeel/quranic marks/tatweel, unifies alef/ya variants.
    public static func normalizeForSearch(_ query: String) -> String {
        var out = String.UnicodeScalarView()
        for scalar in query.unicodeScalars {
            let value = scalar.value
            if (0x064B...0x065F).contains(value) || (0x06D6...0x06ED).contains(value)
                || value == 0x0670 || value == 0x0640 {
                continue
            }
            switch value {
            case 0x0622, 0x0623, 0x0625, 0x0671:
                out.append(UnicodeScalar(0x0627)!)  // alef variants → bare alef
            case 0x0649:
                out.append(UnicodeScalar(0x064A)!)  // alef maqsura → ya
            default:
                out.append(scalar)
            }
        }
        return String(out)
    }

    /// Word search over the normalized index; returns the untouched display
    /// text of matching ayat.
    public func searchVerses(_ query: String, limit: Int = 80) throws -> [SearchHit] {
        let normalized = Self.normalizeForSearch(query)
            .trimmingCharacters(in: .whitespaces)
        guard normalized.count >= 2 else { return [] }
        let escaped = normalized
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        return try read { db in
            try Row.fetchAll(db, sql: """
                SELECT v.surah_id, v.ayah, v.text
                FROM verse_search s
                JOIN verse v ON v.surah_id = s.surah_id AND v.ayah = s.ayah
                WHERE s.text_normalized LIKE ? ESCAPE '\\'
                ORDER BY v.surah_id, v.ayah
                LIMIT ?
                """, arguments: ["%\(escaped)%", limit])
            .map { SearchHit(surahId: $0["surah_id"], ayah: $0["ayah"], text: $0["text"]) }
        }
    }
}
