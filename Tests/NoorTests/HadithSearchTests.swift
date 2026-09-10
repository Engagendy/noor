import ContentDB
import SQLite3
import XCTest
@testable import Noor

/// Hadith search: the packs store fully voweled Arabic and people type bare
/// letters, so matching runs against a folded column, results are ranked, and
/// LIKE wildcards typed into the field stay literal.
///
/// No Arabic is typed into this file: every query is derived at runtime from
/// the bundled Forty (`hadith.json`), which is also what fills the test
/// database — real voweled hadith text, never Quranic text.
final class HadithSearchTests: XCTestCase {
    private var items: [HadithItem]!
    private var url: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        items = HadithStore.load()
        XCTAssertFalse(items.isEmpty, "bundled hadith.json must load")
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hadith-search-\(UUID().uuidString).db")
        try makeLegacyDatabase(at: url)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: url)
        try super.tearDownWithError()
    }

    // MARK: - Fixture

    /// Builds a database in the schema a pack downloaded by an OLDER build
    /// has: no folded columns. Searching it therefore also exercises the
    /// in-place migration.
    private func makeLegacyDatabase(at url: URL, extraArabic: [String: String] = [:]) throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        sqlite3_exec(db, """
            CREATE TABLE books(idx INTEGER PRIMARY KEY, ar TEXT, en TEXT, count INTEGER);
            CREATE TABLE hadith(book INTEGER, num TEXT, ar TEXT, en TEXT);
            """, nil, nil, nil)
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        var insert: OpaquePointer?
        sqlite3_prepare_v2(db, "INSERT INTO hadith(book, num, ar, en) VALUES(1,?,?,?)",
                           -1, &insert, nil)
        for item in items {
            let number = String(item.number)
            sqlite3_bind_text(insert, 1, number, -1, transient)
            sqlite3_bind_text(insert, 2, extraArabic[number] ?? item.arabic, -1, transient)
            sqlite3_bind_text(insert, 3, item.english, -1, transient)
            sqlite3_step(insert)
            sqlite3_reset(insert)
        }
        sqlite3_finalize(insert)
        var book: OpaquePointer?
        sqlite3_prepare_v2(db, "INSERT INTO books(idx, ar, en, count) VALUES(1,?,?,?)",
                           -1, &book, nil)
        sqlite3_bind_text(book, 1, items[0].collectionArabic, -1, transient)
        sqlite3_bind_text(book, 2, items[0].collectionEnglish, -1, transient)
        sqlite3_bind_int(book, 3, Int32(items.count))
        sqlite3_step(book)
        sqlite3_finalize(book)
    }

    private func hits(_ query: String, isArabicUI: Bool = true,
                      limit: Int = 80, in database: URL? = nil) -> [HadithLibrary.SearchHit] {
        HadithLibrary.searchHits(in: database ?? url, collection: .bukhari,
                                 query: query, isArabicUI: isArabicUI, limit: limit)
    }

    /// A word of at least four letters taken out of real hadith text, with
    /// its marks stripped — exactly what a user types.
    private func bareWord(from text: String) throws -> String {
        let word = try XCTUnwrap(text.split(separator: " ")
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .first { ArabicSearch.fold($0).count >= 4 && $0.allSatisfy { !$0.isPunctuation } })
        return ArabicSearch.fold(word)
    }

    // MARK: - Folding

    func testUndiacriticisedArabicQueryMatchesVoweledText() throws {
        let hadith = try XCTUnwrap(items.first)
        let bare = try bareWord(from: hadith.arabic)
        XCTAssertFalse(hadith.arabic.contains(bare),
                       "the raw text must NOT contain the bare form — that was the bug")
        let results = hits(bare)
        XCTAssertFalse(results.isEmpty, "bare typing must find voweled text")
        XCTAssertTrue(results.contains { $0.hadith.number == String(hadith.number) })
    }

    func testMigrationAddsFoldedColumnsToAnOlderPack() throws {
        XCTAssertFalse(try columns().contains("ar_fold"), "fixture starts on the old schema")
        _ = hits(try bareWord(from: items[0].arabic))
        let migrated = try columns()
        XCTAssertTrue(migrated.contains("ar_fold"))
        XCTAssertTrue(migrated.contains("en_fold"))
    }

    private func columns() throws -> [String] {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "PRAGMA table_info(hadith)", -1, &stmt, nil),
                       SQLITE_OK)
        defer { sqlite3_finalize(stmt) }
        var names: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            names.append(sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? "")
        }
        return names
    }

    func testBidiMarksInsideTheTextDoNotBreakAPhraseSearch() throws {
        // The downloaded packs sprinkle U+200F between words; simulate one.
        let hadith = try XCTUnwrap(items.first)
        let words = hadith.arabic.split(separator: " ").map(String.init)
        let phrase = ArabicSearch.fold("\(words[0]) \(words[1])")
        let noisy = ([words[0], "\u{200F}" + words[1]] + words.dropFirst(2)).joined(separator: " ")
        let noisyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hadith-bidi-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: noisyURL) }
        try makeLegacyDatabase(at: noisyURL, extraArabic: [String(hadith.number): noisy])
        let results = hits(phrase, in: noisyURL)
        XCTAssertTrue(results.contains { $0.hadith.number == String(hadith.number) },
                      "an invisible bidi mark must not hide a two-word match")
    }

    // MARK: - Ranking and snippets

    func testWholeWordMatchesRankAboveMidWordOnes() throws {
        let bare = try bareWord(from: items[0].arabic)
        let results = hits(bare)
        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(results.first?.tier, .wholeWord)
        XCTAssertEqual(results.map(\.tier), results.map(\.tier).sorted(),
                       "results must come back best-first")
    }

    func testHitCarriesASnippetCentredOnTheMatch() throws {
        let bare = try bareWord(from: items[0].arabic)
        let hit = try XCTUnwrap(hits(bare).first)
        let snippet = try XCTUnwrap(hit.snippet)
        XCTAssertEqual(ArabicSearch.fold(snippet.match), bare,
                       "the highlighted run is the match, in the original voweled text")
        XCTAssertFalse(hit.snippetIsEnglish)
        XCTAssertTrue(hit.hadith.arabic.contains(snippet.match))
    }

    func testResultsAreCappedAtTheLimit() throws {
        let bare = try bareWord(from: items[0].arabic)
        XCTAssertLessThanOrEqual(hits(bare, limit: 3).count, 3)
        XCTAssertTrue(hits(bare, limit: 0).isEmpty)
    }

    // MARK: - Wildcards, numbers, English

    func testLikeWildcardsAreTreatedLiterally() {
        // "%%" and "__" used to be wildcards: they matched every hadith.
        XCTAssertTrue(hits("%%").isEmpty, "percent must not act as a wildcard")
        XCTAssertTrue(hits("__").isEmpty, "underscore must not act as a wildcard")
        XCTAssertTrue(hits("%a%").isEmpty)
        XCTAssertFalse(hits("Allah", isArabicUI: false).isEmpty, "control: plain words still match")
    }

    func testQuotesInTheQueryAreData() {
        XCTAssertTrue(hits("'; DROP TABLE hadith; --").isEmpty)
        XCTAssertFalse(hits("Allah", isArabicUI: false).isEmpty, "the table is still there")
    }

    func testNumberLookupStillWorksAndRanksFirst() throws {
        let hadith = try XCTUnwrap(items.first { $0.number > 9 })
        let results = hits(String(hadith.number))
        XCTAssertEqual(results.first?.hadith.number, String(hadith.number))
    }

    func testArabicIndicDigitsFindTheSameHadith() throws {
        let hadith = try XCTUnwrap(items.first { $0.number > 9 })
        let arabicDigits = String(String(hadith.number).map {
            Character(UnicodeScalar($0.wholeNumberValue! + 0x0660)!)
        })
        XCTAssertEqual(hits(arabicDigits).first?.hadith.number, String(hadith.number))
    }

    func testEnglishQueryWorksWhileTheInterfaceIsArabic() throws {
        let hadith = try XCTUnwrap(items.first)
        let word = try XCTUnwrap(hadith.english.split(separator: " ")
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .first { $0.count >= 6 && $0.allSatisfy(\.isLetter) })
        let hit = try XCTUnwrap(hits(word.uppercased()).first { $0.snippetIsEnglish })
        XCTAssertEqual(hit.bookTitle, items[0].collectionArabic,
                       "the Arabic interface still labels the hit in Arabic")
        XCTAssertEqual(ArabicSearch.fold(try XCTUnwrap(hit.snippet).match), word.lowercased())
    }

    func testShortQueriesAreIgnored() {
        XCTAssertTrue(hits("a").isEmpty)
        XCTAssertTrue(hits("  ").isEmpty)
    }
}
