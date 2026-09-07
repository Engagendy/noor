import ContentDB
import Learn
import Tafsir
import XCTest

/// The Learn-area search: matching inside the bundled matns, the shared
/// ranking order, and — the part that matters most — that the tafsir /
/// غريب القرآن coverage figure is the truth about what was searched.
///
/// Every Arabic query here is derived from the bundled data at runtime; no
/// Arabic string (and certainly no Quranic text) is typed into this file.
final class LearnSearchTests: XCTestCase {
    private var matns: [Matn]!

    override func setUpWithError() throws {
        try super.setUpWithError()
        matns = MatnStore.load()
        XCTAssertFalse(matns.isEmpty, "the bundled matn JSON must load")
    }

    // MARK: - Undiacriticised typing against vowelled matn text

    /// The matns are fully vowelled and people type bare letters. Stripping
    /// every diacritic from a real hemistich must still find that line.
    func testBareQueryMatchesVowelledMatnText() throws {
        for matn in matns {
            let index = MatnSearchIndex(matn: matn)
            let line = try XCTUnwrap(matn.lines.first { $0.first.split(separator: " " as Character).count > 2 })
            let words: [String] = line.first.split(separator: " " as Character).map(String.init)
            let word = try XCTUnwrap(words.max(by: { $0.count < $1.count }))
            // The typed form: folded, i.e. no harakat at all.
            let typed = ArabicSearch.fold(word)
            XCTAssertNotEqual(typed, word, "the matn word must carry diacritics to make this a test")
            let hits = index.search(typed)
            XCTAssertTrue(hits.contains { $0.line.number == line.number },
                          "\(matn.id): bare typing must find the vowelled line")
        }
    }

    /// A vowelled query must find the same line as the bare one — folding
    /// applies to both sides.
    func testVowelledQueryFindsTheSameLine() throws {
        let matn = try XCTUnwrap(matns.first)
        let index = MatnSearchIndex(matn: matn)
        let line = try XCTUnwrap(matn.lines.first { $0.second.split(separator: " " as Character).count > 2 })
        let words: [String] = line.second.split(separator: " " as Character).map(String.init)
        let word = try XCTUnwrap(words.max(by: { $0.count < $1.count }))
        let vowelled = index.search(word).map(\.line.number)
        let bare = index.search(ArabicSearch.fold(word)).map(\.line.number)
        XCTAssertEqual(vowelled, bare)
        XCTAssertTrue(vowelled.contains(line.number))
    }

    /// A line matching in both hemistichs is one result, not two.
    func testEachLineAppearsOnce() throws {
        let matn = try XCTUnwrap(matns.first)
        let index = MatnSearchIndex(matn: matn)
        // A single Arabic letter that is bound to appear all over the poem.
        let letter = try XCTUnwrap(ArabicSearch.fold(matn.lines[0].first).first.map(String.init))
        let numbers = index.search(letter).map(\.line.number)
        XCTAssertEqual(numbers.count, Set(numbers).count)
        XCTAssertFalse(numbers.isEmpty)
    }

    func testEmptyQueryFindsNothing() throws {
        let matn = try XCTUnwrap(matns.first)
        let index = MatnSearchIndex(matn: matn)
        XCTAssertTrue(index.search("").isEmpty)
        XCTAssertTrue(index.search("   ").isEmpty)
    }

    /// The snippet must be a genuine window on the real text — never
    /// rewritten. Its pieces must concatenate back into the line.
    func testSnippetIsASliceOfTheRealLine() throws {
        let matn = try XCTUnwrap(matns.first)
        let index = MatnSearchIndex(matn: matn)
        let line = matn.lines[3]
        let words: [String] = line.first.split(separator: " " as Character).map(String.init)
        let word = try XCTUnwrap(words.first)
        let hit = try XCTUnwrap(index.search(ArabicSearch.fold(word))
            .first { $0.line.number == line.number })
        let rebuilt = hit.snippet.before + hit.snippet.match + hit.snippet.after
        XCTAssertTrue(line.first.contains(rebuilt) || line.second.contains(rebuilt),
                      "the snippet must be a slice of the hemistich, not new text")
    }

    // MARK: - Ranking: whole word, then word prefix, then mid-word

    /// The shared tiers, exercised on a corpus built here (non-Quranic
    /// placeholder Arabic — CLAUDE.md rule 1).
    func testRankingOrderIsWholeWordThenPrefixThenPartial() {
        // "بحث" as a standalone word, as the start of a longer word, and
        // buried inside one.
        let corpus = FoldedCorpus<Int>(documents: [
            .init(key: 0, text: "الكلمة مبحثها هنا"),   // mid-word  → partial
            .init(key: 1, text: "هذا بحثنا الطويل"),    // word prefix
            .init(key: 2, text: "هذا بحث قصير"),        // whole word
        ])
        let hits = corpus.search("بحث")
        XCTAssertEqual(hits.map(\.key), [2, 1, 0])
        XCTAssertEqual(hits.map(\.tier), [.wholeWord, .wordPrefix, .partial])
    }

    /// Inside one tier, results keep corpus order (the sort is not stable on
    /// its own, so this guards the explicit ordinal tiebreak).
    func testEqualTiersKeepCorpusOrder() {
        let corpus = FoldedCorpus<Int>(documents: (0..<6).map {
            .init(key: $0, text: "سطر رقم فيه كلمة مشتركة")
        })
        XCTAssertEqual(corpus.search("مشتركة").map(\.key), [0, 1, 2, 3, 4, 5])
    }

    func testMatchCountIgnoresTheDisplayCap() {
        let corpus = FoldedCorpus<Int>(documents: (0..<40).map {
            .init(key: $0, text: "سطر فيه كلمة مشتركة")
        })
        XCTAssertEqual(corpus.search("مشتركة", limit: 5).count, 5)
        XCTAssertEqual(corpus.matchCount("مشتركة"), 40)
    }

    /// Folding is diacritic-insensitive in the corpus too: a vowelled
    /// document is found by a bare query.
    func testCorpusMatchesAcrossDiacritics() {
        let corpus = FoldedCorpus<Int>(documents: [
            .init(key: 0, text: "كَلِمَةٌ مَشْكُولَةٌ لِلاخْتِبَارِ")
        ])
        XCTAssertEqual(corpus.search("مشكولة").count, 1)
    }

    /// The budget is what keeps a giant edition from being indexed whole; a
    /// corpus that refuses documents must report it, so the UI can say the
    /// coverage is short rather than pretending.
    func testCorpusRefusesDocumentsPastItsBudget() {
        var corpus = FoldedCorpus<Int>()
        let document = FoldedCorpus<Int>.Document(key: 0, text: "كلمة")
        XCTAssertTrue(corpus.append([document], budget: 100))
        XCTAssertFalse(corpus.append(Array(repeating: document, count: 50), budget: 8))
    }

    // MARK: - "How much is searchable" must be exact

    /// The coverage figure is the promise the search screen makes to the
    /// user, so it is derived from the cache, never assumed.
    func testCoverageCountsExactlyTheCachedSurahs() throws {
        let edition = TafsirEdition.gharib
        let cached = TafsirService.cachedSurahNumbers(edition: edition)
        let index = TafsirSearchIndex.build(edition: edition)
        XCTAssertEqual(index.coverage.searchedSurahs, cached.count,
                       "coverage must equal the surahs actually indexed")
        XCTAssertEqual(index.coverage.totalSurahs, 114)
        XCTAssertEqual(index.coverage.isComplete, cached.count == 114)
    }

    /// A device with nothing downloaded must say so — an empty index is
    /// never "complete".
    func testEmptyIndexIsNeverComplete() {
        let index = TafsirSearchIndex.empty(edition: .gharib)
        XCTAssertTrue(index.isEmpty)
        XCTAssertEqual(index.coverage.searchedSurahs, 0)
        XCTAssertFalse(index.coverage.isComplete)
        XCTAssertTrue(index.search("كلمة").isEmpty)
    }

    /// The budget cutting an index short must never read as full coverage.
    func testBudgetReachedIsNotComplete() {
        let coverage = TafsirCoverage(searchedSurahs: 114, entries: 6000, budgetReached: true)
        XCTAssertFalse(coverage.isComplete)
    }

    /// The line the user reads must carry the real numbers, in the digits of
    /// the interface language.
    func testCoverageSummaryStatesBothNumbers() {
        let partial = TafsirCoverage(searchedSurahs: 12, entries: 300)
        XCTAssertTrue(partial.summary(arabicUI: false).contains("12 of 114"))
        XCTAssertTrue(partial.summary(arabicUI: true).contains("١٢"))
        XCTAssertTrue(partial.summary(arabicUI: true).contains("١١٤"))
        let complete = TafsirCoverage(searchedSurahs: 114, entries: 6000)
        XCTAssertFalse(complete.summary(arabicUI: false).contains("of 114"))
    }
}
