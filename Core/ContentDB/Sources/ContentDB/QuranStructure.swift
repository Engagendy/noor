import Foundation
import GRDB

/// A mushaf division start point (juz, hizb quarter, or page).
public struct DivisionStart: Codable, Hashable, Sendable, FetchableRecord {
    public let idx: Int
    public let surahId: Int
    public let ayah: Int

    enum CodingKeys: String, CodingKey {
        case idx
        case surahId = "surah_id"
        case ayah
    }
}

/// Madani mushaf structure: 30 ajza, 240 hizb quarters, 604 pages, 15 sajdas.
/// Loaded once; lookups are binary searches over the sorted start lists.
public struct QuranStructure: Sendable {
    public let juzStarts: [DivisionStart]
    public let quarterStarts: [DivisionStart]
    public let pageStarts: [DivisionStart]

    /// Global sort key for (surah, ayah) comparisons.
    private static func key(_ surahId: Int, _ ayah: Int) -> Int {
        surahId * 1000 + ayah
    }

    private static func division(of starts: [DivisionStart], surahId: Int, ayah: Int) -> Int {
        let target = key(surahId, ayah)
        var low = 0, high = starts.count - 1, answer = 1
        while low <= high {
            let mid = (low + high) / 2
            if key(starts[mid].surahId, starts[mid].ayah) <= target {
                answer = starts[mid].idx
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return answer
    }

    public func juz(surahId: Int, ayah: Int) -> Int {
        Self.division(of: juzStarts, surahId: surahId, ayah: ayah)
    }

    public func page(surahId: Int, ayah: Int) -> Int {
        Self.division(of: pageStarts, surahId: surahId, ayah: ayah)
    }

    /// Non-nil when this exact ayah begins a hizb quarter (ربع الحزب).
    /// Quarter 1-based global index (1...240): quarter 5 = start of hizb 2.
    public func quarterIndex(startingAtSurah surahId: Int, ayah: Int) -> Int? {
        quarterStarts.first { $0.surahId == surahId && $0.ayah == ayah }?.idx
    }

    /// Human division of a global quarter index: (juzNumber, hizbInJuz 1-2, quarterInHizb 1-4).
    public static func quarterDescription(_ quarter: Int) -> (hizb: Int, quarterInHizb: Int) {
        ((quarter - 1) / 4 + 1, (quarter - 1) % 4 + 1)
    }
}

extension QuranDatabase {
    public func structure() throws -> QuranStructure {
        try read { db in
            QuranStructure(
                juzStarts: try DivisionStart.fetchAll(
                    db, sql: "SELECT idx, surah_id, ayah FROM juz_start ORDER BY idx"),
                quarterStarts: try DivisionStart.fetchAll(
                    db, sql: "SELECT idx, surah_id, ayah FROM hizb_quarter_start ORDER BY idx"),
                pageStarts: try DivisionStart.fetchAll(
                    db, sql: "SELECT idx, surah_id, ayah FROM page_start ORDER BY idx"))
        }
    }
}
