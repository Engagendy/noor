import CryptoKit
import Foundation
import GRDB

/// Read-only access to the bundled Quran SQLite (Tanzil Uthmani text).
///
/// The Quran text is sacred: this type opens the database strictly read-only
/// and verifies a SHA-256 checksum over every verse before the text is served.
public final class QuranDatabase: Sendable {
    /// SHA-256 over all 6236 verse lines ("surah|ayah|text\n"), computed by
    /// Tools/build_quran_db.py from the verbatim Tanzil source.
    public static let expectedTextChecksum =
        "fbf5e7dbcb58abc3a78ef681a373dc55d79353a4901b704f0048ac5b7d0e04f3"

    private let queue: DatabaseQueue

    public init() throws {
        guard let url = Bundle.module.url(forResource: "quran", withExtension: "sqlite") else {
            throw QuranDatabaseError.missingDatabase
        }
        var config = Configuration()
        config.readonly = true
        self.queue = try DatabaseQueue(path: url.path, configuration: config)
    }

    /// Recomputes the text checksum from the database and compares it against
    /// the build-time value. Call at startup; a mismatch means the bundle is
    /// corrupted and the app must not display the text.
    public func verifyIntegrity() throws {
        let checksum = try queue.read { db in
            var hasher = SHA256()
            let rows = try Row.fetchCursor(
                db, sql: "SELECT surah_id, ayah, text FROM verse ORDER BY surah_id, ayah")
            while let row = try rows.next() {
                let line = "\(row["surah_id"] as Int)|\(row["ayah"] as Int)|\(row["text"] as String)\n"
                hasher.update(data: Data(line.utf8))
            }
            return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        }
        guard checksum == Self.expectedTextChecksum else {
            throw QuranDatabaseError.checksumMismatch(actual: checksum)
        }
    }

    public func allSurahs() throws -> [Surah] {
        try queue.read { try Surah.order(Column("id")).fetchAll($0) }
    }

    public func verses(surahId: Int) throws -> [Verse] {
        try queue.read {
            try Verse.filter(Column("surah_id") == surahId)
                .order(Column("ayah"))
                .fetchAll($0)
        }
    }

    public func verseCount() throws -> Int {
        try queue.read { try Verse.fetchCount($0) }
    }
}

public enum QuranDatabaseError: Error, Equatable {
    case missingDatabase
    case checksumMismatch(actual: String)
}
