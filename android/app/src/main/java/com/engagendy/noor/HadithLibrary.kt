package com.engagendy.noor

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.JsonReader
import android.util.JsonToken
import org.json.JSONObject
import java.io.File
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

/// The major hadith collections, downloadable as offline packs
/// (fawazahmed0/hadith-api, public domain — see LICENSES.md).
enum class HadithCollection(
    val key: String,
    val nameArabic: String,
    val nameEnglish: String,
    val sizeLabel: String,
) {
    BUKHARI("bukhari", "صحيح البخاري", "Sahih al-Bukhari", "~١٤ م.ب"),
    MUSLIM("muslim", "صحيح مسلم", "Sahih Muslim", "~١٥ م.ب"),
}

data class HadithBook(val index: Int, val arabicTitle: String, val count: Int)
data class LibraryHadith(val number: String, val arabic: String, val english: String, val book: Int)
data class HadithSearchHit(
    val collection: HadithCollection,
    val bookTitle: String,
    val hadith: LibraryHadith,
)

/// Downloads collections, converts them ONCE into SQLite, then serves
/// book lists, hadiths, and search straight from disk — mirrors the iOS
/// HadithLibrary. Every function here must run off the main thread.
object HadithLibrary {

    private fun dir(context: Context) = File(context.filesDir, "hadith").apply { mkdirs() }
    private fun dbFile(context: Context, collection: HadithCollection) =
        File(dir(context), "${collection.key}.db")
    private fun jsonFile(context: Context, collection: HadithCollection, lang: String) =
        File(dir(context), "$lang-${collection.key}.json")

    fun isDownloaded(context: Context, collection: HadithCollection): Boolean =
        dbFile(context, collection).exists()

    fun remove(context: Context, collection: HadithCollection) {
        dbFile(context, collection).delete()
        jsonFile(context, collection, "ara").delete()
        jsonFile(context, collection, "eng").delete()
    }

    /// Fetches both language editions and converts them into SQLite.
    /// Blocking — call from Dispatchers.IO.
    fun download(context: Context, collection: HadithCollection): Boolean {
        if (isDownloaded(context, collection)) return true
        for (lang in listOf("ara", "eng")) {
            val target = jsonFile(context, collection, lang)
            if (target.exists() && target.length() > 0) continue
            if (!fetch(
                    "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/$lang-${collection.key}.min.json",
                    target
                )
            ) return false
        }
        return buildDatabase(context, collection)
    }

    private fun fetch(url: String, target: File): Boolean = try {
        val temp = File(target.parentFile, "${target.name}.part")
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = 20_000
        connection.readTimeout = 60_000
        val ok = connection.responseCode == 200
        if (ok) {
            connection.inputStream.use { input ->
                temp.outputStream().use { input.copyTo(it) }
            }
        }
        connection.disconnect()
        ok && temp.renameTo(target).also { if (!it) temp.delete() }
    } catch (_: Exception) {
        false
    }

    // MARK: - One-time JSON → SQLite conversion

    /// Authentic Arabic book titles (the dataset's "Arabic" metadata is in
    /// English) — bundled mapping extracted from AhmedBaset/hadith-json.
    private fun arabicTitles(context: Context, collection: HadithCollection): Map<String, String> {
        val raw = context.assets.open("hadith_books_ar.json").bufferedReader().readText()
        val all = JSONObject(raw)
        val titles = all.optJSONObject(collection.key) ?: return emptyMap()
        return buildMap {
            titles.keys().forEach { key -> put(key, titles.getString(key)) }
        }
    }

    /// The dataset mixes ints, doubles, and strings for hadith numbers —
    /// normalize like the iOS AnyNumber (1234.0 → "1234").
    private fun readNumber(reader: JsonReader): String = when (reader.peek()) {
        JsonToken.NUMBER -> {
            val value = reader.nextDouble()
            if (value % 1.0 == 0.0) value.toLong().toString() else value.toString()
        }
        JsonToken.STRING -> reader.nextString()
        else -> { reader.skipValue(); "0" }
    }

    private class Item(val number: String, val text: String, val book: Int?)

    /// Streams one edition file: (sections metadata, hadith items).
    private fun readEdition(file: File): Pair<Map<String, String>, List<Item>> {
        val sections = mutableMapOf<String, String>()
        val items = mutableListOf<Item>()
        JsonReader(InputStreamReader(file.inputStream(), Charsets.UTF_8)).use { reader ->
            reader.beginObject()
            while (reader.hasNext()) {
                when (reader.nextName()) {
                    "metadata" -> {
                        reader.beginObject()
                        while (reader.hasNext()) {
                            if (reader.nextName() == "sections") {
                                reader.beginObject()
                                while (reader.hasNext()) {
                                    sections[reader.nextName()] = reader.nextString()
                                }
                                reader.endObject()
                            } else reader.skipValue()
                        }
                        reader.endObject()
                    }
                    "hadiths" -> {
                        reader.beginArray()
                        while (reader.hasNext()) {
                            var number = "0"
                            var text = ""
                            var book: Int? = null
                            reader.beginObject()
                            while (reader.hasNext()) {
                                when (reader.nextName()) {
                                    "hadithnumber" -> number = readNumber(reader)
                                    "text" -> text = reader.nextString()
                                    "reference" -> {
                                        reader.beginObject()
                                        while (reader.hasNext()) {
                                            if (reader.nextName() == "book") {
                                                book = readNumber(reader).toIntOrNull()
                                            } else reader.skipValue()
                                        }
                                        reader.endObject()
                                    }
                                    else -> reader.skipValue()
                                }
                            }
                            reader.endObject()
                            items.add(Item(number, text, book))
                        }
                        reader.endArray()
                    }
                    else -> reader.skipValue()
                }
            }
            reader.endObject()
        }
        return sections to items
    }

    private fun buildDatabase(context: Context, collection: HadithCollection): Boolean = try {
        val (_, araItems) = readEdition(jsonFile(context, collection, "ara"))
        val (engSections, engItems) = readEdition(jsonFile(context, collection, "eng"))
        val arabicByIndex = arabicTitles(context, collection)
        val engByNumber = HashMap<String, String>(engItems.size)
        engItems.forEach { engByNumber.putIfAbsent(it.number, it.text) }

        val temp = File(dir(context), "${collection.key}.building")
        temp.delete()
        val db = SQLiteDatabase.openOrCreateDatabase(temp, null)
        db.execSQL("CREATE TABLE books(idx INTEGER PRIMARY KEY, ar TEXT, en TEXT, count INTEGER)")
        db.execSQL("CREATE TABLE hadith(book INTEGER, num TEXT, ar TEXT, en TEXT)")
        db.execSQL("CREATE INDEX idx_book ON hadith(book)")
        db.execSQL("CREATE INDEX idx_num ON hadith(num)")
        db.beginTransaction()
        try {
            val insert = db.compileStatement("INSERT INTO hadith(book, num, ar, en) VALUES(?,?,?,?)")
            val counts = sortedMapOf<Int, Int>()
            for (item in araItems) {
                val book = item.book ?: continue
                val arabic = item.text.trim()
                if (arabic.isEmpty()) continue  // dataset gaps
                insert.bindLong(1, book.toLong())
                insert.bindString(2, item.number)
                insert.bindString(3, arabic)
                insert.bindString(4, engByNumber[item.number] ?: "")
                insert.executeInsert()
                counts[book] = (counts[book] ?: 0) + 1
            }
            insert.close()
            val bookInsert = db.compileStatement("INSERT INTO books(idx, ar, en, count) VALUES(?,?,?,?)")
            for ((index, count) in counts) {
                val key = index.toString()
                bookInsert.bindLong(1, index.toLong())
                bookInsert.bindString(2, arabicByIndex[key] ?: "كتاب ${index.arabicIndic()}")
                bookInsert.bindString(3, engSections[key] ?: "Book $index")
                bookInsert.bindLong(4, count.toLong())
                bookInsert.executeInsert()
            }
            bookInsert.close()
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
            db.close()
        }
        val target = dbFile(context, collection)
        target.delete()
        val moved = temp.renameTo(target)
        if (moved) {
            // The JSONs are no longer needed — reclaim ~28 MB per collection.
            jsonFile(context, collection, "ara").delete()
            jsonFile(context, collection, "eng").delete()
        }
        moved
    } catch (_: Exception) {
        false
    }

    // MARK: - Reads (blocking — call from Dispatchers.IO)

    private fun <Row> query(
        context: Context,
        collection: HadithCollection,
        sql: String,
        args: Array<String> = emptyArray(),
        map: (android.database.Cursor) -> Row,
    ): List<Row> {
        val file = dbFile(context, collection)
        if (!file.exists()) return emptyList()
        return SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
            db.rawQuery(sql, args).use { c ->
                buildList { while (c.moveToNext()) add(map(c)) }
            }
        }
    }

    fun books(context: Context, collection: HadithCollection): List<HadithBook> =
        query(context, collection, "SELECT idx, ar, count FROM books ORDER BY idx") { c ->
            HadithBook(c.getInt(0), c.getString(1), c.getInt(2))
        }

    fun hadiths(context: Context, collection: HadithCollection, book: Int): List<LibraryHadith> =
        query(
            context, collection,
            "SELECT num, ar, en FROM hadith WHERE book = ? ORDER BY rowid",
            arrayOf(book.toString())
        ) { c ->
            LibraryHadith(c.getString(0), c.getString(1), c.getString(2), book)
        }

    /// Global search across every downloaded collection.
    fun search(context: Context, rawQuery: String, limit: Int = 80): List<HadithSearchHit> {
        val trimmed = rawQuery.trim()
        if (trimmed.length < 2) return emptyList()
        val hits = mutableListOf<HadithSearchHit>()
        for (collection in HadithCollection.entries) {
            if (!isDownloaded(context, collection)) continue
            hits += query(
                context, collection,
                """
                SELECT h.num, h.ar, h.en, h.book, b.ar FROM hadith h
                JOIN books b ON b.idx = h.book
                WHERE h.ar LIKE ? OR h.en LIKE ? OR h.num = ?
                LIMIT ${limit - hits.size}
                """.trimIndent(),
                arrayOf("%$trimmed%", "%$trimmed%", trimmed)
            ) { c ->
                HadithSearchHit(
                    collection, c.getString(4),
                    LibraryHadith(c.getString(0), c.getString(1), c.getString(2), c.getInt(3))
                )
            }
            if (hits.size >= limit) break
        }
        return hits
    }
}

/// Bundled hadith: An-Nawawi's Forty + Forty Hadith Qudsi (offline,
/// public-domain dataset — see LICENSES.md).
data class BundledHadith(
    val collection: String,
    val collectionArabic: String,
    val number: Int,
    val arabic: String,
)

object HadithStore {
    /// Parses the bundled JSON — call from Dispatchers.IO.
    fun load(context: Context): List<BundledHadith> {
        val raw = context.assets.open("hadith.json").bufferedReader().readText()
        val array = org.json.JSONArray(raw)
        return buildList {
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                add(
                    BundledHadith(
                        obj.getString("collection"),
                        obj.getString("collectionArabic"),
                        obj.getInt("number"),
                        obj.getString("arabic"),
                    )
                )
            }
        }
    }
}
