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
            if (c.moveToFirst()) c.getInt(0) else 6236
        }

    /// Verse at a global 0-based index in mushaf order (daily ayah pick).
    fun verseAt(globalIndex: Int): Verse? =
        db.rawQuery(
            "SELECT surah_id, ayah, text FROM verse ORDER BY surah_id, ayah LIMIT 1 OFFSET ?",
            arrayOf(globalIndex.toString())
        ).use { c ->
            if (c.moveToFirst()) Verse(c.getInt(0), c.getInt(1), c.getString(2)) else null
        }

    /// Basmala for injected print-mode lines — the verified DB text of
    /// 1:1, never typed in code.
    fun basmala(): String? = verses(1).firstOrNull()?.text

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
