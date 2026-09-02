package com.engagendy.noor

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.ui.platform.LocalLayoutDirection
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
    )

    fun named(slug: String?): TafsirEdition =
        editions.firstOrNull { it.slug == slug } ?: editions[0]

    private fun cacheFile(context: Context, slug: String, surah: Int, ayah: Int): File =
        File(context.filesDir, "tafsir/$slug/$surah/$ayah.txt")

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
            .onFailure { error = it.message ?: "تعذر التحميل" }
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
                    "التفسير · ${surahId.arabicIndic()}:${ayah.arabicIndic()}",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Bold,
                    color = NoorColor.inkPrimary,
                    modifier = Modifier.weight(1f),
                )
                // Ayah image-card share, like the iOS reader ShareAyahSheet.
                ShareIconButton {
                    val name = surahName.ifBlank { "سورة ${surahId.arabicIndic()}" }
                    shareRendered(
                        context, ayahText,
                        "$name · ${surahId.arabicIndic()}:${ayah.arabicIndic()}",
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
                                    modifier = Modifier.padding(bottom = 14.dp)
                                )
                            }
                        }
                    }
                }
                error != null -> Text(
                    "تعذر تحميل التفسير — تحقق من الاتصال. ($error)",
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
