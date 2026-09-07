import ContentDB
import DesignSystem
import SwiftUI

/// One result of a Learn-area search, whatever it came from.
public struct LearnSearchHit: Identifiable {
    public let id: String
    /// The window of text that matched, ready for `HighlightedSnippet` —
    /// the same snippet type the Quran and athkar searches show.
    public let snippet: ArabicSearch.Snippet
    /// The line under the snippet saying where it is (surah + ayah, matn
    /// line number). Already display-ready — it is rendered verbatim.
    public let reference: String
    /// Where tapping the result goes. Nil for a result that cannot be
    /// navigated to (nothing produces one today).
    public let route: LearnRoute?
    /// Arabic content is an `arabicBlock`; English tafsir is not.
    public let isArabic: Bool

    public init(id: String, snippet: ArabicSearch.Snippet, reference: String,
                route: LearnRoute?, isArabic: Bool = true) {
        self.id = id
        self.snippet = snippet
        self.reference = reference
        self.route = route
        self.isArabic = isArabic
    }
}

/// Results from ONE source (a matn, an edition of tafsir), so the hub can
/// group them and it is obvious what came from where.
public struct LearnSearchGroup: Identifiable {
    public let id: String
    /// Heading — the work's own name, rendered verbatim.
    public let title: String
    public let hits: [LearnSearchHit]
    /// Total matches before the display cap, so a truncated group can say so.
    public let totalHits: Int
    /// What this group could actually see, in the user's words, e.g.
    /// "Searching 12 of 114 surahs you have downloaded". Nil when the source
    /// is bundled and therefore complete (the matns).
    ///
    /// This is the honest part of the feature: a source cached per surah can
    /// only answer for what is on the device, and the user must be able to
    /// tell "no such word" from "not downloaded yet".
    public let coverage: String?
    /// True when the whole source was searched. A group that is not complete
    /// never presents "no matches" as a final answer.
    public let isComplete: Bool
    /// Control for widening the corpus, built by the host — the EXISTING
    /// tafsir pack row with its existing progress. Learn cannot build it
    /// (it must not import the Tafsir module), and there must not be a
    /// second download path, so the host hands it over as a view.
    public let footer: (() -> AnyView)?

    public init(id: String, title: String, hits: [LearnSearchHit], totalHits: Int? = nil,
                coverage: String? = nil, isComplete: Bool = true,
                footer: (() -> AnyView)? = nil) {
        self.id = id
        self.title = title
        self.hits = hits
        self.totalHits = totalHits ?? hits.count
        self.coverage = coverage
        self.isComplete = isComplete
        self.footer = footer
    }
}

/// Supplies Learn-area search results the Learn module cannot produce
/// itself — today the tafsir and غريب القرآن caches, which live in the
/// Tafsir module (CLAUDE.md §4: features never import each other, so the
/// host wires this up exactly as it wires `learnDestinations`).
@MainActor
public protocol LearnSearchProviding: AnyObject {
    /// Groups for `query`, already ranked and capped. Called on a debounce,
    /// and must NOT hit the network: the corpus is what has been downloaded.
    /// - Parameter arabicUI: the interface language, because the coverage
    ///   line and the references carry numerals, which are Arabic-Indic in
    ///   the Arabic interface as everywhere else in the app.
    func groups(for query: String, arabicUI: Bool) async -> [LearnSearchGroup]
}

private struct LearnSearchProviderKey: EnvironmentKey {
    static let defaultValue: LearnSearchProviding? = nil
}

public extension EnvironmentValues {
    var learnSearchProvider: LearnSearchProviding? {
        get { self[LearnSearchProviderKey.self] }
        set { self[LearnSearchProviderKey.self] = newValue }
    }
}

public extension View {
    /// Gives the learning area its cross-source search provider. Set it on
    /// the same view that declares `learnDestinations`, so both the pushed
    /// `LearnView` and a directly built one see it.
    func learnSearch(_ provider: LearnSearchProviding?) -> some View {
        environment(\.learnSearchProvider, provider)
    }
}

/// The shared `SearchResultRow` (DesignSystem, a leaf module that cannot see
/// ContentDB) taking the shared `ArabicSearch.Snippet` directly.
extension SearchResultRow {
    init(snippet: ArabicSearch.Snippet, reference: String,
         isArabic: Bool = true, font: Font = .noorScaled(16)) {
        self.init(before: snippet.before, match: snippet.match, after: snippet.after,
                  truncatedStart: snippet.truncatedStart, truncatedEnd: snippet.truncatedEnd,
                  reference: reference, isArabic: isArabic, font: font)
    }
}
