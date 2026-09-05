package com.engagendy.noor

import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import java.text.Normalizer
import java.util.Locale
import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/// One row of the bundled GeoNames city table (assets/cities.sqlite,
/// CC BY 4.0 — see LICENSES.md). Coordinates and the IANA zone are all
/// the prayer engine needs; nothing here ever touches the network.
data class City(
    val id: Int,
    val name: String,
    val nameArabic: String?,
    val countryCode: String,
    val admin1: String?,
    val latitude: Double,
    val longitude: Double,
    val timeZone: String,
    val population: Int,
) {
    /// Arabic name in the Arabic UI when the table knows one, else the
    /// Latin name (never blank).
    fun displayName(arabicUi: Boolean): String =
        if (arabicUi) nameArabic?.takeIf { it.isNotBlank() } ?: name else name

    /// The other-language name, for the secondary row line (null when the
    /// table has no Arabic spelling, or the two are identical).
    fun secondaryName(arabicUi: Boolean): String? {
        val other = if (arabicUi) name else nameArabic
        return other?.takeIf { it.isNotBlank() && it != displayName(arabicUi) }
    }

    /// Localized country name from the platform (ICU), falling back to the
    /// bundled English table when the JVM has nothing for the code.
    fun countryName(locale: Locale = Locale.getDefault()): String {
        val platform = Locale("", countryCode).getDisplayCountry(locale)
        return if (platform.isNotBlank() && platform != countryCode) platform
            else CityDb.countryFallbackName(countryCode) ?: countryCode
    }

    /// Resolved prayer location — the shape every caller of PrayerPrefs
    /// already understands.
    fun asPreset(): CityPreset =
        CityPreset(name, nameArabic?.takeIf { it.isNotBlank() } ?: name,
                   latitude, longitude, timeZone)
}

data class Country(val code: String, val name: String)

/// Read-only access to the bundled offline city database — the Android
/// counterpart of the iOS CityDatabase. Singleton like PageLayoutDb; all
/// queries are plain SQLite and must be called off the main thread.
class CityDb private constructor(private val db: SQLiteDatabase) {

    companion object {
        @Volatile private var instance: CityDb? = null
        @Volatile private var fallbackCountries: Map<String, String> = emptyMap()

        fun get(context: Context): CityDb = instance ?: synchronized(this) {
            instance ?: open(context).also { instance = it }
        }

        private fun open(context: Context): CityDb {
            val target = BundledDb.install(context, "cities.sqlite")
            val db = SQLiteDatabase.openDatabase(
                target.path, null, SQLiteDatabase.OPEN_READONLY)
            return CityDb(db)
        }

        internal fun countryFallbackName(code: String): String? = fallbackCountries[code]

        /// Letters NFKD leaves alone; same map as Tools/build_cities_db.py and
        /// the iOS CityDatabase.fold, so a query folds the way the column did.
        private val letterMap = mapOf('ł' to "l", 'Ł' to "l", 'ø' to "o", 'Ø' to "o", 'ß' to "ss", 'đ' to "d", 'Đ' to "d", 'æ' to "ae", 'Æ' to "ae", 'œ' to "oe", 'Œ' to "oe", 'ı' to "i", 'ð' to "d", 'Ð' to "d", 'þ' to "th", 'Þ' to "th")
        private fun mapLetters(text: String): String =
            buildString(text.length) { for (ch in text) append(letterMap[ch] ?: ch) }

        /// Accent-stripped lowercase, matching the `ascii` column: NFKD then
        /// drop combining marks. Locale.ROOT so Turkish İ etc. never bite.
        fun normalize(text: String): String {
            val decomposed = Normalizer.normalize(mapLetters(text.trim()), Normalizer.Form.NFKD)
            val stripped = StringBuilder(decomposed.length)
            for (ch in decomposed) {
                val type = Character.getType(ch)
                if (type == Character.NON_SPACING_MARK.toInt() ||
                    type == Character.COMBINING_SPACING_MARK.toInt() ||
                    type == Character.ENCLOSING_MARK.toInt()) continue
                stripped.append(ch)
            }
            return stripped.toString().lowercase(Locale.ROOT)
        }

        fun hasArabicLetters(text: String): Boolean =
            text.any { Character.UnicodeBlock.of(it) == Character.UnicodeBlock.ARABIC }

        /// Great-circle distance in kilometres (haversine).
        fun distanceKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
            val r = 6371.0
            val dLat = Math.toRadians(lat2 - lat1)
            val dLon = Math.toRadians(lon2 - lon1)
            val a = sin(dLat / 2) * sin(dLat / 2) +
                cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) *
                sin(dLon / 2) * sin(dLon / 2)
            return 2 * r * asin(sqrt(a))
        }

        private const val COLUMNS =
            "id, name, ascii, name_ar, country, admin1, lat, lon, tz, population"
    }

    private fun Cursor.toCity(): City = City(
        id = getInt(0),
        name = getString(1),
        nameArabic = if (isNull(3)) null else getString(3),
        countryCode = getString(4),
        admin1 = if (isNull(5)) null else getString(5),
        latitude = getDouble(6),
        longitude = getDouble(7),
        timeZone = getString(8),
        population = getInt(9),
    )

    private fun query(sql: String, args: Array<String>): List<City> =
        db.rawQuery(sql, args).use { c ->
            buildList { while (c.moveToNext()) add(c.toCity()) }
        }

    /// Prefix / word-prefix search on the Latin name, or a substring search
    /// on the Arabic name when the query contains Arabic letters. Biggest
    /// cities first so "Lon" yields London before Long Beach.
    fun search(query: String, limit: Int = 40): List<City> {
        val trimmed = query.trim()
        if (trimmed.isEmpty()) return emptyList()
        return if (hasArabicLetters(trimmed)) {
            // Tatweel and short vowels are never in the table; strip them so
            // a carefully typed query still matches.
            val q = trimmed.filter { it != 'ـ' && it !in 'ً'..'ْ' }
            query(
                "SELECT $COLUMNS FROM city WHERE name_ar LIKE ? ESCAPE '\\' " +
                    "ORDER BY population DESC LIMIT ?",
                arrayOf("%${escapeLike(q)}%", limit.toString()))
        } else {
            val q = escapeLike(normalize(trimmed))
            if (q.isEmpty()) return emptyList()
            query(
                "SELECT $COLUMNS FROM city WHERE ascii LIKE ? ESCAPE '\\' " +
                    "OR ascii LIKE ? ESCAPE '\\' ORDER BY population DESC LIMIT ?",
                arrayOf("$q%", "% $q%", limit.toString()))
        }
    }

    private fun escapeLike(text: String): String =
        text.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")

    fun city(id: Int): City? =
        query("SELECT $COLUMNS FROM city WHERE id = ?", arrayOf(id.toString())).firstOrNull()

    /// Cities of one country, largest first.
    fun citiesIn(countryCode: String, limit: Int = 500): List<City> =
        query(
            "SELECT $COLUMNS FROM city WHERE country = ? ORDER BY population DESC LIMIT ?",
            arrayOf(countryCode, limit.toString()))

    /// Every country in the table, sorted by its localized name.
    fun countries(locale: Locale = Locale.getDefault()): List<Country> {
        val table = db.rawQuery("SELECT code, name FROM country", null).use { c ->
            buildList { while (c.moveToNext()) add(c.getString(0) to c.getString(1)) }
        }
        fallbackCountries = table.toMap()
        val collator = java.text.Collator.getInstance(locale)
        return table.map { (code, english) ->
            val platform = Locale("", code).getDisplayCountry(locale)
            Country(code, if (platform.isNotBlank() && platform != code) platform else english)
        }.sortedWith { a, b -> collator.compare(a.name, b.name) }
    }

    /// Closest cities to a coordinate: a ±1.5° box (index-friendly), then
    /// exact haversine ordering.
    fun nearest(latitude: Double, longitude: Double, limit: Int = 5): List<City> {
        val box = 1.5
        val candidates = query(
            "SELECT $COLUMNS FROM city WHERE lat BETWEEN ? AND ? AND lon BETWEEN ? AND ? " +
                "ORDER BY population DESC LIMIT 400",
            arrayOf(
                (latitude - box).toString(), (latitude + box).toString(),
                (longitude - box).toString(), (longitude + box).toString()))
        return candidates
            .sortedBy { distanceKm(latitude, longitude, it.latitude, it.longitude) }
            .take(limit)
    }

    /// The curated preset (Prayers.kt) resolved to its GeoNames row —
    /// matched on the Arabic spelling the table was seeded with, preferring
    /// the same time zone (London GB over London CA), then by name.
    @Volatile private var popularCache: List<City>? = null

    /// The curated presets resolved to database rows, computed once — 57
    /// lookups on every picker open otherwise.
    fun popular(): List<City> = popularCache ?: Cities.all
        .mapNotNull { resolvePreset(it) }.distinctBy { it.id }
        .also { popularCache = it }

    fun resolvePreset(preset: CityPreset): City? {
        val byArabic = query(
            "SELECT $COLUMNS FROM city WHERE name_ar = ? ORDER BY population DESC LIMIT 10",
            arrayOf(preset.nameArabic))
        byArabic.firstOrNull { it.timeZone == preset.timeZone }?.let { return it }
        byArabic.firstOrNull()?.let { return it }
        val byName = query(
            "SELECT $COLUMNS FROM city WHERE ascii = ? ORDER BY population DESC LIMIT 10",
            arrayOf(normalize(preset.name)))
        return byName.firstOrNull { it.timeZone == preset.timeZone } ?: byName.firstOrNull()
    }
}
