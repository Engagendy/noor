import Foundation
import GRDB

/// One word (or ayah-end marker) on a Madani mushaf page, with its QCF v1
/// glyph, Uthmani text, and English word-by-word translation.
public struct PageWord: Codable, Hashable, Sendable, FetchableRecord {
    public let page: Int
    public let line: Int
    public let surahId: Int
    public let ayah: Int
    public let position: Int
    public let glyph: String
    public let glyphV2: String
    public let text: String
    public let translation: String
    public let charType: String

    public var isAyahEnd: Bool { charType == "end" }

    enum CodingKeys: String, CodingKey {
        case page, line, ayah, position, glyph, text, translation
        case glyphV2 = "glyph_v2"
        case surahId = "surah_id"
        case charType = "char_type"
    }
}

/// A rendered line of a mushaf page: glyphs concatenated in reading order,
/// plus which ayat appear on the line (for tap targeting).
public struct PageLine: Identifiable, Hashable, Sendable {
    public struct Ref: Hashable, Sendable {
        public let surahId: Int
        public let ayah: Int
    }

    public let line: Int
    public let glyphs: String
    /// QCF v2 glyphs (the exact printed Madani mushaf typeface).
    public let glyphsV2: String
    public let ayahRefs: [Ref]
    public var id: Int { line }
}

/// Read-only access to the bundled page-layout DB (built by
/// Tools/build_page_layout.py from the quran.com layout data).
public final class PageLayoutDatabase: Sendable {
    private let queue: DatabaseQueue

    public init() throws {
        guard let url = Bundle.module.url(forResource: "page_layout", withExtension: "sqlite") else {
            throw QuranDatabaseError.missingDatabase
        }
        var config = Configuration()
        config.readonly = true
        queue = try DatabaseQueue(path: url.path, configuration: config)
    }

    /// The QCF glyph lines of one page (line numbers are sparse; surah-header
    /// ornament lines are not word lines and are omitted).
    public func lines(page: Int) throws -> [PageLine] {
        try queue.read { db in
            let words = try PageWord.fetchAll(db, sql: """
                SELECT * FROM page_word WHERE page = ?
                ORDER BY line, surah_id, ayah, position
                """, arguments: [page])
            return Dictionary(grouping: words, by: \.line)
                .map { line, words in
                    var refs: [PageLine.Ref] = []
                    for word in words {
                        let ref = PageLine.Ref(surahId: word.surahId, ayah: word.ayah)
                        if refs.last != ref { refs.append(ref) }
                    }
                    return PageLine(
                        line: line,
                        glyphs: words.map(\.glyph).joined(),
                        glyphsV2: words.map(\.glyphV2).joined(),
                        ayahRefs: refs)
                }
                .sorted { $0.line < $1.line }
        }
    }

    /// Words of one ayah for word-by-word display (markers excluded).
    public func words(surahId: Int, ayah: Int) throws -> [PageWord] {
        try queue.read { db in
            try PageWord.fetchAll(db, sql: """
                SELECT * FROM page_word
                WHERE surah_id = ? AND ayah = ? AND char_type = 'word'
                ORDER BY position
                """, arguments: [surahId, ayah])
        }
    }

    public func wordCount() throws -> Int {
        try queue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM page_word") ?? 0
        }
    }
}
