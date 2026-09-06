import DesignSystem
import XCTest
#if canImport(UIKit)
import UIKit
#endif

/// The interface font must never break UIKit's fixed-height chrome.
///
/// Arabic faces reserve much more vertical room than SF does (Cairo's line
/// box is ~1.6× the system's at the same point size), and UIKit lays a
/// tab-bar item out from that box — which is how the Cairo tab-bar labels
/// grew up into their icons. `chromeAttributes` pins the line box to the
/// system face's without touching the point size.
final class ChromeFontTests: XCTestCase {
    #if canImport(UIKit)
    override func setUp() {
        super.setUp()
        FontRegistrar.registerQuranFont()   // also registers the five UI families
    }

    private func lineBox(_ attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        let font = attributes[.font] as? UIFont
        if let style = attributes[.paragraphStyle] as? NSParagraphStyle,
           style.maximumLineHeight > 0 {
            return style.maximumLineHeight
        }
        return font?.lineHeight ?? 0
    }

    func testEveryFamilyResolvesToARealFace() throws {
        for family in NoorAppFont.allCases {
            let attributes = try XCTUnwrap(family.chromeAttributes(size: 10, weight: .medium,
                                                                  textStyle: .caption2),
                                           "\(family.displayName) has no bundled face")
            let font = try XCTUnwrap(attributes[.font] as? UIFont)
            XCTAssertEqual(font.fontName, family.fontName(for: .medium),
                           "\(family.displayName) must resolve to its own face, not a fallback")
        }
    }

    func testChromeLineBoxNeverExceedsTheSystemFace() throws {
        let systemLine = UIFontMetrics(forTextStyle: .caption2)
            .scaledFont(for: .systemFont(ofSize: 10)).lineHeight
        for family in NoorAppFont.allCases {
            let attributes = try XCTUnwrap(family.chromeAttributes(size: 10, weight: .medium,
                                                                  textStyle: .caption2))
            XCTAssertLessThanOrEqual(
                lineBox(attributes), systemLine + 0.01,
                "\(family.displayName) would overflow the tab-bar item's fixed height")
        }
    }

    func testCairoIsClampedAndItsGlyphSizeIsUntouched() throws {
        let size: CGFloat = 10
        let attributes = try XCTUnwrap(NoorAppFont.cairo.chromeAttributes(
            size: size, weight: .medium, textStyle: .caption2))
        let font = try XCTUnwrap(attributes[.font] as? UIFont)
        // The clamp is on the LINE BOX only: shrinking the point size would
        // render Cairo at ~6pt, which is the trap this test exists to catch.
        XCTAssertEqual(font.pointSize,
                       UIFontMetrics(forTextStyle: .caption2).scaledValue(for: size),
                       accuracy: 0.01)
        XCTAssertNotNil(attributes[.paragraphStyle], "Cairo must be clamped")
        XCTAssertGreaterThan(font.lineHeight, lineBox(attributes),
                             "Cairo's natural line box is the thing being clamped")
    }

    func testShortMetricFamilyIsLeftAlone() throws {
        // Almarai's line box is already under the system's — no clamp, no
        // paragraph style, nothing to distort.
        let attributes = try XCTUnwrap(NoorAppFont.almarai.chromeAttributes(
            size: 10, weight: .medium, textStyle: .caption2))
        XCTAssertNil(attributes[.paragraphStyle])
    }
    #endif
}
