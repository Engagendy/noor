package com.engagendy.noor

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.io.File

/// One word (or ayah-end marker) on a Madani mushaf page, with its QCF
/// glyph codes. Port of the iOS ContentDB PageLayoutDatabase.
data class PageWord(
    val page: Int,
    val line: Int,
    val surahId: Int,
    val ayah: Int,
    val position: Int,
    val glyph: String,
    val glyphV2: String,
)

data class AyahRef(val surahId: Int, val ayah: Int)

/// Header/basmala lines are synthetic — the layout data only carries
/// verse words; the reserved lines before a surah start are injected.
sealed interface LineKind {
    data object Words : LineKind
    data class SurahHeader(val surahId: Int) : LineKind
    /// Single reserved line: header frame and basmala share it (e.g.
    /// An-Nisa on page 77 in the Madani print).
    data class SurahHeaderWithBasmala(val surahId: Int) : LineKind
    data object Basmala : LineKind
}

/// A rendered line of a mushaf page: glyphs concatenated in reading order,
/// plus which ayat appear on the line (for tap targeting).
data class PageLine(
    val line: Int,
    val kind: LineKind,
    val glyphs: String,
    /// QCF v2 glyphs (the exact printed Madani mushaf typeface).
    val glyphsV2: String,
    val ayahRefs: List<AyahRef>,
)

/// Read-only access to the bundled page-layout DB — the same file the iOS
/// app ships (built by Tools/build_page_layout.py from quran.com data).
class PageLayoutDb private constructor(private val db: SQLiteDatabase) {

    companion object {
        const val PAGE_COUNT = 604

        /// First printed page of each juz in the standard 604-page Madani
        /// mushaf (layout metadata, mirrors the iOS ContentDB juz table).
        private val JUZ_START_PAGES = intArrayOf(
            1, 22, 42, 62, 82, 102, 122, 142, 162, 182,
            202, 222, 242, 262, 282, 302, 322, 342, 362, 382,
            402, 422, 442, 462, 482, 502, 522, 542, 562, 582)

        fun juzForPage(page: Int): Int =
            JUZ_START_PAGES.indexOfLast { it <= page } + 1

        @Volatile private var instance: PageLayoutDb? = null

        fun get(context: Context): PageLayoutDb = instance ?: synchronized(this) {
            instance ?: open(context).also { instance = it }
        }

        private fun open(context: Context): PageLayoutDb {
            val target = File(context.filesDir, "page_layout.sqlite")
            if (!target.exists()) {
                context.assets.open("page_layout.sqlite").use { input ->
                    target.outputStream().use { input.copyTo(it) }
                }
            }
            val db = SQLiteDatabase.openDatabase(
                target.path, null, SQLiteDatabase.OPEN_READONLY)
            return PageLayoutDb(db)
        }
    }

    /// First printed page of a surah (Madani mode entry from the surah list).
    fun firstPage(surahId: Int): Int =
        db.rawQuery(
            "SELECT MIN(page) FROM page_word WHERE surah_id = ?",
            arrayOf(surahId.toString())
        ).use { c -> if (c.moveToFirst()) c.getInt(0).coerceAtLeast(1) else 1 }

    /// Printed page of an exact ayah (open-at-ayah from search/juz/bookmarks).
    fun pageFor(surahId: Int, ayah: Int): Int =
        db.rawQuery(
            "SELECT page FROM page_word WHERE surah_id = ? AND ayah = ? LIMIT 1",
            arrayOf(surahId.toString(), ayah.toString())
        ).use { c -> if (c.moveToFirst()) c.getInt(0).coerceAtLeast(1) else firstPage(surahId) }

    /// Topmost surah printed on a page (drives the reader top-bar title,
    /// like the iOS viewModel.surah(forPage:)).
    fun firstSurahOnPage(page: Int): Int =
        db.rawQuery(
            "SELECT surah_id FROM page_word WHERE page = ? ORDER BY line, position LIMIT 1",
            arrayOf(page.toString())
        ).use { c -> if (c.moveToFirst()) c.getInt(0) else 0 }

    /// First ayah printed on a page — the play-from-here entry point.
    fun firstAyahOnPage(page: Int): AyahRef? =
        db.rawQuery(
            "SELECT surah_id, ayah FROM page_word WHERE page = ? ORDER BY line, position LIMIT 1",
            arrayOf(page.toString())
        ).use { c -> if (c.moveToFirst()) AyahRef(c.getInt(0), c.getInt(1)) else null }

    /// Last ayah of a surah printed on the same page as the given ayah —
    /// drives the "this page only" playback mode, like iOS pageEndAyah.
    fun pageEndAyah(surahId: Int, ayah: Int): Int {
        val page = db.rawQuery(
            "SELECT page FROM page_word WHERE surah_id = ? AND ayah = ? LIMIT 1",
            arrayOf(surahId.toString(), ayah.toString())
        ).use { c -> if (c.moveToFirst()) c.getInt(0) else return 0 }
        return db.rawQuery(
            "SELECT MAX(ayah) FROM page_word WHERE page = ? AND surah_id = ?",
            arrayOf(page.toString(), surahId.toString())
        ).use { c -> if (c.moveToFirst()) c.getInt(0) else 0 }
    }

    /// The QCF glyph lines of one page, with the reserved surah-header and
    /// basmala lines injected (At-Tawbah opens without the basmala;
    /// Al-Fatiha's basmala is its first ayah).
    fun lines(page: Int): List<PageLine> {
        val words = db.rawQuery(
            "SELECT page, line, surah_id, ayah, position, glyph, glyph_v2 FROM page_word " +
                "WHERE page = ? ORDER BY line, surah_id, ayah, position",
            arrayOf(page.toString())
        ).use { c ->
            buildList {
                while (c.moveToNext()) {
                    add(PageWord(c.getInt(0), c.getInt(1), c.getInt(2), c.getInt(3),
                                 c.getInt(4), c.getString(5), c.getString(6)))
                }
            }
        }

        val lines = words.groupBy { it.line }
            .map { (line, lineWords) ->
                val refs = mutableListOf<AyahRef>()
                for (word in lineWords) {
                    val ref = AyahRef(word.surahId, word.ayah)
                    if (refs.lastOrNull() != ref) refs.add(ref)
                }
                PageLine(
                    line = line,
                    kind = LineKind.Words,
                    glyphs = lineWords.joinToString("") { it.glyph },
                    glyphsV2 = lineWords.joinToString("") { it.glyphV2 },
                    ayahRefs = refs)
            }
            .toMutableList()

        // Inject the reserved header/basmala lines before surah starts.
        val present = words.map { it.line }.toHashSet()
        val starts = words.filter { it.ayah == 1 && it.position == 1 }.groupBy { it.surahId }
        for ((surahId, startWords) in starts) {
            val firstLine = startWords.minOf { it.line }
            val headerAt = firstLine - 2
            val basmalaAt = firstLine - 1
            if (basmalaAt >= 1 && basmalaAt !in present) {
                val needsBasmala = surahId != 9 && surahId != 1
                if (headerAt >= 1 && headerAt !in present) {
                    lines.add(PageLine(headerAt, LineKind.SurahHeader(surahId), "", "", emptyList()))
                    if (needsBasmala) {
                        lines.add(PageLine(basmalaAt, LineKind.Basmala, "", "", emptyList()))
                    }
                } else {
                    // One reserved line — header and basmala share it.
                    val kind = if (needsBasmala) LineKind.SurahHeaderWithBasmala(surahId)
                               else LineKind.SurahHeader(surahId)
                    lines.add(PageLine(basmalaAt, kind, "", "", emptyList()))
                }
            }
        }
        return lines.sortedBy { it.line }
    }
}
