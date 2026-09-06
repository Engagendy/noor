package com.engagendy.noor

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/// Reader side drawer: the full surah index, reachable without leaving the
/// reader. Slides in from the START edge (right in the Arabic UI, left in
/// English) over a scrim, opens scrolled to the surah being read, and
/// carries the explicit way out of the reader ("الرجوع إلى القرآن") — the
/// reader chrome's back button is now the list button, so this row and
/// system back are the exits.
///
/// Drop it as the LAST child of a full-size Box so it paints above the
/// reader. It renders nothing (and costs nothing) while `visible` is false
/// except the two AnimatedVisibility wrappers.
@Composable
fun SurahDrawer(
    visible: Boolean,
    surahs: List<Surah>,
    currentSurahId: Int,
    onPick: (Surah) -> Unit,
    onClose: () -> Unit,
    onExitReader: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // The panel hugs the start edge; the slide must travel towards that same
    // edge, so its sign follows the UI direction (never hard-coded).
    val startEdgeSign = if (LocalLayoutDirection.current == LayoutDirection.Rtl) 1 else -1
    val listState = rememberLazyListState()
    var query by remember { mutableStateOf("") }
    // Every opening starts fresh, scrolled to the surah in view (a couple of
    // rows above it, so its neighbours give context).
    LaunchedEffect(visible, currentSurahId) {
        if (!visible) return@LaunchedEffect
        query = ""
        listState.scrollToItem((currentSurahId - 3).coerceAtLeast(0))
    }
    val trimmed = query.trim()
    val filtered = remember(trimmed, surahs) {
        if (trimmed.isEmpty()) surahs
        else surahs.filter {
            it.nameArabic.contains(trimmed) ||
                it.nameTransliterated.contains(trimmed, ignoreCase = true) ||
                it.id.toString() == trimmed
        }
    }

    Box(modifier.fillMaxSize()) {
        AnimatedVisibility(visible, enter = fadeIn(), exit = fadeOut()) {
            Box(
                Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.45f))
                    .pointerInput(Unit) { detectTapGestures { onClose() } }
            )
        }
        AnimatedVisibility(
            visible,
            modifier = Modifier.align(Alignment.CenterStart),
            enter = slideInHorizontally { it * startEdgeSign },
            exit = slideOutHorizontally { it * startEdgeSign },
        ) {
            Surface(
                color = NoorColor.bgPrimary,
                shadowElevation = 12.dp,
                modifier = Modifier.fillMaxHeight().width(300.dp)
            ) {
                Column(Modifier.fillMaxHeight()) {
                    // Explicit exit — discoverable without the system gesture.
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onExitReader() }
                            .padding(horizontal = 16.dp, vertical = 14.dp)
                    ) {
                        Icon(
                            painterResource(NoorIcons.chevronBackward()),
                            contentDescription = null,
                            tint = NoorColor.accentPrimary,
                            modifier = Modifier.size(16.dp))
                        Text(
                            stringResource(R.string.g2_back_to_quran),
                            fontSize = 15.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = NoorColor.accentPrimary,
                            modifier = Modifier.padding(horizontal = 10.dp))
                    }
                    HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.08f))
                    // Same custom search field as the Quran index header.
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 12.dp, vertical = 10.dp)
                            .height(38.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(NoorColor.bgElevated)
                            .border(1.dp, NoorColor.inkPrimary.copy(alpha = 0.08f),
                                    RoundedCornerShape(12.dp))
                            .padding(horizontal = 12.dp),
                        contentAlignment = Alignment.CenterStart
                    ) {
                        if (query.isEmpty()) {
                            Text(
                                stringResource(R.string.g2_search_quran_hint),
                                fontSize = 14.sp,
                                color = NoorColor.inkSecondary.copy(alpha = 0.8f))
                        }
                        BasicTextField(
                            value = query,
                            onValueChange = { query = it },
                            singleLine = true,
                            textStyle = TextStyle(fontSize = 14.sp, color = NoorColor.inkPrimary,
                                                  fontFamily = NoorFont.family),
                            modifier = Modifier.fillMaxWidth())
                    }
                    LazyColumn(state = listState, modifier = Modifier.fillMaxSize()) {
                        items(filtered, key = { it.id }) { surah ->
                            val active = surah.id == currentSurahId
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable { onPick(surah) }
                                    .background(
                                        if (active) NoorColor.accentPrimary.copy(alpha = 0.12f)
                                        else Color.Transparent)
                                    .padding(horizontal = 14.dp, vertical = 10.dp)
                            ) {
                                Box(
                                    contentAlignment = Alignment.Center,
                                    modifier = Modifier
                                        .size(32.dp)
                                        .border(1.dp, NoorColor.accentGold, CircleShape)
                                ) {
                                    Text(surah.id.localizedDigits(), fontSize = 12.sp,
                                         color = NoorColor.accentGold)
                                }
                                Column(Modifier.padding(horizontal = 12.dp).weight(1f)) {
                                    Text(
                                        surah.nameArabic,
                                        fontFamily = HafsFont,
                                        fontSize = 18.sp,
                                        fontWeight = if (active) FontWeight.Bold else FontWeight.Normal,
                                        color = if (active) NoorColor.accentPrimary
                                                else NoorColor.inkPrimary,
                                        style = arabicText())
                                    Text(
                                        stringResource(
                                            R.string.g2_surah_meta,
                                            surah.ayahCount.localizedDigits(),
                                            stringResource(
                                                if (surah.revelation == "Meccan") R.string.g2_makki
                                                else R.string.g2_madani)),
                                        fontSize = 11.sp,
                                        color = NoorColor.inkSecondary)
                                }
                            }
                            HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.05f))
                        }
                    }
                }
            }
        }
    }
}

/// The reader chrome's list button (replaces the old back chevron): opens
/// the surah drawer. A bare glyph on the page background — no filled chip —
/// with a 48dp target and a circular, clipped ripple for press feedback.
@Composable
fun SurahListButton(size: Int = 48, onClick: () -> Unit) {
    val label = stringResource(R.string.g2_surah_list)
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .size(size.dp)
            .clip(CircleShape)
            .clickable(onClick = onClick)
            .semantics { contentDescription = label }
    ) {
        Icon(
            painterResource(R.drawable.ic_list),
            contentDescription = null,
            tint = NoorColor.accentPrimary,
            modifier = Modifier.size(22.dp))
    }
}
