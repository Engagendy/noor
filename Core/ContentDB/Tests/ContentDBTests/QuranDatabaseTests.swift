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

    func testMushafStructure() throws {
        let structure = try QuranDatabase().structure()
        XCTAssertEqual(structure.juzStarts.count, 30)
        XCTAssertEqual(structure.quarterStarts.count, 240)
        XCTAssertEqual(structure.pageStarts.count, 604)

        // Juz 2 famously begins at 2:142 ("سيقول السفهاء").
        XCTAssertEqual(structure.juz(surahId: 2, ayah: 141), 1)
        XCTAssertEqual(structure.juz(surahId: 2, ayah: 142), 2)
        XCTAssertEqual(structure.juz(surahId: 114, ayah: 6), 30)

        XCTAssertEqual(structure.page(surahId: 1, ayah: 1), 1)
        XCTAssertEqual(structure.page(surahId: 114, ayah: 6), 604)

        XCTAssertEqual(structure.quarterIndex(startingAtSurah: 1, ayah: 1), 1)
        XCTAssertNil(structure.quarterIndex(startingAtSurah: 1, ayah: 2))

        XCTAssertEqual(QuranStructure.quarterDescription(1).hizb, 1)
        XCTAssertEqual(QuranStructure.quarterDescription(5).hizb, 2)
        XCTAssertEqual(QuranStructure.quarterDescription(8).quarterInHizb, 4)
    }

    func testSurahAyahCountsMatchVerseTable() throws {
        let db = try QuranDatabase()
        for surah in try db.allSurahs() {
            XCTAssertEqual(try db.verses(surahId: surah.id).count, surah.ayahCount,
                           "ayah count mismatch in surah \(surah.id)")
        }
    }
}
