import Foundation
import GRDB

public struct SearchHit: Identifiable, Hashable {
    public let surahId: Int
    public let ayah: Int
    /// Untouched display text of the ayah (fully vocalized).
    public let text: String
    /// How the query sat in the ayah — drives the result ordering.
    public let tier: ArabicSearch.MatchTier
    /// Window of the ayah around the match, for in-context display.
    public let snippet: ArabicSearch.Snippet?
    public var id: String { "\(surahId):\(ayah)" }

    public init(surahId: Int, ayah: Int, text: String,
                tier: ArabicSearch.MatchTier = .partial,
                snippet: ArabicSearch.Snippet? = nil) {
        self.surahId = surahId
        self.ayah = ayah
        self.text = text
        self.tier = tier
        self.snippet = snippet
    }
}

/// A page of verse hits plus whether the DB had more to give — the UI must
/// say so rather than silently dropping matches.
public struct VerseSearchResults: Hashable {
    public let hits: [SearchHit]
    /// True when the result cap was reached and more ayat match.
    public let truncated: Bool
    /// The cap that was applied (what `hits.count` was limited to).
    public let cap: Int

    public init(hits: [SearchHit], truncated: Bool, cap: Int) {
        self.hits = hits
        self.truncated = truncated
        self.cap = cap
    }

    public static let empty = VerseSearchResults(hits: [], truncated: false, cap: 0)
}

extension QuranDatabase {
    /// Search normalization ONLY (must mirror Tools/build_quran_db.py):
    /// strips tashkeel/quranic marks/tatweel, unifies alef/ya variants.
    /// Thin wrapper over the shared `ArabicSearch.fold` — case and digit
    /// folding are off so this stays byte-identical to the built column.
    public static func normalizeForSearch(_ query: String) -> String {
        ArabicSearch.fold(query, caseInsensitive: false, foldingDigits: false)
    }

    /// Word search over the normalized index; returns the untouched display
    /// text of matching ayat, best matches first.
    public func searchVerses(_ query: String, limit: Int = 300) throws -> [SearchHit] {
        try searchVerseResults(query, limit: limit).hits
    }

    /// Ranked word search. Whole-word matches come first, then matches that
    /// start a word, then mid-word substrings; mushaf order inside each tier.
    ///
    /// The tiering happens in SQL so the cap keeps the *best* matches rather
    /// than the first ones in mushaf order; the snippet and the final tier are
    /// then recomputed on the display text, which is what the user sees.
    public func searchVerseResults(_ query: String, limit: Int = 300) throws -> VerseSearchResults {
        let normalized = Self.normalizeForSearch(query)
            .trimmingCharacters(in: .whitespaces)
        guard normalized.count >= 2 else { return .empty }
        let escaped = normalized
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        // `verse_search.text_normalized` holds only Arabic letters and single
        // spaces, so padding with spaces gives exact word boundaries.
        let rows = try read { db in
            try Row.fetchAll(db, sql: """
                SELECT v.surah_id AS surah_id, v.ayah AS ayah, v.text AS text,
                       CASE
                         WHEN (' ' || s.text_normalized || ' ') LIKE ? ESCAPE '\\' THEN 0
                         WHEN (' ' || s.text_normalized || ' ') LIKE ? ESCAPE '\\' THEN 1
                         ELSE 2
                       END AS tier
                FROM verse_search s
                JOIN verse v ON v.surah_id = s.surah_id AND v.ayah = s.ayah
                WHERE s.text_normalized LIKE ? ESCAPE '\\'
                ORDER BY tier, v.surah_id, v.ayah
                LIMIT ?
                """, arguments: ["% \(escaped) %", "% \(escaped)%",
                                 "%\(escaped)%", limit + 1])
        }
        let truncated = rows.count > limit
        let hits: [SearchHit] = rows.prefix(limit).map { row in
            let text: String = row["text"]
            let match = ArabicSearch.firstMatch(of: query, in: text)
            return SearchHit(
                surahId: row["surah_id"],
                ayah: row["ayah"],
                text: text,
                tier: match?.tier ?? ArabicSearch.MatchTier(rawValue: row["tier"]) ?? .partial,
                snippet: ArabicSearch.snippet(for: text, matching: query))
        }
        .sorted {
            if $0.tier != $1.tier { return $0.tier < $1.tier }
            if $0.surahId != $1.surahId { return $0.surahId < $1.surahId }
            return $0.ayah < $1.ayah
        }
        return VerseSearchResults(hits: hits, truncated: truncated, cap: limit)
    }
}
