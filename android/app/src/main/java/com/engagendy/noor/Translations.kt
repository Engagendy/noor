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
import java.util.Locale

/// Downloads and serves one Quran TRANSLATION (Tanzil text format:
/// "surah|ayah|text" lines) — 1:1 port of the iOS Core/Translations
/// TranslationStore. Downloaded once into filesDir, then fully offline.
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

    fun selectedId(context: Context): String =
        KhatmahPlan.prefs(context).getString("translation.id", TanzilEditions[0].id)
            ?: TanzilEditions[0].id

    private fun file(context: Context, id: String): File =
        File(File(context.filesDir, "translations").apply { mkdirs() }, "$id.txt")

    fun text(surah: Int, ayah: Int): String? = texts[surah * 1000 + ayah]

    /// Loads the selected edition from disk, downloading it once if needed.
    /// Safe to call repeatedly (a no-op once ready). Never touches the main
    /// thread: the file is a few MB and parsing it there stalls the reader.
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

    private fun download(id: String, target: File): Boolean {
        val temp = File(target.parentFile, "$id.part")
        return try {
            val connection = URL("https://tanzil.net/trans/%s".format(Locale.ROOT, id))
                .openConnection() as HttpURLConnection
            connection.connectTimeout = 15_000
            connection.readTimeout = 30_000
            val ok = connection.responseCode == 200
            val copied = if (ok) connection.inputStream.use { input ->
                temp.outputStream().use { input.copyTo(it) }
            } else -1L
            connection.disconnect()
            if (ok && copied > 100_000 && temp.renameTo(target)) true
            else { temp.delete(); false }
        } catch (_: Exception) {
            temp.delete()
            false
        }
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
