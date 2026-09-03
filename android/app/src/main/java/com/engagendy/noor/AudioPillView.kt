package com.engagendy.noor

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay

/// Compact floating player pill — 1:1 with iOS AudioPillView (design 1c):
/// reciter (icon + name open the picker), ayah reference, previous/play/next,
/// playback-mode button, stop.
@Composable
fun AudioPillView() {
    if (NoorPlayer.currentSurah == 0) return
    var showReciterPicker by remember { mutableStateOf(false) }
    var showModePicker by remember { mutableStateOf(false) }
    if (showReciterPicker) ReciterPickerSheet(onDismiss = { showReciterPicker = false })
    if (showModePicker) PlaybackModeSheet(onDismiss = { showModePicker = false })

    // The pill lays out left-to-right even in the RTL app, exactly like
    // iOS (.environment(\.layoutDirection, .leftToRight) on AudioPillView):
    // media controls keep the universal ⏮ ▶ ⏭ order.
    androidx.compose.runtime.CompositionLocalProvider(
        androidx.compose.ui.platform.LocalLayoutDirection provides
            androidx.compose.ui.unit.LayoutDirection.Ltr
    ) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 6.dp)
            .clip(RoundedCornerShape(50))
            .background(NoorColor.bgElevated)
            .padding(horizontal = 14.dp, vertical = 10.dp)
    ) {
        // Icon AND name open the reciter picker, like iOS.
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier.weight(1f).clickable { showReciterPicker = true }
        ) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(38.dp)
                    .background(NoorColor.accentPrimary.copy(alpha = 0.15f), CircleShape)
            ) {
                Icon(painterResource(R.drawable.ic_mic), contentDescription = null,
                     tint = NoorColor.accentPrimary, modifier = Modifier.size(18.dp))
            }
            Column {
                Text(
                    NoorPlayer.reciter.localizedName,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = NoorColor.inkPrimary,
                    maxLines = 1
                )
                Text(
                    stringResource(
                        R.string.g2_ayah_ref,
                        NoorPlayer.surahName, NoorPlayer.currentAyah.localizedDigits()),
                    fontSize = 11.sp,
                    color = NoorColor.inkSecondary,
                    maxLines = 1
                )
            }
        }
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            PillIconButton(R.drawable.ic_prev_track, stringResource(R.string.g2_previous),
                           NoorColor.inkSecondary) { NoorPlayer.previous() }
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(NoorColor.accentPrimary, CircleShape)
                    .clickable { NoorPlayer.toggle() }
            ) {
                // White vector on the green circle — never an emoji glyph.
                // While the ayah downloads, the button spins instead so the
                // wait is visible.
                if (NoorPlayer.isBuffering) {
                    androidx.compose.material3.CircularProgressIndicator(
                        color = NoorColor.bgPrimary,
                        strokeWidth = 2.dp,
                        modifier = Modifier.size(18.dp))
                } else {
                    Icon(
                        painterResource(if (NoorPlayer.isPlaying) R.drawable.ic_pause_fill
                                        else R.drawable.ic_play_fill),
                        contentDescription = stringResource(
                            if (NoorPlayer.isPlaying) R.string.g2_pause else R.string.g2_play),
                        tint = NoorColor.bgPrimary,
                        modifier = Modifier.size(18.dp))
                }
            }
            PillIconButton(R.drawable.ic_next_track, stringResource(R.string.g2_next),
                           NoorColor.inkSecondary) { NoorPlayer.next() }
            PillIconButton(
                modeIcon(NoorPlayer.mode),
                stringResource(R.string.g2_playback_mode),
                if (NoorPlayer.mode == PlaybackMode.CONTINUOUS)
                    NoorColor.inkSecondary else NoorColor.accentPrimary
            ) { showModePicker = true }
            PillIconButton(R.drawable.ic_close, stringResource(R.string.g2_stop),
                           NoorColor.inkSecondary, glyphSize = 15.dp) { NoorPlayer.stop() }
        }
    }
    }
}

/// Pill control with a 38×44dp hit area around a small glyph — mirrors the
/// iOS AudioPillView button frames and keeps every control above the
/// minimum touch-target size even though the icon itself stays 16dp.
@Composable
private fun PillIconButton(
    icon: Int,
    contentDescription: String,
    tint: Color,
    glyphSize: Dp = 16.dp,
    onClick: () -> Unit
) {
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .size(width = 38.dp, height = 44.dp)
            .clip(RoundedCornerShape(50))
            .clickable(onClick = onClick)
    ) {
        Icon(painterResource(icon), contentDescription = contentDescription,
             tint = tint, modifier = Modifier.size(glyphSize))
    }
}

/// Drawable per playback mode — tinted vectors matching the iOS SF symbols
/// (repeat, repeat.1, doc.plaintext, brain ≈ book), never emoji.
private fun modeIcon(mode: PlaybackMode): Int = when (mode) {
    PlaybackMode.CONTINUOUS -> R.drawable.ic_repeat
    PlaybackMode.REPEAT_AYAH -> R.drawable.ic_repeat_one
    PlaybackMode.PAGE_ONLY -> R.drawable.ic_page
    PlaybackMode.MEMORIZE -> R.drawable.ic_book
}

/// Compact playback-mode sheet — 1:1 with the iOS PlaybackModeSheet:
/// modes with icon + checkmark, speed chips, sleep timer, memorize range.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PlaybackModeSheet(onDismiss: () -> Unit) {
    var showMemorize by remember { mutableStateOf(false) }
    if (showMemorize) MemorizeRangeSheet(onDismiss = { showMemorize = false })

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = NoorColor.bgPrimary) {
        Column(Modifier.padding(horizontal = 16.dp).padding(bottom = 24.dp)) {
            Text(
                stringResource(R.string.g2_playback_mode),
                fontSize = 17.sp,
                fontWeight = FontWeight.Bold,
                color = NoorColor.inkPrimary,
                modifier = Modifier.padding(bottom = 10.dp)
            )
            val options = listOf(
                // Symmetric vector icons: match modeIcon() and can't point
                // the wrong way under the app-wide RTL.
                Triple(PlaybackMode.CONTINUOUS,
                       stringResource(R.string.g2_mode_continuous), R.drawable.ic_repeat),
                Triple(PlaybackMode.REPEAT_AYAH,
                       stringResource(R.string.g2_mode_repeat_ayah), R.drawable.ic_repeat_one),
                Triple(PlaybackMode.PAGE_ONLY,
                       stringResource(R.string.g2_mode_page_only), R.drawable.ic_page),
            )
            options.forEach { (mode, label, icon) ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { NoorPlayer.selectMode(mode); onDismiss() }
                        .padding(vertical = 12.dp)
                ) {
                    Icon(painterResource(icon), contentDescription = null,
                         tint = NoorColor.accentPrimary, modifier = Modifier.size(18.dp))
                    Text(
                        label,
                        fontSize = 16.sp,
                        fontWeight = if (NoorPlayer.mode == mode) FontWeight.SemiBold
                                     else FontWeight.Normal,
                        color = NoorColor.inkPrimary,
                        modifier = Modifier.weight(1f)
                    )
                    if (NoorPlayer.mode == mode) {
                        Icon(painterResource(R.drawable.ic_check), contentDescription = null,
                             tint = NoorColor.accentPrimary, modifier = Modifier.size(15.dp))
                    }
                }
                HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
            }

            // Playback speed — same chips as iOS (0.75×…2×).
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.padding(top = 14.dp).horizontalScroll(rememberScrollState())
            ) {
                Icon(painterResource(R.drawable.ic_clock), contentDescription = null,
                     tint = NoorColor.inkSecondary, modifier = Modifier.size(16.dp))
                PlaybackSpeeds.forEach { value ->
                    SheetChip(
                        label = if (value == value.toLong().toFloat()) "${value.toInt()}×"
                                else "$value×",
                        selected = NoorPlayer.speed == value,
                        onClick = { NoorPlayer.selectSpeed(value) })
                }
            }

            // Sleep timer — 15/30/60 + end-of-surah + live countdown chip.
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.padding(top = 12.dp).horizontalScroll(rememberScrollState())
            ) {
                Icon(painterResource(R.drawable.ic_moon), contentDescription = null,
                     tint = NoorColor.inkSecondary, modifier = Modifier.size(16.dp))
                listOf(15, 30, 60).forEach { minutes ->
                    SheetChip(
                        label = minutes.localizedDigits(),
                        selected = false,
                        onClick = { NoorPlayer.setSleepTimer(minutes) })
                }
                SheetChip(
                    label = stringResource(R.string.g2_end_of_surah),
                    selected = NoorPlayer.stopAfterSurah,
                    onClick = { NoorPlayer.stopAfterSurah = !NoorPlayer.stopAfterSurah })
                if (NoorPlayer.sleepDeadline != 0L) {
                    SleepCountdownChip()
                }
            }

            // حفظ مقطع — opens the range sheet (iOS "Memorize a range").
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 16.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(NoorColor.accentPrimary.copy(alpha = 0.1f))
                    .clickable { showMemorize = true }
                    .padding(14.dp)
            ) {
                Icon(painterResource(R.drawable.ic_book), contentDescription = null,
                     tint = NoorColor.accentPrimary, modifier = Modifier.size(18.dp))
                Text(
                    stringResource(R.string.g2_memorize_range),
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = NoorColor.accentPrimary,
                    modifier = Modifier.weight(1f)
                )
                if (NoorPlayer.mode == PlaybackMode.MEMORIZE) {
                    Icon(painterResource(R.drawable.ic_check), contentDescription = null,
                         tint = NoorColor.accentPrimary, modifier = Modifier.size(15.dp))
                }
            }
        }
    }
}

/// Ticking mm:ss until the sleep deadline, with an ✕ to cancel — gold, like iOS.
@Composable
private fun SleepCountdownChip() {
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        while (true) { now = System.currentTimeMillis(); delay(1_000) }
    }
    val remaining = ((NoorPlayer.sleepDeadline - now) / 1_000).coerceAtLeast(0)
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp),
        modifier = Modifier.clip(RoundedCornerShape(50)).clickable { NoorPlayer.setSleepTimer(null) }.padding(4.dp)
    ) {
        Text(
            "%d:%02d".format(java.util.Locale.ROOT, remaining / 60, remaining % 60),
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
            color = NoorColor.accentGold
        )
        Icon(painterResource(R.drawable.ic_close), contentDescription = stringResource(R.string.g2_cancel),
             tint = NoorColor.accentGold, modifier = Modifier.size(13.dp))
    }
}

/// Configure the memorize loop: ayah range + repeats per ayah (iOS
/// MemorizeRangeSheet), with − value + steppers.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MemorizeRangeSheet(onDismiss: () -> Unit) {
    val ayahCount = maxOf(1, NoorPlayer.currentAyahCount)
    var start by remember {
        mutableStateOf(if (NoorPlayer.currentAyah > 0) NoorPlayer.currentAyah
                       else NoorPlayer.memorizeStart)
    }
    var end by remember {
        mutableStateOf(
            if (NoorPlayer.currentAyah > 0) minOf(NoorPlayer.currentAyah + 4, ayahCount)
            else minOf(maxOf(NoorPlayer.memorizeEnd, NoorPlayer.memorizeStart), ayahCount))
    }
    var perAyah by remember { mutableStateOf(NoorPlayer.memorizePerAyah) }
    if (end < start) end = start

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = NoorColor.bgPrimary) {
        Column(Modifier.padding(horizontal = 16.dp).padding(bottom = 24.dp)) {
            Text(
                stringResource(R.string.g2_memorize_range),
                fontSize = 17.sp,
                fontWeight = FontWeight.Bold,
                color = NoorColor.inkPrimary,
                modifier = Modifier.padding(bottom = 6.dp)
            )
            StepperRow(stringResource(R.string.g2_from_ayah), start.localizedDigits(),
                       onMinus = { if (start > 1) { start -= 1; if (end < start) end = start } },
                       onPlus = { if (start < ayahCount) { start += 1; if (end < start) end = start } })
            StepperRow(stringResource(R.string.g2_to_ayah), end.localizedDigits(),
                       onMinus = { if (end > start) end -= 1 },
                       onPlus = { if (end < ayahCount) end += 1 })
            StepperRow(stringResource(R.string.g2_repeat_each_ayah), "×${perAyah.localizedDigits()}",
                       onMinus = { if (perAyah > 1) perAyah -= 1 },
                       onPlus = { if (perAyah < 20) perAyah += 1 })
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 14.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(NoorColor.accentPrimary)
                    .clickable {
                        NoorPlayer.startMemorize(start, end, perAyah)
                        onDismiss()
                    }
                    .padding(vertical = 14.dp)
            ) {
                Text(
                    stringResource(R.string.g2_start_memorizing),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = NoorColor.bgPrimary
                )
            }
        }
    }
}

@Composable
private fun StepperRow(label: String, value: String, onMinus: () -> Unit, onPlus: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp)
    ) {
        Text(label, fontSize = 15.sp, color = NoorColor.inkPrimary, modifier = Modifier.weight(1f))
        StepperButton("−", onMinus)
        Text(
            value,
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            color = NoorColor.accentPrimary,
            modifier = Modifier.padding(horizontal = 14.dp)
        )
        StepperButton("+", onPlus)
    }
}

@Composable
private fun StepperButton(symbol: String, onClick: () -> Unit) {
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .size(34.dp)
            .clip(CircleShape)
            .background(NoorColor.bgElevated)
            .clickable(onClick = onClick)
    ) {
        Text(symbol, fontSize = 18.sp, color = NoorColor.accentPrimary)
    }
}

@Composable
private fun SheetChip(label: String, selected: Boolean, onClick: () -> Unit) {
    Text(
        label,
        fontSize = 13.sp,
        fontWeight = FontWeight.SemiBold,
        color = if (selected) NoorColor.bgPrimary else NoorColor.inkPrimary,
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(if (selected) NoorColor.accentPrimary else NoorColor.bgElevated)
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 6.dp)
    )
}
