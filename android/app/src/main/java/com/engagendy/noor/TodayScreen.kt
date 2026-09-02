package com.engagendy.noor

import android.icu.text.DateFormat
import android.icu.util.ULocale
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import java.text.SimpleDateFormat
import java.time.LocalDate
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlin.math.ceil

/// Home / Today — parity with the iOS App/TodayView.swift core cards:
/// hijri header, next-prayer hero, continue reading, khatmah plan with
/// the reading-streak flame, and the daily ayah.
@Composable
fun TodayScreen(
    modifier: Modifier = Modifier,
    openResume: () -> Unit,
    openPage: (Int) -> Unit,
) {
    val context = LocalContext.current
    val city = Cities.all[0]
    val entries = remember { PrayerEngine.today(city) }
    val next = PrayerEngine.next(entries)
    val formatter = remember {
        SimpleDateFormat("h:mm a", Locale("ar")).apply {
            timeZone = TimeZone.getTimeZone(city.timeZone)
        }
    }
    // Umm al-Qura hijri date, like the iOS islamicUmmAlQura header.
    val hijriLine = remember {
        val hijri = DateFormat.getDateInstance(
            DateFormat.LONG, ULocale("ar-SA@calendar=islamic-umalqura"))
        val greg = SimpleDateFormat("EEEE d MMM", Locale("ar"))
        "${hijri.format(Date())} · ${greg.format(Date())}"
    }

    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp)) {
        Text(hijriLine, fontSize = 13.sp, color = NoorColor.inkSecondary)
        Text("السلام عليكم", fontSize = 28.sp, fontWeight = FontWeight.Bold, color = NoorColor.inkPrimary)

        // Next-prayer hero.
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

        ContinueReadingCard(openResume)
        KhatmahCard(openPage)
        DailyAyahCard()
    }
}

@Composable
private fun ContinueReadingCard(openResume: () -> Unit) {
    val context = LocalContext.current
    val maxPage = remember { KhatmahPlan.prefs(context).getInt("khatmah.maxPage", 0) }
    // Where "continue" resumes: last surah name or last Madani page —
    // surah name needs the DB, so it loads off-main.
    val resumeLabel by produceState<String?>(initialValue = null) {
        value = withContext(Dispatchers.IO) {
            val p = KhatmahPlan.prefs(context)
            when (p.getString("reader.lastMode", null)) {
                "surah" -> {
                    val id = p.getInt("reader.lastSurah", 0)
                    QuranDb.get(context).surahs().firstOrNull { it.id == id }
                        ?.let { "آخر قراءة: سورة ${it.nameArabic}" }
                }
                "page" -> "آخر قراءة: صفحة ${p.getInt("reader.lastPage", 1).arabicIndic()}"
                else -> null
            }
        }
    }
    Column(
        Modifier
            .padding(top = 12.dp)
            .fillMaxWidth()
            .background(NoorColor.bgElevated, RoundedCornerShape(18.dp))
            .clickable(onClick = openResume)
            .padding(18.dp)
    ) {
        Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
            Text("متابعة القراءة", fontSize = 16.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.inkPrimary)
            Text("←", color = NoorColor.accentPrimary)
        }
        resumeLabel?.let {
            Text(it, fontSize = 13.sp, color = NoorColor.inkSecondary,
                 modifier = Modifier.padding(top = 4.dp))
        }
        if (maxPage > 0) {
            ProgressBar(maxPage / 604f, NoorColor.accentGold, Modifier.padding(top = 10.dp))
            Text(
                "الختمة · صفحة ${maxPage.arabicIndic()} من ٦٠٤",
                fontSize = 11.sp,
                color = NoorColor.inkSecondary,
                modifier = Modifier.padding(top = 4.dp)
            )
        }
    }
}

/// Khatmah plan card: daily portion, behind/ahead, streak flame, and the
/// goal dialog with the 15/30/60/90-day presets — per the iOS card.
@Composable
private fun KhatmahCard(openPage: (Int) -> Unit) {
    val context = LocalContext.current
    var version by remember { mutableIntStateOf(0) }
    var showGoal by remember { mutableStateOf(false) }
    val plan = remember(version) { KhatmahPlan.load(context) }
    val streak = remember(version) { ReadingProgress.streakDays(context) }

    Column(
        Modifier
            .padding(top = 12.dp)
            .fillMaxWidth()
            .background(NoorColor.bgElevated, RoundedCornerShape(18.dp))
            .clickable {
                if (plan == null) showGoal = true
                else openPage(KhatmahPlan.frontier(context))
            }
            .padding(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            Text("خطة الختمة", fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.inkSecondary)
            if (streak > 1) {
                Text(
                    "🔥 ${streak.arabicIndic()}",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    color = NoorColor.accentGold,
                    modifier = Modifier
                        .padding(horizontal = 8.dp)
                        .background(NoorColor.accentGold.copy(alpha = 0.12f), CircleShape)
                        .padding(horizontal = 8.dp, vertical = 3.dp)
                )
            }
            Spacer(Modifier.weight(1f))
            if (plan != null) {
                Text(
                    "اليوم ${plan.dayNumber().arabicIndic()} من ${plan.goalDays.arabicIndic()}",
                    fontSize = 12.sp,
                    color = NoorColor.accentGold
                )
                Text(
                    "تعديل",
                    fontSize = 12.sp,
                    color = NoorColor.inkSecondary,
                    modifier = Modifier.clickable { showGoal = true }.padding(start = 10.dp, top = 2.dp, bottom = 2.dp)
                )
            }
        }
        if (plan == null) {
            Text(
                "ابدأ خطة ختمة ←",
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = NoorColor.inkPrimary,
                modifier = Modifier.padding(top = 8.dp)
            )
        } else {
            val now = LocalDate.now()
            val lastRead = KhatmahPlan.lastRead(context)
            val left = plan.pagesLeftToday(now, lastRead)
            val behind = plan.pagesBehind(now, lastRead)
            when {
                plan.isFinished(lastRead) -> {
                    Text(
                        "ما شاء الله، أتممت الختمة 🎉",
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = NoorColor.accentPrimary,
                        modifier = Modifier.padding(top = 8.dp)
                    )
                    Text(
                        "ابدأ ختمة جديدة",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = NoorColor.bgPrimary,
                        modifier = Modifier
                            .padding(top = 8.dp)
                            .background(NoorColor.accentPrimary, CircleShape)
                            .clickable {
                                KhatmahPlan.recordCompletion(context)
                                KhatmahPlan.start(context, plan.goalDays)
                                version += 1
                            }
                            .padding(horizontal = 14.dp, vertical = 7.dp)
                    )
                }
                left == 0 -> Text(
                    "أنجزت وِرد اليوم، تقبّل الله",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = NoorColor.accentPrimary,
                    modifier = Modifier.padding(top = 8.dp)
                )
                else -> {
                    Text(
                        "اقرأ إلى صفحة ${plan.targetPage(now).arabicIndic()} · بقيت ${left.arabicIndic()} صفحات اليوم",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = NoorColor.inkPrimary,
                        modifier = Modifier.padding(top = 8.dp)
                    )
                    if (behind > 0) {
                        Text(
                            "متأخر بـ ${behind.arabicIndic()} صفحات عن الخطة",
                            fontSize = 12.sp,
                            color = NoorColor.accentGold,
                            modifier = Modifier.padding(top = 2.dp)
                        )
                    }
                }
            }
            ProgressBar(minOf(lastRead, 604) / 604f, NoorColor.accentPrimary,
                        Modifier.padding(top = 10.dp))
            Text(
                "تابع من صفحة ${KhatmahPlan.frontier(context).arabicIndic()} ←",
                fontSize = 12.sp,
                color = NoorColor.accentPrimary,
                modifier = Modifier.padding(top = 6.dp)
            )
        }
    }

    if (showGoal) {
        KhatmahGoalDialog(
            hasPlan = plan != null,
            initialDays = plan?.goalDays ?: 30,
            onStart = { days ->
                KhatmahPlan.start(context, days)
                version += 1
                showGoal = false
            },
            onStop = {
                KhatmahPlan.clear(context)
                version += 1
                showGoal = false
            },
            onDismiss = { showGoal = false })
    }
}

/// Choose the khatmah duration; shows the resulting daily portion live.
@Composable
private fun KhatmahGoalDialog(
    hasPlan: Boolean,
    initialDays: Int,
    onStart: (Int) -> Unit,
    onStop: () -> Unit,
    onDismiss: () -> Unit,
) {
    var days by remember { mutableIntStateOf(initialDays) }
    Dialog(onDismissRequest = onDismiss) {
        Column(
            Modifier
                .background(NoorColor.bgPrimary, RoundedCornerShape(18.dp))
                .padding(20.dp)
        ) {
            Text("أتمّ القرآن خلال", fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.inkSecondary)
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.padding(vertical = 14.dp)
            ) {
                listOf(15, 30, 60, 90).forEach { preset ->
                    val on = days == preset
                    Text(
                        preset.arabicIndic(),
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = if (on) NoorColor.bgPrimary else NoorColor.inkPrimary,
                        textAlign = TextAlign.Center,
                        modifier = Modifier
                            .weight(1f)
                            .background(
                                if (on) NoorColor.accentPrimary else NoorColor.bgElevated,
                                RoundedCornerShape(12.dp)
                            )
                            .clickable { days = preset }
                            .padding(vertical = 12.dp)
                    )
                }
            }
            Text(
                "وِردك اليومي: نحو ${ceil(604.0 / days).toInt().arabicIndic()} صفحات",
                fontSize = 14.sp,
                color = NoorColor.accentGold
            )
            Text(
                "ابدأ الخطة",
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                color = NoorColor.bgPrimary,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .padding(top = 16.dp)
                    .fillMaxWidth()
                    .background(NoorColor.accentPrimary, RoundedCornerShape(14.dp))
                    .clickable { onStart(days) }
                    .padding(vertical = 14.dp)
            )
            if (hasPlan) {
                TextButton(onClick = onStop, modifier = Modifier.fillMaxWidth()) {
                    Text("إيقاف الخطة", color = NoorColor.inkSecondary)
                }
            }
        }
    }
}

/// Daily ayah: same deterministic pick as iOS (dayOfYear·271 + year mod
/// verse count) — text straight from the verified DB, in Amiri.
@Composable
private fun DailyAyahCard() {
    val context = LocalContext.current
    val daily by produceState<Pair<Verse, Surah>?>(initialValue = null) {
        value = withContext(Dispatchers.IO) {
            val db = QuranDb.get(context)
            val today = LocalDate.now()
            val index = (today.dayOfYear * 271 + today.year) % maxOf(db.verseCount(), 1)
            db.verseAt(index)?.let { pair ->
                pair.first to db.surahs().first { it.id == pair.first.surahId }
            }
        }
    }
    val loaded = daily ?: return

    Column(
        Modifier
            .padding(top = 12.dp)
            .fillMaxWidth()
            .background(NoorColor.bgElevated, RoundedCornerShape(18.dp))
            .padding(16.dp)
    ) {
        Text("آية اليوم", fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
             color = NoorColor.inkSecondary)
        Text(
            loaded.first.text,
            fontFamily = QuranFont,
            fontSize = 21.sp,
            lineHeight = 44.sp,
            color = NoorColor.inkPrimary,
            modifier = Modifier.padding(top = 8.dp)
        )
        Text(
            "${loaded.second.nameArabic} ${loaded.first.surahId.arabicIndic()}:${loaded.first.ayah.arabicIndic()}",
            fontSize = 12.sp,
            color = NoorColor.inkSecondary,
            modifier = Modifier.padding(top = 6.dp)
        )
    }
}

@Composable
private fun ProgressBar(fraction: Float, tint: androidx.compose.ui.graphics.Color, modifier: Modifier = Modifier) {
    Box(
        modifier
            .fillMaxWidth()
            .height(5.dp)
            .background(NoorColor.inkPrimary.copy(alpha = 0.07f), CircleShape)
    ) {
        Box(
            Modifier
                .fillMaxWidth(fraction.coerceIn(0f, 1f))
                .height(5.dp)
                .background(tint, CircleShape)
        )
    }
}
