package com.engagendy.noor

import android.content.Context
import org.json.JSONObject

/// A classical didactic poem (متن) the user memorises — 1:1 with the iOS
/// `Modules/Learn/Sources/Learn/Matn.swift` model, reading the SAME JSON
/// files (`assets/matn-*.json` are byte-identical copies of the iOS bundle
/// resources built by `Tools/build_matn_*.py`).
///
/// The schema is deliberately wider than today's needs: it carries N matns,
/// and reserves `audio`/`timings` for follow-along recitation. No audio
/// ships until a recording's licence is recorded in LICENSES.md.
data class MatnSection(val id: String, val titleAr: String, val titleEn: String?) {
    fun displayTitle(): String = if (isArabicLocale()) titleAr else (titleEn ?: titleAr)
}

/// One بيت: two hemistichs (صدر / عجز).
data class MatnLine(
    val number: Int,
    val sectionId: String,
    val first: String,
    val second: String,
)

data class Matn(
    val id: String,
    val titleAr: String,
    val titleEn: String,
    val shortTitleAr: String?,
    val shortTitleEn: String?,
    val authorAr: String,
    val authorEn: String,
    val composedAr: String?,
    val sourceName: String,
    val sourceLicense: String,
    /// True when the section headings are OURS, not the source's — the
    /// reader says so under the poem rather than letting an editorial label
    /// pass for the author's (al-Bayquniyyah's source page has none).
    val sectionsEditorial: Boolean,
    val sections: List<MatnSection>,
    val lines: List<MatnLine>,
) {
    fun displayTitle(): String = if (isArabicLocale()) titleAr else titleEn

    /// Short enough for a screen header beside its buttons; falls back to
    /// the full title when a matn declares no short form.
    fun navigationTitle(): String =
        (if (isArabicLocale()) shortTitleAr else shortTitleEn) ?: displayTitle()

    fun displayAuthor(): String = if (isArabicLocale()) authorAr else authorEn

    fun lines(section: MatnSection): List<MatnLine> = lines.filter { it.sectionId == section.id }
}

object MatnStore {
    /// Every bundled matn. Add a file here (and its builder under `Tools/`)
    /// to ship another one — the UI is already N-matn.
    private val bundledFiles = listOf("matn-tuhfat-al-atfal", "matn-bayquniyyah")

    @Volatile
    private var cache: List<Matn>? = null

    /// Reads and parses the bundled JSON. ~13 KB total, but still call it
    /// off the main thread (the screens do, via `produceState`).
    fun load(context: Context): List<Matn> {
        cache?.let { return it }
        val parsed = bundledFiles.mapNotNull { name ->
            runCatching {
                parse(context.assets.open("$name.json").bufferedReader().use { it.readText() })
            }.getOrNull()
        }
        cache = parsed
        return parsed
    }

    fun matn(context: Context, id: String): Matn? = load(context).firstOrNull { it.id == id }

    private fun parse(json: String): Matn {
        val root = JSONObject(json)
        val sections = root.getJSONArray("sections").let { array ->
            (0 until array.length()).map { index ->
                val obj = array.getJSONObject(index)
                MatnSection(
                    id = obj.getString("id"),
                    titleAr = obj.getString("title_ar"),
                    titleEn = obj.optString("title_en").takeIf { it.isNotEmpty() })
            }
        }
        val lines = root.getJSONArray("lines").let { array ->
            (0 until array.length()).map { index ->
                val obj = array.getJSONObject(index)
                MatnLine(
                    number = obj.getInt("number"),
                    sectionId = obj.getString("section_id"),
                    first = obj.getString("first"),
                    second = obj.getString("second"))
            }
        }
        return Matn(
            id = root.getString("id"),
            titleAr = root.getString("title_ar"),
            titleEn = root.getString("title_en"),
            shortTitleAr = root.optString("short_title_ar").takeIf { it.isNotEmpty() },
            shortTitleEn = root.optString("short_title_en").takeIf { it.isNotEmpty() },
            authorAr = root.getString("author_ar"),
            authorEn = root.getString("author_en"),
            composedAr = root.optString("composed_ar").takeIf { it.isNotEmpty() },
            sourceName = root.getString("source_name"),
            sourceLicense = root.getString("source_license"),
            sectionsEditorial = root.optBoolean("sections_editorial", false),
            sections = sections,
            lines = lines)
    }
}

/// Search inside one matn — every hemistich of every line, folded ONCE when
/// the index is built so a keystroke only scans pre-folded text.
///
/// Nothing here re-implements folding or ranking: `SearchText` is the single
/// Arabic matcher in the app (Quran + athkar search), and the matns are
/// vowelled while people type bare letters, so it is exactly what is needed.
class MatnSearchIndex(matn: Matn) {
    /// One line that matched, and the hemistich the match is in — a snippet
    /// is always a window on text that exists in the poem, never a stitched
    /// string.
    data class Hit(val line: MatnLine, val text: String, val tier: Int)

    // Two documents per line (صدر then عجز).
    private val documents: List<Triple<MatnLine, String, String>> =
        matn.lines.flatMap { line ->
            listOf(
                Triple(line, line.first, SearchText.normalizeForSearch(line.first)),
                Triple(line, line.second, SearchText.normalizeForSearch(line.second)))
        }

    val lineCount: Int = matn.lines.size

    /// Matching lines, best tier first and line order inside a tier. A line
    /// whose two hemistichs both match appears once, at its better tier.
    fun search(query: String): List<Hit> {
        val normalized = SearchText.normalizeForSearch(query.trim())
        if (normalized.isEmpty()) return emptyList()
        val best = LinkedHashMap<Int, Hit>()
        for ((line, text, norm) in documents) {
            if (!norm.contains(normalized)) continue
            val tier = SearchText.matchTier(text, normalized)
            val existing = best[line.number]
            if (existing == null || tier < existing.tier) {
                best[line.number] = Hit(line, text, tier)
            }
        }
        return best.values.sortedWith(compareBy({ it.tier }, { it.line.number }))
    }
}
