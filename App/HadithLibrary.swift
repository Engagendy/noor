import ContentDB
import Foundation
import Observation
import SQLite3

/// The major hadith collections, downloadable as offline packs
/// (fawazahmed0/hadith-api, public domain — see LICENSES.md).
enum HadithCollectionID: String, CaseIterable, Identifiable {
    case bukhari, muslim

    var id: String { rawValue }
    var arabicName: String {
        switch self {
        case .bukhari: "صحيح البخاري"
        case .muslim: "صحيح مسلم"
        }
    }
    var englishName: String {
        switch self {
        case .bukhari: "Sahih al-Bukhari"
        case .muslim: "Sahih Muslim"
        }
    }
    var sizeLabel: String {
        switch self {
        case .bukhari: "~14 MB"
        case .muslim: "~15 MB"
        }
    }
}

struct LibraryHadith: Identifiable {
    let number: String
    let arabic: String
    let english: String
    let book: Int
    var id: String { number }
}

struct HadithBook: Identifiable {
    let index: Int
    let arabicTitle: String
    let englishTitle: String
    let count: Int
    var id: Int { index }
}

/// Downloads collections, converts them ONCE into SQLite, then serves
/// book lists, hadiths, and search straight from disk — instant opens,
/// no multi-megabyte JSON parsing per session.
@Observable
@MainActor
final class HadithLibrary {
    static let shared = HadithLibrary()

    enum PackState: Equatable {
        case notDownloaded, downloading, ready, failed
    }

    private(set) var states: [HadithCollectionID: PackState] = [:]

    init() {
        for collection in HadithCollectionID.allCases {
            states[collection] = Self.isDownloaded(collection) ? .ready : .notDownloaded
        }
    }

    nonisolated private static func jsonURL(_ collection: HadithCollectionID, lang: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("hadith/\(lang)-\(collection.rawValue).json")
    }

    nonisolated private static func dbURL(_ collection: HadithCollectionID) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("hadith/\(collection.rawValue).db")
    }

    nonisolated static func isDownloaded(_ collection: HadithCollectionID) -> Bool {
        FileManager.default.fileExists(atPath: dbURL(collection).path)
            || (FileManager.default.fileExists(atPath: jsonURL(collection, lang: "ara").path)
                && FileManager.default.fileExists(atPath: jsonURL(collection, lang: "eng").path))
    }

    func download(_ collection: HadithCollectionID) async {
        guard states[collection] != .downloading else { return }
        states[collection] = .downloading
        for lang in ["ara", "eng"] {
            let local = Self.jsonURL(collection, lang: lang)
            if FileManager.default.fileExists(atPath: local.path) { continue }
            guard let url = URL(string:
                "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/\(lang)-\(collection.rawValue).min.json"),
                let (temp, response) = try? await URLSession.shared.download(from: url),
                (response as? HTTPURLResponse)?.statusCode == 200
            else {
                states[collection] = .failed
                return
            }
            try? FileManager.default.createDirectory(
                at: local.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: local)
            guard (try? FileManager.default.moveItem(at: temp, to: local)) != nil else {
                states[collection] = .failed
                return
            }
        }
        let ok = await Task.detached(priority: .userInitiated) {
            Self.buildDatabaseIfNeeded(collection)
        }.value
        states[collection] = ok ? .ready : .failed
    }

    func remove(_ collection: HadithCollectionID) {
        for lang in ["ara", "eng"] {
            try? FileManager.default.removeItem(at: Self.jsonURL(collection, lang: lang))
        }
        try? FileManager.default.removeItem(at: Self.dbURL(collection))
        states[collection] = .notDownloaded
    }

    // MARK: - Reads (SQLite)

    func books(for collection: HadithCollectionID) async -> [HadithBook] {
        await Task.detached(priority: .userInitiated) {
            guard Self.buildDatabaseIfNeeded(collection) else { return [] }
            return Self.query(collection,
                sql: "SELECT idx, ar, en, count FROM books ORDER BY idx") { stmt in
                HadithBook(index: Int(sqlite3_column_int(stmt, 0)),
                           arabicTitle: Self.text(stmt, 1),
                           englishTitle: Self.text(stmt, 2),
                           count: Int(sqlite3_column_int(stmt, 3)))
            }
        }.value
    }

    func hadiths(collection: HadithCollectionID, book: Int) async -> [LibraryHadith] {
        await Task.detached(priority: .userInitiated) {
            Self.query(collection,
                sql: "SELECT num, ar, en FROM hadith WHERE book = \(book) ORDER BY rowid") { stmt in
                LibraryHadith(number: Self.text(stmt, 0),
                              arabic: Self.text(stmt, 1),
                              english: Self.text(stmt, 2),
                              book: book)
            }
        }.value
    }

    /// Lookup by number (bookmarks resolution) with its Arabic/English
    /// book titles.
    func lookup(collection: HadithCollectionID, number: String)
        async -> (hadith: LibraryHadith, bookAr: String, bookEn: String)? {
        await Task.detached(priority: .userInitiated) {
            let escaped = number.replacingOccurrences(of: "'", with: "''")
            let rows: [(LibraryHadith, String, String)] = Self.query(collection, sql: """
                SELECT h.num, h.ar, h.en, h.book, b.ar, b.en FROM hadith h
                JOIN books b ON b.idx = h.book WHERE h.num = '\(escaped)' LIMIT 1
                """) { stmt in
                (LibraryHadith(number: Self.text(stmt, 0), arabic: Self.text(stmt, 1),
                               english: Self.text(stmt, 2), book: Int(sqlite3_column_int(stmt, 3))),
                 Self.text(stmt, 4), Self.text(stmt, 5))
            }
            return rows.first.map { ($0.0, $0.1, $0.2) }
        }.value
    }

    struct SearchHit: Identifiable {
        let collection: HadithCollectionID
        let bookTitle: String
        let hadith: LibraryHadith
        /// How the query sat in the matched text — drives the ordering.
        /// Defaulted so callers that just carry a hadith around (bookmarks)
        /// need not invent search metadata.
        var tier: ArabicSearch.MatchTier = .wholeWord
        /// Window of the matched text around the match, for in-context
        /// display; nil when the hit came from the hadith number alone.
        var snippet: ArabicSearch.Snippet?
        /// True when the snippet was cut from the English translation.
        var snippetIsEnglish = false
        var id: String { "\(collection.rawValue)-\(hadith.book)-\(hadith.number)" }
    }

    /// True when at least one collection is on disk and searchable — the
    /// difference between "nothing matched" and "nothing to search".
    var hasSearchableCollections: Bool {
        HadithCollectionID.allCases.contains { states[$0] == .ready }
    }

    /// Re-reads the disk. `states` is built once at launch, but a pack can be
    /// downloaded through another `HadithLibrary` instance (or a share
    /// extension) — without this the search would filter itself down to
    /// nothing and tell the user to download books they already have.
    func refreshStates() {
        for collection in HadithCollectionID.allCases where states[collection] != .downloading {
            let ready = Self.isDownloaded(collection)
            let state: PackState = ready ? .ready : .notDownloaded
            if states[collection] != state { states[collection] = state }
        }
    }

    /// Ranked, diacritic-insensitive search across every downloaded
    /// collection, mirroring the Quran search (`QuranDatabase.searchVerses`):
    /// matching runs against a folded column so bare typing finds the fully
    /// voweled text, the tiering happens in SQL so the cap keeps the *best*
    /// matches, and the snippet is then cut from the display text.
    func search(_ query: String, isArabicUI: Bool, limit: Int = 80) async -> [SearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard ArabicSearch.fold(trimmed).count >= 2 else { return [] }
        let ready = HadithCollectionID.allCases.filter { states[$0] == .ready }
        return await Task.detached(priority: .userInitiated) {
            var hits: [SearchHit] = []
            for collection in ready {
                // A pack can be downloaded but not yet converted (the app was
                // killed mid-build) — build it here rather than silently
                // searching a database that does not exist.
                guard Self.buildDatabaseIfNeeded(collection) else { continue }
                hits += Self.searchHits(in: Self.dbURL(collection), collection: collection,
                                        query: trimmed, isArabicUI: isArabicUI, limit: limit)
            }
            // Best matches first, source order inside a tier (Swift's sort is
            // not stable, hence the ordinal).
            return hits.enumerated()
                .sorted {
                    $0.element.tier != $1.element.tier
                        ? $0.element.tier < $1.element.tier
                        : $0.offset < $1.offset
                }
                .prefix(limit)
                .map(\.element)
        }.value
    }

    /// One collection's hits, ranked by SQL then re-tiered on the display
    /// text. Split out from `search` so tests can point it at a database
    /// they built themselves.
    nonisolated static func searchHits(in url: URL, collection: HadithCollectionID,
                                       query: String, isArabicUI: Bool,
                                       limit: Int) -> [SearchHit] {
        let folded = ArabicSearch.fold(query).trimmingCharacters(in: .whitespaces)
        guard folded.count >= 2, limit > 0, ensureFoldedColumns(at: url) else { return [] }
        // LIKE wildcards must be literal: without this a query of "%" matched
        // every hadith in the book.
        let escaped = folded
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        let titleColumn = isArabicUI ? "b.ar" : "b.en"
        return rows(at: url, sql: """
            SELECT h.num, h.ar, h.en, h.book, \(titleColumn) AS title,
                   CASE
                     WHEN h.num = ?4 THEN 0
                     WHEN (' ' || h.ar_fold || ' ') LIKE ?1 ESCAPE '\\'
                       OR (' ' || h.en_fold || ' ') LIKE ?1 ESCAPE '\\' THEN 1
                     WHEN (' ' || h.ar_fold || ' ') LIKE ?2 ESCAPE '\\'
                       OR (' ' || h.en_fold || ' ') LIKE ?2 ESCAPE '\\' THEN 2
                     ELSE 3
                   END AS tier
            FROM hadith h JOIN books b ON b.idx = h.book
            WHERE h.ar_fold LIKE ?3 ESCAPE '\\' OR h.en_fold LIKE ?3 ESCAPE '\\'
               OR h.num = ?4
            ORDER BY tier, h.rowid
            LIMIT \(limit)
            """,
            bind: ["% \(escaped) %", "% \(escaped)%", "%\(escaped)%", folded]) { stmt in
            let arabic = text(stmt, 1)
            let english = text(stmt, 2)
            let arabicMatch = ArabicSearch.firstMatch(of: query, in: arabic)
            let englishMatch = arabicMatch == nil
                ? ArabicSearch.firstMatch(of: query, in: english) : nil
            let matched = arabicMatch != nil ? arabic : (englishMatch != nil ? english : nil)
            // A number-only hit has no text match: keep SQL's tier (0 → the
            // top of the list, alongside whole-word matches).
            let sqlTier = Int(sqlite3_column_int(stmt, 5))
            return SearchHit(
                collection: collection,
                bookTitle: text(stmt, 4),
                hadith: LibraryHadith(number: text(stmt, 0), arabic: arabic,
                                      english: english,
                                      book: Int(sqlite3_column_int(stmt, 3))),
                tier: arabicMatch?.tier ?? englishMatch?.tier
                    ?? ArabicSearch.MatchTier(rawValue: max(sqlTier - 1, 0)) ?? .partial,
                snippet: matched.flatMap { ArabicSearch.snippet(for: $0, matching: query) },
                snippetIsEnglish: arabicMatch == nil && englishMatch != nil)
        }
    }

    /// Adds and fills the folded search columns (`ar_fold` / `en_fold`).
    /// Packs downloaded by an older build carry the pre-folding schema, so
    /// this migrates them in place; afterwards it costs one PRAGMA.
    @discardableResult
    nonisolated static func ensureFoldedColumns(at url: URL) -> Bool {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK
        else { return false }
        defer { sqlite3_close(db) }
        var hasFolded = false
        var columns: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA table_info(hadith)", -1, &columns, nil) == SQLITE_OK {
            while !hasFolded, sqlite3_step(columns) == SQLITE_ROW {
                hasFolded = text(columns, 1) == "ar_fold"
            }
        }
        sqlite3_finalize(columns)
        if hasFolded { return true }
        guard sqlite3_exec(db, """
            ALTER TABLE hadith ADD COLUMN ar_fold TEXT;
            ALTER TABLE hadith ADD COLUMN en_fold TEXT;
            """, nil, nil, nil) == SQLITE_OK else { return false }
        var rows: [(id: Int64, arabic: String, english: String)] = []
        var read: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT rowid, ar, en FROM hadith", -1, &read, nil) == SQLITE_OK {
            while sqlite3_step(read) == SQLITE_ROW {
                rows.append((sqlite3_column_int64(read, 0), text(read, 1), text(read, 2)))
            }
        }
        sqlite3_finalize(read)
        sqlite3_exec(db, "BEGIN", nil, nil, nil)
        var update: OpaquePointer?
        sqlite3_prepare_v2(db, "UPDATE hadith SET ar_fold = ?, en_fold = ? WHERE rowid = ?",
                           -1, &update, nil)
        for row in rows {
            sqlite3_bind_text(update, 1, ArabicSearch.fold(row.arabic), -1, transientText)
            sqlite3_bind_text(update, 2, ArabicSearch.fold(row.english), -1, transientText)
            sqlite3_bind_int64(update, 3, row.id)
            sqlite3_step(update)
            sqlite3_reset(update)
        }
        sqlite3_finalize(update)
        sqlite3_exec(db, "COMMIT", nil, nil, nil)
        return true
    }

    func dailySahih(date: Date) async -> (hadith: LibraryHadith, collection: HadithCollectionID)? {
        let ready = HadithCollectionID.allCases.filter { states[$0] == .ready }
        guard !ready.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let collection = ready[day % ready.count]
        return await Task.detached(priority: .userInitiated) {
            guard Self.buildDatabaseIfNeeded(collection) else { return nil }
            let counts: [Int] = Self.query(collection, sql: "SELECT COUNT(*) FROM hadith") {
                Int(sqlite3_column_int($0, 0))
            }
            guard let total = counts.first, total > 0 else { return nil }
            let offset = (day &* 37) % total
            let rows: [LibraryHadith] = Self.query(collection,
                sql: "SELECT num, ar, en, book FROM hadith LIMIT 1 OFFSET \(offset)") { stmt in
                LibraryHadith(number: Self.text(stmt, 0), arabic: Self.text(stmt, 1),
                              english: Self.text(stmt, 2), book: Int(sqlite3_column_int(stmt, 3)))
            }
            return rows.first.map { ($0, collection) }
        }.value
    }

    // MARK: - SQLite plumbing

    nonisolated private static func text(_ stmt: OpaquePointer?, _ column: Int32) -> String {
        sqlite3_column_text(stmt, column).map { String(cString: $0) } ?? ""
    }

    /// SQLITE_TRANSIENT: sqlite copies the bytes, so Swift's temporary
    /// buffers can go away right after the bind.
    nonisolated private static var transientText: sqlite3_destructor_type {
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    }

    nonisolated private static func query<Row>(
        _ collection: HadithCollectionID, sql: String,
        map: (OpaquePointer?) -> Row
    ) -> [Row] {
        rows(at: dbURL(collection), sql: sql, map: map)
    }

    /// Read-only query with optional text parameters (`?1`, `?2`, …).
    /// Values are bound, never interpolated — a quote or a wildcard typed
    /// into the search field stays data.
    nonisolated private static func rows<Row>(
        at url: URL, sql: String, bind: [String] = [],
        map: (OpaquePointer?) -> Row
    ) -> [Row] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK
        else { return [] }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        for (index, value) in bind.enumerated() {
            sqlite3_bind_text(stmt, Int32(index + 1), value, -1, transientText)
        }
        var results: [Row] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(map(stmt))
        }
        return results
    }

    // MARK: - One-time JSON → SQLite conversion

    private struct Edition: Decodable {
        struct Meta: Decodable { let sections: [String: String] }
        struct Item: Decodable {
            let hadithnumber: AnyNumber
            let text: String
            let reference: Ref
        }
        struct Ref: Decodable { let book: AnyNumber }
        let metadata: Meta
        let hadiths: [Item]
    }

    /// The dataset mixes numeric and string numbers.
    struct AnyNumber: Decodable {
        let value: String
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let intValue = try? container.decode(Int.self) {
                value = String(intValue)
            } else if let doubleValue = try? container.decode(Double.self) {
                value = doubleValue.truncatingRemainder(dividingBy: 1) == 0
                    ? String(Int(doubleValue)) : String(doubleValue)
            } else {
                value = (try? container.decode(String.self)) ?? "0"
            }
        }
    }

    /// Authentic Arabic book titles (the dataset's "Arabic" metadata is in
    /// English) — bundled mapping extracted from AhmedBaset/hadith-json.
    nonisolated private static func arabicTitles(_ collection: String) -> [String: String] {
        guard let url = Bundle.main.url(forResource: "hadith_books_ar", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let all = try? JSONDecoder().decode([String: [String: String]].self, from: data)
        else { return [:] }
        return all[collection] ?? [:]
    }

    @discardableResult
    nonisolated static func buildDatabaseIfNeeded(_ collection: HadithCollectionID) -> Bool {
        let target = dbURL(collection)
        if FileManager.default.fileExists(atPath: target.path) { return true }
        guard let araData = try? Data(contentsOf: jsonURL(collection, lang: "ara")),
              let engData = try? Data(contentsOf: jsonURL(collection, lang: "eng")),
              let ara = try? JSONDecoder().decode(Edition.self, from: araData),
              let eng = try? JSONDecoder().decode(Edition.self, from: engData)
        else { return false }
        let arabicByIndex = arabicTitles(collection.rawValue)
        let engByNumber = Dictionary(eng.hadiths.map { ($0.hadithnumber.value, $0.text) },
                                     uniquingKeysWith: { first, _ in first })

        var db: OpaquePointer?
        let temp = target.deletingLastPathComponent()
            .appendingPathComponent("\(collection.rawValue).building")
        try? FileManager.default.removeItem(at: temp)
        guard sqlite3_open(temp.path, &db) == SQLITE_OK else { return false }
        sqlite3_exec(db, """
            CREATE TABLE books(idx INTEGER PRIMARY KEY, ar TEXT, en TEXT, count INTEGER);
            CREATE TABLE hadith(book INTEGER, num TEXT, ar TEXT, en TEXT,
                                ar_fold TEXT, en_fold TEXT);
            CREATE INDEX idx_book ON hadith(book);
            CREATE INDEX idx_num ON hadith(num);
            """, nil, nil, nil)
        sqlite3_exec(db, "BEGIN", nil, nil, nil)
        var insert: OpaquePointer?
        sqlite3_prepare_v2(db, """
            INSERT INTO hadith(book, num, ar, en, ar_fold, en_fold) VALUES(?,?,?,?,?,?)
            """, -1, &insert, nil)
        var counts: [Int: Int] = [:]
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for item in ara.hadiths {
            guard let book = Int(item.reference.book.value) else { continue }
            let arabic = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !arabic.isEmpty else { continue }  // dataset gaps
            let english = engByNumber[item.hadithnumber.value] ?? ""
            sqlite3_bind_int(insert, 1, Int32(book))
            sqlite3_bind_text(insert, 2, item.hadithnumber.value, -1, transient)
            sqlite3_bind_text(insert, 3, arabic, -1, transient)
            sqlite3_bind_text(insert, 4, english, -1, transient)
            // Folded copies power the search: the dataset text is fully
            // voweled and people type bare letters.
            sqlite3_bind_text(insert, 5, ArabicSearch.fold(arabic), -1, transient)
            sqlite3_bind_text(insert, 6, ArabicSearch.fold(english), -1, transient)
            sqlite3_step(insert)
            sqlite3_reset(insert)
            counts[book, default: 0] += 1
        }
        sqlite3_finalize(insert)
        var bookInsert: OpaquePointer?
        sqlite3_prepare_v2(db, "INSERT INTO books(idx, ar, en, count) VALUES(?,?,?,?)", -1, &bookInsert, nil)
        for (index, count) in counts.sorted(by: { $0.key < $1.key }) {
            let key = String(index)
            sqlite3_bind_int(bookInsert, 1, Int32(index))
            sqlite3_bind_text(bookInsert, 2,
                arabicByIndex[key] ?? ara.metadata.sections[key] ?? "كتاب \(index)", -1, transient)
            sqlite3_bind_text(bookInsert, 3,
                eng.metadata.sections[key] ?? "Book \(index)", -1, transient)
            sqlite3_bind_int(bookInsert, 4, Int32(count))
            sqlite3_step(bookInsert)
            sqlite3_reset(bookInsert)
        }
        sqlite3_finalize(bookInsert)
        sqlite3_exec(db, "COMMIT", nil, nil, nil)
        sqlite3_close(db)
        try? FileManager.default.removeItem(at: target)
        guard (try? FileManager.default.moveItem(at: temp, to: target)) != nil else { return false }
        // The JSONs are no longer needed — reclaim ~28 MB per collection.
        try? FileManager.default.removeItem(at: jsonURL(collection, lang: "ara"))
        try? FileManager.default.removeItem(at: jsonURL(collection, lang: "eng"))
        return true
    }
}
