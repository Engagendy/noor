import ContentDB
import QuranReader
import XCTest

/// Tests over the bundled tajweed annotations (`tajweed.sqlite`, built by
/// `Tools/build_tajweed.py` from cpfair/quran-tajweed, CC BY 4.0).
///
/// Per the Quran-integrity rule no Quranic string is written here: every
/// expectation is derived from the read-only content DB at runtime. The
/// qalqalah checks name only the five qalqalah CONSONANTS (ق ط ب ج د), which
/// are letters of the alphabet and not Quranic text.
final class TajweedTests: XCTestCase {
    private var quran: QuranDatabase!
    private var tajweed: TajweedDatabase!

    override func setUpWithError() throws {
        try super.setUpWithError()
        quran = try QuranDatabase()
        tajweed = try TajweedDatabase()
    }

    private func text(_ surah: Int, _ ayah: Int) throws -> [Unicode.Scalar] {
        let verse = try XCTUnwrap(quran.verses(surahId: surah).first { $0.ayah == ayah })
        return Array(verse.text.unicodeScalars)
    }

    // MARK: Structural integrity of the bundled data

    /// EVERY span must fall inside its own ayah. A span running past the end
    /// would crash the renderer's scalar indexing, and one landing in the
    /// wrong place would colour the wrong letters.
    func testEverySpanFallsInsideItsAyah() throws {
        var checked = 0
        // One read for the whole mushaf, then one span lookup per surah:
        // the old shape opened 114 reads and failed intermittently under
        // full-suite I/O load.
        let allVerses = try quran.allVerses()
        for (_, verses) in Dictionary(grouping: allVerses, by: \.surahId)
            .sorted(by: { $0.key < $1.key }) {
            let spansByAyah = try tajweed.spans(for: verses)
            for verse in verses {
                let length = verse.text.unicodeScalars.count
                for span in spansByAyah[verse.surahId * 1000 + verse.ayah] ?? [] {
                    XCTAssertGreaterThanOrEqual(span.start, 0,
                        "\(verse.id) \(span.rule.rawValue) starts before the ayah")
                    XCTAssertLessThan(span.start, span.end,
                        "\(verse.id) \(span.rule.rawValue) is empty or inverted")
                    XCTAssertLessThanOrEqual(span.end, length,
                        "\(verse.id) \(span.rule.rawValue) ends past the ayah (\(length))")
                    checked += 1
                }
            }
        }
        XCTAssertEqual(checked, try tajweed.spanCount(),
                       "the per-ayah queries did not return every stored span")
        XCTAssertGreaterThan(checked, 60_000, "far fewer spans than expected")
    }

    /// The DB's rule table and `TajweedRule` must agree exactly — the app
    /// would otherwise silently drop, or mis-colour, a whole rule.
    /// `TajweedDatabase.init` enforces this; here we pin the count and names.
    func testRuleSetMatchesTheEnum() throws {
        XCTAssertEqual(TajweedRule.allCases.count, 18)
        XCTAssertEqual(Set(TajweedRule.legendOrder), Set(TajweedRule.allCases),
                       "the legend must list every rule exactly once")
        XCTAssertEqual(TajweedRule.legendOrder.count, TajweedRule.allCases.count)
    }

    /// Every rule is actually present in the data — a rule that never occurs
    /// would be a dead legend row and a sign the build lost something.
    func testEveryRuleOccursInTheData() throws {
        var seen: Set<TajweedRule> = []
        for surah in try quran.allSurahs() {
            let verses = try quran.verses(surahId: surah.id)
            for spans in try tajweed.spans(for: verses).values {
                seen.formUnion(spans.map(\.rule))
            }
            if seen.count == TajweedRule.allCases.count { break }
        }
        XCTAssertEqual(seen, Set(TajweedRule.allCases))
    }

    /// The builder recorded its provenance, so a shipped binary can say where
    /// the data came from and under what licence.
    func testProvenanceMetadataIsRecorded() throws {
        XCTAssertEqual(try tajweed.metadata("source"),
                       "https://github.com/cpfair/quran-tajweed")
        let license = try XCTUnwrap(tajweed.metadata("license"))
        XCTAssertTrue(license.contains("CC BY 4.0"), license)
        XCTAssertNotNil(try tajweed.metadata("retrieved"))
    }

    // MARK: Known cases — is the colour on the RIGHT letters?

    /// Qalqalah applies to ق ط ب ج د carrying sukun. Across the whole Quran,
    /// every qalqalah span must contain one of those five consonants. This is
    /// the sharpest available check that the offsets were carried onto OUR
    /// text correctly rather than merely landing inside the right ayah.
    func testEveryQalqalahSpanCoversAQalqalahLetter() throws {
        let qalqalah: Set<Unicode.Scalar> = ["ق", "ط", "ب", "ج", "د"]
        var checked = 0
        for surah in try quran.allSurahs() {
            let verses = try quran.verses(surahId: surah.id)
            let spansByAyah = try tajweed.spans(for: verses)
            for verse in verses {
                let scalars = Array(verse.text.unicodeScalars)
                for span in spansByAyah[verse.surahId * 1000 + verse.ayah] ?? []
                where span.rule == .qalqalah {
                    XCTAssertTrue(scalars[span.start..<span.end].contains(where: qalqalah.contains),
                                  "\(verse.id) qalqalah span covers no qalqalah letter")
                    checked += 1
                }
            }
        }
        XCTAssertGreaterThan(checked, 3_000, "suspiciously few qalqalah spans")
    }

    /// Al-Masad — the classic teaching example for qalqalah on bā, which ends
    /// four of its five ayat. Each of those ayat carries exactly one qalqalah,
    /// and it sits on the bā; ayah 5 adds the dāl of "masad".
    func testQalqalahInAlMasad() throws {
        for ayah in 1...4 {
            let scalars = try text(111, ayah)
            let spans = try tajweed.spans(surahId: 111, ayah: ayah)
                .filter { $0.rule == .qalqalah }
            XCTAssertEqual(spans.count, 1, "expected one qalqalah in 111:\(ayah)")
            for span in spans {
                XCTAssertTrue(scalars[span.start..<span.end].contains("ب"),
                              "111:\(ayah) qalqalah span is not on a bā")
            }
        }
        let last = try text(111, 5)
        let spans = try tajweed.spans(surahId: 111, ayah: 5).filter { $0.rule == .qalqalah }
        XCTAssertEqual(spans.count, 2, "expected qalqalah on both bā and dāl in 111:5")
        let letters = spans.flatMap { Array(last[$0.start..<$0.end]) }
        XCTAssertTrue(letters.contains("ب"))
        XCTAssertTrue(letters.contains("د"))
    }

    /// Lām shamsiyyah is the silent lām of the definite article: the span must
    /// always sit on a lām.
    func testLamShamsiyyahSpansSitOnALam() throws {
        var checked = 0
        for surahId in 1...20 {
            let verses = try quran.verses(surahId: surahId)
            let spansByAyah = try tajweed.spans(for: verses)
            for verse in verses {
                let scalars = Array(verse.text.unicodeScalars)
                for span in spansByAyah[verse.surahId * 1000 + verse.ayah] ?? []
                where span.rule == .lamShamsiyyah {
                    XCTAssertTrue(scalars[span.start..<span.end].contains("ل"),
                                  "\(verse.id) lam_shamsiyyah span is not on a lām")
                    checked += 1
                }
            }
        }
        XCTAssertGreaterThan(checked, 100)
    }

    /// Iqlab is noon sākinah/tanween turning into a hidden meem before bā.
    /// The annotated run covers the noon/tanween, the small meem the mushaf
    /// prints on it, and the bā that triggers it — so the letters an ayah's
    /// iqlab colouring touches must include both a meem and a bā.
    ///
    /// Asserted per AYAH, not per span, because the builder deliberately
    /// splits a run around an intervening waqf mark (20 of the 582 iqlab runs
    /// have one between the tanwin and the bā) so the pause mark is not tinted
    /// as though it were a tajweed letter.
    ///
    /// The meem is written high (U+06E2) after fatha or damma tanwin and low
    /// (U+06ED) after kasra tanwin; both are it.
    func testIqlabColouringCoversTheMeemAndTheBa() throws {
        let iqlabMeems: Set<Unicode.Scalar> = ["\u{06E2}", "\u{06ED}"]
        var checked = 0
        for surahId in 1...30 {
            let verses = try quran.verses(surahId: surahId)
            let spansByAyah = try tajweed.spans(for: verses)
            for verse in verses {
                let scalars = Array(verse.text.unicodeScalars)
                let iqlab = (spansByAyah[verse.surahId * 1000 + verse.ayah] ?? [])
                    .filter { $0.rule == .iqlab }
                guard !iqlab.isEmpty else { continue }
                let covered = iqlab.flatMap { Array(scalars[$0.start..<$0.end]) }
                XCTAssertTrue(covered.contains(where: iqlabMeems.contains),
                              "\(verse.id) iqlab colouring misses the small meem")
                XCTAssertTrue(covered.contains("ب"),
                              "\(verse.id) iqlab colouring misses the bā")
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 50)
    }

    /// No span may cover a waqf/sajdah mark: those are recitation
    /// instructions, not letters, and tinting one would read as a rule.
    func testNoSpanCoversAWaqfMark() throws {
        let waqf = Set((0x06D6...0x06DE).compactMap(Unicode.Scalar.init) + [Unicode.Scalar(0x06E9)!])
        for surahId in 1...40 {
            let verses = try quran.verses(surahId: surahId)
            let spansByAyah = try tajweed.spans(for: verses)
            for verse in verses {
                let scalars = Array(verse.text.unicodeScalars)
                for span in spansByAyah[verse.surahId * 1000 + verse.ayah] ?? [] {
                    XCTAssertFalse(scalars[span.start..<span.end].contains(where: waqf.contains),
                                   "\(verse.id) \(span.rule.rawValue) tints a waqf mark")
                }
            }
        }
    }

    // MARK: Flow rendering uses the same coordinates as the data

    /// The reader colours per WORD, using `QuranFlowItem.scalarStart` as the
    /// word's offset into the stored ayah. If that drifts, every colour lands
    /// on the wrong letter — so assert the offset reproduces the word exactly,
    /// including on ayah 1 where a leading basmala is stripped for display.
    func testFlowItemScalarOffsetsAddressTheStoredText() throws {
        let basmala = try XCTUnwrap(quran.verses(surahId: 1).first?.text)
        for surahId in [1, 2, 9, 95, 97, 110, 114] {
            let verses = try quran.verses(surahId: surahId)
            let items = QuranFlow.items(verses: verses,
                                        basmalaToStrip: surahId == 1 ? nil : basmala)
            let textByAyah = Dictionary(uniqueKeysWithValues:
                verses.map { ($0.ayah, Array($0.text.unicodeScalars)) })
            var words = 0
            for item in items where item.kind == .word {
                let scalars = try XCTUnwrap(textByAyah[item.ayah])
                let length = item.text.unicodeScalars.count
                XCTAssertLessThanOrEqual(item.scalarStart + length, scalars.count,
                                         "\(surahId):\(item.ayah) word runs past the ayah")
                let slice = String(String.UnicodeScalarView(
                    scalars[item.scalarStart..<(item.scalarStart + length)]))
                XCTAssertEqual(slice, item.text,
                               "\(surahId):\(item.ayah) scalarStart does not address the word")
                words += 1
            }
            XCTAssertGreaterThan(words, 0)
        }
    }

    /// End to end: a span's letters must survive the trip through the flow
    /// splitter into the per-word tint. Take every qalqalah span of Al-Masad
    /// and confirm each word that will be tinted really carries a qalqalah
    /// letter — the bā ending ayat 1-4, and the dāl of "masad" in ayah 5.
    func testColouringReachesTheIntendedWord() throws {
        let verses = try quran.verses(surahId: 111)
        let items = QuranFlow.items(verses: verses)
        let spansByAyah = try tajweed.spans(for: verses)
        let qalqalah: Set<Unicode.Scalar> = ["ق", "ط", "ب", "ج", "د"]
        var tinted = 0
        for item in items where item.kind == .word {
            let spans = TajweedColoring.spans(spansByAyah[111 * 1000 + item.ayah] ?? [],
                                              overlapping: item.scalarStart,
                                              length: item.text.unicodeScalars.count)
            for span in spans where span.rule == .qalqalah {
                XCTAssertTrue(item.text.unicodeScalars.contains(where: qalqalah.contains),
                              "a qalqalah tint landed on a word with no qalqalah letter: \(item.text)")
                tinted += 1
            }
        }
        XCTAssertGreaterThan(tinted, 0, "no qalqalah reached a word in Al-Masad")
    }
}

/// The reader's colour legend and the Learn tajweed guide must name a rule the
/// same way. `TajweedGuideView` builds its rows from `TajweedRule`, so this
/// pins the shared names against accidental divergence.
final class TajweedRuleNamingTests: XCTestCase {
    func testEveryRuleIsNamedInBothLanguages() {
        for rule in TajweedRule.allCases {
            XCTAssertFalse(rule.nameArabic.isEmpty, rule.rawValue)
            XCTAssertFalse(rule.nameEnglish.isEmpty, rule.rawValue)
            XCTAssertEqual(rule.name(arabicUI: true), rule.nameArabic)
            XCTAssertEqual(rule.name(arabicUI: false), rule.nameEnglish)
        }
    }

    func testRuleNamesAreUnique() {
        XCTAssertEqual(Set(TajweedRule.allCases.map(\.nameArabic)).count,
                       TajweedRule.allCases.count)
        XCTAssertEqual(Set(TajweedRule.allCases.map(\.nameEnglish)).count,
                       TajweedRule.allCases.count)
    }

    /// The five rules the Learn guide also teaches keep the guide's wording.
    func testSharedRuleNamesMatchTheLearnGuide() {
        XCTAssertEqual(TajweedRule.idghaamGhunnah.nameEnglish, "Idghām with ghunnah")
        XCTAssertEqual(TajweedRule.idghaamNoGhunnah.nameEnglish, "Idghām without ghunnah")
        XCTAssertEqual(TajweedRule.iqlab.nameEnglish, "Iqlāb")
        XCTAssertEqual(TajweedRule.ikhfa.nameEnglish, "Ikhfāʾ (hiding)")
        XCTAssertEqual(TajweedRule.qalqalah.nameEnglish, "Qalqalah (echoing)")
        XCTAssertEqual(TajweedRule.idghaamGhunnah.nameArabic, "الإدغام بغنة")
        XCTAssertEqual(TajweedRule.qalqalah.nameArabic, "القلقلة")
    }
}
