package com.engagendy.noor

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.border
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun QuranScreen(
    modifier: Modifier = Modifier,
    mushafPage: Int = 0,
    resumeSurahId: Int = 0,
    onMushafClosed: () -> Unit = {},
    onSurahClosed: () -> Unit = {},
) {
    val context = LocalContext.current
    val db = remember { QuranDb.get(context) }
    val surahs = remember { db.surahs() }
    val prefs = remember { KhatmahPlan.prefs(context) }
    // Persisted reading mode — same raw values as iOS ("mushaf"/"page"/"ayah").
    var readerMode by remember {
        mutableStateOf(prefs.getString("reader.mode", "mushaf") ?: "mushaf")
    }
    // Flow reader: opened from the list or from Today (continue reading).
    var openSurah by remember(resumeSurahId) {
        mutableStateOf(surahs.firstOrNull { it.id == resumeSurahId })
    }
    // Madani page mode: opened from Today (frontier) or the mushaf button.
    var openMushafAt by remember(mushafPage) { mutableStateOf(mushafPage) }

    if (openMushafAt > 0) {
        MushafScreen(
            startPage = openMushafAt,
            onBack = { openMushafAt = 0; onMushafClosed() },
            modifier = modifier)
        return
    }

    val current = openSurah
    if (current != null) {
        // The reader OPENS in the persisted mode: Madani mode from the surah
        // list goes straight to the printed page (first page of the surah).
        if (readerMode == "page") {
            // First DB access copies the asset — keep it off the main thread.
            val firstPage by produceState(0, current.id) {
                value = withContext(Dispatchers.IO) {
                    PageLayoutDb.get(context).firstPage(current.id)
                }
            }
            if (firstPage > 0) {
                MushafScreen(
                    startPage = firstPage,
                    onBack = { openSurah = null; onSurahClosed() },
                    modifier = modifier)
            } else {
                Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = NoorColor.accentPrimary)
                }
            }
        } else {
            ReaderScreen(
                surah = current,
                mode = readerMode,
                onModeChange = { newMode ->
                    // User action from the options panel — persist + switch.
                    prefs.edit().putString("reader.mode", newMode).apply()
                    readerMode = newMode
                },
                onBack = { openSurah = null; onSurahClosed() },
                modifier = modifier)
        }
        return
    }

    LazyColumn(modifier = modifier.fillMaxSize()) {
        item {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp)
            ) {
                Text(
                    "القرآن",
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold,
                    color = NoorColor.inkPrimary
                )
                Text(
                    "المصحف",
                    color = NoorColor.accentPrimary,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.clickable {
                        openMushafAt = KhatmahPlan.prefs(context)
                            .getInt("reader.lastPage", 0).coerceAtLeast(1)
                    }.padding(8.dp)
                )
            }
        }
        items(surahs) { surah ->
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { openSurah = surah }
                    .padding(horizontal = 20.dp, vertical = 12.dp)
            ) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .size(36.dp)
                        .border(1.dp, NoorColor.accentGold, CircleShape)
                ) {
                    Text(surah.id.arabicIndic(), fontSize = 13.sp, color = NoorColor.accentGold)
                }
                Column(Modifier.padding(horizontal = 14.dp).weight(1f)) {
                    Text(
                        surah.nameArabic,
                        fontFamily = HafsFont,
                        fontSize = 20.sp,
                        color = NoorColor.inkPrimary
                    )
                    Text(
                        "${surah.ayahCount.arabicIndic()} آية · ${if (surah.revelation == "Meccan") "مكية" else "مدنية"}",
                        fontSize = 12.sp,
                        color = NoorColor.inkSecondary
                    )
                }
            }
            HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
        }
    }
}

/// The flow / ayah-by-ayah reader, with the iOS-style "Aa" options panel:
/// segmented reading-mode picker + text-size stepper on an elevated card.
@Composable
fun ReaderScreen(
    surah: Surah,
    mode: String,
    onModeChange: (String) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val db = remember { QuranDb.get(context) }
    val verses = remember(surah.id) { db.verses(surah.id) }
    val prefs = remember { KhatmahPlan.prefs(context) }
    val scope = rememberCoroutineScope()
    var showOptions by remember { mutableStateOf(false) }
    var fontSize by remember { mutableFloatStateOf(prefs.getFloat("reader.fontSize", 26f)) }
    // Resume position: one direct prefs write per surah open, off-main —
    // never observed as Compose state (same rule as the Madani pager).
    LaunchedEffect(surah.id) {
        withContext(Dispatchers.IO) {
            ReadingProgress.surahViewed(context, surah.id)
        }
    }
    // Continuous mushaf-style flow: one attributed stream with ayah markers,
    // each verse span annotated so a tap/long-press can resolve its ayah.
    val flow = remember(surah.id) {
        buildAnnotatedString {
            verses.forEach { verse ->
                pushStringAnnotation(tag = "ayah", annotation = verse.ayah.toString())
                append(verse.text)
                append(" ⁧﴿${verse.ayah.arabicIndic()}﴾⁩ ")
                pop()
            }
        }
    }
    // Ayah picked for tafsir (0 = none).
    var tafsirAyah by remember(surah.id) { mutableStateOf(0) }
    var textLayout by remember { mutableStateOf<TextLayoutResult?>(null) }

    fun ayahAt(position: Offset) {
        val layout = textLayout ?: return
        val offset = layout.getOffsetForPosition(position)
        flow.getStringAnnotations("ayah", offset, offset).firstOrNull()?.let {
            tafsirAyah = it.item.toIntOrNull() ?: 0
        }
    }

    fun startPlayback(fromAyah: Int = 1) {
        scope.launch {
            // "This page only" boundary comes from the layout DB — off-main.
            val pageEnd = withContext(Dispatchers.IO) {
                runCatching {
                    PageLayoutDb.get(context).pageEndAyah(surah.id, fromAyah)
                }.getOrDefault(0)
            }
            NoorPlayer.play(surah.id, surah.ayahCount, fromAyah, surah.nameArabic, pageEnd)
        }
    }

    if (tafsirAyah > 0) {
        val verse = verses.firstOrNull { it.ayah == tafsirAyah }
        if (verse != null) {
            TafsirSheet(
                surahId = surah.id,
                ayah = verse.ayah,
                ayahText = verse.text,
                onDismiss = { tafsirAyah = 0 })
        }
    }

    Column(modifier.fillMaxSize()) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 8.dp)
        ) {
            // Circular elevated back button, like the iOS reader chrome.
            Surface(
                shape = CircleShape,
                color = NoorColor.bgElevated,
                shadowElevation = 3.dp,
                modifier = Modifier.size(38.dp).clickable(onClick = onBack)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    // RTL: back points RIGHT (iOS mirrored chevron.backward).
                    Text("›", fontSize = 20.sp, fontWeight = FontWeight.SemiBold,
                         color = NoorColor.accentPrimary)
                }
            }
            Text(
                surah.nameArabic,
                fontFamily = HafsFont,
                fontSize = 20.sp,
                color = NoorColor.inkPrimary,
                textAlign = TextAlign.Center,
                modifier = Modifier.weight(1f)
            )
            // Play/pause reflecting the live player state (pause while playing).
            Text(
                if (NoorPlayer.currentSurah != 0 && NoorPlayer.isPlaying) "⏸" else "▶",
                fontSize = 17.sp,
                color = NoorColor.accentPrimary,
                modifier = Modifier.clickable {
                    if (NoorPlayer.currentSurah != 0) NoorPlayer.toggle()
                    else startPlayback()
                }.padding(10.dp)
            )
            // "Aa" opens the reader-options floating panel.
            Text(
                "Aa",
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                color = if (showOptions) NoorColor.accentGold else NoorColor.accentPrimary,
                modifier = Modifier.clickable { showOptions = !showOptions }.padding(10.dp)
            )
        }
        Box(Modifier.weight(1f)) {
            LazyColumn(Modifier.fillMaxSize().padding(horizontal = 18.dp)) {
                if (surah.id != 9 && surah.id != 1) {
                    item {
                        Text(
                            "بِسْمِ اللَّهِ الرَّحْمَـٰنِ الرَّحِيمِ",
                            fontFamily = QuranFont,
                            fontSize = (fontSize * 0.85f).sp,
                            textAlign = TextAlign.Center,
                            color = NoorColor.inkPrimary,
                            modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp)
                        )
                    }
                }
                if (mode == "ayah") {
                    // آية آية: each ayah its own block with the gold number badge.
                    items(verses, key = { it.ayah }) { verse ->
                        Text(
                            buildAnnotatedString {
                                append(verse.text)
                                withStyle(SpanStyle(
                                    color = NoorColor.accentGold,
                                    fontSize = (fontSize * 0.62f).sp)) {
                                    append("  ⁧﴿${verse.ayah.arabicIndic()}﴾⁩")
                                }
                            },
                            fontFamily = QuranFont,
                            fontSize = fontSize.sp,
                            lineHeight = (fontSize * 2.2f).sp,
                            color = NoorColor.inkPrimary,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(10.dp))
                                .clickable { tafsirAyah = verse.ayah }
                                .padding(horizontal = 12.dp, vertical = 8.dp)
                        )
                    }
                } else {
                    item {
                        Text(
                            flow,
                            fontFamily = QuranFont,
                            fontSize = fontSize.sp,
                            lineHeight = (fontSize * 2.2f).sp,
                            color = NoorColor.inkPrimary,
                            textAlign = TextAlign.Justify,
                            onTextLayout = { textLayout = it },
                            modifier = Modifier
                                .padding(bottom = 40.dp)
                                .pointerInput(surah.id) {
                                    detectTapGestures(
                                        onTap = { ayahAt(it) },
                                        onLongPress = { ayahAt(it) })
                                }
                        )
                    }
                }
            }
            if (showOptions) {
                // Scrim: any tap outside the panel dismisses it.
                Box(
                    Modifier
                        .fillMaxSize()
                        .pointerInput(Unit) { detectTapGestures { showOptions = false } }
                )
                ReaderOptionsPanel(
                    mode = mode,
                    fontSize = fontSize,
                    onMode = { newMode ->
                        showOptions = false
                        onModeChange(newMode)
                    },
                    onFontSize = { size ->
                        fontSize = size
                        prefs.edit().putFloat("reader.fontSize", size).apply()
                    },
                    modifier = Modifier.align(Alignment.TopCenter)
                )
            }
        }
    }
}

/// Floating elevated card under the top bar — the iOS reader options panel:
/// segmented مصحف / المدني / آية آية picker + Quran text-size stepper.
@Composable
private fun ReaderOptionsPanel(
    mode: String,
    fontSize: Float,
    onMode: (String) -> Unit,
    onFontSize: (Float) -> Unit,
    modifier: Modifier = Modifier,
) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = NoorColor.bgElevated,
        shadowElevation = 10.dp,
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp)
            .padding(top = 4.dp)
    ) {
        Column(Modifier.padding(16.dp)) {
            // Segmented reading-mode picker.
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(NoorColor.bgPrimary)
                    .padding(3.dp)
            ) {
                ModeSegment("مصحف", selected = mode == "mushaf",
                            modifier = Modifier.weight(1f)) { onMode("mushaf") }
                ModeSegment("المدني", selected = mode == "page",
                            modifier = Modifier.weight(1f)) { onMode("page") }
                ModeSegment("آية آية", selected = mode == "ayah",
                            modifier = Modifier.weight(1f)) { onMode("ayah") }
            }
            // The printed Madani page has fixed geometry — size buttons
            // only apply to the flow and ayah modes.
            if (mode != "page") {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth().padding(top = 14.dp)
                ) {
                    Text(
                        "حجم نص القرآن",
                        fontSize = 14.sp,
                        color = NoorColor.inkSecondary,
                        modifier = Modifier.weight(1f)
                    )
                    SizeButton("−") { onFontSize((fontSize - 2f).coerceAtLeast(20f)) }
                    Text(
                        fontSize.toInt().arabicIndic(),
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = NoorColor.accentPrimary,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(horizontal = 12.dp)
                    )
                    SizeButton("+") { onFontSize((fontSize + 2f).coerceAtMost(40f)) }
                }
            }
        }
    }
}

@Composable
private fun ModeSegment(
    label: String,
    selected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Box(
        contentAlignment = Alignment.Center,
        modifier = modifier
            .clip(RoundedCornerShape(8.dp))
            .background(if (selected) NoorColor.accentPrimary else NoorColor.bgPrimary)
            .clickable(onClick = onClick)
            .padding(vertical = 8.dp)
    ) {
        Text(
            label,
            fontSize = 13.sp,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
            color = if (selected) NoorColor.bgPrimary else NoorColor.inkPrimary
        )
    }
}

@Composable
private fun SizeButton(symbol: String, onClick: () -> Unit) {
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .size(34.dp)
            .clip(CircleShape)
            .background(NoorColor.bgPrimary)
            .clickable(onClick = onClick)
    ) {
        Text(symbol, fontSize = 18.sp, color = NoorColor.accentPrimary)
    }
}
