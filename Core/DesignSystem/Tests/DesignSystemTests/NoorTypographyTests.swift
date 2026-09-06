import CoreText
import Foundation
@testable import DesignSystem
import XCTest

final class NoorTypographyTests: XCTestCase {
    func testArabicLocalesUseArabicInterfaceFont() {
        XCTAssertTrue(
            NoorFont.usesArabicInterfaceFont(locale: Locale(identifier: "ar"))
        )
        XCTAssertTrue(
            NoorFont.usesArabicInterfaceFont(locale: Locale(identifier: "ar_AE"))
        )
        XCTAssertFalse(
            NoorFont.usesArabicInterfaceFont(locale: Locale(identifier: "en_AE"))
        )
    }

    func testBundledCairoRegistersWithExpectedNames() {
        FontRegistrar.registerBundledFonts()

        let expectedNames = [
            "Cairo-Regular",
            "Cairo-Regular_SemiBold",
            "Cairo-Regular_Bold",
        ]
        for expectedName in expectedNames {
            let font = CTFontCreateWithName(expectedName as CFString, 17, nil)
            XCTAssertEqual(CTFontCopyPostScriptName(font) as String, expectedName)
            XCTAssertEqual(CTFontCopyFamilyName(font) as String, "Cairo")
        }
    }
}
