package com.engagendy.noor

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.io.File

data class Surah(
    val id: Int,
    val nameArabic: String,
    val nameTransliterated: String,
    val ayahCount: Int,
    val revelation: String,
)

data class Verse(val surahId: Int, val ayah: Int, val text: String)

/// A word-search match: untouched display text from the verified DB.
data class SearchHit(val surahId: Int, val ayah: Int, val text: String)

/// Start of a juz / hizb quarter (indexing metadata, not Quran text).
data class DivisionStart(val idx: Int, val surahId: Int, val ayah: Int)

/// Read-only access to the bundled, verified Tanzil database — the same
/// file the iOS app ships. The Quran text is never generated or edited.
class QuranDb private constructor(private val db: SQLiteDatabase) {

    companion object {
        @Volatile private var instance: QuranDb? = null

        fun get(context: Context): QuranDb = instance ?: synchronized(this) {
            instance ?: open(context).also { instance = it }
        }

        private fun open(context: Context): QuranDb {
            val target = File(context.filesDir, "quran.sqlite")
            if (!target.exists()) {
                context.assets.open("quran.sqlite").use { input ->
                    target.outputStream().use { input.copyTo(it) }
                }
            }
            val db = SQLiteDatabase.openDatabase(
                target.path, null, SQLiteDatabase.OPEN_READONLY)
            return QuranDb(db)
        }

        /// Search normalization ONLY (mirrors iOS QuranSearch /
        /// Tools/build_quran_db.py): strips tashkeel/quranic marks/tatweel,
        /// unifies alef/ya variants. Never touches the display text.
        fun normalizeForSearch(query: String): String = buildString {
            for (ch in query) {
                val v = ch.code
                if (v in 0x064B..0x065F || v in 0x06D6..0x06ED ||
                    v == 0x0670 || v == 0x0640) continue
                when (v) {
                    0x0622, 0x0623, 0x0625, 0x0671 -> append('ا') // alef variants
                    0x0649 -> append('ي')                          // alef maqsura → ya
                    else -> append(ch)
                }
            }
        }
    }

    fun surahs(): List<Surah> =
        db.rawQuery(
            "SELECT id, name_arabic, name_transliterated, ayah_count, revelation_type FROM surah ORDER BY id",
            null
        ).use { c ->
            buildList {
                while (c.moveToNext()) {
                    add(Surah(c.getInt(0), c.getString(1), c.getString(2), c.getInt(3), c.getString(4)))
                }
            }
        }

    fun verseCount(): Int =
        db.rawQuery("SELECT COUNT(*) FROM verse", null).use { c ->
            c.moveToFirst()
            c.getInt(0)
        }

    /// One verse by global position, with its surah's Arabic name —
    /// backs the deterministic daily ayah.
    fun verseAt(globalIndex: Int): Pair<Verse, String>? =
        db.rawQuery(
            "SELECT v.surah_id, v.ayah, v.text, s.name_arabic FROM verse v " +
                "JOIN surah s ON s.id = v.surah_id ORDER BY v.surah_id, v.ayah LIMIT 1 OFFSET ?",
            arrayOf(globalIndex.toString())
        ).use { c ->
            if (!c.moveToFirst()) return null
            Verse(c.getInt(0), c.getInt(1), c.getString(2)) to c.getString(3)
        }

    /// From the verified DB (never typed): Al-Fatiha 1:1.
    fun basmala(): String? =
        db.rawQuery("SELECT text FROM verse WHERE surah_id=1 AND ayah=1", null).use { c ->
            if (c.moveToFirst()) c.getString(0) else null
        }

    /// Word search over the normalized index (same LIKE query as iOS);
    /// returns the untouched display text of matching ayat. Call on IO.
    fun searchVerses(query: String, limit: Int = 80): List<SearchHit> {
        val normalized = normalizeForSearch(query).trim()
        if (normalized.length < 2) return emptyList()
        val escaped = normalized.replace("%", "\\%").replace("_", "\\_")
        return db.rawQuery(
            "SELECT v.surah_id, v.ayah, v.text FROM verse_search s " +
                "JOIN verse v ON v.surah_id = s.surah_id AND v.ayah = s.ayah " +
                "WHERE s.text_normalized LIKE ? ESCAPE '\\' " +
                "ORDER BY v.surah_id, v.ayah LIMIT ?",
            arrayOf("%$escaped%", limit.toString())
        ).use { c ->
            buildList {
                while (c.moveToNext()) {
                    add(SearchHit(c.getInt(0), c.getInt(1), c.getString(2)))
                }
            }
        }
    }

    /// The 30 juz starting references (indexing metadata).
    fun juzStarts(): List<DivisionStart> =
        db.rawQuery(
            "SELECT idx, surah_id, ayah FROM juz_start ORDER BY idx", null
        ).use { c ->
            buildList {
                while (c.moveToNext()) {
                    add(DivisionStart(c.getInt(0), c.getInt(1), c.getInt(2)))
                }
            }
        }

    /// The 240 hizb-quarter starting references (indexing metadata).
    fun quarterStarts(): List<DivisionStart> =
        db.rawQuery(
            "SELECT idx, surah_id, ayah FROM hizb_quarter_start ORDER BY idx", null
        ).use { c ->
            buildList {
                while (c.moveToNext()) {
                    add(DivisionStart(c.getInt(0), c.getInt(1), c.getInt(2)))
                }
            }
        }

    /// The 15 sajdah ayat, keyed surah*1000+ayah.
    fun sajdaKeys(): Set<Int> =
        db.rawQuery("SELECT surah_id, ayah FROM sajda", null).use { c ->
            buildSet {
                while (c.moveToNext()) add(c.getInt(0) * 1000 + c.getInt(1))
            }
        }

    /// Juz containing a reference (last juz start at or before it).
    fun juzFor(surahId: Int, ayah: Int): Int {
        var juz = 1
        for (start in juzStarts()) {
            if (start.surahId < surahId ||
                (start.surahId == surahId && start.ayah <= ayah)) juz = start.idx
            else break
        }
        return juz
    }

    fun verses(surahId: Int): List<Verse> =
        db.rawQuery(
            "SELECT surah_id, ayah, text FROM verse WHERE surah_id = ? ORDER BY ayah",
            arrayOf(surahId.toString())
        ).use { c ->
            buildList {
                while (c.moveToNext()) {
                    add(Verse(c.getInt(0), c.getInt(1), c.getString(2)))
                }
            }
        }
}
