import XCTest
@testable import Tafsir

final class TafsirServiceTests: XCTestCase {
    func testParsePayload() throws {
        let json = #"{"surah":1,"ayah":1,"text":"<p>In the name of Allah</p><br>the Merciful &amp; Compassionate"}"#
        let text = try TafsirService.parse(Data(json.utf8))
        XCTAssertEqual(text, "In the name of Allah\n\nthe Merciful & Compassionate")
    }

    func testStripHTMLKeepsPlainText() {
        XCTAssertEqual(TafsirService.stripHTML("plain arabic نص"), "plain arabic نص")
        XCTAssertEqual(TafsirService.stripHTML("<b>bold</b> &quot;q&quot;"), "bold \"q\"")
    }
}
