import Foundation

/// A pre-folded body of text that can be searched repeatedly — the shared
/// engine behind every "search inside this content" screen that is not
/// backed by the Quran SQLite (the matns, tafsir, غريب القرآن).
///
/// It adds NO matching, ranking or snippet rules of its own: folding is
/// `ArabicSearch.fold`, the tier is `ArabicSearch.tier` and the window is
/// `ArabicSearch.snippet`, exactly as the Quran and athkar searches use
/// them. What it adds is the one thing those two hand-rolled separately —
/// folding the corpus ONCE at build time so a keystroke only scans
/// pre-folded scalars, plus the tier/ordinal ordering.
///
/// Cost note: the folded form is `[UnicodeScalar]` (4 bytes per scalar),
/// which is nothing for a matn (~3 KB) but is real for a whole tafsir
/// edition. Callers that index something unbounded should build with
/// `scalarBudget` and tell the user how much ended up searchable — see
/// `TafsirSearchIndex`, which reports its coverage rather than pretending.
public struct FoldedCorpus<Key: Hashable & Sendable>: Sendable {
    /// One searchable unit of text — an ayah's tafsir, one hemistich of a
    /// matn line. `key` is whatever the caller needs to navigate back to it.
    public struct Document: Sendable {
        public let key: Key
        public let text: String
        let folded: [UnicodeScalar]

        public init(key: Key, text: String) {
            self.key = key
            self.text = text
            self.folded = Array(ArabicSearch.fold(text).unicodeScalars)
        }
    }

    /// A document that matched, with the window of text that matched it.
    public struct Hit: Sendable {
        public let key: Key
        public let text: String
        public let snippet: ArabicSearch.Snippet
        public let tier: ArabicSearch.MatchTier
        /// Position of the document in the corpus, so callers can restore
        /// content order (mushaf order, line order) inside a tier.
        public let ordinal: Int
    }

    public private(set) var documents: [Document] = []
    /// Total folded scalars held — the memory the index is costing.
    public private(set) var scalarCount = 0

    public init() {}

    public init(documents: [Document]) {
        self.documents = documents
        scalarCount = documents.reduce(0) { $0 + $1.folded.count }
    }

    public var count: Int { documents.count }
    public var isEmpty: Bool { documents.isEmpty }

    /// Appends documents, refusing the ones that would push the corpus past
    /// `budget` folded scalars. Returns true when everything fit — a caller
    /// that gets false must not claim complete coverage.
    @discardableResult
    public mutating func append(_ newDocuments: [Document], budget: Int = .max) -> Bool {
        for document in newDocuments {
            guard scalarCount + document.folded.count <= budget else { return false }
            documents.append(document)
            scalarCount += document.folded.count
        }
        return true
    }

    /// Documents matching `query`, best tier first and content order inside a
    /// tier (whole word, then word prefix, then mid-word — the same tiers the
    /// Quran search shows). Snippets are built only for the results actually
    /// returned, since building one re-folds the whole document.
    public func search(_ query: String, limit: Int = 100) -> [Hit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ArabicSearch.fold(trimmed).isEmpty else { return [] }

        var matches: [(ordinal: Int, tier: ArabicSearch.MatchTier)] = []
        for (ordinal, document) in documents.enumerated() {
            guard let tier = ArabicSearch.tier(of: trimmed, inFolded: document.folded) else { continue }
            matches.append((ordinal, tier))
        }
        // Swift's sort is not stable, hence the explicit ordinal tiebreak.
        matches.sort { $0.tier != $1.tier ? $0.tier < $1.tier : $0.ordinal < $1.ordinal }

        return matches.prefix(limit).map { match in
            let document = documents[match.ordinal]
            let snippet = ArabicSearch.snippet(for: document.text, matching: trimmed)
                ?? ArabicSearch.Snippet(before: "", match: document.text, after: "",
                                        truncatedStart: false, truncatedEnd: false)
            return Hit(key: document.key, text: document.text, snippet: snippet,
                       tier: match.tier, ordinal: match.ordinal)
        }
    }

    /// How many documents match, without building any snippet — for a count
    /// badge next to a group heading.
    public func matchCount(_ query: String) -> Int {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ArabicSearch.fold(trimmed).isEmpty else { return 0 }
        return documents.reduce(into: 0) { total, document in
            if ArabicSearch.tier(of: trimmed, inFolded: document.folded) != nil { total += 1 }
        }
    }
}
