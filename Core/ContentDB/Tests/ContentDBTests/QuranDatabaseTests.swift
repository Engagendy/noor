import XCTest
@testable import ContentDB

final class QuranDatabaseTests: XCTestCase {
    func testChecksumVerificationPasses() throws {
        let db = try QuranDatabase()
        XCTAssertNoThrow(try db.verifyIntegrity())
    }

    func testQuranHas6236VersesAnd114Surahs() throws {
        let db = try QuranDatabase()
        XCTAssertEqual(try db.verseCount(), 6236)
        XCTAssertEqual(try db.allSurahs().count, 114)
    }

    func testAlFatihaStructure() throws {
        let db = try QuranDatabase()
        let fatiha = try db.allSurahs()[0]
        XCTAssertEqual(fatiha.id, 1)
        XCTAssertEqual(fatiha.ayahCount, 7)
        XCTAssertEqual(fatiha.nameTransliterated, "Al-Faatiha")
        XCTAssertTrue(fatiha.isMeccan)

        let verses = try db.verses(surahId: 1)
        XCTAssertEqual(verses.count, 7)
        // Verify structure only — never assert on Quranic text contents here.
        XCTAssertFalse(verses.contains { $0.text.isEmpty })
    }

    func testSurahAyahCountsMatchVerseTable() throws {
        let db = try QuranDatabase()
        for surah in try db.allSurahs() {
            XCTAssertEqual(try db.verses(surahId: surah.id).count, surah.ayahCount,
                           "ayah count mismatch in surah \(surah.id)")
        }
    }
}
