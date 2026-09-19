package com.engagendy.noor

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/// Ayah tap target — port of the iOS AyahActionsSheet: the ayah framed in
/// gold, then big (56dp) action rows: play from here, tafsir, share, share
/// as video (captioned with the current reciter), copy, bookmark. All side effects run in the row click handlers.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AyahActionsSheet(
    verse: Verse,
    isBookmarked: Boolean,
    /// Ayat available from this one to the end of the surah, capped
    /// (`AyahShareRun.available`). 1 hides the range stepper.
    availableAyat: Int = 1,
    onPlay: () -> Unit,
    onTafsir: () -> Unit,
    /// Share / copy the run starting here: the count the user chose.
    onShare: (Int) -> Unit,
    onShareVideo: (Int) -> Unit,
    onCopy: (Int) -> Unit,
    onToggleBookmark: () -> Unit,
    onDismiss: () -> Unit,
) {
    // Reset per ayah: a new long-press is a new selection.
    var count by remember(verse.surahId, verse.ayah) { mutableIntStateOf(1) }
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = NoorColor.bgPrimary) {
      // A ModalBottomSheet renders in its OWN window, which re-provides
      // LocalContext/LocalConfiguration from the Activity — so the app's
      // in-process language (NoorLocaleProvider, applied around the app's
      // content) does NOT reach here and every string fell back to the
      // Arabic default resources while the UI was in English.
      NoorLocaleProvider {
        Column(
            verticalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .padding(bottom = 32.dp)
        ) {
            // The ayah, straight from the verified DB, in the gold frame.
            Text(
                verse.text,
                fontFamily = QuranFont,
                fontSize = 19.sp,
                lineHeight = 40.sp,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis,
                color = NoorColor.inkPrimary,
                style = arabicText(),
                modifier = Modifier
                    .fillMaxWidth()
                    .border(1.dp, NoorColor.accentGold.copy(alpha = 0.5f), RoundedCornerShape(10.dp))
                    .padding(14.dp)
            )
            ActionRow(stringResource(R.string.g2_listen_from_here), icon = R.drawable.ic_play, prominent = true) {
                onDismiss(); onPlay()
            }
            ActionRow(stringResource(R.string.g2_tafsir), icon = R.drawable.ic_book) { onDismiss(); onTafsir() }
            if (availableAyat > 1) {
                AyatRangePicker(count, availableAyat) { count = it }
            }
            ActionRow(stringResource(R.string.g2_share), icon = R.drawable.ic_share) { onDismiss(); onShare(count) }
            ActionRow(
                stringResource(R.string.feat_share_video),
                icon = R.drawable.ic_share,
                caption = stringResource(R.string.feat_share_video_caption, NoorPlayer.reciter.localizedName),
            ) { onDismiss(); onShareVideo(count) }
            ActionRow(stringResource(R.string.g2_copy), glyph = "⧉") { onDismiss(); onCopy(count) }
            ActionRow(
                stringResource(
                    if (isBookmarked) R.string.g2_bookmarked else R.string.g2_bookmark),
                glyph = if (isBookmarked) "★" else "☆",
                gold = isBookmarked,
                onClick = onToggleBookmark)
        }
      }
    }
}

/// How many ayat the share / video / copy rows below should carry. Centred
/// and intrinsically sized, matching the iOS sheet's stepper.
@Composable
private fun AyatRangePicker(count: Int, available: Int, onChange: (Int) -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.fillMaxWidth().padding(top = 4.dp)
    ) {
        Text(
            stringResource(R.string.feat_share_ayat_count),
            fontSize = 13.sp,
            color = NoorColor.inkSecondary)
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            StepButton("−", enabled = count > 1) { onChange(count - 1) }
            Text(
                count.localizedDigits(),
                fontSize = 19.sp,
                fontWeight = FontWeight.SemiBold,
                color = NoorColor.inkPrimary,
                modifier = Modifier.widthIn(min = 46.dp),
                textAlign = TextAlign.Center)
            StepButton("+", enabled = count < available) { onChange(count + 1) }
        }
    }
}

@Composable
private fun StepButton(glyph: String, enabled: Boolean, onClick: () -> Unit) {
    Box(
        contentAlignment = Alignment.Center,
        // Clip BEFORE clickable so the ripple stays inside the circle.
        modifier = Modifier
            .size(44.dp)
            .clip(CircleShape)
            .background(NoorColor.bgElevated)
            .clickable(enabled = enabled, onClick = onClick)
    ) {
        Text(
            glyph,
            fontSize = 18.sp,
            fontWeight = FontWeight.SemiBold,
            color = if (enabled) NoorColor.accentPrimary
                    else NoorColor.inkSecondary.copy(alpha = 0.4f))
    }
}

/// Shared row style for the action sheets (ayah actions, dhikr share).
@Composable
internal fun ActionRow(
    title: String,
    icon: Int? = null,
    glyph: String? = null,
    prominent: Boolean = false,
    gold: Boolean = false,
    caption: String? = null,
    onClick: () -> Unit,
) {
    val tint = when {
        prominent -> NoorColor.bgPrimary
        gold -> NoorColor.accentGold
        else -> NoorColor.accentPrimary
    }
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(if (prominent) NoorColor.accentPrimary else NoorColor.bgElevated)
            .border(
                1.dp,
                if (prominent) Color.Transparent else NoorColor.inkPrimary.copy(alpha = 0.07f),
                RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 18.dp)
    ) {
        Box(contentAlignment = Alignment.Center, modifier = Modifier.size(30.dp)) {
            if (icon != null) {
                Icon(painterResource(icon), contentDescription = null, tint = tint,
                     modifier = Modifier.size(20.dp))
            } else {
                Text(glyph ?: "", fontSize = 19.sp, color = tint)
            }
        }
        Column(modifier = Modifier.padding(start = 14.dp)) {
            Text(
                title,
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                color = tint,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (caption != null) {
                Text(
                    caption,
                    fontSize = 12.sp,
                    color = NoorColor.inkSecondary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}
