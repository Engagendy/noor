import ContentDB
import Foundation

/// Search inside one matn: every hemistich of every line, folded once when
/// the index is built so a keystroke only scans pre-folded scalars.
///
/// The matns are vowelled (that is the whole point of a tajweed matn — see
/// `MatnTests`), and people type bare letters, so matching goes through the
/// shared `ArabicSearch` folding used by the Quran and athkar searches.
/// Nothing here re-implements folding, ranking or snippets: it is all
/// `FoldedCorpus`.
///
/// Cost: 60 lines / ~3 KB per matn. Building the index is free, so the
/// reader builds it on appear and searches on the main thread.
public struct MatnSearchIndex: Sendable {
    /// One line that matched, with the window of text that matched.
    public struct Hit: Identifiable, Sendable {
        public let line: Matn.Line
        public let snippet: ArabicSearch.Snippet
        public let tier: ArabicSearch.MatchTier
        public var id: Int { line.number }
    }

    private let corpus: FoldedCorpus<Int>
    private let lines: [Int: Matn.Line]

    public init(matn: Matn) {
        // Two documents per line (صدر then عجز) so a snippet is a window on
        // the hemistich the reader actually shows, never a stitched-together
        // string that exists nowhere in the poem.
        corpus = FoldedCorpus(documents: matn.lines.flatMap { line in
            [FoldedCorpus<Int>.Document(key: line.number, text: line.first),
             FoldedCorpus<Int>.Document(key: line.number, text: line.second)]
        })
        lines = Dictionary(uniqueKeysWithValues: matn.lines.map { ($0.number, $0) })
    }

    public var lineCount: Int { lines.count }

    /// Matching lines, best tier first, line order inside a tier. A line
    /// whose two hemistichs both match appears once, at its better tier.
    public func search(_ query: String) -> [Hit] {
        var seen = Set<Int>()
        var hits: [Hit] = []
        for hit in corpus.search(query, limit: 400) {
            guard let line = lines[hit.key], seen.insert(hit.key).inserted else { continue }
            hits.append(Hit(line: line, snippet: hit.snippet, tier: hit.tier))
        }
        return hits
    }
}
