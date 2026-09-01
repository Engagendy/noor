package com.engagendy.noor

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

@Composable
fun PrayerScreen(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val prefs = remember { PrayerPrefs(context) }
    var showSettings by remember { mutableStateOf(false) }
    // Bumped when the settings screen closes so times reflect new prefs.
    var version by remember { mutableIntStateOf(0) }

    if (showSettings) {
        PrayerSettingsScreen(modifier, onDone = {
            showSettings = false
            version++
        })
        return
    }

    val city = remember(version) { prefs.city }
    val method = remember(version) { prefs.method }
    val madhab = remember(version) { prefs.madhab }
    val entries = remember(version) { PrayerEngine.today(prefs) }
    val next = PrayerEngine.next(entries)
    val formatter = remember(city) {
        SimpleDateFormat("h:mm a", Locale("ar")).apply {
            timeZone = TimeZone.getTimeZone(city.timeZone)
        }
    }

    Column(modifier.fillMaxSize().padding(20.dp)) {
        Row(
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth()
        ) {
            Column {
                Text("الصلاة", fontSize = 28.sp, fontWeight = FontWeight.Bold,
                     color = NoorColor.inkPrimary)
                Text(city.nameArabic, fontSize = 13.sp, color = NoorColor.inkSecondary)
            }
            Icon(
                painterResource(R.drawable.ic_gear),
                contentDescription = "إعدادات الصلاة",
                tint = NoorColor.accentPrimary,
                modifier = Modifier
                    .clickable { showSettings = true }
                    .padding(10.dp)
            )
        }
        androidx.compose.foundation.layout.Spacer(Modifier.padding(top = 8.dp))
        entries.forEach { entry ->
            val isNext = entry === next
            Row(
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 4.dp)
                    .background(
                        if (isNext) NoorColor.stateReciting else NoorColor.bgElevated,
                        RoundedCornerShape(14.dp)
                    )
                    .padding(horizontal = 18.dp, vertical = 16.dp)
            ) {
                Text(
                    entry.nameArabic,
                    fontSize = 17.sp,
                    fontWeight = if (isNext) FontWeight.Bold else FontWeight.Normal,
                    color = if (isNext) NoorColor.accentPrimary else NoorColor.inkPrimary
                )
                Text(
                    formatter.format(entry.time),
                    fontSize = 17.sp,
                    color = if (isNext) NoorColor.accentPrimary else NoorColor.inkSecondary
                )
            }
        }
        // Settings summary row like iOS (method · madhab).
        Text(
            "${method.nameArabic} · ${madhab.nameArabic}",
            fontSize = 12.sp,
            color = NoorColor.inkSecondary,
            modifier = Modifier
                .padding(top = 10.dp)
                .clickable { showSettings = true }
                .padding(6.dp)
        )
    }
}

@Composable
fun TodayScreen(modifier: Modifier = Modifier, openQuran: () -> Unit) {
    val context = LocalContext.current
    val prefs = remember { PrayerPrefs(context) }
    val city = remember { prefs.city }
    val entries = remember { PrayerEngine.today(prefs) }
    val next = PrayerEngine.next(entries)
    val formatter = remember {
        SimpleDateFormat("h:mm a", Locale("ar")).apply {
            timeZone = TimeZone.getTimeZone(city.timeZone)
        }
    }

    Column(modifier.fillMaxSize().padding(20.dp)) {
        Text("السلام عليكم", fontSize = 28.sp, fontWeight = FontWeight.Bold, color = NoorColor.inkPrimary)
        Column(
            Modifier
                .padding(top = 14.dp)
                .fillMaxWidth()
                .background(NoorColor.accentPrimary, RoundedCornerShape(18.dp))
                .padding(20.dp)
        ) {
            Text(
                next?.nameArabic ?: "انقضت صلوات اليوم",
                fontSize = 14.sp,
                color = NoorColor.bgPrimary.copy(alpha = 0.85f)
            )
            Text(
                next?.let { formatter.format(it.time) } ?: "",
                fontSize = 30.sp,
                fontWeight = FontWeight.Bold,
                color = NoorColor.bgPrimary
            )
        }
        Row(
            horizontalArrangement = Arrangement.SpaceBetween,
            modifier = Modifier
                .padding(top = 12.dp)
                .fillMaxWidth()
                .background(NoorColor.bgElevated, RoundedCornerShape(18.dp))
                .clickable(onClick = openQuran)
                .padding(18.dp)
        ) {
            Text("متابعة القراءة", fontSize = 16.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.inkPrimary)
            Text("←", color = NoorColor.accentPrimary)
        }
    }
}
