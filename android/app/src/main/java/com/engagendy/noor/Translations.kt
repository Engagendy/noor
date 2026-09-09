package com.engagendy.noor

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

/// Downloads and serves one Quran TRANSLATION — 1:1 port of the iOS
/// Core/Translations TranslationStore. Downloaded once into filesDir as the
/// Tanzil line format ("surah|ayah|text"), then fully offline for good.
/// Never mixed with the Arabic text: the Quran itself always comes from the
/// bundled verified DB, this file only ever feeds the gloss line under it.
object TranslationStore {

    enum class State { NOT_DOWNLOADED, DOWNLOADING, READY, FAILED }

    var state by mutableStateOf(State.NOT_DOWNLOADED)
        private set

    /// The edition currently parsed into `texts` — a change of
    /// "translation.id" in Settings makes the next `ensure` reload.
    private var loadedId: String? = null
    /// Compose state: an ayah's translation line appears the moment the
    /// file finishes parsing, without the reader having to be reopened.
    private var texts by mutableStateOf<Map<Int, String>>(emptyMap())

    /// Urdu reads right to left; the rest of the editions are LTR.
    val isRTL: Boolean get() = loadedId?.startsWith("ur") == true

    /// Our edition id → the equivalent file in fawazahmed0/quran-api.
    /// Verified live 2026-09-09: every one of the five returns 200 with a
    /// complete 6236-ayah file. Note the repo's editions.json KEYS use
    /// underscores while the FILES use hyphens — these are the file names.
    private val MirrorFile = mapOf(
        // Saheeh International is the Umm Muhammad (Emily Assami,
        // Mary Kennedy, Amatullah Bantley) translation — same text.
        "en.sahih" to "eng-ummmuhammad",
        "ur.jalandhry" to "urd-fatehmuhammadja",
        "fr.hamidullah" to "fra-muhammadhamidul",
        "id.indonesian" to "ind-indonesianislam",
        "tr.diyanet" to "tur-diyanetisleri",
    )

    /// Where an edition is fetched from, in order, first success wins.
    ///
    /// The jsDelivr mirror leads and tanzil.net trails deliberately:
    /// tanzil.net is a single origin that national/corporate web filters
    /// block wholesale (verified 2026-09-09 from a UAE network — TLS reset
    /// on 443, and plain HTTP answers a filter's "Web Page Blocked …
    /// Category: religion" 503 page), which is exactly how this bug was
    /// reported. jsDelivr is a global CDN with no rate limits, and its own
    /// README asks callers to carry a fallback, hence the GitHub raw URL in
    /// the middle. Whichever host answers, the file lands on disk in the
    /// same Tanzil line format, so an already-downloaded edition keeps
    /// working untouched.
    private fun sources(id: String): List<String> = buildList {
        MirrorFile[id]?.let { file ->
            add("https://cdn.jsdelivr.net/gh/fawazahmed0/quran-api@1/editions/$file.json")
            add("https://raw.githubusercontent.com/fawazahmed0/quran-api/1/editions/$file.json")
        }
        add("https://tanzil.net/trans/$id")
    }

    fun selectedId(context: Context): String =
        KhatmahPlan.prefs(context).getString("translation.id", TanzilEditions[0].id)
            ?: TanzilEditions[0].id

    private fun file(context: Context, id: String): File =
        File(File(context.filesDir, "translations").apply { mkdirs() }, "$id.txt")

    fun text(surah: Int, ayah: Int): String? = texts[surah * 1000 + ayah]

    /// Loads the selected edition from disk, downloading it once if needed.
    /// Safe to call repeatedly (a no-op once ready), and safe to call again
    /// after a failure — that is what the reader's "tap to retry" line does.
    /// Never touches the main thread: the file is a few MB and parsing it
    /// there stalls the reader.
    suspend fun ensure(context: Context, allowDownload: Boolean = true) {
        val id = selectedId(context)
        if (id == loadedId && state == State.READY) return
        if (state == State.DOWNLOADING) return
        state = State.DOWNLOADING
        val local = file(context, id)
        val parsed = withContext(Dispatchers.IO) {
            if (!local.exists() && allowDownload) download(id, local)
            if (local.exists()) runCatching { parse(local.readText()) }.getOrNull() else null
        }
        if (parsed != null && parsed.size > 6000) {
            texts = parsed
            loadedId = id
            state = State.READY
        } else {
            // An incomplete file is worse than none: drop it so a retry
            // fetches cleanly rather than serving half a translation.
            withContext(Dispatchers.IO) { if (parsed != null) local.delete() }
            texts = emptyMap()
            loadedId = null
            state = State.FAILED
        }
    }

    /// Tries every mirror in turn and writes the first complete answer.
    private fun download(id: String, target: File): Boolean {
        val temp = File(target.parentFile, "$id.part")
        for (url in sources(id)) {
            val lines = fetch(url)?.let { normalize(it) } ?: continue
            val written = runCatching {
                temp.writeText(lines)
                temp.renameTo(target)
            }.getOrDefault(false)
            if (written) return true
            temp.delete()
        }
        temp.delete()
        return false
    }

    private fun fetch(url: String): String? = try {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = 15_000
        connection.readTimeout = 60_000
        connection.instanceFollowRedirects = true
        val body = if (connection.responseCode == 200) {
            connection.inputStream.bufferedReader().use { it.readText() }
        } else null
        connection.disconnect()
        body
    } catch (_: Exception) {
        null
    }

    /// Accepts either wire format and returns the Tanzil line format we
    /// store, or null when the body is not a whole Quran (a captive-portal
    /// or filter page never survives this).
    internal fun normalize(body: String): String? {
        val head = body.trimStart('\uFEFF', ' ', '\n', '\r', '\t')
        val lines = if (head.startsWith("{")) jsonToLines(head) ?: return null else body
        return if (parse(lines).size > 6000) lines else null
    }

    /// fawazahmed0/quran-api shape: {"quran":[{"chapter":1,"verse":1,…}]}.
    private fun jsonToLines(body: String): String? = try {
        val ayat = org.json.JSONObject(body).getJSONArray("quran")
        buildString(ayat.length() * 140) {
            for (i in 0 until ayat.length()) {
                val ayah = ayat.getJSONObject(i)
                // StringBuilder.append(Int) is ASCII whatever the app
                // locale — never String.format here (Arabic-Indic digits).
                append(ayah.getInt("chapter")).append('|')
                append(ayah.getInt("verse")).append('|')
                // One ayah per line is the storage contract.
                append(ayah.getString("text").replace('\n', ' ').replace('\r', ' '))
                append('\n')
            }
        }
    } catch (_: Exception) {
        null
    }

    /// Parses Tanzil "surah|ayah|text" lines; ignores comments and blanks.
    internal fun parse(content: String): Map<Int, String> {
        val result = HashMap<Int, String>(6300)
        for (line in content.lineSequence()) {
            if (line.isBlank() || line.startsWith("#")) continue
            val parts = line.split("|", limit = 3)
            if (parts.size < 3) continue
            val surah = parts[0].trim().toIntOrNull() ?: continue
            val ayah = parts[1].trim().toIntOrNull() ?: continue
            result[surah * 1000 + ayah] = parts[2].trim()
        }
        return result
    }
}
