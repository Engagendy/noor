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
/// One offered translation edition. `id` is the Tanzil id where Tanzil
/// carries the work (it is also the on-disk file name and the value of the
/// "translation.id" pref); `language` is the `NoorLanguage.code` the edition
/// is the default for; `displayName` is the edition's OWN language and
/// script (an endonym, like the language picker — never routed through
/// strings.xml, because a Bengali reader must find "বাংলা" whatever the UI
/// language is); `isRtl` is the direction its text reads in.
data class TranslationEdition(
    val id: String,
    val language: String,
    val displayName: String,
    val isRtl: Boolean = false,
)

/// The offered editions — 1:1 with the iOS Core/Translations
/// TranslationStore.allEditions ("translation.id"), in the NoorLanguage
/// order, Somali last (no interface language yet; its default only applies
/// once `so` joins the picker). Where each one is actually fetched from
/// (jsDelivr mirror first, tanzil.net last) lives in TranslationStore.
val TanzilEditions = listOf(
    TranslationEdition("en.sahih", "en", "English — Saheeh International"),
    TranslationEdition("id.indonesian", "id", "Indonesia — Kemenag"),
    TranslationEdition("ur.jalandhry", "ur", "اردو — جالندہری", isRtl = true),
    TranslationEdition("fa.fooladvand", "fa", "فارسی — فولادوند", isRtl = true),
    TranslationEdition("tr.diyanet", "tr", "Türkçe — Diyanet"),
    TranslationEdition("ms.basmeih", "ms", "Bahasa Melayu — Basmeih"),
    TranslationEdition("bn.zakaria", "bn", "বাংলা — আবু বকর যাকারিয়া"),
    TranslationEdition("fr.hamidullah", "fr", "Français — Hamidullah"),
    TranslationEdition("es.garcia", "es", "Español — Isa García"),
    TranslationEdition("so.abduh", "so", "Soomaali — Maxamuud Maxamed Cabduh"),
)

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

    /// The direction of the LOADED edition's text (Urdu and Persian read
    /// right to left; the rest are LTR) — from the edition table, so a new
    /// edition can never be listed without saying which way it reads.
    val isRTL: Boolean get() = TanzilEditions.firstOrNull { it.id == loadedId }?.isRtl == true

    /// The edition an interface language reads by default. Arabic has no
    /// translation to follow (the Arabic reader reads the Quran itself), so
    /// it — and anything unknown — keeps the English default the app has
    /// always had.
    fun defaultFor(language: String): String =
        TanzilEditions.firstOrNull { it.language == language }?.id ?: TanzilEditions[0].id

    /// Our edition id → the equivalent file in fawazahmed0/quran-api.
    /// Verified live 2026-09-09 (first five) and 2026-09-12 (last five):
    /// every one returns 200 with a complete 6236-ayah file. Note the repo's
    /// editions.json KEYS use underscores (`fas_mohammadmahdifo`) while the
    /// FILES use hyphens — these are the file names, read from each
    /// catalogue entry's `link`, never derived from the key.
    private val MirrorFile = mapOf(
        // Saheeh International is the Umm Muhammad (Emily Assami,
        // Mary Kennedy, Amatullah Bantley) translation — same text.
        "en.sahih" to "eng-ummmuhammad",
        "ur.jalandhry" to "urd-fatehmuhammadja",
        "fr.hamidullah" to "fra-muhammadhamidul",
        "id.indonesian" to "ind-indonesianislam",
        "tr.diyanet" to "tur-diyanetisleri",
        // Mohammad Mahdi Fooladvand — the same work as the Persian
        // translation AUDIO (TranslationVoice.PERSIAN), so text and voice
        // agree ayah for ayah. Catalogue key fas_mohammadmahdifo.
        "fa.fooladvand" to "fas-mohammadmahdifo",
        // Dr. Abu Bakr Muhammad Zakaria (KFGQPC edition) — the widely read
        // modern Bengali. Catalogue key ben_abubakrzakaria; not on tanzil.net.
        "bn.zakaria" to "ben-abubakrzakaria",
        // Abdullah Muhammad Basmeih (Tafsir Pimpinan Ar-Rahman) — the only
        // Malay edition the mirror carries. Catalogue key msa_abdullahmuhamma.
        "ms.basmeih" to "msa-abdullahmuhamma",
        // Muhammad Isa García. Catalogue key spa_muhammadisagarc.
        "es.garcia" to "spa-muhammadisagarc",
        // Mahmud Muhammad Abduh. Catalogue key som_mahmudmuhammada.
        "so.abduh" to "som-mahmudmuhammada",
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

    /// The pref holds an edition id only once the user has picked one in
    /// Settings; while it is ABSENT the edition follows the interface
    /// language (a Turkish interface reads Diyanet, a Persian one
    /// Fooladvand, …). Absence is the "never chosen" sentinel, so an
    /// explicit choice — English included — survives every language change,
    /// and "Follow app language" in Settings is simply removing the key.
    fun explicitId(context: Context): String? =
        KhatmahPlan.prefs(context).getString("translation.id", null)
            ?.takeIf { id -> TanzilEditions.any { it.id == id } }

    fun selectedId(context: Context): String =
        explicitId(context) ?: defaultFor(NoorLanguage.current().code)

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
