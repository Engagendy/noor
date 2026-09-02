package com.engagendy.noor

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
import androidx.compose.foundation.border
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

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
        ReaderScreen(
            surah = current,
            onBack = { openSurah = null; onSurahClosed() },
            modifier = modifier)
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

@Composable
fun ReaderScreen(surah: Surah, onBack: () -> Unit, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val db = remember { QuranDb.get(context) }
    val verses = remember(surah.id) { db.verses(surah.id) }
    // Resume position: one direct prefs write per surah open, off-main —
    // never observed as Compose state (same rule as the Madani pager).
    androidx.compose.runtime.LaunchedEffect(surah.id) {
        kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
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
            horizontalArrangement = Arrangement.SpaceBetween,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp)
        ) {
            Text(
                surah.nameArabic,
                fontFamily = HafsFont,
                fontSize = 22.sp,
                color = NoorColor.inkPrimary
            )
            Text(
                if (NoorPlayer.isPlaying && NoorPlayer.currentSurah == surah.id) "⏸" else "▶ استمع",
                color = NoorColor.accentPrimary,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.clickable {
                    if (NoorPlayer.currentSurah == surah.id) NoorPlayer.toggle()
                    else NoorPlayer.play(surah.id, surah.ayahCount, 1, surah.nameArabic)
                }.padding(8.dp)
            )
            Text(
                "رجوع",
                color = NoorColor.accentPrimary,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.clickable(onClick = onBack).padding(8.dp)
            )
        }
        LazyColumn(Modifier.fillMaxSize().padding(horizontal = 18.dp)) {
            if (surah.id != 9 && surah.id != 1) {
                item {
                    Text(
                        "بِسْمِ اللَّهِ الرَّحْمَـٰنِ الرَّحِيمِ",
                        fontFamily = QuranFont,
                        fontSize = 22.sp,
                        textAlign = TextAlign.Center,
                        color = NoorColor.inkPrimary,
                        modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp)
                    )
                }
            }
            item {
                // Reader size from Settings ("reader.fontSize", 20–44pt).
                val quranSize = remember {
                    KhatmahPlan.prefs(context).getFloat("reader.fontSize", 26f)
                }
                Text(
                    flow,
                    fontFamily = QuranFont,
                    fontSize = quranSize.sp,
                    lineHeight = (quranSize * 2.25f).sp,
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
}
