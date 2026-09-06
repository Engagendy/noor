import Athkar
import ContentDB
import XCTest

/// Athkar search must reach inside the dhikr text, not just the chapter
/// titles, and must match bare (undiacriticised) typing against the fully
/// voweled bundled text.
///
/// Every query here is derived from the bundled data at runtime — no Arabic
/// (and certainly no Quranic) string is typed into this file.
final class AthkarSearchTests: XCTestCase {
    private var categories: [DhikrCategory]!
    private var index: AthkarSearchIndex!

    override func setUpWithError() throws {
        try super.setUpWithError()
        categories = AthkarStore.load()
        XCTAssertFalse(categories.isEmpty, "bundled athkar.json must load")
        index = AthkarSearchIndex(categories: categories)
    }

    func testEmptyQueryReturnsEveryCategoryAndNoItems() {
        let results = index.search("   ")
        XCTAssertEqual(results.categories.count, categories.count)
        XCTAssertTrue(results.items.isEmpty)
    }

    func testCategoryTitleMatch() throws {
        let category = try XCTUnwrap(categories.first { $0.category.split(separator: " ").count > 1 })
        let word = try XCTUnwrap(category.category.split(separator: " ").last.map(String.init))
        let results = index.search(word)
        XCTAssertTrue(results.categories.contains(category),
                      "searching a word of a chapter title must list that chapter")
    }

    func testEnglishCategoryTitleMatchIsCaseInsensitive() throws {
        let category = try XCTUnwrap(categories.first { ($0.categoryEn?.count ?? 0) > 6 })
        let english = try XCTUnwrap(category.categoryEn)
        let word = try XCTUnwrap(english.split(separator: " ").max(by: { $0.count < $1.count }))
        XCTAssertTrue(index.search(String(word).uppercased()).categories.contains(category))
        XCTAssertTrue(index.search(String(word).lowercased()).categories.contains(category))
    }

    /// The whole point of the change: a word that only appears INSIDE a dhikr.
    func testTextInsideADhikrIsFound() throws {
        let category = try XCTUnwrap(categories.first { category in
            category.items.contains { $0.text.split(separator: " ").count > 5 }
        })
        let dhikr = try XCTUnwrap(category.items.first { $0.text.split(separator: " ").count > 5 })
        let words = dhikr.text.split(separator: " ").map(String.init)
        // A word from the middle of the dhikr, stripped of its vowel marks —
        // exactly what a user types.
        let bare = ArabicSearch.fold(words[words.count / 2])
        XCTAssertNotEqual(bare, words[words.count / 2], "the source text is voweled")
        let results = index.search(bare)
        XCTAssertTrue(results.items.contains { $0.dhikr == dhikr },
                      "an undiacriticised query must match the voweled dhikr")
        // The hit points back at its own category and position…
        let hit = try XCTUnwrap(results.items.first { $0.dhikr == dhikr })
        XCTAssertEqual(hit.category.items[hit.itemIndex], dhikr)
        // …and the snippet slices the real text around the match.
        XCTAssertEqual(ArabicSearch.fold(hit.snippet.match), bare)
        XCTAssertTrue(dhikr.text.contains(hit.snippet.match))
    }

    func testItemsAreRankedWholeWordFirst() throws {
        let dhikr = try XCTUnwrap(categories.flatMap(\.items)
            .first { $0.text.split(separator: " ").count > 5 })
        let word = ArabicSearch.fold(String(try XCTUnwrap(dhikr.text.split(separator: " ").first)))
        let tiers = index.search(word).items.map(\.tier)
        XCTAssertFalse(tiers.isEmpty)
        XCTAssertEqual(tiers, tiers.sorted(), "item hits must be ordered by match tier")
    }

    func testNonsenseQueryMatchesNothing() {
        let results = index.search("zzqxzz")
        XCTAssertTrue(results.isEmpty)
    }
}
