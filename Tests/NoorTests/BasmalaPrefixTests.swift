import ContentDB
import QuranReader
import XCTest

/// The bundled Quran text stores the basmala inside ayah 1 for 111 surahs,
/// and the reader draws its own basmala line — see `BasmalaPrefix`.
///
/// Per the Quran-integrity rule, no Quranic string is ever written here: all
/// expectations are derived from the read-only content DB at runtime.
final class BasmalaPrefixTests: XCTestCase {
    private var database: QuranDatabase!
    /// Reference basmala = surah 1 ayah 1, straight from the DB.
    private var basmala: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        database = try QuranDatabase()
        basmala = try XCTUnwrap(database.verses(surahId: 1).first?.text)
    }

    private func verse(_ surah: Int, _ ayah: Int) throws -> String {
        try XCTUnwrap(database.verses(surahId: surah).first { $0.ayah == ayah }?.text)
    }

    private func stripped(_ surah: Int, _ ayah: Int) throws -> String {
        BasmalaPrefix.strippingLeadingBasmala(from: try verse(surah, ayah), basmala: basmala)
    }

    /// Al-Baqarah 1: the leading basmala and its single space are dropped, and
    /// what remains is byte-identical to the stored suffix.
    func testSurah2Ayah1DropsLeadingBasmalaAndKeepsSuffixVerbatim() throws {
        let stored = try verse(2, 1)
        let display = try stripped(2, 1)
        XCTAssertNotEqual(display, stored)
        XCTAssertFalse(display.hasPrefix(basmala))
        XCTAssertTrue(stored.hasSuffix(display))
        // Exactly one space was consumed between basmala and body.
        XCTAssertEqual(stored.count, display.count + basmala.count + 1)
    }

    /// Every surah that stores the prefix loses it exactly once, and the
    /// result is always a verbatim suffix of the stored row.
    func testAllPrefixedSurahsStripToAVerbatimSuffix() throws {
        var strippedCount = 0
        for surah in 1...114 {
            let stored = try verse(surah, 1)
            let display = try stripped(surah, 1)
            XCTAssertTrue(stored.hasSuffix(display), "surah \(surah)")
            if display != stored { strippedCount += 1 }
        }
        // 114 surahs − At-Tawbah (no basmala) − Al-Fatiha (basmala IS the ayah).
        XCTAssertEqual(strippedCount, 112)
    }

    /// At-Tawbah has no basmala at all: ayah 1 must pass through untouched.
    func testSurah9Ayah1Unchanged() throws {
        XCTAssertEqual(try stripped(9, 1), try verse(9, 1))
    }

    /// 27:30 carries the basmala MID-verse (Sulayman's letter) — never touched.
    func testSurah27Ayah30Unchanged() throws {
        let stored = try verse(27, 30)
        XCTAssertTrue(stored.contains(basmala), "fixture check: 27:30 should contain the basmala")
        XCTAssertEqual(BasmalaPrefix.strippingLeadingBasmala(from: stored, basmala: basmala), stored)
    }

    /// Al-Fatiha ayah 1 IS the basmala — a counted ayah, rendered as-is.
    func testSurah1Ayah1Unchanged() throws {
        XCTAssertEqual(try stripped(1, 1), basmala)
        XCTAssertEqual(try stripped(1, 1), try verse(1, 1))
    }
}
