import Foundation
import GRDB

/// The tajweed rules annotated in the bundled `tajweed.sqlite`.
///
/// Raw values are the rule names used by the source data set
/// (cpfair/quran-tajweed, CC BY 4.0 — see LICENSES.md) and are the contract
/// between `Tools/build_tajweed.py` and the app: the builder asserts the data
/// file contains exactly these 18 names, and `TajweedDatabase.init` asserts
/// the bundled DB maps onto them.
public enum TajweedRule: String, CaseIterable, Sendable, Hashable, Identifiable {
    case ghunnah
    case hamzatWasl = "hamzat_wasl"
    case idghaamGhunnah = "idghaam_ghunnah"
    case idghaamMutajanisayn = "idghaam_mutajanisayn"
    case idghaamMutaqaribayn = "idghaam_mutaqaribayn"
    case idghaamNoGhunnah = "idghaam_no_ghunnah"
    case idghaamShafawi = "idghaam_shafawi"
    case ikhfa
    case ikhfaShafawi = "ikhfa_shafawi"
    case iqlab
    case lamShamsiyyah = "lam_shamsiyyah"
    case madd2 = "madd_2"
    case madd246 = "madd_246"
    case madd6 = "madd_6"
    case maddMunfasil = "madd_munfasil"
    case maddMuttasil = "madd_muttasil"
    case qalqalah
    case silent

    public var id: String { rawValue }

    /// Rule name in Arabic. Single source of truth for the whole app: the
    /// Learn tajweed guide and the reader's colour legend both read these, so
    /// the same rule is never described two different ways.
    public var nameArabic: String {
        switch self {
        case .ghunnah: "الغنة"
        case .hamzatWasl: "همزة الوصل"
        case .idghaamGhunnah: "الإدغام بغنة"
        case .idghaamMutajanisayn: "إدغام المتجانسين"
        case .idghaamMutaqaribayn: "إدغام المتقاربين"
        case .idghaamNoGhunnah: "الإدغام بغير غنة"
        case .idghaamShafawi: "الإدغام الشفوي"
        case .ikhfa: "الإخفاء الحقيقي"
        case .ikhfaShafawi: "الإخفاء الشفوي"
        case .iqlab: "الإقلاب"
        case .lamShamsiyyah: "اللام الشمسية"
        case .madd2: "المد الطبيعي"
        case .madd246: "مد العارض واللين"
        case .madd6: "المد اللازم"
        case .maddMunfasil: "المد المنفصل"
        case .maddMuttasil: "المد المتصل"
        case .qalqalah: "القلقلة"
        case .silent: "حرف لا يُنطق"
        }
    }

    /// Rule name in English, in the transliteration style the Learn guide
    /// already uses (macrons and ʾ/ʿ, not ASCII).
    public var nameEnglish: String {
        switch self {
        case .ghunnah: "Ghunnah (nasal sound)"
        case .hamzatWasl: "Hamzat al-wasl"
        case .idghaamGhunnah: "Idghām with ghunnah"
        case .idghaamMutajanisayn: "Idghām mutajānisayn"
        case .idghaamMutaqaribayn: "Idghām mutaqāribayn"
        case .idghaamNoGhunnah: "Idghām without ghunnah"
        case .idghaamShafawi: "Idghām shafawī"
        case .ikhfa: "Ikhfāʾ (hiding)"
        case .ikhfaShafawi: "Ikhfāʾ shafawī"
        case .iqlab: "Iqlāb"
        case .lamShamsiyyah: "Lām shamsiyyah"
        case .madd2: "Natural madd — 2 counts"
        case .madd246: "Madd al-ʿārid / al-līn — 2, 4 or 6"
        case .madd6: "Madd lāzim — 6 counts"
        case .maddMunfasil: "Madd munfasil — 4 or 5"
        case .maddMuttasil: "Madd muttasil — 4 or 5"
        case .qalqalah: "Qalqalah (echoing)"
        case .silent: "Silent letter"
        }
    }

    /// Name in the UI language, chosen the same way the Learn guide chooses.
    public func name(arabicUI: Bool) -> String {
        arabicUI ? nameArabic : nameEnglish
    }
}

/// One coloured run inside an ayah.
///
/// `start`/`end` are Unicode *scalar* offsets into `Verse.text` — a half-open
/// range, always `0 <= start < end <= text.unicodeScalars.count`. They were
/// carried across from the source data set's own Tanzil variant to ours by
/// `Tools/build_tajweed.py`; the Quran text itself is never modified.
public struct TajweedSpan: Sendable, Hashable {
    public let rule: TajweedRule
    public let start: Int
    public let end: Int

    public init(rule: TajweedRule, start: Int, end: Int) {
        self.rule = rule
        self.start = start
        self.end = end
    }
}

/// Read-only access to the bundled tajweed annotations.
///
/// Kept as a separate SQLite file rather than a table in `quran.sqlite`
/// because that database is checksummed (`QuranDatabase.verifyIntegrity`) and
/// must stay byte-identical, and rather than a bundled JSON blob because the
/// reader only ever needs the handful of ayat on screen: an indexed lookup on
/// `(surah_id, ayah)` touches a few rows, where JSON would mean parsing and
/// holding all 60k spans in memory for a single page.
public final class TajweedDatabase: Sendable {
    private let queue: DatabaseQueue

    public init() throws {
        guard let url = Bundle.module.url(forResource: "tajweed", withExtension: "sqlite") else {
            throw QuranDatabaseError.missingDatabase
        }
        var config = Configuration()
        config.readonly = true
        self.queue = try DatabaseQueue(path: url.path, configuration: config)

        // Fail fast and loudly if the bundled data and this enum disagree:
        // a silent mismatch would colour letters with the wrong rule.
        let names = try queue.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM tajweed_rule")
        }
        let known = Set(TajweedRule.allCases.map(\.rawValue))
        guard Set(names) == known else {
            throw TajweedDatabaseError.ruleSetMismatch(Set(names).symmetricDifference(known))
        }
    }

    /// Spans for one ayah, in start order.
    public func spans(surahId: Int, ayah: Int) throws -> [TajweedSpan] {
        try queue.read { db in
            try Self.decode(rows: Row.fetchAll(
                db,
                sql: """
                    SELECT r.name, s.start, s.end
                    FROM tajweed_span s JOIN tajweed_rule r ON r.id = s.rule_id
                    WHERE s.surah_id = ? AND s.ayah = ?
                    ORDER BY s.start
                    """,
                arguments: [surahId, ayah]))
        }
    }

    /// Spans for a run of verses in ONE query, keyed by `surahId * 1000 + ayah`.
    ///
    /// The readers draw a whole page or surah at a time, so this is the hot
    /// path — per-ayah queries in a loop would be 15+ round trips per page.
    public func spans(for verses: [Verse]) throws -> [Int: [TajweedSpan]] {
        guard !verses.isEmpty else { return [:] }
        let keys = verses.map { $0.surahId * 1000 + $0.ayah }
        let placeholders = databaseQuestionMarks(count: keys.count)
        return try queue.read { db in
            var result: [Int: [TajweedSpan]] = [:]
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT s.surah_id, s.ayah, r.name, s.start, s.end
                    FROM tajweed_span s JOIN tajweed_rule r ON r.id = s.rule_id
                    WHERE s.surah_id * 1000 + s.ayah IN (\(placeholders))
                    ORDER BY s.surah_id, s.ayah, s.start
                    """,
                arguments: StatementArguments(keys))
            for row in rows {
                guard let rule = TajweedRule(rawValue: row["name"]) else { continue }
                let key: Int = row["surah_id"] * 1000 + row["ayah"]
                result[key, default: []].append(
                    TajweedSpan(rule: rule, start: row["start"], end: row["end"]))
            }
            return result
        }
    }

    public func spanCount() throws -> Int {
        try queue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM tajweed_span") ?? 0
        }
    }

    /// A `meta` row from the builder (source, licence, retrieval date, …).
    public func metadata(_ key: String) throws -> String? {
        try queue.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM meta WHERE key = ?",
                                arguments: [key])
        }
    }

    private static func decode(rows: [Row]) -> [TajweedSpan] {
        rows.compactMap { row in
            guard let rule = TajweedRule(rawValue: row["name"]) else { return nil }
            return TajweedSpan(rule: rule, start: row["start"], end: row["end"])
        }
    }
}

public enum TajweedDatabaseError: Error, Equatable {
    /// The bundled rule names and `TajweedRule` disagree — rebuild the DB
    /// with `Tools/build_tajweed.py` or update the enum, never ship both.
    case ruleSetMismatch(Set<String>)
}
