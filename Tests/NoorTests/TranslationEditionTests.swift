import DesignSystem
import Translations
import XCTest

/// Which translation edition the reader loads, and when it follows the
/// interface language versus a choice the user made.
final class TranslationEditionTests: XCTestCase {
    /// A throwaway defaults domain so no test reads or writes the app's
    /// real `translation.id`.
    private var defaults: UserDefaults!
    private let suite = "TranslationEditionTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    /// Every interface language has an edition of its own — except Arabic,
    /// which reads the Quran itself and keeps English.
    func testEveryInterfaceLanguageHasADefaultEdition() {
        let expected: [NoorLanguage: String] = [
            .en: "en.sahih", .ur: "ur.jalandhry", .fr: "fr.hamidullah",
            .id: "id.indonesian", .tr: "tr.diyanet", .fa: "fa.fooladvand",
            .bn: "bn.zakaria", .ms: "ms.basmeih", .es: "es.garcia",
            .ar: "en.sahih",
        ]
        XCTAssertEqual(Set(expected.keys), Set(NoorLanguage.allCases), "a language has no expectation")
        for (language, id) in expected {
            XCTAssertEqual(TranslationStore.defaultEdition(forLanguage: language.rawValue).id, id,
                           "wrong default for \(language.rawValue)")
        }
        // Somali is offered ahead of its interface language.
        XCTAssertEqual(TranslationStore.defaultEdition(forLanguage: "so").id, "so.abduh")
        // Unknown languages fall back to English, never crash or go blank.
        XCTAssertEqual(TranslationStore.defaultEdition(forLanguage: "pt").id, "en.sahih")
    }

    func testEveryEditionIsOfferedExactlyOnceWithAMirrorFile() {
        let ids = TranslationStore.allEditions.map(\.id)
        XCTAssertEqual(ids.count, 10)
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate edition id")
        XCTAssertEqual(Set(ids), ["en.sahih", "ur.jalandhry", "fr.hamidullah", "id.indonesian",
                                  "tr.diyanet", "fa.fooladvand", "bn.zakaria", "ms.basmeih",
                                  "es.garcia", "so.abduh"])
        for edition in TranslationStore.allEditions {
            XCTAssertEqual(edition.sources.compactMap(\.host),
                           ["cdn.jsdelivr.net", "raw.githubusercontent.com", "tanzil.net"],
                           "unexpected sources for \(edition.id)")
            XCTAssertFalse(edition.displayName.isEmpty)
        }
    }

    /// The gloss reads in ITS direction, not the interface's: Urdu and
    /// Persian right to left, everything else left to right.
    func testOnlyUrduAndPersianEditionsReadRightToLeft() {
        let rtl = TranslationStore.allEditions.filter(\.isRTL).map(\.id)
        XCTAssertEqual(Set(rtl), ["ur.jalandhry", "fa.fooladvand"])
        for id in ["bn.zakaria", "ms.basmeih", "es.garcia", "so.abduh", "en.sahih"] {
            XCTAssertFalse(TranslationStore.allEditions.first { $0.id == id }!.isRTL, "\(id) must be LTR")
        }
    }

    /// Never chosen (key absent): the edition follows whatever language the
    /// interface is in, and changes with it.
    func testNeverChosenFollowsTheInterfaceLanguage() {
        XCTAssertNil(TranslationStore.explicitEdition(defaults: defaults))
        XCTAssertEqual(TranslationStore.selectedEdition(interfaceLanguage: "tr", defaults: defaults).id,
                       "tr.diyanet")
        XCTAssertEqual(TranslationStore.selectedEdition(interfaceLanguage: "fa", defaults: defaults).id,
                       "fa.fooladvand")
        XCTAssertEqual(TranslationStore.selectedEdition(interfaceLanguage: "bn", defaults: defaults).id,
                       "bn.zakaria")
        XCTAssertEqual(TranslationStore.selectedEdition(interfaceLanguage: "ar", defaults: defaults).id,
                       "en.sahih")
    }

    /// An explicit choice — English included, which is indistinguishable
    /// from the old default unless absence is the sentinel — survives a
    /// later language change.
    func testExplicitChoiceSurvivesALanguageChange() {
        defaults.set("en.sahih", forKey: TranslationStore.defaultsKey)
        XCTAssertEqual(TranslationStore.explicitEdition(defaults: defaults)?.id, "en.sahih")
        XCTAssertEqual(TranslationStore.selectedEdition(interfaceLanguage: "fr", defaults: defaults).id,
                       "en.sahih", "chose English deliberately; French must not override it")
        XCTAssertEqual(TranslationStore.selectedEdition(interfaceLanguage: "fa", defaults: defaults).id,
                       "en.sahih")

        // Un-pinning is removing the key — back to following the language.
        defaults.removeObject(forKey: TranslationStore.defaultsKey)
        XCTAssertEqual(TranslationStore.selectedEdition(interfaceLanguage: "fr", defaults: defaults).id,
                       "fr.hamidullah")
    }

    /// An id that is no longer offered must not strand the reader on a
    /// missing edition.
    func testUnknownStoredIdFallsBackToTheLanguageDefault() {
        defaults.set("de.bubenheim", forKey: TranslationStore.defaultsKey)
        XCTAssertNil(TranslationStore.explicitEdition(defaults: defaults))
        XCTAssertEqual(TranslationStore.selectedEdition(interfaceLanguage: "ms", defaults: defaults).id,
                       "ms.basmeih")
    }
}
