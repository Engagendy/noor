import DesignSystem
import XCTest

/// A half-translated language must not be able to ship.
///
/// The app offers ten interface languages from one picker. Nothing at
/// runtime notices when a key is missing from one of them: SwiftUI falls
/// back to the development language, so an Urdu screen quietly grows an
/// English row and only a native speaker would ever report it. These tests
/// read the *source* string catalog and fail the build instead.
final class LocalizationCatalogTests: XCTestCase {
    /// The catalog as committed, not the compiled `.strings` in the test
    /// bundle — the point is to check what a translator has to fill in.
    private static let catalogURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // NoorTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // repo root
        .appendingPathComponent("App/Resources/Localizable.xcstrings")

    private struct Catalog {
        let sourceLanguage: String
        /// key -> language -> the value, or `nil` for a plural entry (whose
        /// value depends on the count and is checked separately).
        let strings: [String: [String: String?]]
        let pluralKeys: Set<String>
    }

    private func loadCatalog() throws -> Catalog {
        let data = try Data(contentsOf: Self.catalogURL)
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let rawStrings = try XCTUnwrap(root["strings"] as? [String: [String: Any]])
        var strings: [String: [String: String?]] = [:]
        var pluralKeys: Set<String> = []
        for (key, entry) in rawStrings {
            var byLanguage: [String: String?] = [:]
            let localizations = entry["localizations"] as? [String: [String: Any]] ?? [:]
            for (language, localization) in localizations {
                if let unit = localization["stringUnit"] as? [String: Any],
                   let value = unit["value"] as? String {
                    byLanguage[language] = value
                } else if localization["variations"] != nil {
                    pluralKeys.insert(key)
                    byLanguage[language] = String?.none
                }
            }
            strings[key] = byLanguage
        }
        return Catalog(sourceLanguage: root["sourceLanguage"] as? String ?? "en",
                       strings: strings, pluralKeys: pluralKeys)
    }

    /// The English text a translator worked from: the `en` localization when
    /// there is one, otherwise the key itself (the SwiftUI default, and the
    /// shape most of this catalog is in).
    private func source(_ key: String, _ byLanguage: [String: String?]) -> String {
        (byLanguage["en"] ?? nil) ?? key
    }

    func testEveryPickerLanguageTranslatesEveryKey() throws {
        let catalog = try loadCatalog()
        XCTAssertGreaterThan(catalog.strings.count, 300, "catalog failed to load")
        var missing: [String] = []
        for language in NoorLanguage.allCases where language.rawValue != catalog.sourceLanguage {
            for (key, byLanguage) in catalog.strings {
                guard let value = byLanguage[language.rawValue] else {
                    missing.append("\(language.rawValue): \(key)")
                    continue
                }
                if let value, value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    missing.append("\(language.rawValue): \(key) is empty")
                }
            }
        }
        XCTAssertEqual(
            missing.count, 0,
            """
            \(missing.count) untranslated string(s). A language in the picker \
            with a gap ships an English row inside an otherwise translated \
            screen. First 20:
            \(missing.sorted().prefix(20).joined(separator: "\n"))
            """)
    }

    /// A translation that drops or adds a `%@` crashes, or prints the wrong
    /// argument, only on the language nobody on the team reads.
    func testFormatSpecifiersSurviveTranslation() throws {
        let catalog = try loadCatalog()
        var wrong: [String] = []
        for (key, byLanguage) in catalog.strings where !catalog.pluralKeys.contains(key) {
            let expected = Self.specifiers(in: source(key, byLanguage))
            for language in NoorLanguage.allCases {
                guard let value = byLanguage[language.rawValue] ?? nil else { continue }
                let found = Self.specifiers(in: value)
                if found != expected {
                    wrong.append("\(language.rawValue): \(key) — \(expected) vs \(found)")
                }
                // Mixing `%@` with `%1$@` in one string is a runtime trap:
                // once any specifier is positional they all must be.
                let positional = value.ranges(of: /%\d+\$/).count
                if positional > 0 && positional != found.count {
                    wrong.append("\(language.rawValue): \(key) mixes positional and plain specifiers")
                }
            }
        }
        XCTAssertEqual(wrong.count, 0, wrong.sorted().joined(separator: "\n"))
    }

    /// The conversion characters, in order, ignoring argument position and
    /// `%%` escapes — `%1$lld` and `%lld` both count as one `d`.
    private static func specifiers(in value: String) -> [String] {
        let pattern = /%(?:\d+\$)?[-+ #0]*[0-9*]*(?:\.[0-9]+)?(?:hh|h|ll|l|q|L|z|t|j)?([@dioufeEgGxXcsp%])/
        return value.matches(of: pattern)
            .map { String($0.1) }
            .filter { $0 != "%" }
    }

    /// The picker's promise: every language written in its own script, and
    /// no two rows alike.
    func testEveryLanguageHasADistinctEndonym() {
        var seen: Set<String> = []
        for language in NoorLanguage.allCases {
            XCTAssertFalse(language.endonym.isEmpty, "\(language.rawValue) has no endonym")
            XCTAssertTrue(seen.insert(language.endonym).inserted,
                          "\(language.endonym) appears twice in the picker")
        }
        // Spot-check the ones a well-meaning edit would "translate".
        XCTAssertEqual(NoorLanguage.ar.endonym, "العربية")
        XCTAssertEqual(NoorLanguage.ur.endonym, "اردو")
        XCTAssertEqual(NoorLanguage.bn.endonym, "বাংলা")
    }

    /// iOS only offers a language in Settings → Noor if the bundle declares
    /// it, so `project.yml` and `NoorLanguage` must not drift apart.
    func testProjectDeclaresEveryLanguageAsAKnownRegion() throws {
        let projectURL = Self.catalogURL
            .deletingLastPathComponent()   // Resources
            .deletingLastPathComponent()   // App
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("project.yml")
        let yaml = try String(contentsOf: projectURL, encoding: .utf8)
        let line = try XCTUnwrap(
            yaml.split(separator: "\n").first { $0.contains("knownRegions:") },
            "project.yml has no knownRegions")
        for language in NoorLanguage.allCases {
            XCTAssertTrue(line.contains(language.rawValue),
                          "knownRegions is missing \(language.rawValue)")
        }
    }
}

/// The direction, digits and face that follow from the language choice.
final class NoorLanguageTests: XCTestCase {
    func testRightToLeftIsNotJustArabic() {
        XCTAssertEqual(NoorLanguage.allCases.filter(\.isRTL), [.ar, .ur, .fa])
        // Bengali is non-Latin but left-to-right — the trap this check exists
        // to catch is a "non-Latin means RTL" shortcut.
        XCTAssertFalse(NoorLanguage.bn.isRTL)
        XCTAssertEqual(NoorLanguage.bn.layoutDirection, .leftToRight)
        XCTAssertEqual(NoorLanguage.ur.layoutDirection, .rightToLeft)
    }

    func testTrackingIsSuppressedForEveryNonLatinScript() {
        for language in [NoorLanguage.ar, .ur, .fa, .bn] {
            XCTAssertFalse(language.usesLatinScript, "\(language.rawValue) must not be tracked")
        }
        for language in [NoorLanguage.en, .id, .ms, .tr, .fr, .es] {
            XCTAssertTrue(language.usesLatinScript)
        }
    }

    func testEachLanguageWritesNumbersInItsOwnDigits() {
        XCTAssertEqual(604.noorDigits(.en), "604")
        XCTAssertEqual(604.noorDigits(.fr), "604")
        XCTAssertEqual(604.noorDigits(.ar), "٦٠٤")
        XCTAssertEqual(604.noorDigits(.fa), "۶۰۴")
        // Urdu takes the eastern forms Persian uses, not Arabic's.
        XCTAssertEqual(604.noorDigits(.ur), "۶۰۴")
        XCTAssertEqual(604.noorDigits(.bn), "৬০৪")
    }

    /// Urdu and Bengali override CLDR, which defaults both to Western
    /// digits; every formatter in the app reads this locale, so this is what
    /// keeps a formatted prayer time in the same numerals as the sentence
    /// around it.
    func testUrduAndBengaliFormatInTheirOwnDigits() {
        XCTAssertEqual(NoorLanguage.ur.locale.numberFormat(604), "۶۰۴")
        XCTAssertEqual(NoorLanguage.fa.locale.numberFormat(604), "۶۰۴")
        XCTAssertEqual(NoorLanguage.bn.locale.numberFormat(604), "৬০৪")
        XCTAssertEqual(NoorLanguage.tr.locale.numberFormat(604), "604")
        XCTAssertEqual(NoorLanguage.ur.locale.language.languageCode?.identifier, "ur",
                       "the numbering-system override must not change the language")
        XCTAssertEqual(NoorLanguage.bn.locale.language.languageCode?.identifier, "bn")
    }

    func testResolveFallsBackToAKnownLanguage() {
        XCTAssertEqual(NoorLanguage.resolve("bn"), .bn)
        XCTAssertEqual(NoorLanguage.resolve("pt-BR"), .en)
        XCTAssertEqual(NoorLanguage.resolve("ur-PK"), .ur)
    }
}

private extension Locale {
    func numberFormat(_ value: Int) -> String {
        value.formatted(.number.grouping(.never).locale(self))
    }
}
