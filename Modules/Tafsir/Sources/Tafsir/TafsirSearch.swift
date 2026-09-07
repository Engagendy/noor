import ContentDB
import DesignSystem
import Foundation

/// One ayah of one edition — where a tafsir/gharib search result lives.
public struct TafsirRef: Hashable, Sendable {
    public let surah: Int
    public let ayah: Int

    public init(surah: Int, ayah: Int) {
        self.surah = surah
        self.ayah = ayah
    }
}

/// How much of an edition a search could actually see.
///
/// This exists because the honest answer matters more than the feature:
/// tafsir and غريب القرآن are cached per surah, so a search over them is a
/// search over a DOWNLOADED SUBSET. Every screen that searches an edition
/// shows this, so "no result" can never be mistaken for "no such word".
public struct TafsirCoverage: Equatable, Sendable {
    /// Surahs whose whole bundle is on disk and was indexed.
    public let searchedSurahs: Int
    /// Surahs in the Quran — 114, always.
    public let totalSurahs: Int
    /// Ayat actually indexed (word-meaning editions gloss only some ayat, so
    /// this is far below the surahs' ayah count and that is expected).
    public let entries: Int
    /// True when the scalar budget stopped the index short of the surahs on
    /// disk — the count above is then still exact, it just is not everything
    /// that was downloaded. Only a giant edition (Tabari, Qurtubi) can hit it.
    public let budgetReached: Bool

    public var isComplete: Bool { searchedSurahs >= totalSurahs && !budgetReached }

    public init(searchedSurahs: Int, totalSurahs: Int = 114, entries: Int,
                budgetReached: Bool = false) {
        self.searchedSurahs = searchedSurahs
        self.totalSurahs = totalSurahs
        self.entries = entries
        self.budgetReached = budgetReached
    }
}

public extension TafsirCoverage {
    /// The coverage line the user reads, e.g. "Searching 12 of 114 surahs
    /// you have downloaded". Built here rather than in the string catalog
    /// because the digits must be Arabic-Indic in the Arabic interface, the
    /// same rule the surah rows and the matn footer follow.
    ///
    /// It is shown whenever an edition is searched, complete or not — a
    /// partial corpus must never be able to pass for the whole book.
    func summary(arabicUI: Bool) -> String {
        if arabicUI {
            return isComplete
                ? "البحث في \(totalSurahs.arabicIndic) سورة — التفسير كامل على جهازك"
                : "البحث في \(searchedSurahs.arabicIndic) من \(totalSurahs.arabicIndic) سورة نزّلتها على جهازك"
        }
        return isComplete
            ? "Searching all \(totalSurahs) surahs — this edition is fully downloaded"
            : "Searching \(searchedSurahs) of \(totalSurahs) surahs you have downloaded"
    }
}

/// Search over the tafsir already cached on this device — the same per-ayah
/// cache `TafsirService.load` / `loadSurah` fill. It NEVER fetches: an
/// offline-first app must not turn a keystroke into a network request, so
/// the corpus is exactly what has been downloaded and the UI says how much
/// that is (`coverage`). Downloading more is the user's explicit choice,
/// through the one existing `TafsirService.downloadPack`.
public struct TafsirSearchIndex: Sendable {
    public let edition: TafsirEdition
    public let coverage: TafsirCoverage
    private let corpus: FoldedCorpus<TafsirRef>

    /// One glossed ayah that matched.
    public struct Hit: Identifiable, Sendable {
        public let ref: TafsirRef
        public let text: String
        public let snippet: ArabicSearch.Snippet
        public let tier: ArabicSearch.MatchTier
        public var id: TafsirRef { ref }
    }

    /// Roughly 24 MB of folded scalars. The gharib and Muyassar editions are
    /// a fraction of this; only the very large commentaries can reach it, and
    /// when they do `coverage.budgetReached` makes the shortfall visible
    /// instead of silently searching part of the edition.
    public static let scalarBudget = 6_000_000

    private init(edition: TafsirEdition, corpus: FoldedCorpus<TafsirRef>,
                 coverage: TafsirCoverage) {
        self.edition = edition
        self.corpus = corpus
        self.coverage = coverage
    }

    public static func empty(edition: TafsirEdition) -> TafsirSearchIndex {
        TafsirSearchIndex(edition: edition, corpus: FoldedCorpus(),
                          coverage: TafsirCoverage(searchedSurahs: 0, entries: 0))
    }

    /// Builds the index from disk. Reads every cached surah of the edition
    /// and folds it once — hundreds of small files and megabytes of Arabic
    /// prose for a full edition, so this is `nonisolated` and callers run it
    /// off the main actor (`Task.detached`), never inside a view update.
    public static func build(edition: TafsirEdition,
                             budget: Int = scalarBudget) -> TafsirSearchIndex {
        var corpus = FoldedCorpus<TafsirRef>()
        var surahs = 0
        var budgetReached = false
        for surah in TafsirService.cachedSurahNumbers(edition: edition) {
            if Task.isCancelled { break }
            let entries = TafsirService.cachedEntries(edition: edition, surah: surah)
            let documents = entries.map {
                FoldedCorpus<TafsirRef>.Document(
                    key: TafsirRef(surah: surah, ayah: $0.ayah), text: $0.text)
            }
            guard corpus.append(documents, budget: budget) else {
                budgetReached = true
                break
            }
            surahs += 1
        }
        return TafsirSearchIndex(
            edition: edition, corpus: corpus,
            coverage: TafsirCoverage(searchedSurahs: surahs, entries: corpus.count,
                                     budgetReached: budgetReached))
    }

    /// Matching ayat, best tier first and mushaf order inside a tier.
    public func search(_ query: String, limit: Int = 100) -> [Hit] {
        corpus.search(query, limit: limit).map {
            Hit(ref: $0.key, text: $0.text, snippet: $0.snippet, tier: $0.tier)
        }
    }

    /// Total matches, ignoring the display cap — so a capped list can say
    /// how many it is not showing rather than dropping them silently.
    public func matchCount(_ query: String) -> Int { corpus.matchCount(query) }

    public var isEmpty: Bool { corpus.isEmpty }
}

public extension TafsirService {
    /// The surahs of this edition whose whole bundle is cached, in order.
    /// A surah half-filled by tapping single ayat in the reader is NOT one of
    /// them — searching it would look like a complete surah and quietly miss
    /// most of it (this is exactly what the `.complete` marker is for).
    nonisolated static func cachedSurahNumbers(edition: TafsirEdition) -> [Int] {
        (1...114).filter { isSurahCached(edition: edition, surah: $0) }
    }

    /// Every cached ayah of one surah, ayah order. Public so the search index
    /// reads the SAME cache the reader fills — there is one tafsir cache.
    nonisolated static func cachedEntries(edition: TafsirEdition, surah: Int) -> [Entry] {
        cachedSurah(edition: edition, surah: surah)
    }
}
