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

    /// The bundled Tanzil text already carries the sajdah sign ۩ (U+06E9) on
    /// every sajdah ayah, so readers must NOT append their own (it would show
    /// as "۩ ۩"). This checks only the presence of the structural mark, not
    /// the Quranic wording.
    func testSajdahAyatAlreadyContainSajdahSign() throws {
        let db = try QuranDatabase()
        let structure = try db.structure()
        XCTAssertEqual(structure.sajdaAyat.count, 15)
        for sajda in structure.sajdaAyat {
            let verse = try XCTUnwrap(
                db.verses(surahId: sajda.surahId).first { $0.ayah == sajda.ayah })
            XCTAssertTrue(verse.text.contains("\u{06E9}"),
                          "\(sajda.surahId):\(sajda.ayah) lacks ۩ in DB text")
            XCTAssertFalse(verse.text.contains("\u{06E9} \u{06E9}"),
                           "\(sajda.surahId):\(sajda.ayah) has a doubled ۩")
        }
    }

    func testWordSearchIgnoresDiacritics() throws {
        let db = try QuranDatabase()
        // Plain query must match fully-vocalized Uthmani text.
        let hits = try db.searchVerses("الحمد لله")
        XCTAssertTrue(hits.contains { $0.surahId == 1 && $0.ayah == 2 })
        XCTAssertFalse(hits.isEmpty)
        // Returned text is the untouched display text (has diacritics).
        XCTAssertNotEqual(hits[0].text, QuranDatabase.normalizeForSearch(hits[0].text))
        // Too-short queries return nothing.
        XCTAssertTrue(try db.searchVerses("ا").isEmpty)
    }

    func testPageLayoutDatabase() throws {
        let layout = try PageLayoutDatabase()
        XCTAssertGreaterThan(try layout.wordCount(), 77000)

        let page1 = try layout.lines(page: 1)
        XCTAssertFalse(page1.isEmpty)
        XCTAssertTrue(page1.allSatisfy { $0.kind != .words || !$0.glyphs.isEmpty })
        // Al-Fatiha's page carries an injected surah-header line.
        XCTAssertTrue(page1.contains { $0.kind == .surahHeader(surahId: 1) })

        // Surah 3 starts mid-page 50: header + basmala lines injected.
        let page50 = try layout.lines(page: 50)
        XCTAssertTrue(page50.contains { $0.kind == .surahHeader(surahId: 3) })
        XCTAssertTrue(page50.contains { $0.kind == .basmala })

        // An-Nisa (page 77) reserves ONE line: header + basmala share it.
        let page77 = try layout.lines(page: 77)
        XCTAssertTrue(page77.contains { $0.kind == .surahHeaderWithBasmala(surahId: 4) })

        // At-Tawbah (page 187): header only, never a basmala.
        let page187 = try layout.lines(page: 187)
        XCTAssertTrue(page187.contains { $0.kind == .surahHeader(surahId: 9) })
        XCTAssertFalse(page187.contains { $0.kind == .basmala })

        let page604 = try layout.lines(page: 604)
        XCTAssertFalse(page604.isEmpty)

        // Al-Fatiha 1:1 (basmala) has exactly 4 words.
        XCTAssertEqual(try layout.words(surahId: 1, ayah: 1).count, 4)
        // Word-by-word glosses present.
        let words = try layout.words(surahId: 1, ayah: 2)
        XCTAssertTrue(words.allSatisfy { !$0.translation.isEmpty })
    }

    func testSurahAyahCountsMatchVerseTable() throws {
        let db = try QuranDatabase()
        for surah in try db.allSurahs() {
            XCTAssertEqual(try db.verses(surahId: surah.id).count, surah.ayahCount,
                           "ayah count mismatch in surah \(surah.id)")
        }
    }
}
