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
}
