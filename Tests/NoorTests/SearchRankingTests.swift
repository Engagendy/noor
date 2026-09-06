import ContentDB
import XCTest

/// Search matching, ranking and reference parsing.
///
/// Per the Quran-integrity rule no Quranic string is written here: every
/// Arabic expectation is read from the bundled read-only content DB and,
/// where a bare (undiacriticised) query is needed, derived from that text
/// with the shared normalizer.
final class SearchRankingTests: XCTestCase {
    private var db: QuranDatabase!
    private var surahs: [Surah]!

    override func setUpWithError() throws {
        try super.setUpWithError()
        db = try QuranDatabase()
        surahs = try db.allSurahs()
    }

    // MARK: - Folding / diacritic-insensitive matching

    func testFoldStripsDiacriticsFromRealQuranText() throws {
        let ayah = try XCTUnwrap(db.verses(surahId: 1).first { $0.ayah == 2 }?.text)
        let folded = ArabicSearch.fold(ayah)
        XCTAssertNotEqual(folded, ayah, "voweled text must fold to something shorter")
        XCTAssertLessThan(folded.unicodeScalars.count, ayah.unicodeScalars.count)
        // The bare form of the ayah matches the voweled original.
        XCTAssertTrue(ArabicSearch.contains(folded, in: ayah))
        // …and folding is idempotent.
        XCTAssertEqual(ArabicSearch.fold(folded), folded)
    }

    func testUndiacriticisedQueryMatchesVoweledText() throws {
        let ayah = try XCTUnwrap(db.verses(surahId: 112).first { $0.ayah == 1 }?.text)
        // Take a real word out of the ayah and strip its marks — that is
        // exactly what a user types.
        let word = try XCTUnwrap(ayah.split(separator: " ").last.map(String.init))
        let bare = ArabicSearch.fold(word)
        XCTAssertNotEqual(bare, word)
        let match = try XCTUnwrap(ArabicSearch.firstMatch(of: bare, in: ayah))
        // The highlighted range is inside the ORIGINAL, still-voweled text.
        XCTAssertEqual(ArabicSearch.fold(String(ayah[match.range])), bare)
        XCTAssertEqual(match.tier, .wholeWord)
    }

    func testMatchTiers() {
        // Latin stand-ins keep the tier rules readable; the same code path
        // runs for Arabic (see testUndiacriticisedQueryMatchesVoweledText).
        XCTAssertEqual(ArabicSearch.firstMatch(of: "cow", in: "The Cow grazes")?.tier, .wholeWord)
        XCTAssertEqual(ArabicSearch.firstMatch(of: "graz", in: "The Cow grazes")?.tier, .wordPrefix)
        XCTAssertEqual(ArabicSearch.firstMatch(of: "razes", in: "The Cow grazes")?.tier, .partial)
        XCTAssertNil(ArabicSearch.firstMatch(of: "goat", in: "The Cow grazes"))
    }

    func testSnippetCentresOnTheMatch() throws {
        let ayah = try XCTUnwrap(db.verses(surahId: 2).first { $0.ayah == 255 }?.text)
        let words = ayah.split(separator: " ").map(String.init)
        let middle = ArabicSearch.fold(words[words.count / 2])
        let snippet = try XCTUnwrap(ArabicSearch.snippet(for: ayah, matching: middle))
        XCTAssertEqual(ArabicSearch.fold(snippet.match), middle)
        XCTAssertTrue(snippet.truncatedStart || snippet.truncatedEnd,
                      "ayat al-kursi is long enough to be windowed")
        XCTAssertTrue(ayah.contains(snippet.before + snippet.match + snippet.after))
        XCTAssertLessThan(snippet.plain.count, ayah.count)
    }

    // MARK: - Verse search ranking

    func testVerseSearchRanksWholeWordsFirst() throws {
        // A word taken from a real ayah: every whole-word hit must sort
        // before every hit where it only sits inside a longer word.
        let ayah = try XCTUnwrap(db.verses(surahId: 1).first { $0.ayah == 2 }?.text)
        let word = ArabicSearch.fold(String(try XCTUnwrap(ayah.split(separator: " ").first)))
        let results = try db.searchVerseResults(word)
        XCTAssertFalse(results.hits.isEmpty)
        let tiers = results.hits.map(\.tier)
        XCTAssertEqual(tiers, tiers.sorted(), "hits must be ordered by tier")
        // Inside a tier, mushaf order.
        for tier in Set(tiers) {
            let group = results.hits.filter { $0.tier == tier }
            let keys = group.map { $0.surahId * 1000 + $0.ayah }
            XCTAssertEqual(keys, keys.sorted(), "tier \(tier) must be in mushaf order")
        }
        XCTAssertTrue(results.hits.allSatisfy { $0.snippet != nil })
    }

    func testVerseSearchReportsTruncation() throws {
        let ayah = try XCTUnwrap(db.verses(surahId: 1).first { $0.ayah == 2 }?.text)
        let word = ArabicSearch.fold(String(try XCTUnwrap(ayah.split(separator: " ").first)))
        let small = try db.searchVerseResults(word, limit: 3)
        XCTAssertEqual(small.hits.count, 3)
        XCTAssertTrue(small.truncated)
        XCTAssertEqual(small.cap, 3)
        // The returned text is still the untouched display text.
        XCTAssertNotEqual(small.hits[0].text, ArabicSearch.fold(small.hits[0].text))
    }

    func testVerseSearchIgnoresShortQueries() throws {
        XCTAssertTrue(try db.searchVerses("ا").isEmpty)
        XCTAssertTrue(try db.searchVerseResults("").hits.isEmpty)
    }

    // MARK: - Surah names

    func testEnglishSurahNameMatching() throws {
        func ids(_ query: String) -> [Int] { SurahSearch.matches(surahs, query: query).map(\.id) }
        XCTAssertEqual(ids("The Cow").first, 2)
        XCTAssertEqual(ids("cow").first, 2)
        XCTAssertEqual(ids("Cave").first, 18)
        XCTAssertEqual(ids("the opening").first, 1)
        // Transliteration and Arabic keep working.
        XCTAssertEqual(ids("baqara").first, 2)
        XCTAssertEqual(ids("Al-Kahf").first, 18)
        XCTAssertEqual(ids("alkahf").first, 18)
        let arabicName = try XCTUnwrap(surahs.first { $0.id == 18 }?.nameArabic)
        XCTAssertEqual(ids(arabicName).first, 18)
        XCTAssertEqual(ids(ArabicSearch.fold(arabicName)).first, 18)
        XCTAssertTrue(ids("zzzz").isEmpty)
    }

    func testSurahNameRankingPrefersExactThenPrefix() {
        // "Ya" prefixes several transliterations; the exact-name surah wins.
        let ranked = SurahSearch.matches(surahs, query: "The Cave")
        XCTAssertEqual(ranked.first?.id, 18)
        let light = SurahSearch.matches(surahs, query: "Light")
        XCTAssertEqual(light.first?.id, 24, "An-Noor is named The Light")
        // An empty query returns the full list untouched.
        XCTAssertEqual(SurahSearch.matches(surahs, query: "  ").count, surahs.count)
    }

    // MARK: - References

    func testReferenceForms() {
        let expected = QuranReference(surahId: 2, ayah: 255)
        XCTAssertEqual(QuranReference.parse("2:255"), expected)
        XCTAssertEqual(QuranReference.parse("2 255"), expected)
        XCTAssertEqual(QuranReference.parse(" 2 : 255 "), expected)
        XCTAssertEqual(QuranReference.parse("2-255"), expected)
        // Arabic-Indic digits, in either position.
        XCTAssertEqual(QuranReference.parse("٢:٢٥٥"), expected)
        XCTAssertEqual(QuranReference.parse("2:٢٥٥"), expected)
        XCTAssertEqual(QuranReference.parse("٢ 255"), expected)
        XCTAssertEqual(QuranReference.parse("۲:۲۵۵"), expected)
        // Surah only.
        XCTAssertEqual(QuranReference.parse("18"), QuranReference(surahId: 18, ayah: nil))
        XCTAssertEqual(QuranReference.parse("١٨"), QuranReference(surahId: 18, ayah: nil))
        // Not references.
        XCTAssertNil(QuranReference.parse("0:1"))
        XCTAssertNil(QuranReference.parse("115"))
        XCTAssertNil(QuranReference.parse("2:0"))
        XCTAssertNil(QuranReference.parse("cow"))
        XCTAssertNil(QuranReference.parse("2:255:1"))
        // Regression: a view can parse before its surah list has loaded.
        XCTAssertNil(QuranReference.parse("2:255", surahCount: 0))
        XCTAssertNil(QuranReference.parse("2", surahCount: 0))
    }

    func testReferenceSelectsTheSurah() {
        XCTAssertEqual(SurahSearch.matches(surahs, query: "٢:٢٥٥").map(\.id), [2])
        XCTAssertEqual(SurahSearch.matches(surahs, query: "18").map(\.id), [18])
    }
}
