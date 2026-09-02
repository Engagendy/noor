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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/// Ayah tap target — port of the iOS AyahActionsSheet: the ayah framed in
/// gold, then big (56dp) action rows: play from here, tafsir, share, copy,
/// bookmark. All side effects run in the row click handlers.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AyahActionsSheet(
    verse: Verse,
    isBookmarked: Boolean,
    onPlay: () -> Unit,
    onTafsir: () -> Unit,
    onShare: () -> Unit,
    onCopy: () -> Unit,
    onToggleBookmark: () -> Unit,
    onDismiss: () -> Unit,
) {
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = NoorColor.bgPrimary) {
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
                modifier = Modifier
                    .fillMaxWidth()
                    .border(1.dp, NoorColor.accentGold.copy(alpha = 0.5f), RoundedCornerShape(10.dp))
                    .padding(14.dp)
            )
            ActionRow("الاستماع من هنا", icon = R.drawable.ic_play, prominent = true) {
                onDismiss(); onPlay()
            }
            ActionRow("التفسير", icon = R.drawable.ic_book) { onDismiss(); onTafsir() }
            ActionRow("مشاركة", icon = R.drawable.ic_share) { onDismiss(); onShare() }
            ActionRow("نسخ", glyph = "⧉") { onDismiss(); onCopy() }
            ActionRow(
                if (isBookmarked) "محفوظة في الإشارات" else "إشارة مرجعية",
                glyph = if (isBookmarked) "★" else "☆",
                gold = isBookmarked,
                onClick = onToggleBookmark)
        }
    }
}

@Composable
private fun ActionRow(
    title: String,
    icon: Int? = null,
    glyph: String? = null,
    prominent: Boolean = false,
    gold: Boolean = false,
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
        Text(
            title,
            fontSize = 17.sp,
            fontWeight = FontWeight.SemiBold,
            color = tint,
            modifier = Modifier.padding(start = 14.dp)
        )
    }
}
