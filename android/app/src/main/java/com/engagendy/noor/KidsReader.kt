package com.engagendy.noor

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/// Base Quran text size the kids reader scales from (the grown-up reader's
/// default), so a band's ×1.35 / ×1.2 / ×1.0 is comparable across platforms.
private const val KIDS_BASE_FONT = 26f

/// The kids reader: the same verified text and the same rendering as the
/// grown-up reader, with everything sharp removed. No share, no video, no
/// bookmark, no tafsir, no copy, no long-press — the ayah actions sheet is
/// simply never constructed. No page numbers, no juz labels, no go-to-page.
///
/// Playback runs through NoorPlayer: younger bands repeat every ayah
/// (`KidsMode.repeatCount`) via the memorize loop, and the surah STOPS at
/// its end instead of rolling into the next one, which is where the star
/// is awarded (one per completed play, three maximum).
@Composable
fun KidsReader(
    surah: Surah,
    age: Int,
    autoPlay: Boolean,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val db = remember { QuranDb.get(context) }
    val scale = KidsMode.textScale(age)
    val fontSize = KIDS_BASE_FONT * scale
    // Listen mode (the child's own choice, from the shell's sound sheet)
    // drops the repeats entirely; memorise keeps the age band's count.
    val repeat = KidsMode.repeatCount(age, KidsStore.listenMode)
    // Ayah-by-ayah is forced below 10; the oldest band may switch to flow.
    var flowLayout by remember(age) { mutableStateOf(false) }
    var celebrate by remember(surah.id) { mutableStateOf(false) }

    val verses by produceState(emptyList<Verse>(), surah.id) {
        value = withContext(Dispatchers.IO) { db.verses(surah.id) }
    }
    // Sajdah marks + the basmala line, straight from the verified DB.
    val sajdaKeys by produceState(emptySet<Int>()) {
        value = withContext(Dispatchers.IO) { db.sajdaKeys() }
    }
    val basmala by produceState<String?>(null) {
        value = withContext(Dispatchers.IO) { db.basmala() }
    }

    fun startPlayback() {
        NoorPlayer.playForKids(surah.id, surah.ayahCount, surah.nameArabic, repeat)
    }

    // A completed play earns a star. The callback is owned by this screen;
    // only OUR callback is cleared on dispose, so a configuration change
    // (the language switch, a rotation) hands over cleanly instead of
    // clobbering the screen that composed next. Stopping the recitation is
    // deliberately NOT done here — the shell stops it when the child
    // actually leaves the reader, so a recreate does not cut the ayah off.
    DisposableEffect(surah.id) {
        val callback: (Int) -> Unit = { finished ->
            if (finished == surah.id) {
                KidsStore.recordCompletion(context, surah.id)
                celebrate = true
            }
        }
        NoorPlayer.onSurahFinished = callback
        onDispose {
            if (NoorPlayer.onSurahFinished === callback) NoorPlayer.onSurahFinished = null
        }
    }
    // Autoplay only when nothing of this surah is already playing, so a
    // recreate mid-recitation resumes the view without restarting the audio.
    LaunchedEffect(surah.id) {
        if (autoPlay && NoorPlayer.currentSurah != surah.id) startPlayback()
    }

    val playingHere = NoorPlayer.currentSurah == surah.id
    val recitingAyah = if (playingHere) NoorPlayer.currentAyah else 0

    Column(modifier.fillMaxSize().background(NoorColor.bgPrimary)) {
        // Header: back, surah name, stars earned so far. Nothing else.
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .padding(horizontal = 12.dp, vertical = 8.dp)
        ) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .clickable(onClick = onBack)
            ) {
                Icon(
                    painterResource(NoorIcons.back()),
                    contentDescription = stringResource(R.string.g2_back),
                    tint = NoorColor.accentPrimary,
                    modifier = Modifier.size(22.dp))
            }
            Text(
                surah.nameArabic,
                fontFamily = HafsFont,
                fontSize = 24.sp,
                color = NoorColor.inkPrimary,
                textAlign = TextAlign.Center,
                style = arabicText(TextAlign.Center),
                modifier = Modifier.weight(1f))
            StarRow(KidsStore.stars(surah.id), size = 18.dp)
        }
        if (KidsMode.allowsFlowLayout(age)) {
            // Only the 10–12 band gets a layout choice; the younger bands
            // stay ayah-by-ayah whatever they tap.
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp)
            ) {
                LayoutChip(
                    label = stringResource(R.string.g2_reading_mode_ayah),
                    selected = !flowLayout,
                    modifier = Modifier.weight(1f)) { flowLayout = false }
                LayoutChip(
                    label = stringResource(R.string.g2_reading_mode_mushaf),
                    selected = flowLayout,
                    modifier = Modifier.weight(1f)) { flowLayout = true }
            }
        }

        val listState = rememberLazyListState()
        val hasBasmala = surah.id != 1 && surah.id != 9
        // Follow the recitation, ayah by ayah (no page flipping here).
        LaunchedEffect(surah.id, flowLayout, verses) {
            androidx.compose.runtime.snapshotFlow {
                if (NoorPlayer.currentSurah == surah.id) NoorPlayer.currentAyah else 0
            }.collect { ayah ->
                if (ayah <= 0 || flowLayout || verses.isEmpty()) return@collect
                val index = verses.indexOfFirst { it.ayah == ayah }
                if (index >= 0) {
                    listState.animateScrollToItem((if (hasBasmala) 1 else 0) + index)
                }
            }
        }

        // The Quran text area is an RTL block whatever the UI language.
        ArabicDirection {
            LazyColumn(
                state = listState,
                modifier = Modifier.weight(1f).fillMaxWidth().padding(horizontal = 18.dp)
            ) {
                if (hasBasmala) {
                    item("basmala") {
                        Text(
                            basmala ?: "",
                            fontFamily = QuranFont,
                            fontSize = (fontSize * 0.85f).sp,
                            textAlign = TextAlign.Center,
                            style = arabicText(TextAlign.Center),
                            color = NoorColor.inkPrimary,
                            modifier = Modifier.fillMaxWidth().padding(vertical = 14.dp))
                    }
                }
                if (flowLayout) {
                    item("flow") {
                        // Same flow builder as the grown-up reader, with the
                        // juz headers and hizb marks left out (no divisions
                        // in kids mode) — the text itself is untouched.
                        val flow = buildSurahFlow(
                            context, db, surah.id, verses,
                            juzAt = emptyMap(), quarterKeys = emptySet(),
                            sajdaKeys = sajdaKeys, fontSize = fontSize,
                            highlightAyah = recitingAyah)
                        Text(
                            flow,
                            fontFamily = QuranFont,
                            fontSize = fontSize.sp,
                            lineHeight = (fontSize * 2.2f).sp,
                            color = NoorColor.inkPrimary,
                            textAlign = TextAlign.Justify,
                            style = arabicText(TextAlign.Justify),
                            modifier = Modifier.fillMaxWidth().padding(bottom = 30.dp))
                    }
                } else {
                    items(verses, key = { it.ayah }) { verse ->
                        val key = surah.id * 1000 + verse.ayah
                        Text(
                            buildAnnotatedString {
                                append(db.textWithoutLeadingBasmala(verse))
                                if (key in sajdaKeys) {
                                    withStyle(SpanStyle(color = NoorColor.accentGold)) {
                                        append(" ۩")
                                    }
                                }
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
                            style = arabicText(),
                            // No tap target at all: the actions sheet must
                            // not be reachable from kids mode.
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 4.dp)
                                .clip(RoundedCornerShape(14.dp))
                                .background(
                                    if (verse.ayah == recitingAyah) NoorColor.stateReciting
                                    else NoorColor.bgPrimary.copy(alpha = 0f),
                                    RoundedCornerShape(14.dp))
                                .padding(horizontal = 12.dp, vertical = 10.dp))
                    }
                }
                item("tail") { Box(Modifier.padding(bottom = 20.dp)) }
            }
        }

        // Transport: one big play/pause, and the repeat indicator.
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(6.dp),
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(vertical = 12.dp)
        ) {
            if (celebrate) {
                Text(
                    stringResource(R.string.kids_well_done),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = NoorColor.accentGold)
            } else if (repeat > 1 && playingHere) {
                Text(
                    stringResource(
                        R.string.kids_repeat,
                        (NoorPlayer.memorizeDone + 1).coerceAtMost(repeat).localizedDigits(),
                        repeat.localizedDigits()),
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = NoorColor.accentPrimary)
            }
            val playing = playingHere && NoorPlayer.isPlaying
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(72.dp)
                    .clip(CircleShape)
                    .background(NoorColor.accentPrimary, CircleShape)
                    .clickable {
                        celebrate = false
                        if (playingHere) NoorPlayer.toggle() else startPlayback()
                    }
            ) {
                Icon(
                    painterResource(
                        if (playing) R.drawable.ic_pause_fill else R.drawable.ic_play_fill),
                    contentDescription = stringResource(
                        if (playing) R.string.kids_pause else R.string.kids_listen),
                    tint = NoorColor.bgPrimary,
                    modifier = Modifier.size(30.dp))
            }
        }
    }
}

@Composable
private fun LayoutChip(
    label: String,
    selected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(12.dp)
    Box(
        contentAlignment = Alignment.Center,
        modifier = modifier
            .clip(shape)
            .background(if (selected) NoorColor.accentPrimary else NoorColor.bgElevated, shape)
            .clickable(onClick = onClick)
            .padding(vertical = 12.dp)
    ) {
        Text(
            label,
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            color = if (selected) NoorColor.bgPrimary else NoorColor.inkPrimary)
    }
}
