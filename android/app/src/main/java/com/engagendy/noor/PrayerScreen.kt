package com.engagendy.noor

import android.content.Context
import android.media.MediaPlayer
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
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
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/// Prayer Times — 1:1 with the iOS PrayerTimesView (design 1f): city line,
/// 7-day week strip, vertical timeline with the next prayer enlarged
/// (countdown + sound chips + bell toggles), then the adhan-sound, nawafil,
/// and calculation-settings rows. Updates minute-level, calmly.
@Composable
fun PrayerScreen(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val prefs = remember { PrayerPrefs(context) }
    // Bumped after every prefs write (inside click handlers only) so the UI
    // re-reads stored values; prefs themselves are never observed.
    var version by remember { mutableIntStateOf(0) }
    fun changed() {
        version++
        AdhanScheduler.reschedule(context)
    }

    var dayOffset by remember { mutableIntStateOf(0) }
    var showSettings by remember { mutableStateOf(false) }
    var showNawafil by remember { mutableStateOf(false) }
    var showSounds by remember { mutableStateOf(false) }
    var showQibla by remember { mutableStateOf(false) }

    // Minute-level clock, like the iOS TimelineView(.everyMinute).
    var nowMillis by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        while (true) {
            nowMillis = System.currentTimeMillis()
            kotlinx.coroutines.delay(60_000L - nowMillis % 60_000L + 250)
        }
    }
    DisposableEffect(Unit) { onDispose { AdhanPreview.stop() } }

    if (showQibla) {
        QiblaScreen(onClose = { showQibla = false })
        return
    }
    if (showSettings) {
        PrayerSettingsScreen(modifier, onDone = { version++; showSettings = false })
        return
    }

    val city = remember(version) { prefs.location }
    val useCustomLocation = remember(version) { prefs.useCustomLocation }
    val sound = remember(version) { prefs.sound }
    val method = remember(version) { prefs.method }
    val madhab = remember(version) { prefs.madhab }
    val now = Date(nowMillis)
    val shownDate = remember(nowMillis / 60_000, dayOffset) {
        Calendar.getInstance().apply { time = now; add(Calendar.DAY_OF_YEAR, dayOffset) }.time
    }
    val entries = remember(version, nowMillis / 60_000, dayOffset) {
        PrayerEngine.today(prefs, shownDate)
    }
    val isToday = dayOffset == 0
    val next = if (isToday) PrayerEngine.next(entries, now) else null
    val zone = remember(version) { TimeZone.getTimeZone(city.timeZone) }
    val timeFormatter = remember(version) {
        SimpleDateFormat("h:mm a", Locale("ar")).apply { timeZone = zone }
    }

    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        Column(Modifier.padding(horizontal = 20.dp, vertical = 8.dp)) {
            // Title + qibla entry.
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("مواقيت الصلاة", fontSize = 28.sp, fontWeight = FontWeight.Bold,
                     color = NoorColor.inkPrimary)
                Icon(painterResource(R.drawable.ic_compass), contentDescription = "القبلة",
                     tint = NoorColor.accentPrimary,
                     modifier = Modifier
                         .size(44.dp)
                         .clickable { showQibla = true }
                         .padding(10.dp))
            }
            Spacer(Modifier.height(4.dp))

            // City line.
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(painterResource(R.drawable.ic_pin), contentDescription = null,
                     tint = NoorColor.inkSecondary, modifier = Modifier.size(14.dp))
                Spacer(Modifier.width(6.dp))
                Text(
                    if (useCustomLocation) "قرب ${city.nameArabic}" else city.nameArabic,
                    fontSize = 13.sp, color = NoorColor.inkSecondary)
            }
            Spacer(Modifier.height(14.dp))

            WeekStrip(now = now, dayOffset = dayOffset, onSelect = { dayOffset = it })
            Spacer(Modifier.height(14.dp))

            // Vertical timeline: next prayer enlarged in a highlighted card.
            entries.forEach { entry ->
                val bellOn = remember(version) { prefs.notificationEnabled(entry.key) }
                val toggleBell = {
                    prefs.setNotificationEnabled(entry.key, !bellOn)
                    changed()
                }
                if (entry === next) {
                    NextPrayerCard(
                        entry = entry, now = now,
                        timeString = timeFormatter.format(entry.time),
                        bellOn = bellOn, onBell = toggleBell,
                        sound = sound,
                        onSound = { chosen ->
                            prefs.sound = chosen
                            changed()
                            AdhanPreview.play(context, chosen)
                        })
                } else {
                    val passed = isToday && !entry.time.after(now)
                    TimelineRow(
                        entry = entry, passed = passed,
                        timeString = timeFormatter.format(entry.time),
                        bellOn = bellOn, onBell = toggleBell)
                }
            }
            Spacer(Modifier.height(16.dp))

            // Adhan sound row — always-visible entry to the sound picker.
            CardRow(
                icon = R.drawable.ic_speaker, tint = NoorColor.accentPrimary,
                title = "صوت الأذان", subtitle = sound.nameArabic,
                onClick = { showSounds = true })
            Spacer(Modifier.height(10.dp))
            // Nawafil — voluntary prayers reference.
            CardRow(
                icon = R.drawable.ic_moon, tint = NoorColor.accentGold,
                title = "النوافل", subtitle = "نوافل الصلاة وأوقاتها",
                onClick = { showNawafil = true })
            Spacer(Modifier.height(10.dp))
            CardRow(
                icon = R.drawable.ic_gear, tint = NoorColor.accentPrimary,
                title = "إعدادات الصلاة",
                subtitle = "${method.nameArabic} · ${madhab.nameArabic}",
                onClick = { showSettings = true })
            Spacer(Modifier.height(24.dp))
        }
    }

    if (showSounds) {
        AdhanSoundSheet(
            selected = sound,
            onSelect = { chosen ->
                prefs.sound = chosen
                changed()
                AdhanPreview.play(context, chosen)
            },
            onDismiss = { AdhanPreview.stop(); showSounds = false })
    }
    if (showNawafil) {
        NawafilSheet(onDismiss = { showNawafil = false })
    }
}

@Composable
private fun WeekStrip(now: Date, dayOffset: Int, onSelect: (Int) -> Unit) {
    val weekdayFormat = remember { SimpleDateFormat("EEE", Locale("ar")) }
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp),
        modifier = Modifier.fillMaxWidth()) {
        for (offset in 0..6) {
            val date = remember(now.time / 60_000, offset) {
                Calendar.getInstance().apply { time = now; add(Calendar.DAY_OF_YEAR, offset) }
            }
            val selected = offset == dayOffset
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .weight(1f)
                    .background(
                        if (selected) NoorColor.accentPrimary else NoorColor.bgPrimary,
                        RoundedCornerShape(12.dp))
                    .clickable { onSelect(offset) }
                    .padding(vertical = 8.dp)
            ) {
                Text(weekdayFormat.format(date.time), fontSize = 12.sp,
                     color = if (selected) NoorColor.bgPrimary else NoorColor.inkSecondary)
                Spacer(Modifier.height(2.dp))
                Text(date.get(Calendar.DAY_OF_MONTH).arabicIndic(), fontSize = 14.sp,
                     fontWeight = if (selected) FontWeight.Bold else FontWeight.SemiBold,
                     color = if (selected) NoorColor.bgPrimary else NoorColor.inkSecondary)
            }
        }
    }
}

@Composable
private fun BellToggle(on: Boolean, onClick: () -> Unit) {
    Icon(
        painterResource(if (on) R.drawable.ic_bell else R.drawable.ic_bell_off),
        contentDescription = "التنبيه",
        tint = if (on) NoorColor.accentPrimary else NoorColor.inkSecondary.copy(alpha = 0.5f),
        modifier = Modifier.size(44.dp).clickable(onClick = onClick).padding(13.dp))
}

@Composable
private fun TimelineRow(
    entry: PrayerEntry,
    passed: Boolean,
    timeString: String,
    bellOn: Boolean,
    onBell: () -> Unit,
) {
    Column {
        HorizontalDivider(color = NoorColor.inkSecondary.copy(alpha = 0.15f))
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 9.dp)
        ) {
            Box(
                Modifier.size(10.dp).background(
                    if (passed) NoorColor.accentPrimary else NoorColor.bgPrimary, CircleShape)
                    .border(1.5.dp,
                            if (passed) NoorColor.accentPrimary
                            else NoorColor.inkSecondary.copy(alpha = 0.4f), CircleShape))
            Spacer(Modifier.width(14.dp))
            Text(entry.nameArabic, fontSize = 16.sp,
                 color = NoorColor.inkPrimary.copy(alpha = if (passed) 0.6f else 1f),
                 modifier = Modifier.weight(1f))
            Text(timeString, fontSize = 15.sp,
                 color = NoorColor.inkSecondary.copy(alpha = if (passed) 0.6f else 1f))
            BellToggle(on = bellOn, onClick = onBell)
        }
    }
}

/// Arabic countdown to the next prayer: "بعد ساعتين و٥ دقائق".
private fun countdownArabic(from: Date, to: Date): String {
    val totalMinutes = ((to.time - from.time) / 60_000L).coerceAtLeast(0)
    val hours = totalMinutes / 60
    val minutes = totalMinutes % 60
    val hourPart = when (hours) {
        0L -> null
        1L -> "ساعة"
        2L -> "ساعتين"
        else -> "${hours.toInt().arabicIndic()} ساعات"
    }
    val minutePart = when (minutes) {
        0L -> null
        1L -> "دقيقة"
        2L -> "دقيقتين"
        in 3..10 -> "${minutes.toInt().arabicIndic()} دقائق"
        else -> "${minutes.toInt().arabicIndic()} دقيقة"
    }
    val parts = listOfNotNull(hourPart, minutePart)
    return if (parts.isEmpty()) "الآن" else "بعد " + parts.joinToString(" و")
}

@Composable
private fun NextPrayerCard(
    entry: PrayerEntry,
    now: Date,
    timeString: String,
    bellOn: Boolean,
    onBell: () -> Unit,
    sound: AdhanSound,
    onSound: (AdhanSound) -> Unit,
) {
    Column(
        Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp)
            .background(NoorColor.bgElevated, RoundedCornerShape(18.dp))
            .border(1.dp, NoorColor.accentPrimary.copy(alpha = 0.35f), RoundedCornerShape(18.dp))
            .padding(18.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(10.dp).background(NoorColor.accentPrimary, CircleShape))
            Spacer(Modifier.width(10.dp))
            Text(entry.nameArabic, fontSize = 19.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.inkPrimary)
            Spacer(Modifier.width(10.dp))
            Text("التالية · ${countdownArabic(now, entry.time)}",
                 fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.accentPrimary, modifier = Modifier.weight(1f))
            Text(timeString, fontSize = 19.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.inkPrimary)
            BellToggle(on = bellOn, onClick = onBell)
        }
        Spacer(Modifier.height(10.dp))
        // Sound chips: tapping stores the choice AND plays a preview.
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.horizontalScroll(rememberScrollState())
        ) {
            AdhanSound.entries.forEach { choice ->
                val on = choice == sound
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .background(
                            if (on) NoorColor.stateReciting else NoorColor.bgElevated,
                            RoundedCornerShape(50))
                        .border(1.dp,
                                if (on) NoorColor.accentPrimary.copy(alpha = 0.5f)
                                else NoorColor.inkSecondary.copy(alpha = 0.25f),
                                RoundedCornerShape(50))
                        .clickable { onSound(choice) }
                        .padding(horizontal = 13.dp, vertical = 7.dp)
                ) {
                    if (choice.rawRes != null) {
                        Icon(painterResource(R.drawable.ic_speaker), contentDescription = null,
                             tint = if (on) NoorColor.accentPrimary else NoorColor.inkSecondary,
                             modifier = Modifier.size(12.dp))
                        Spacer(Modifier.width(5.dp))
                    }
                    Text(choice.nameArabic, fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                         color = if (on) NoorColor.accentPrimary else NoorColor.inkSecondary)
                }
            }
        }
    }
}

@Composable
private fun CardRow(icon: Int, tint: androidx.compose.ui.graphics.Color,
                    title: String, subtitle: String, onClick: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .background(NoorColor.bgElevated, RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(16.dp)
    ) {
        Icon(painterResource(icon), contentDescription = null, tint = tint,
             modifier = Modifier.size(20.dp))
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Text(title, fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.inkPrimary)
            Spacer(Modifier.height(2.dp))
            Text(subtitle, fontSize = 13.sp, color = NoorColor.inkSecondary)
        }
        Icon(painterResource(R.drawable.ic_chevron_forward), contentDescription = null,
             tint = NoorColor.inkSecondary.copy(alpha = 0.6f),
             modifier = Modifier.size(16.dp))
    }
}

/// Adhan sound list — tapping a row selects it AND plays it immediately,
/// like the iOS AdhanSoundPickerView.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AdhanSoundSheet(
    selected: AdhanSound,
    onSelect: (AdhanSound) -> Unit,
    onDismiss: () -> Unit,
) {
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = NoorColor.bgPrimary) {
        Column(Modifier.padding(horizontal = 16.dp).padding(bottom = 24.dp)) {
            Text("صوت الأذان", fontSize = 18.sp, fontWeight = FontWeight.Bold,
                 color = NoorColor.inkPrimary)
            Spacer(Modifier.height(4.dp))
            Text("اضغط على أي صوت لسماعه", fontSize = 13.sp, color = NoorColor.inkSecondary)
            Spacer(Modifier.height(10.dp))
            AdhanSound.entries.forEach { choice ->
                val on = choice == selected
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 2.dp)
                        .background(
                            if (on) NoorColor.stateReciting else NoorColor.bgPrimary,
                            RoundedCornerShape(12.dp))
                        .clickable { onSelect(choice) }
                        .padding(horizontal = 12.dp, vertical = 12.dp)
                ) {
                    Icon(
                        painterResource(when {
                            choice.rawRes != null -> R.drawable.ic_play
                            choice == AdhanSound.BELL -> R.drawable.ic_bell
                            else -> R.drawable.ic_bell_off
                        }),
                        contentDescription = null,
                        tint = if (choice.rawRes != null) NoorColor.accentPrimary
                               else NoorColor.inkSecondary,
                        modifier = Modifier.size(22.dp))
                    Spacer(Modifier.width(12.dp))
                    Text(choice.nameArabic, fontSize = 16.sp,
                         fontWeight = if (on) FontWeight.SemiBold else FontWeight.Normal,
                         color = NoorColor.inkPrimary, modifier = Modifier.weight(1f))
                    if (on) {
                        Text("✓", fontSize = 15.sp, fontWeight = FontWeight.Bold,
                             color = NoorColor.accentPrimary)
                    }
                }
            }
        }
    }
}

/// Plays a bundled adhan clip when a sound is tapped, so the choice can be
/// made by ear. Stopped when the picker/screen goes away.
object AdhanPreview {
    private var player: MediaPlayer? = null

    fun play(context: Context, sound: AdhanSound) {
        stop()
        val res = sound.rawRes ?: return
        player = MediaPlayer.create(context, res)?.apply { start() }
    }

    fun stop() {
        player?.release()
        player = null
    }
}
