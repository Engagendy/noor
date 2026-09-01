package com.engagendy.noor

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.layout.Box

/// Floating player pill — reciter, ayah, transport — like iOS.
@Composable
fun PlayerBar() {
    if (NoorPlayer.currentSurah == 0) return
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 6.dp)
            .clip(RoundedCornerShape(50))
            .background(NoorColor.bgElevated)
            .padding(horizontal = 16.dp, vertical = 10.dp)
    ) {
        Column(Modifier.weight(1f)) {
            Text(NoorPlayer.reciter.nameArabic, fontSize = 13.sp,
                 fontWeight = FontWeight.SemiBold, color = NoorColor.inkPrimary)
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
}
