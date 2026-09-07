package com.engagendy.noor

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.runtime.CompositionLocalProvider
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

/// Tafsir editions from the spa5k/tafsir_api CDN bundles (see LICENSES.md),
/// 1:1 with the iOS Modules/Tafsir list. Each fetched ayah is cached to a
/// file — offline after the first read.
data class TafsirEdition(val slug: String, val displayName: String, val isArabic: Boolean)

object Tafsir {
    val editions = listOf(
        TafsirEdition("ar-tafsir-muyassar", "الميسر", true),
        TafsirEdition("ar-tafseer-al-saddi", "السعدي", true),
        TafsirEdition("ar-tafsir-ibn-kathir", "ابن كثير", true),
        TafsirEdition("ar-tafsir-al-tabari", "الطبري", true),
        TafsirEdition("ar-tafseer-al-qurtubi", "القرطبي", true),
        TafsirEdition("en-tafisr-ibn-kathir", "Ibn Kathir (English)", false),
        // Word meanings (غريب القرآن) rather than running commentary: each
        // entry glosses the difficult words of its ayah. `GHARIB_SLUG` points
        // the Learn hub's "Quranic word meanings" entry at it — it is an
        // ordinary edition here too, so anyone who prefers it in the ayah
        // sheet can pick it there.
        TafsirEdition("al-muyassar-fi-al-gharib", "الميسر في الغريب", true),
        // Despite its name, what the API serves under this slug is running
        // commentary in the wording of as-Sa'di, NOT a word glossary
        // (verified on iOS 2026-09-07 against 1:1, 2:255 and 18:9) — so it is
        // offered as one more tafsir, not as غريب القرآن.
        TafsirEdition("asseraj-fi-bayan-gharib-alquran", "السراج", true),
    )

    /// The edition behind the Learn hub's "Quranic word meanings" entry.
    const val GHARIB_SLUG = "al-muyassar-fi-al-gharib"

    const val SURAH_COUNT = 114

    val gharib: TafsirEdition get() = named(GHARIB_SLUG)

    fun named(slug: String?): TafsirEdition =
        editions.firstOrNull { it.slug == slug } ?: editions[0]

    // Paths are built from Int.toString()/plain slugs only — never a
    // locale-formatted number (CLAUDE.md: Locale.ROOT for filenames).
    private fun surahDir(context: Context, slug: String, surah: Int): File =
        File(context.filesDir, "tafsir/$slug/$surah")

    private fun cacheFile(context: Context, slug: String, surah: Int, ayah: Int): File =
        File(surahDir(context, slug, surah), "$ayah.txt")

    /// Written after a whole surah bundle has been cached. Without it a
    /// directory holding one ayah the user happened to tap in the reader
    /// would look like a complete surah to the browser and to search. It is
    /// a zero-byte marker in the SAME cache — no tafsir text lives here.
    /// (Mirrors iOS `TafsirService.completionMarker`.)
    private fun completionMarker(context: Context, slug: String, surah: Int): File =
        File(surahDir(context, slug, surah), ".complete")

    /// Cache-first load; the network path runs entirely on IO.
    suspend fun load(context: Context, slug: String, surah: Int, ayah: Int): Result<String> =
        withContext(Dispatchers.IO) {
            val cache = cacheFile(context, slug, surah, ayah)
            if (cache.exists()) {
                val cached = cache.readText()
                if (cached.isNotBlank()) return@withContext Result.success(cached)
            }
            runCatching {
                val url = URL(
                    "https://cdn.jsdelivr.net/gh/spa5k/tafsir_api@main/tafsir/$slug/$surah/$ayah.json")
                val connection = url.openConnection() as HttpURLConnection
                connection.connectTimeout = 15_000
                connection.readTimeout = 15_000
                try {
                    if (connection.responseCode != 200) error("HTTP ${connection.responseCode}")
                    val body = connection.inputStream.bufferedReader().readText()
                    val text = stripHtml(JSONObject(body).getString("text"))
                    cache.parentFile?.mkdirs()
                    cache.writeText(text)
                    text
                } finally {
                    connection.disconnect()
                }
            }
        }

    // MARK: - One surah, as a whole (the Learn browser + search)

    /// One ayah's tafsir. Editions that gloss only some ayat (غريب القرآن)
    /// simply omit the rest, so the browser renders what the edition has
    /// rather than a row per ayah of the surah.
    data class Entry(val ayah: Int, val text: String)

    /// True once this surah's whole bundle is on disk — the browser reads it
    /// with no network at all.
    fun isSurahCached(context: Context, slug: String, surah: Int): Boolean =
        completionMarker(context, slug, surah).exists()

    /// The surahs of this edition whose WHOLE bundle is cached, in order. A
    /// surah half-filled by tapping single ayat in the reader is NOT one of
    /// them — searching it would look complete and quietly miss most of it
    /// (this is exactly what the `.complete` marker is for).
    fun cachedSurahNumbers(context: Context, slug: String): List<Int> =
        (1..SURAH_COUNT).filter { isSurahCached(context, slug, it) }

    /// Reads a cached surah out of the per-ayah cache — the SAME files
    /// `load` writes and reads. There is exactly one tafsir cache.
    fun cachedSurah(context: Context, slug: String, surah: Int): List<Entry> {
        val dir = surahDir(context, slug, surah)
        val names = dir.list() ?: return emptyList()
        return names.mapNotNull { name ->
            if (!name.endsWith(".txt")) return@mapNotNull null
            val ayah = name.dropLast(4).toIntOrNull() ?: return@mapNotNull null
            if (ayah <= 0) return@mapNotNull null
            val text = runCatching { File(dir, name).readText() }.getOrNull() ?: return@mapNotNull null
            if (text.isBlank()) null else Entry(ayah, text)
        }.sortedBy { it.ayah }
    }

    /// True when every surah of this edition is cached (spot-checked, like
    /// iOS). The `1.txt` fallback keeps packs downloaded by earlier versions
    /// — which wrote no completion marker — from looking undownloaded.
    fun isPackDownloaded(context: Context, slug: String): Boolean =
        listOf(1, 2, 18, 67, 114).all { surah ->
            isSurahCached(context, slug, surah) ||
                cacheFile(context, slug, surah, 1).exists()
        }

    /// THE per-surah fetch: one bundle, written into the per-ayah cache that
    /// `load` reads. Both the whole-edition download and the Learn browser go
    /// through here, so there is one network path and one cache.
    private fun fetchAndCacheSurahBlocking(
        context: Context,
        slug: String,
        surah: Int,
    ): List<Entry> {
        val url = URL("https://cdn.jsdelivr.net/gh/spa5k/tafsir_api@main/tafsir/$slug/$surah.json")
        val connection = url.openConnection() as HttpURLConnection
        connection.connectTimeout = 15_000
        connection.readTimeout = 20_000
        val body = try {
            if (connection.responseCode != 200) error("HTTP ${connection.responseCode}")
            connection.inputStream.bufferedReader().readText()
        } finally {
            connection.disconnect()
        }
        val dir = surahDir(context, slug, surah)
        dir.mkdirs()
        val array = org.json.JSONArray(body)
        val entries = ArrayList<Entry>(array.length())
        for (index in 0 until array.length()) {
            val item = array.getJSONObject(index)
            // The bundles carry ayah as a number in some editions and a
            // string in others — accept both (as iOS does).
            val ayah = item.optInt("ayah", 0).takeIf { it > 0 }
                ?: item.optString("ayah").toIntOrNull() ?: 0
            if (ayah <= 0) continue
            val text = stripHtml(item.optString("text"))
            if (text.isEmpty()) continue
            runCatching { cacheFile(context, slug, surah, ayah).writeText(text) }
            entries.add(Entry(ayah, text))
        }
        completionMarker(context, slug, surah).writeText("")
        TafsirPacks.noteCacheChanged()
        return entries.sortedBy { it.ayah }
    }

    /// Loads one surah for the Learn browser: cache first (offline), then the
    /// same per-surah bundle the pack download uses, cached the same way.
    /// An empty result is a real answer, not a failure — word-meaning
    /// editions skip whole surahs.
    suspend fun loadSurah(context: Context, slug: String, surah: Int): Result<List<Entry>> =
        withContext(Dispatchers.IO) {
            if (isSurahCached(context, slug, surah)) {
                val cached = cachedSurah(context, slug, surah)
                if (cached.isNotEmpty()) return@withContext Result.success(cached)
            }
            runCatching { fetchAndCacheSurahBlocking(context, slug, surah) }
                .recoverCatching { error ->
                    // Offline with a partial cache (ayat read one by one in
                    // the reader) is still worth showing.
                    val cached = cachedSurah(context, slug, surah)
                    if (cached.isEmpty()) throw error else cached
                }
        }

    /// Used by the whole-edition download; blocking, IO-dispatcher only.
    internal fun downloadSurahBlocking(context: Context, slug: String, surah: Int) {
        if (isSurahCached(context, slug, surah)) return
        fetchAndCacheSurahBlocking(context, slug, surah)
    }

    /// The CDN texts occasionally carry basic HTML tags — flatten to plain text.
    fun stripHtml(html: String): String = html
        .replace(Regex("<br\\s*/?>"), "\n")
        .replace("</p>", "\n\n")
        .replace(Regex("<[^>]+>"), "")
        .replace("&quot;", "\"")
        .replace("&amp;", "&")
        .replace(Regex("\n{3,}"), "\n\n")
        .trim()
}

/// Tafsir sheet (design 6.5, matching iOS TafsirSheetView): the ayah in a
/// gold frame, one-line edition chips, tafsir rendered per paragraph —
/// monolithic Arabic strings break shaping on long texts.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TafsirSheet(
    surahId: Int,
    ayah: Int,
    ayahText: String,
    onDismiss: () -> Unit,
    surahName: String = "",
) {
    val context = LocalContext.current
    val prefs = remember { KhatmahPlan.prefs(context) }
    var editionSlug by remember {
        mutableStateOf(prefs.getString("tafsir.edition", Tafsir.editions[0].slug))
    }
    val edition = Tafsir.named(editionSlug)
    var text by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(editionSlug) {
        text = null
        error = null
        Tafsir.load(context, edition.slug, surahId, ayah)
            .onSuccess { text = it }
            .onFailure { error = it.message ?: context.getString(R.string.g2_load_failed) }
    }

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = NoorColor.bgPrimary) {
        Column(
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .padding(bottom = 32.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    stringResource(
                        R.string.g2_tafsir_title,
                        surahId.localizedDigits(), ayah.localizedDigits()),
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Bold,
                    color = NoorColor.inkPrimary,
                    modifier = Modifier.weight(1f),
                )
                // Ayah image-card share, like the iOS reader ShareAyahSheet.
                ShareIconButton {
                    val name = surahName.ifBlank {
                        context.getString(R.string.g2_surah_prefix, surahId.localizedDigits())
                    }
                    shareRendered(
                        context, ayahText,
                        "$name · ${surahId.localizedDigits()}:${ayah.localizedDigits()}",
                        useQuranFont = true,
                        attribution = "نور Noor · Quran text: Tanzil.net")
                }
            }
            // The ayah, framed in gold — text straight from the verified DB.
            Text(
                ayahText,
                fontFamily = QuranFont,
                fontSize = 20.sp,
                lineHeight = 42.sp,
                color = NoorColor.inkPrimary,
                style = arabicText(),
                modifier = Modifier
                    .padding(top = 12.dp)
                    .fillMaxWidth()
                    .border(1.dp, NoorColor.accentGold.copy(alpha = 0.6f), RoundedCornerShape(8.dp))
                    .padding(14.dp)
            )
            // One-line edition chips in a horizontal scroll — names never wrap.
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier
                    .padding(top = 14.dp)
                    .horizontalScroll(rememberScrollState())
            ) {
                Tafsir.editions.forEach { candidate ->
                    val on = candidate.slug == editionSlug
                    Text(
                        candidate.displayName,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 1,
                        color = if (on) NoorColor.bgPrimary else NoorColor.accentPrimary,
                        modifier = Modifier
                            .clip(RoundedCornerShape(50))
                            .background(
                                if (on) NoorColor.accentPrimary
                                else NoorColor.accentPrimary.copy(alpha = 0.1f),
                                RoundedCornerShape(50)
                            )
                            .clickable {
                                editionSlug = candidate.slug
                                prefs.edit().putString("tafsir.edition", candidate.slug).apply()
                            }
                            .padding(horizontal = 14.dp, vertical = 8.dp)
                    )
                }
            }

            val body = text
            when {
                body != null -> {
                    // English tafsir flips to LTR inside the RTL app.
                    CompositionLocalProvider(
                        LocalLayoutDirection provides
                            if (edition.isArabic) LayoutDirection.Rtl else LayoutDirection.Ltr
                    ) {
                        Column(Modifier.padding(top = 16.dp)) {
                            val paragraphs = body.split("\n")
                                .map { it.trim() }
                                .filter { it.isNotEmpty() }
                                .ifEmpty { listOf(body) }
                            paragraphs.forEach { paragraph ->
                                Text(
                                    paragraph,
                                    fontSize = if (edition.isArabic) 18.sp else 16.sp,
                                    lineHeight = if (edition.isArabic) 34.sp else 26.sp,
                                    color = NoorColor.inkPrimary,
                                    style = if (edition.isArabic) arabicText() else TextStyle.Default,
                                    modifier = Modifier.fillMaxWidth().padding(bottom = 14.dp)
                                )
                            }
                        }
                    }
                }
                error != null -> Text(
                    stringResource(R.string.g2_tafsir_error, error ?: ""),
                    fontSize = 14.sp,
                    color = NoorColor.inkSecondary,
                    modifier = Modifier.padding(top = 32.dp)
                )
                else -> Box(
                    Modifier.fillMaxWidth().padding(top = 40.dp),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(color = NoorColor.accentPrimary)
                }
            }
        }
    }
}
