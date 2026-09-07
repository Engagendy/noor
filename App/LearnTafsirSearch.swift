import ContentDB
import Learn
import SwiftUI
import Tafsir

/// Supplies the Learn hub's search with the tafsir and غريب القرآن results
/// the Learn module cannot produce itself (it must not import a sibling
/// feature module — CLAUDE.md §4). The App target is the integration layer,
/// exactly as it is for `learnDestinations`.
///
/// Two rules shape this class:
///
/// 1. **It never fetches.** Search runs over the per-surah cache that is
///    already on the device. An offline-first app must not turn a keystroke
///    into a download, and a background fetch would also make results appear
///    and disappear under the user's finger. Widening the corpus is an
///    explicit tap on the pack row this class hands back as a group footer —
///    the SAME `TafsirService.downloadPack` the ayah sheet has always used.
/// 2. **It always states its coverage.** Its groups carry the "searching N
///    of 114 surahs you have downloaded" line, and a group is returned even
///    with zero hits while coverage is partial, so "no match" is never shown
///    as if the whole book had been searched.
@MainActor
final class LearnTafsirSearch: LearnSearchProviding {
    /// One long-lived service, so a pack download started from a search
    /// result keeps its progress when the results are dismissed.
    private let service = TafsirService()
    private var indexes: [String: TafsirSearchIndex] = [:]
    private var surahs: [Surah] = []

    /// Hits shown per group in the hub — the whole list is one tap away in
    /// the work's own screen, which the group footer says.
    private static let hitsPerGroup = 12

    /// The editions the hub searches: غريب القرآن (the reason this feature
    /// exists) and, when it is a different book, the tafsir edition the user
    /// reads. Searching all eight would index editions nobody opened.
    private var editions: [TafsirEdition] {
        var result = [TafsirEdition.gharib]
        let chosen = TafsirEdition.named(
            UserDefaults.standard.string(forKey: "tafsir.edition") ?? TafsirEdition.all[0].slug)
        if chosen.slug != TafsirEdition.gharib.slug { result.append(chosen) }
        return result
    }

    func groups(for query: String, arabicUI: Bool) async -> [LearnSearchGroup] {
        if surahs.isEmpty { surahs = (try? QuranDatabase().allSurahs()) ?? [] }
        var groups: [LearnSearchGroup] = []
        for edition in editions {
            let index = await index(for: edition)
            let hits = index.search(query, limit: Self.hitsPerGroup)
            let total = index.matchCount(query)
            // A group with no hits is still worth showing while coverage is
            // partial: the coverage line is the answer to "why nothing?".
            guard !hits.isEmpty || !index.coverage.isComplete else { continue }
            groups.append(LearnSearchGroup(
                id: "tafsir.\(edition.slug)",
                title: title(for: edition, arabicUI: arabicUI),
                hits: hits.map { hit in
                    LearnSearchHit(
                        id: "\(edition.slug)#\(hit.ref.surah):\(hit.ref.ayah)",
                        snippet: hit.snippet,
                        reference: reference(hit.ref, arabicUI: arabicUI),
                        route: .tafsir(.surah(slug: edition.slug, surah: hit.ref.surah,
                                              ayah: hit.ref.ayah)),
                        isArabic: edition.isArabic)
                },
                totalHits: total,
                coverage: index.coverage.summary(arabicUI: arabicUI),
                isComplete: index.coverage.isComplete,
                footer: index.coverage.isComplete ? nil : { [service] in
                    AnyView(TafsirPackRow(edition: edition, service: service, forSearch: true))
                }))
        }
        return groups
    }

    /// The folded index for one edition, built once and reused. It is
    /// rebuilt when the number of cached surahs has changed — i.e. after a
    /// pack download or after a surah was opened and cached — so the corpus
    /// and the coverage line can never go stale.
    private func index(for edition: TafsirEdition) async -> TafsirSearchIndex {
        let cached = TafsirService.cachedSurahNumbers(edition: edition).count
        if let existing = indexes[edition.slug], existing.coverage.searchedSurahs == cached {
            return existing
        }
        // Reading and folding a whole edition is megabytes of Arabic prose —
        // never on the main actor.
        let built = await Task.detached(priority: .userInitiated) {
            TafsirSearchIndex.build(edition: edition)
        }.value
        indexes[edition.slug] = built
        return built
    }

    private func title(for edition: TafsirEdition, arabicUI: Bool) -> String {
        if edition.slug == TafsirEdition.gharib.slug {
            return arabicUI ? "غريب القرآن — \(edition.displayName)"
                            : "Quranic word meanings — \(edition.displayName)"
        }
        return arabicUI ? "التفسير — \(edition.displayName)"
                        : "Tafsir — \(edition.displayName)"
    }

    /// "سورة البقرة · ٢:٢٥٥", RLM-prefixed so the mixed line lays out as one
    /// right-to-left paragraph (the same rule the Quran search follows).
    private func reference(_ ref: TafsirRef, arabicUI: Bool) -> String {
        let name = surahs.first { $0.id == ref.surah }?.displayName(arabicUI: arabicUI) ?? ""
        if arabicUI {
            return "\u{200F}\(name) · \(ref.surah.arabicIndic):\(ref.ayah.arabicIndic)"
        }
        return "\(name) · \(ref.surah):\(ref.ayah)"
    }
}
