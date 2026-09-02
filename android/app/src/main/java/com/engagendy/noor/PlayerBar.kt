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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/// Floating player pill — reciter, ayah, transport, speed, repeat — like iOS.
/// Tapping the reciter name opens the full 31-voice picker sheet.
@Composable
fun PlayerBar() {
    if (NoorPlayer.currentSurah == 0) return
    var showPicker by remember { mutableStateOf(false) }
    if (showPicker) ReciterPickerSheet(onDismiss = { showPicker = false })

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 6.dp)
            .clip(RoundedCornerShape(22.dp))
            .background(NoorColor.bgElevated)
            .padding(horizontal = 16.dp, vertical = 10.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f).clickable { showPicker = true }) {
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalAlignment = Alignment.CenterVertically) {
                    Text(NoorPlayer.reciter.nameArabic, fontSize = 13.sp,
                         fontWeight = FontWeight.SemiBold, color = NoorColor.inkPrimary)
                    Text("⌄", fontSize = 11.sp, color = NoorColor.accentPrimary)
                }
                Text("${NoorPlayer.surahName} · آية ${NoorPlayer.currentAyah.arabicIndic()}",
                     fontSize = 11.sp, color = NoorColor.inkSecondary)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(18.dp),
                verticalAlignment = Alignment.CenterVertically) {
                Text("⏮", modifier = Modifier.clickable { NoorPlayer.previous() })
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .size(40.dp)
                        .background(NoorColor.accentPrimary, CircleShape)
                        .clickable { NoorPlayer.toggle() }
                ) {
                    Text(if (NoorPlayer.isPlaying) "⏸" else "▶",
                         color = NoorColor.bgPrimary, fontSize = 16.sp)
                }
                Text("⏭", modifier = Modifier.clickable { NoorPlayer.next() })
                Text("✕", color = NoorColor.inkSecondary,
                     modifier = Modifier.clickable { NoorPlayer.stop() })
            }
        }
        // Second row: repeat mode + speed chips, mirroring the iOS controls.
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.padding(top = 8.dp)
        ) {
            val repeating = NoorPlayer.mode == PlaybackMode.REPEAT_AYAH
            Chip(
                label = if (repeating) "🔂 تكرار الآية" else "🔁 متواصل",
                selected = repeating,
                onClick = { NoorPlayer.toggleMode() },
            )
            PlaybackSpeeds.forEach { value ->
                Chip(
                    label = if (value == value.toLong().toFloat())
                        "×${value.toInt().arabicIndic()}" else "×$value",
                    selected = NoorPlayer.speed == value,
                    onClick = { NoorPlayer.selectSpeed(value) },
                )
            }
        }
    }
}

@Composable
private fun Chip(label: String, selected: Boolean, onClick: () -> Unit) {
    Text(
        label,
        fontSize = 11.sp,
        fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
        color = if (selected) NoorColor.bgPrimary else NoorColor.inkSecondary,
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(if (selected) NoorColor.accentPrimary else NoorColor.bgPrimary)
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 5.dp)
    )
}
