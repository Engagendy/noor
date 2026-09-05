import Foundation
import GRDB

/// One populated place from the bundled GeoNames extract (see LICENSES.md,
/// CC BY 4.0). `id` is the stable GeoNames id.
public struct City: Identifiable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let nameArabic: String?
    public let countryCode: String
    /// English country name from the `country` table (fallback when the
    /// locale has no name for the region code).
    public let countryName: String
    /// Region code (e.g. "NY"); disambiguates same-named cities.
    public let admin1: String?
    public let latitude: Double
    public let longitude: Double
    public let timeZoneIdentifier: String
    public let population: Int

    public init(id: Int, name: String, nameArabic: String?, countryCode: String,
                countryName: String, admin1: String?, latitude: Double, longitude: Double,
                timeZoneIdentifier: String, population: Int) {
        self.id = id
        self.name = name
        self.nameArabic = nameArabic
        self.countryCode = countryCode
        self.countryName = countryName
        self.admin1 = admin1
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
        self.population = population
    }

    /// Arabic spelling when the UI is Arabic and one is known; else the
    /// Latin name.
    public func displayName(arabicUI: Bool) -> String {
        if arabicUI, let nameArabic, !nameArabic.isEmpty { return nameArabic }
        return name
    }

    /// The name in the *other* language, for a secondary line; nil when
    /// there is nothing different to show.
    public func alternateName(arabicUI: Bool) -> String? {
        let primary = displayName(arabicUI: arabicUI)
        let other = arabicUI ? name : nameArabic
        guard let other, !other.isEmpty, other != primary else { return nil }
        return other
    }

    public func countryName(locale: Locale) -> String {
        locale.localizedString(forRegionCode: countryCode) ?? countryName
    }
}

public struct Country: Identifiable, Hashable, Sendable {
    public let code: String
    public let name: String
    public var id: String { code }

    public func localizedName(locale: Locale) -> String {
        locale.localizedString(forRegionCode: code) ?? name
    }
}

private struct CityRow: Decodable, FetchableRecord {
    let id: Int
    let name: String
    let ascii: String
    let nameAr: String?
    let country: String
    let countryName: String
    let admin1: String?
    let lat: Double
    let lon: Double
    let tz: String
    let population: Int

    enum CodingKeys: String, CodingKey {
        case id, name, ascii, country, admin1, lat, lon, tz, population
        case nameAr = "name_ar"
        case countryName = "country_name"
    }

    var city: City {
        City(id: id, name: name, nameArabic: nameAr, countryCode: country,
             countryName: countryName, admin1: admin1, latitude: lat, longitude: lon,
             timeZoneIdentifier: tz, population: population)
    }
}

/// Read-only access to the bundled offline city list. Never touches the
/// network: this is the whole "geocoder" (CLAUDE.md rules 2 and 3).
public final class CityDatabase: Sendable {
    /// One read-only connection for the whole app — opening a DatabaseQueue per
    /// view instance was wasteful, and onboarding rebuilds its views often.
    public static let shared: CityDatabase? = try? CityDatabase()

    private let queue: DatabaseQueue

    private static let select = """
        SELECT city.*, country.name AS country_name
        FROM city JOIN country ON country.code = city.country
        """

    public init() throws {
        guard let url = Bundle.module.url(forResource: "cities", withExtension: "sqlite") else {
            throw QuranDatabaseError.missingDatabase
        }
        var config = Configuration()
        config.readonly = true
        queue = try DatabaseQueue(path: url.path, configuration: config)
    }

    /// Accent-stripped lowercase form matching the `ascii` column.
    /// Letters diacritic folding leaves alone; same map as the build script
    /// and the Android `CityDb.fold`, so a query folds the way the column did.
    private static let letterMap: [Character: String] = ["ł": "l", "Ł": "l", "ø": "o", "Ø": "o", "ß": "ss", "đ": "d", "Đ": "d", "æ": "ae", "Æ": "ae", "œ": "oe", "Œ": "oe", "ı": "i", "ð": "d", "Ð": "d", "þ": "th", "Þ": "th"]

    public static func fold(_ text: String) -> String {
        let mapped = text.map { letterMap[$0] ?? String($0) }.joined()
        return mapped.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                              locale: Locale(identifier: "en"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func containsArabic(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x0600...0x06FF).contains($0.value) }
    }

    private static func escapeLike(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }

    /// Word-start prefix search on the Latin name, or substring search on
    /// the Arabic name when the query is Arabic. Largest cities first.
    public func search(_ query: String, limit: Int = 40) throws -> [City] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return try queue.read { db in
            let rows: [CityRow]
            if Self.containsArabic(trimmed) {
                let pattern = "%" + Self.escapeLike(trimmed) + "%"
                rows = try CityRow.fetchAll(db, sql: Self.select + """
                     WHERE name_ar LIKE ? ESCAPE '\\'
                     ORDER BY population DESC LIMIT ?
                    """, arguments: [pattern, limit])
            } else {
                let folded = Self.escapeLike(Self.fold(trimmed))
                rows = try CityRow.fetchAll(db, sql: Self.select + """
                     WHERE ascii LIKE ? ESCAPE '\\' OR ascii LIKE ? ESCAPE '\\'
                     ORDER BY population DESC LIMIT ?
                    """, arguments: [folded + "%", "% " + folded + "%", limit])
            }
            return rows.map(\.city)
        }
    }

    public func cities(inCountry code: String, limit: Int = 500) throws -> [City] {
        try queue.read { db in
            try CityRow.fetchAll(db, sql: Self.select + """
                 WHERE city.country = ? ORDER BY population DESC LIMIT ?
                """, arguments: [code, limit]).map(\.city)
        }
    }

    /// All countries, sorted by their name in `locale`.
    public func countries(locale: Locale = .current) throws -> [Country] {
        let all = try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT code, name FROM country")
                .map { Country(code: $0["code"], name: $0["name"]) }
        }
        return all.sorted {
            $0.localizedName(locale: locale)
                .compare($1.localizedName(locale: locale), locale: locale) == .orderedAscending
        }
    }

    public func city(id: Int) throws -> City? {
        try queue.read { db in
            try CityRow.fetchOne(db, sql: Self.select + " WHERE city.id = ?", arguments: [id])?.city
        }
    }

    /// Resolves curated names (e.g. the app's presets) to database rows:
    /// exact Latin name first, then exact Arabic name; largest wins.
    public func cities(named names: [String], arabicNames: [String]) throws -> [City] {
        guard !names.isEmpty || !arabicNames.isEmpty else { return [] }
        let latin = Array(repeating: "?", count: names.count).joined(separator: ",")
        let arabic = Array(repeating: "?", count: arabicNames.count).joined(separator: ",")
        var clauses: [String] = []
        if !names.isEmpty { clauses.append("name IN (\(latin))") }
        if !arabicNames.isEmpty { clauses.append("name_ar IN (\(arabic))") }
        return try queue.read { db in
            try CityRow.fetchAll(db, sql: Self.select + """
                 WHERE \(clauses.joined(separator: " OR ")) ORDER BY population DESC
                """, arguments: StatementArguments(names + arabicNames)).map(\.city)
        }
    }

    /// Nearest cities by great-circle distance; a ±1.5° box prefilters on
    /// the (lat, lon) index and the haversine ranks the survivors.
    public func nearest(latitude: Double, longitude: Double, limit: Int = 5) throws -> [City] {
        let span = 1.5
        let lonSpan = span / max(0.2, cos(latitude * .pi / 180))
        let candidates = try queue.read { db in
            try CityRow.fetchAll(db, sql: Self.select + """
                 WHERE lat BETWEEN ? AND ? AND lon BETWEEN ? AND ?
                 ORDER BY population DESC LIMIT 2000
                """, arguments: [latitude - span, latitude + span,
                                 longitude - lonSpan, longitude + lonSpan]).map(\.city)
        }
        return candidates
            .map { ($0, Self.haversineKm(latitude, longitude, $0.latitude, $0.longitude)) }
            .sorted { $0.1 < $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    static func haversineKm(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let r = 6371.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * asin(min(1, sqrt(a)))
    }
}
