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

        let font = CTFontCreateWithName("Cairo-Regular" as CFString, 17, nil)
        XCTAssertEqual(CTFontCopyPostScriptName(font) as String, "Cairo-Regular")
        XCTAssertEqual(CTFontCopyFamilyName(font) as String, "Cairo")
    }
}
