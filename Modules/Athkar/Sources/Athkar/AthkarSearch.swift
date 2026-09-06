import ContentDB
import Foundation

/// Search over the bundled Hisn al-Muslim data: chapter titles (Arabic and
/// English) *and* the dhikr text itself, diacritic-insensitive through the
/// shared `ArabicSearch` folding used by the Quran search.
///
/// Cost: 132 chapters / 267 athkar / ~50 KB of text. The folded form of every
/// dhikr is built once when the index is created (screen load), so a keystroke
/// only scans pre-folded scalars — well under a frame, hence no off-main hop.
public struct AthkarSearchIndex: Sendable {
    /// One dhikr that matched, with the window of text that matched.
    public struct ItemMatch: Identifiable, Hashable, Sendable {
        public let category: DhikrCategory
        public let dhikr: Dhikr
        /// Position of the dhikr inside its category (for scroll targeting).
        public let itemIndex: Int
        public let snippet: ArabicSearch.Snippet
        public let tier: ArabicSearch.MatchTier
        public var id: String { "\(category.id)#\(itemIndex)" }
    }

    public struct Results: Sendable {
        public let categories: [DhikrCategory]
        public let items: [ItemMatch]
        public var isEmpty: Bool { categories.isEmpty && items.isEmpty }
    }

    private struct Entry: Sendable {
        let category: DhikrCategory
        let itemIndex: Int
        let dhikr: Dhikr
        let foldedText: [UnicodeScalar]
        /// Reference/source line, when the data ever carries one.
        let foldedReference: [UnicodeScalar]
    }

    private let categories: [DhikrCategory]
    private let foldedTitles: [(category: DhikrCategory, arabic: [UnicodeScalar], english: [UnicodeScalar])]
    private let entries: [Entry]

    public init(categories: [DhikrCategory]) {
        self.categories = categories
        foldedTitles = categories.map {
            (category: $0,
             arabic: Array(ArabicSearch.fold($0.category).unicodeScalars),
             english: Array(ArabicSearch.fold($0.categoryEn ?? "").unicodeScalars))
        }
        entries = categories.flatMap { category in
            category.items.enumerated().map { index, dhikr in
                Entry(category: category,
                      itemIndex: index,
                      dhikr: dhikr,
                      foldedText: Array(ArabicSearch.fold(dhikr.text).unicodeScalars),
                      foldedReference: Array(ArabicSearch.fold(dhikr.reference ?? "").unicodeScalars))
            }
        }
    }

    /// Chapters whose title matches, then individual athkar whose text (or
    /// reference) matches — best matches first inside each group.
    public func search(_ query: String) -> Results {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return Results(categories: categories, items: []) }

        let titleHits: [(DhikrCategory, ArabicSearch.MatchTier)] = foldedTitles.compactMap {
            let arabic = ArabicSearch.tier(of: trimmed, inFolded: $0.arabic)
            let english = ArabicSearch.tier(of: trimmed, inFolded: $0.english)
            guard let tier = [arabic, english].compactMap({ $0 }).min() else { return nil }
            return ($0.category, tier)
        }

        // (ordinal, match) so the sort below can fall back to data order —
        // Swift's sort is not stable.
        var items: [(ordinal: Int, match: ItemMatch)] = []
        for (ordinal, entry) in entries.enumerated() {
            let tier = ArabicSearch.tier(of: trimmed, inFolded: entry.foldedText)
                ?? ArabicSearch.tier(of: trimmed, inFolded: entry.foldedReference)
            guard let tier else { continue }
            // The snippet comes from the display text (or the reference when
            // only that matched), so the highlight lands on what is shown.
            let snippet = ArabicSearch.snippet(for: entry.dhikr.text, matching: trimmed)
                ?? entry.dhikr.reference.flatMap { ArabicSearch.snippet(for: $0, matching: trimmed) }
                ?? ArabicSearch.Snippet(before: "", match: entry.dhikr.text, after: "",
                                        truncatedStart: false, truncatedEnd: false)
            items.append((ordinal, ItemMatch(category: entry.category, dhikr: entry.dhikr,
                                             itemIndex: entry.itemIndex,
                                             snippet: snippet, tier: tier)))
        }

        return Results(
            categories: titleHits
                .sorted { $0.1 != $1.1 ? $0.1 < $1.1 : index(of: $0.0) < index(of: $1.0) }
                .map(\.0),
            items: items
                .sorted {
                    $0.match.tier != $1.match.tier
                        ? $0.match.tier < $1.match.tier
                        : $0.ordinal < $1.ordinal
                }
                .map(\.match))
    }

    private func index(of category: DhikrCategory) -> Int {
        categories.firstIndex(of: category) ?? 0
    }
}
