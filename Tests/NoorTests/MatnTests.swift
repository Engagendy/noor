import Learn
import XCTest

/// Guards over the bundled matn JSON produced by the `Tools/build_matn_*.py`
/// builders. Every guard below runs over EVERY bundled matn, so a new one
/// (add its file to `MatnStore.bundledFiles`) is covered the moment it ships.
///
/// No line of the poem is typed here — every assertion is derived from the
/// bundled data at runtime. The vowel guard is the important one: a future
/// "text cleanup" that stripped the harakat would silently ruin a tajweed
/// matn, and this test would fail first.
final class MatnTests: XCTestCase {
    /// Unicode SCALARS, not `Character`s: a letter and its haraka form one
    /// grapheme cluster, so scanning by `Character` finds neither.
    private static let tatweel = Unicode.Scalar(0x0640)!
    /// Fatha…sukun, the tanween, the superscript alef and the maddah.
    private static let harakat: Set<Unicode.Scalar> = Set(
        [0x064B, 0x064C, 0x064D, 0x064E, 0x064F, 0x0650, 0x0651, 0x0652, 0x0670, 0x0653]
            .compactMap(Unicode.Scalar.init))

    private static func harakatCount(_ text: String) -> Int {
        text.unicodeScalars.filter { harakat.contains($0) }.count
    }

    private static func hasTatweel(_ text: String) -> Bool {
        text.unicodeScalars.contains(tatweel)
    }

    private var matns: [Matn]!

    override func setUpWithError() throws {
        try super.setUpWithError()
        matns = MatnStore.load()
        XCTAssertFalse(matns.isEmpty, "the bundled matn JSON must load")
    }

    /// The counts each Wikisource edition actually carries. The received
    /// counts are conventionally 61 (Tuhfa) and 34 (al-Bayquniyyah) and vary
    /// slightly by edition — if a source is ever re-fetched and differs, this
    /// fails rather than silently changing a poem.
    private static let expected: [String: (lines: Int, sections: Int)] = [
        "tuhfat-al-atfal": (60, 10),
        "bayquniyyah": (34, 3),
    ]

    func testEveryBundledMatnIsPresentWithItsParsedLineAndSectionCounts() throws {
        XCTAssertEqual(Set(matns.map(\.id)), Set(Self.expected.keys),
                       "the bundled set changed — update `expected`")
        for matn in matns {
            let counts = try XCTUnwrap(Self.expected[matn.id])
            XCTAssertEqual(matn.lines.count, counts.lines, matn.id)
            XCTAssertEqual(matn.sections.count, counts.sections, matn.id)
            XCTAssertEqual(matn.lines.map(\.number), Array(1...counts.lines), matn.id)
        }
    }

    /// The section headings of al-Bayquniyyah are ours, not its source's, and
    /// the JSON must keep saying so — the reader prints that note.
    func testEditorialSectionsAreDeclaredWhereTheSourceHasNoHeadings() throws {
        XCTAssertEqual(try XCTUnwrap(MatnStore.matn(id: "bayquniyyah")).sectionsEditorial, true)
        XCTAssertNotEqual(try XCTUnwrap(MatnStore.matn(id: "tuhfat-al-atfal")).sectionsEditorial, true)
    }

    /// The navigation bar shows the short title; without one it truncates.
    func testEveryMatnDeclaresBothShortTitles() {
        for matn in matns {
            XCTAssertFalse(matn.navigationTitle(arabicUI: true).isEmpty, matn.id)
            XCTAssertFalse(matn.navigationTitle(arabicUI: false).isEmpty, matn.id)
            XCTAssertNotNil(matn.shortTitleAr, "\(matn.id): no Arabic short title")
            XCTAssertNotNil(matn.shortTitleEn, "\(matn.id): no English short title")
        }
    }

    func testEveryLineHasBothHemistichsNonEmpty() {
        for matn in matns {
            for line in matn.lines {
                XCTAssertFalse(line.first.trimmingCharacters(in: .whitespaces).isEmpty,
                               "\(matn.id) line \(line.number): empty first hemistich")
                XCTAssertFalse(line.second.trimmingCharacters(in: .whitespaces).isEmpty,
                               "\(matn.id) line \(line.number): empty second hemistich")
            }
        }
    }

    func testEveryLineBelongsToAnExistingSectionAndEverySectionHasLines() {
        for matn in matns {
            let ids = Set(matn.sections.map(\.id))
            XCTAssertEqual(ids.count, matn.sections.count, "\(matn.id): duplicate section id")
            for line in matn.lines {
                XCTAssertTrue(ids.contains(line.sectionId),
                              "\(matn.id) line \(line.number): unknown section '\(line.sectionId)'")
            }
            for section in matn.sections {
                XCTAssertFalse(matn.lines(in: section).isEmpty,
                               "\(matn.id): section '\(section.id)' has no lines")
            }
        }
    }

    func testNoTatweelRemains() {
        for matn in matns {
            for line in matn.lines {
                XCTAssertFalse(Self.hasTatweel(line.first),
                               "\(matn.id) line \(line.number): tatweel in first hemistich")
                XCTAssertFalse(Self.hasTatweel(line.second),
                               "\(matn.id) line \(line.number): tatweel in second hemistich")
            }
            for section in matn.sections {
                XCTAssertFalse(Self.hasTatweel(section.titleAr))
            }
        }
    }

    /// A tajweed matn is worthless unvowelled: every line must still carry
    /// harakat, and the whole poem must carry a great many.
    func testTextIsStillFullyVowelled() {
        for matn in matns {
            var total = 0
            for line in matn.lines {
                let marks = Self.harakatCount(line.first + line.second)
                XCTAssertGreaterThanOrEqual(marks, 5,
                                            "\(matn.id) line \(line.number) has lost its harakat")
                total += marks
            }
            // Scaled, not a flat floor: al-Bayquniyyah is 34 lines and
            // carries 984 harakat, Tuhfat al-Atfal 60 lines and far more.
            XCTAssertGreaterThan(total, matn.lines.count * 20,
                                 "\(matn.id): the matn has lost its vowels")
        }
    }

    func testProvenanceIsRecordedOnEveryMatn() {
        for matn in matns {
            XCTAssertFalse(matn.sourceName.isEmpty)
            XCTAssertTrue(matn.sourceUrl.hasPrefix("https://"))
            XCTAssertFalse(matn.sourceLicense.isEmpty)
            XCTAssertFalse(matn.retrieved.isEmpty)
            XCTAssertFalse(matn.titleAr.isEmpty)
            XCTAssertFalse(matn.authorAr.isEmpty)
            XCTAssertNotNil(ISO8601DateFormatter().date(from: matn.retrieved + "T00:00:00Z"),
                            "\(matn.id): retrieval date '\(matn.retrieved)' is not a date")
            for section in matn.sections {
                XCTAssertFalse(section.displayTitle(arabicUI: true).isEmpty, matn.id)
                XCTAssertFalse(section.displayTitle(arabicUI: false).isEmpty, matn.id)
            }
        }
    }

    /// The audio slot exists and is deliberately empty: nothing ships until a
    /// recording's licence is recorded in LICENSES.md (CLAUDE.md rule 5).
    func testAudioSlotIsPresentAndUnused() {
        for matn in matns {
            XCTAssertNil(matn.audio, "\(matn.id): audio must not ship without a recorded licence")
            XCTAssertNil(matn.timings)
            XCTAssertTrue(matn.lines.allSatisfy { $0.start == nil })
        }
    }
}
