package com.engagendy.noor

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

@Composable
fun PrayerScreen(modifier: Modifier = Modifier) {
    var city by remember { mutableStateOf(Cities.all[0]) }
    val entries = remember(city) { PrayerEngine.today(city) }
    val next = PrayerEngine.next(entries)
    val formatter = remember(city) {
        SimpleDateFormat("h:mm a", Locale("ar")).apply {
            timeZone = TimeZone.getTimeZone(city.timeZone)
        }
    }

    Column(modifier.fillMaxSize().padding(20.dp)) {
        Text("الصلاة", fontSize = 28.sp, fontWeight = FontWeight.Bold, color = NoorColor.inkPrimary)
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.padding(vertical = 12.dp)
        ) {
            items(Cities.all) { preset ->
                val on = preset.name == city.name
                Text(
                    preset.nameArabic,
                    fontSize = 13.sp,
                    color = if (on) NoorColor.bgPrimary else NoorColor.inkPrimary,
                    modifier = Modifier
                        .background(
                            if (on) NoorColor.accentPrimary else NoorColor.bgElevated,
                            RoundedCornerShape(50)
                        )
                        .clickable { city = preset }
                        .padding(horizontal = 14.dp, vertical = 8.dp)
                )
            }
        }
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
    }
}

@Composable
fun TodayScreen(modifier: Modifier = Modifier, openQuran: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val city = Cities.all[0]
    val entries = remember { PrayerEngine.today(city) }
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

        // Daily ayah — same deterministic pick as iOS, from the verified DB.
        val daily = remember {
            val db = QuranDb.get(context)
            val calendar = java.util.Calendar.getInstance()
            val day = calendar.get(java.util.Calendar.DAY_OF_YEAR)
            val year = calendar.get(java.util.Calendar.YEAR)
            val total = db.verseCount().coerceAtLeast(1)
            db.verseAt((day * 271 + year) % total)
        }
        if (daily != null) {
            val (verse, surahName) = daily
            val reference = "سورة $surahName · ${verse.surahId.arabicIndic()}:${verse.ayah.arabicIndic()}"
            Column(
                Modifier
                    .padding(top = 12.dp)
                    .fillMaxWidth()
                    .background(NoorColor.bgElevated, RoundedCornerShape(18.dp))
                    .padding(18.dp)
            ) {
                Row(
                    horizontalArrangement = Arrangement.SpaceBetween,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("آية اليوم", fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                         color = NoorColor.inkSecondary)
                    Text("مشاركة", fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                         color = NoorColor.accentPrimary,
                         modifier = Modifier
                             .clickable {
                                 scope.launch {
                                     val bitmap = withContext(Dispatchers.IO) {
                                         ShareCard.render(
                                             context, verse.text, reference,
                                             attribution = "نور Noor · Quran text: Tanzil.net",
                                             useQuranFont = true)
                                     }
                                     ShareCard.share(context, bitmap)
                                 }
                             }
                             .padding(4.dp))
                }
                Text(verse.text, fontFamily = QuranFont, fontSize = 21.sp, lineHeight = 44.sp,
                     color = NoorColor.inkPrimary, modifier = Modifier.padding(top = 6.dp))
                Text(reference, fontSize = 12.sp, color = NoorColor.inkSecondary,
                     modifier = Modifier.padding(top = 6.dp))
            }
        }
    }
}
