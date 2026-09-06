package com.engagendy.noor

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import java.io.File

/// Installs a bundled read-only content DB (quran.sqlite, page_layout.sqlite)
/// into filesDir so SQLite can open it. The copy is atomic (write to a .tmp
/// then rename) and stamped with the app versionCode, so a process kill
/// mid-copy never leaves a truncated file that wins forever, and an app
/// update that ships a regenerated DB replaces the stale copy.
internal object BundledDb {
    fun install(context: Context, name: String): File {
        val target = File(context.filesDir, name)
        val stamp = File(context.filesDir, "$name.version")
        val version = appVersionCode(context).toString()
        val stale = !target.exists() || !stamp.exists() || stamp.readText() != version
        if (stale) {
            val tmp = File(context.filesDir, "$name.tmp")
            context.assets.open(name).use { input ->
                tmp.outputStream().use { out -> input.copyTo(out); out.fd.sync() }
            }
            stamp.delete()
            if (!tmp.renameTo(target)) {
                target.delete()
                check(tmp.renameTo(target)) { "Cannot install $name" }
            }
            // Stamp only after the DB is fully in place; a missing/old stamp
            // means "re-copy on next launch".
            stamp.writeText(version)
        }
        return target
    }

    private fun appVersionCode(context: Context): Long {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        @Suppress("DEPRECATION")
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode
        else info.versionCode.toLong()
    }
}

data class Surah(
    val id: Int,
    val nameArabic: String,
    val nameTransliterated: String,
    /// Translated meaning ("The Cow") — searchable in the English UI.
    val nameEnglish: String,
    val ayahCount: Int,
    val revelation: String,
)

data class Verse(val surahId: Int, val ayah: Int, val text: String)

/// A word-search match: untouched display text from the verified DB.
/// `tier` is the ranking tier (see SearchText.matchTier), 0 = best.
data class SearchHit(val surahId: Int, val ayah: Int, val text: String, val tier: Int = 3)

/// Ranked verse hits plus whether the DB had more matches than were read.
data class VerseSearchResults(val hits: List<SearchHit>, val truncated: Boolean)

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
            val target = BundledDb.install(context, "quran.sqlite")
            val db = SQLiteDatabase.openDatabase(
                target.path, null, SQLiteDatabase.OPEN_READONLY)
            return QuranDb(db)
        }

        /// Search normalization — the shared implementation lives in
        /// `SearchText` so every screen (Quran, athkar) folds text the same
        /// way. Kept here as the historical entry point.
        fun normalizeForSearch(query: String): String = SearchText.normalizeForSearch(query)
    }

    fun surahs(): List<Surah> =
        db.rawQuery(
            "SELECT id, name_arabic, name_transliterated, name_english, ayah_count, revelation_type " +
                "FROM surah ORDER BY id",
            null
        ).use { c ->
            buildList {
                while (c.moveToNext()) {
                    add(Surah(c.getInt(0), c.getString(1), c.getString(2), c.getString(3),
                              c.getInt(4), c.getString(5)))
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

    /// Cached once: the basmala exactly as stored in the verified DB (1:1).
    /// Used only to RECOGNISE the prefix below — never to produce text.
    private val storedBasmala: String? by lazy { basmala() }

    /// DISPLAY-ONLY helper for readers that already draw a separate basmala
    /// line above ayah 1.
    ///
    /// Data quirk of the bundled Tanzil DB (verified, never to be "fixed"):
    /// for the 111 surahs that open with it, the basmala is stored as a
    /// LEADING prefix inside the text of ayah 1, followed by one space and
    /// then that ayah's own words. Rendering the injected basmala header AND
    /// the stored text therefore shows it twice. This returns the same stored
    /// characters minus that leading prefix — nothing is rewritten, joined or
    /// normalised; the row in the DB is never modified.
    ///
    /// Deliberately does nothing for:
    /// - Surah 1 (Al-Fatiha): in the Hafs count the basmala IS ayah 1, so it
    ///   must render in full as an ordinary numbered ayah (readers skip the
    ///   injected header for surah 1 instead).
    /// - Surah 9 (At-Tawbah): no basmala in the data, nothing to strip.
    /// - Any ayah other than ayah 1 — notably 27:30, where the basmala
    ///   appears MID-VERSE inside Sulayman's letter and must never be touched.
    ///   Only a leading prefix on ayah 1 is ever in scope.
    ///
    /// Every other consumer (share card, share video, widgets, bookmarks,
    /// tafsir, search, copy) presents ayah 1 on its own and must keep the
    /// stored text as-is — do not call this there.
    fun textWithoutLeadingBasmala(verse: Verse): String {
        if (verse.ayah != 1 || verse.surahId == 1) return verse.text
        val prefix = storedBasmala ?: return verse.text
        val end = leadingBasmalaEnd(verse.text, prefix) ?: return verse.text
        var rest = verse.text.substring(end)
        if (rest.startsWith(" ")) rest = rest.substring(1)
        // Defensive: never render an empty ayah if the data ever changes.
        return if (rest.isBlank()) verse.text else rest
    }

    /// Index just past the leading basmala in [text], or null if it does not
    /// open with one. Compares base letters only, skipping Arabic combining
    /// marks on BOTH sides: surahs 95 and 97 store the same basmala with one
    /// extra shadda on its first letter, so an exact prefix match would miss
    /// them and leave a second basmala on screen. Nothing is rewritten — the
    /// caller only ever slices the stored string at the returned index.
    private fun leadingBasmalaEnd(text: String, prefix: String): Int? {
        var i = 0
        var j = 0
        while (j < prefix.length) {
            while (j < prefix.length && isArabicMark(prefix[j])) j++
            if (j >= prefix.length) break
            while (i < text.length && isArabicMark(text[i])) i++
            if (i >= text.length || text[i] != prefix[j]) return null
            i++
            j++
        }
        // Consume any marks trailing the final matched letter.
        while (i < text.length && isArabicMark(text[i])) i++
        return i
    }

    /// Arabic combining marks and tatweel: diacritics that may differ between
    /// the stored basmala variants without changing the letters themselves.
    private fun isArabicMark(c: Char): Boolean =
        c == '\u0640' || c in '\u064B'..'\u065F' || c == '\u0670' || c in '\u06D6'..'\u06ED'

    /// Word search over the normalized index (same LIKE query as iOS),
    /// then RANKED in Kotlin: whole-word matches first, then word-start
    /// matches (also after the ال/و/ف… proclitics), then mid-word ones;
    /// within a tier, mushaf order. Ranking needs the whole candidate set,
    /// so up to [fetchLimit] rows are read — when that cap is reached the
    /// UI says so instead of silently dropping matches.
    /// Returns the untouched display text of matching ayat. Call on IO.
    fun searchVerses(query: String, fetchLimit: Int = 300): VerseSearchResults {
        val normalized = normalizeForSearch(query).trim()
        if (normalized.length < 2) return VerseSearchResults(emptyList(), false)
        val escaped = normalized.replace("%", "\\%").replace("_", "\\_")
        val rows = db.rawQuery(
            "SELECT v.surah_id, v.ayah, v.text FROM verse_search s " +
                "JOIN verse v ON v.surah_id = s.surah_id AND v.ayah = s.ayah " +
                "WHERE s.text_normalized LIKE ? ESCAPE '\\' " +
                "ORDER BY v.surah_id, v.ayah LIMIT ?",
            arrayOf("%$escaped%", fetchLimit.toString())
        ).use { c ->
            buildList {
                while (c.moveToNext()) {
                    val text = c.getString(2)
                    add(SearchHit(c.getInt(0), c.getInt(1), text,
                                  SearchText.matchTier(text, normalized)))
                }
            }
        }
        val ranked = rows.sortedWith(compareBy({ it.tier }, { it.surahId }, { it.ayah }))
        return VerseSearchResults(ranked, rows.size >= fetchLimit)
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
