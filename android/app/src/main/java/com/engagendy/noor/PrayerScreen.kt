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

