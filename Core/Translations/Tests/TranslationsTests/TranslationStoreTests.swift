import XCTest
@testable import Translations

final class TranslationStoreTests: XCTestCase {
    func testParsesTanzilFormat() {
        let sample = """
        1|1|In the name of Allah, the Entirely Merciful, the Especially Merciful.
        1|2|[All] praise is [due] to Allah, Lord of the worlds -
        # comment line
        2|255|Allah - there is no deity except Him...
        """
        let parsed = TranslationStore.parse(sample)
        XCTAssertEqual(parsed.count, 3)
        XCTAssertEqual(parsed[1001], "In the name of Allah, the Entirely Merciful, the Especially Merciful.")
        XCTAssertEqual(parsed[2255], "Allah - there is no deity except Him...")
        XCTAssertNil(parsed[3001])
    }

    func testParseIgnoresMalformedLines() {
        let parsed = TranslationStore.parse("not a line\n1|x|bad\n1|1|ok")
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[1001], "ok")
    }

    // MARK: - Mirror (fawazahmed0/quran-api) JSON

    /// A whole-Quran-sized body of clearly NON-Quranic placeholder text —
    /// the shape is what is under test, never the scripture.
    private func mirrorJSON(ayat: Int) -> String {
        let entries = (0..<ayat).map { index in
            "{\"chapter\":\(index / 300 + 1),\"verse\":\(index % 300 + 1),\"text\":\"placeholder \(index)\"}"
        }
        return "{\"quran\":[" + entries.joined(separator: ",") + "]}"
    }

    func testNormalizeConvertsMirrorJSONToTanzilLines() throws {
        let lines = try XCTUnwrap(TranslationStore.normalize(mirrorJSON(ayat: 6236)))
        let parsed = TranslationStore.parse(lines)
        XCTAssertEqual(parsed.count, 6236)
        XCTAssertEqual(parsed[1001], "placeholder 0")
        XCTAssertTrue(lines.hasPrefix("1|1|placeholder 0\n"))
    }

    func testNormalizePassesTanzilLinesThrough() throws {
        let sample = (0..<6236).map { "\($0 / 300 + 1)|\($0 % 300 + 1)|placeholder \($0)" }
            .joined(separator: "\n")
        XCTAssertEqual(TranslationStore.normalize(sample), sample)
    }

    /// A web filter's "Web Page Blocked" HTML — or any short body — must
    /// never be written to disk as if it were a translation.
    func testNormalizeRejectsNonQuranBodies() {
        XCTAssertNil(TranslationStore.normalize("<html><body>Web Page Blocked</body></html>"))
        XCTAssertNil(TranslationStore.normalize(mirrorJSON(ayat: 10)))
        XCTAssertNil(TranslationStore.normalize("{\"quran\":"))
    }

    func testEveryEditionHasAllThreeSources() {
        for edition in TranslationStore.allEditions {
            let hosts = edition.sources.compactMap(\.host)
            XCTAssertEqual(hosts, ["cdn.jsdelivr.net", "raw.githubusercontent.com", "tanzil.net"],
                           "unexpected sources for \(edition.id)")
        }
    }
}
