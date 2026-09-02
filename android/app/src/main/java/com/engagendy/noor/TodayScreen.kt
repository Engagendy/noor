package com.engagendy.noor

import android.icu.text.DateFormat
import android.icu.text.RelativeDateTimeFormatter
import android.icu.util.ULocale
import androidx.compose.animation.core.animateDpAsState
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import java.text.SimpleDateFormat
import java.time.LocalDate
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.math.ceil
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext

/// Home / Today — 1:1 with the iOS App/TodayView.swift structure and
/// order: header (dates + calendar + settings), السلام عليكم, next-prayer
/// hero, jumu'ah card on Fridays, continue reading, continue listening,
/// khatmah plan, then the swipeable daily carousel with page dots.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TodayScreen(
    modifier: Modifier = Modifier,
    openResume: () -> Unit,
    openPage: (Int) -> Unit,
    openSurah: (Int) -> Unit,
    openAthkar: () -> Unit,
) {
    val context = LocalContext.current
    var showSettings by remember { mutableStateOf(false) }
    var showHijriCalendar by remember { mutableStateOf(false) }
    var showAllEvents by remember { mutableStateOf(false) }
    var detailEvent by remember { mutableStateOf<IslamicEvent?>(null) }
    var hadithDetail by remember { mutableStateOf<Pair<String, String>?>(null) }

    if (showSettings) {
        SettingsScreen(onBack = { showSettings = false }, modifier = modifier)
        return
    }

    // A minute pulse, like the iOS TimelineView(.everyMinute).
    val now by produceState(initialValue = Date()) {
        while (true) {
            delay(60_000)
            value = Date()
        }
    }

    val prayerPrefs = remember { PrayerPrefs(context) }
    val entries = remember(now.time / 60_000, prayerPrefs.cityName, prayerPrefs.useCustomLocation) {
        PrayerEngine.today(prayerPrefs, now)
    }

    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
        TodayHeader(
            now = now,
            onCalendar = { showHijriCalendar = true },
            onSettings = { showSettings = true })
        NextPrayerHero(entries = entries, now = now, city = prayerPrefs.location)
        JumuahCard(now = now, openKahf = { openSurah(18) })
        ContinueReadingCard(openResume)
        ContinueListeningCard()
        KhatmahCard(openPage)
        DailyCarousel(
            now = now,
            entries = entries,
            openAthkar = openAthkar,
            openEventDetail = { detailEvent = it },
            openAllEvents = { showAllEvents = true },
            openHadithDetail = { hadithDetail = it })
        Spacer(Modifier.height(16.dp))
    }

    if (showHijriCalendar) HijriCalendarSheet(onDismiss = { showHijriCalendar = false })
    if (showAllEvents) AllEventsSheet(onDismiss = { showAllEvents = false })
    detailEvent?.let { EventDetailSheet(it, onDismiss = { detailEvent = null }) }
    hadithDetail?.let { (arabic, reference) ->
        ModalBottomSheet(
            onDismissRequest = { hadithDetail = null },
            containerColor = NoorColor.bgPrimary
        ) {
            Column(
                Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp)
                    .padding(bottom = 32.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(reference, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                         color = NoorColor.accentGold, modifier = Modifier.weight(1f))
                    ShareIconButton { shareRendered(context, arabic, reference) }
                }
                Text(arabic, fontSize = 17.sp, lineHeight = 34.sp,
                     color = NoorColor.inkPrimary,
                     modifier = Modifier.padding(top = 8.dp))
            }
        }
    }
}

// MARK: - Header

@Composable
private fun TodayHeader(now: Date, onCalendar: () -> Unit, onSettings: () -> Unit) {
    // Umm al-Qura hijri + gregorian date line, like the iOS header.
    val dateLine = remember(now.time / 60_000) {
        // Locale-aware like iOS: ar → ar-SA umm-al-qura, en → islamic-umalqura
        // with the English locale.
        val lang = if (isArabicLocale()) "ar-SA" else "en"
        val hijri = DateFormat.getDateInstance(
            DateFormat.LONG, ULocale("$lang@calendar=islamic-umalqura"))
        val greg = SimpleDateFormat("EEEE d MMM", Locale.getDefault())
        "${hijri.format(now)} · ${greg.format(now)}"
    }
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(top = 12.dp)
    ) {
        Text(dateLine, fontSize = 13.sp, color = NoorColor.inkSecondary,
             maxLines = 1, overflow = TextOverflow.Ellipsis,
             modifier = Modifier.weight(1f))
        // 44dp tinted circle — the hijri calendar entry.
        Icon(
            painterResource(R.drawable.ic_calendar),
            contentDescription = stringResource(R.string.g1_hijri_calendar),
            tint = NoorColor.accentPrimary,
            modifier = Modifier
                .padding(start = 6.dp)
                .size(44.dp)
                .clip(CircleShape)
                .background(NoorColor.accentPrimary.copy(alpha = 0.12f), CircleShape)
                .clickable(onClick = onCalendar)
                .padding(11.dp))
        Icon(
            painterResource(R.drawable.ic_gear),
            contentDescription = stringResource(R.string.g1_settings),
            tint = NoorColor.inkSecondary,
            modifier = Modifier
                .padding(start = 6.dp)
                .size(44.dp)
                .clip(CircleShape)
                .background(NoorColor.inkPrimary.copy(alpha = 0.06f), CircleShape)
                .clickable(onClick = onSettings)
                .padding(11.dp))
    }
    Text(stringResource(R.string.g1_salam), fontSize = 28.sp, fontWeight = FontWeight.Bold,
         color = NoorColor.inkPrimary,
         modifier = Modifier.padding(top = 2.dp, bottom = 4.dp))
}

// MARK: - Next-prayer hero

/// Green hero: next prayer name + time, big countdown, five progress
/// capsules with the prayer names under them — per the iOS hero.
@Composable
private fun NextPrayerHero(entries: List<PrayerEntry>, now: Date, city: CityPreset) {
    val next = PrayerEngine.next(entries, now)
    val passed = entries.count { !it.time.after(now) }
    val formatter = remember(city.timeZone) {
        SimpleDateFormat("h:mm a", Locale.getDefault()).apply {
            timeZone = TimeZone.getTimeZone(city.timeZone)
        }
    }
    val countdown = next?.let { relativeCountdown(it.time.time - now.time) }

    Box(
        Modifier
            .padding(top = 8.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(NoorColor.accentPrimary)
    ) {
        // Subtle star-lattice ornament, exactly the iOS hero overlay.
        IslamicLattice(Color.White.copy(alpha = 0.06f), 64.dp, Modifier.matchParentSize())
        Column(Modifier.padding(20.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            Text(
                next?.displayName() ?: stringResource(R.string.g1_isha),
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                letterSpacing = 1.5.sp,
                color = Color.White.copy(alpha = 0.85f))
            Spacer(Modifier.weight(1f))
            if (next != null) {
                Text(formatter.format(next.time), fontSize = 13.sp,
                     color = Color.White.copy(alpha = 0.85f))
            }
        }
        Text(
            countdown ?: stringResource(R.string.g1_all_prayers_done),
            fontSize = if (countdown != null) 32.sp else 22.sp,
            fontWeight = FontWeight.SemiBold,
            color = Color.White,
            modifier = Modifier.padding(top = 4.dp))
        // Five progress capsules.
        Row(
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            modifier = Modifier.fillMaxWidth().padding(top = 14.dp)
        ) {
            repeat(5) { index ->
                Box(
                    Modifier
                        .weight(1f)
                        .height(3.dp)
                        .background(
                            Color.White.copy(alpha = if (index < passed) 0.9f else 0.35f),
                            CircleShape))
            }
        }
        // Prayer names under their capsules.
        Row(
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            modifier = Modifier.fillMaxWidth().padding(top = 4.dp)
        ) {
            entries.forEach { entry ->
                Text(entry.displayName(), fontSize = 10.5.sp,
                     color = Color.White.copy(alpha = 0.8f),
                     textAlign = TextAlign.Center,
                     maxLines = 1,
                     modifier = Modifier.weight(1f))
            }
        }
        }
    }
}

/// "بعد ٢٥ دقيقة" / "in 25 minutes" — ICU handles the plurals in the
/// current UI locale, like the iOS .relative numeric format.
private fun relativeCountdown(millis: Long): String {
    val totalMinutes = (millis / 60_000).toInt().coerceAtLeast(0)
    val formatter = RelativeDateTimeFormatter.getInstance(ULocale.getDefault())
    return if (totalMinutes >= 60) {
        formatter.format((totalMinutes / 60).toDouble(),
            RelativeDateTimeFormatter.Direction.NEXT,
            RelativeDateTimeFormatter.RelativeUnit.HOURS)
    } else {
        formatter.format(totalMinutes.coerceAtLeast(1).toDouble(),
            RelativeDateTimeFormatter.Direction.NEXT,
            RelativeDateTimeFormatter.RelativeUnit.MINUTES)
    }
}

// MARK: - Jumu'ah

/// Friday: Surat al-Kahf + salawat reminder (sunnah of the day).
@Composable
private fun JumuahCard(now: Date, openKahf: () -> Unit) {
    val isFriday = remember(now.time / 60_000) {
        java.util.Calendar.getInstance().apply { time = now }
            .get(java.util.Calendar.DAY_OF_WEEK) == java.util.Calendar.FRIDAY
    }
    if (!isFriday) return
    Box(
        Modifier
            .padding(top = 12.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(NoorColor.bgElevated)
            .clickable(onClick = openKahf)
    ) {
        // Gold star-lattice behind the card, per the iOS jumuahCard.
        IslamicLattice(NoorColor.accentGold.copy(alpha = 0.05f), 54.dp, Modifier.matchParentSize())
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().padding(14.dp)
        ) {
        Icon(painterResource(R.drawable.ic_sparkle), contentDescription = null,
             tint = NoorColor.accentGold, modifier = Modifier.size(20.dp))
        Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
            Text(stringResource(R.string.g1_jumuah_title), fontSize = 14.sp, fontWeight = FontWeight.Bold,
                 color = NoorColor.accentGold)
            Text(stringResource(R.string.g1_jumuah_subtitle),
                 fontSize = 13.5.sp, color = NoorColor.inkPrimary)
        }
        Text(stringResource(R.string.g1_read_kahf), fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold,
             color = NoorColor.bgPrimary,
             modifier = Modifier
                 .background(NoorColor.accentPrimary, CircleShape)
                 .padding(horizontal = 12.dp, vertical = 6.dp))
        }
    }
}

// MARK: - Continue reading

@Composable
private fun ContinueReadingCard(openResume: () -> Unit) {
    val context = LocalContext.current
    val maxPage = remember { KhatmahPlan.prefs(context).getInt("khatmah.maxPage", 0) }
    // Surah name needs the DB — loads off-main.
    val resumeLabel by produceState<String?>(initialValue = null) {
        value = withContext(Dispatchers.IO) {
            val p = KhatmahPlan.prefs(context)
            when (p.getString("reader.lastMode", null)) {
                "surah" -> {
                    val id = p.getInt("reader.lastSurah", 0)
                    QuranDb.get(context).surahs().firstOrNull { it.id == id }
                        ?.let { context.getString(R.string.g1_surah_prefix, it.displayName()) }
                }
                "page" -> context.getString(
                    R.string.g1_page_n,
                    p.getInt("reader.lastPage", 1).localizedDigits())
                else -> QuranDb.get(context).surahs().firstOrNull { it.id == 1 }
                    ?.let { context.getString(R.string.g1_surah_prefix, it.displayName()) }
            }
        }
    }
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .padding(top = 12.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(NoorColor.bgElevated, RoundedCornerShape(18.dp))
            .clickable(onClick = openResume)
            .padding(16.dp)
    ) {
        // Gold book badge, like the iOS card.
        Icon(
            painterResource(R.drawable.ic_book),
            contentDescription = null,
            tint = NoorColor.accentGold,
            modifier = Modifier
                .size(42.dp)
                .background(NoorColor.accentGold.copy(alpha = 0.12f), RoundedCornerShape(12.dp))
                .padding(10.dp))
        Column(Modifier.weight(1f).padding(horizontal = 14.dp)) {
            Text(stringResource(R.string.g1_continue_reading), fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.inkSecondary)
            Text(resumeLabel ?: "", fontSize = 16.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.inkPrimary,
                 modifier = Modifier.padding(top = 2.dp))
            if (maxPage > 0) {
                ProgressBar(maxPage / 604f, NoorColor.accentGold,
                            Modifier.padding(top = 8.dp), height = 3.dp)
                Text(stringResource(R.string.g1_khatmah_page_of,
                                    maxPage.localizedDigits(), 604.localizedDigits()),
                     fontSize = 11.sp, color = NoorColor.inkSecondary,
                     modifier = Modifier.padding(top = 3.dp))
            }
        }
        // Disclosure ("go deeper") points forward: LEFT in RTL, RIGHT in LTR.
        Icon(painterResource(NoorIcons.chevronForward()), contentDescription = null,
             tint = NoorColor.inkSecondary, modifier = Modifier.size(16.dp))
    }
}

// MARK: - Continue listening

/// Resume the last recitation (surah + ayah persisted by the player) —
/// shown only when a position was saved, per the iOS card.
@Composable
private fun ContinueListeningCard() {
    val context = LocalContext.current
    val saved = remember {
        val p = context.getSharedPreferences("audio", android.content.Context.MODE_PRIVATE)
        val surah = p.getInt("audio.lastSurah", 0)
        val ayah = p.getInt("audio.lastAyah", 0)
        if (surah > 0 && ayah > 0) surah to ayah else null
    } ?: return
    val surahInfo by produceState<Surah?>(initialValue = null) {
        value = withContext(Dispatchers.IO) {
            QuranDb.get(context).surahs().firstOrNull { it.id == saved.first }
        }
    }
    val surah = surahInfo ?: return
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .padding(top = 12.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(NoorColor.bgElevated, RoundedCornerShape(18.dp))
            .clickable {
                NoorPlayer.play(surah.id, surah.ayahCount, saved.second, surah.displayName())
            }
            .padding(14.dp)
    ) {
        Icon(
            painterResource(R.drawable.ic_headphones),
            contentDescription = null,
            tint = NoorColor.accentPrimary,
            modifier = Modifier
                .size(42.dp)
                .background(NoorColor.accentPrimary.copy(alpha = 0.1f), RoundedCornerShape(12.dp))
                .padding(11.dp))
        Column(Modifier.weight(1f).padding(horizontal = 14.dp)) {
            Text(stringResource(R.string.g1_continue_listening), fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.inkSecondary)
            Text(stringResource(R.string.g1_listening_line,
                                surah.displayName(), saved.second.localizedDigits()),
                 fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.inkPrimary,
                 modifier = Modifier.padding(top = 2.dp))
        }
        Icon(painterResource(R.drawable.ic_play_circle_fill), contentDescription = stringResource(R.string.g1_play),
             tint = NoorColor.accentPrimary, modifier = Modifier.size(26.dp))
    }
}

// MARK: - Khatmah plan

/// Khatmah plan card: daily portion, behind-schedule note, streak flame,
/// frontier link, and the goal sheet (15/30/60/90 + reached-page stepper).
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
            .clip(RoundedCornerShape(18.dp))
            .background(NoorColor.bgElevated, RoundedCornerShape(18.dp))
            .clickable {
                if (plan == null) showGoal = true
                else openPage(KhatmahPlan.frontier(context))
            }
            .padding(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.g1_khatmah_plan), fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.inkSecondary)
            if (streak > 1) {
                Text(
                    "🔥 ${streak.localizedDigits()}",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    color = NoorColor.accentGold,
                    modifier = Modifier
                        .padding(horizontal = 8.dp)
                        .background(NoorColor.accentGold.copy(alpha = 0.12f), CircleShape)
                        .padding(horizontal = 8.dp, vertical = 3.dp))
            }
            Spacer(Modifier.weight(1f))
            if (plan != null) {
                val completions = KhatmahPlan.completions(context)
                Text(
                    buildString {
                        append(stringResource(R.string.g1_khatmah_day_of,
                            plan.dayNumber().localizedDigits(), plan.goalDays.localizedDigits()))
                        if (completions > 0) {
                            append(" · ")
                            append(stringResource(R.string.g1_khatmah_count,
                                                  (completions + 1).localizedDigits()))
                        }
                    },
                    fontSize = 12.sp,
                    color = NoorColor.accentGold)
                // Edit (slider) icon opens the goal sheet.
                Icon(
                    painterResource(R.drawable.ic_sliders),
                    contentDescription = stringResource(R.string.g1_edit_plan),
                    tint = NoorColor.inkSecondary,
                    modifier = Modifier
                        .padding(start = 4.dp)
                        .size(34.dp)
                        .clickable { showGoal = true }
                        .padding(8.dp))
            }
        }
        if (plan == null) {
            // Forward action: arrow points LEFT in RTL, RIGHT in LTR.
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(top = 8.dp)
            ) {
                Text(stringResource(R.string.g1_start_khatmah), fontSize = 15.sp,
                     fontWeight = FontWeight.SemiBold,
                     color = NoorColor.inkPrimary)
                Icon(painterResource(NoorIcons.forward()), contentDescription = null,
                     tint = NoorColor.inkPrimary,
                     modifier = Modifier.padding(start = 6.dp).size(15.dp))
            }
        } else {
            val now = LocalDate.now()
            val lastRead = KhatmahPlan.lastRead(context)
            val left = plan.pagesLeftToday(now, lastRead)
            val behind = plan.pagesBehind(now, lastRead)
            when {
                plan.isFinished(lastRead) -> {
                    Text(stringResource(R.string.g1_khatmah_finished), fontSize = 16.sp,
                         fontWeight = FontWeight.SemiBold, color = NoorColor.accentPrimary,
                         modifier = Modifier.padding(top = 8.dp))
                    Text(
                        stringResource(R.string.g1_start_new_khatmah),
                        fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                        color = NoorColor.bgPrimary,
                        modifier = Modifier
                            .padding(top = 8.dp)
                            .clip(CircleShape)
                            .background(NoorColor.accentPrimary, CircleShape)
                            .clickable {
                                KhatmahPlan.recordCompletion(context)
                                KhatmahPlan.start(context, plan.goalDays)
                                version += 1
                            }
                            .padding(horizontal = 14.dp, vertical = 7.dp))
                }
                left == 0 -> Text(
                    stringResource(R.string.g1_daily_portion_done),
                    fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                    color = NoorColor.accentPrimary,
                    modifier = Modifier.padding(top = 8.dp))
                else -> {
                    Text(
                        stringResource(R.string.g1_read_to_page,
                            plan.targetPage(now).localizedDigits(), left.localizedDigits()),
                        fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                        color = NoorColor.inkPrimary,
                        modifier = Modifier.padding(top = 8.dp))
                    if (behind > 0) {
                        Text(stringResource(R.string.g1_behind_plan, behind.localizedDigits()),
                             fontSize = 12.sp, color = NoorColor.accentGold,
                             modifier = Modifier.padding(top = 2.dp))
                    }
                }
            }
            ProgressBar(minOf(lastRead, 604) / 604f, NoorColor.accentPrimary,
                        Modifier.padding(top = 10.dp))
            // Forward action: arrow points LEFT in RTL, RIGHT in LTR.
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(top = 6.dp)
            ) {
                Text(stringResource(R.string.g1_continue_from_page,
                                    KhatmahPlan.frontier(context).localizedDigits()),
                     fontSize = 12.sp, color = NoorColor.accentPrimary)
                Icon(painterResource(NoorIcons.forward()), contentDescription = null,
                     tint = NoorColor.accentPrimary,
                     modifier = Modifier.padding(start = 4.dp).size(12.dp))
            }
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
            onPageChanged = { version += 1 },
            onDismiss = { showGoal = false })
    }
}

/// Choose the khatmah duration; shows the daily portion live. With an
/// active plan it also offers the "I reached page N" stepper, like iOS.
@Composable
private fun KhatmahGoalDialog(
    hasPlan: Boolean,
    initialDays: Int,
    onStart: (Int) -> Unit,
    onStop: () -> Unit,
    onPageChanged: () -> Unit,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    var days by remember { mutableIntStateOf(initialDays) }
    var reachedPage by remember { mutableIntStateOf(KhatmahPlan.lastRead(context)) }
    Dialog(onDismissRequest = onDismiss) {
        Column(
            Modifier
                .background(NoorColor.bgPrimary, RoundedCornerShape(18.dp))
                .padding(20.dp)
        ) {
            Text(stringResource(R.string.g1_finish_quran_in), fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.inkSecondary)
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.padding(vertical = 14.dp)
            ) {
                listOf(15, 30, 60, 90).forEach { preset ->
                    val on = days == preset
                    Text(
                        preset.localizedDigits(),
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = if (on) NoorColor.bgPrimary else NoorColor.inkPrimary,
                        textAlign = TextAlign.Center,
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(12.dp))
                            .background(
                                if (on) NoorColor.accentPrimary else NoorColor.bgElevated,
                                RoundedCornerShape(12.dp))
                            .clickable { days = preset }
                            .padding(vertical = 12.dp))
                }
            }
            if (hasPlan) {
                // "I reached page N" — corrects the frontier by hand.
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp)
                ) {
                    Text(stringResource(R.string.g1_reached_page, reachedPage.localizedDigits()),
                         fontSize = 15.sp, color = NoorColor.inkPrimary,
                         modifier = Modifier.weight(1f))
                    StepperText("−", enabled = reachedPage > 0) {
                        reachedPage -= 1
                        KhatmahPlan.prefs(context).edit()
                            .putInt("khatmah.page", minOf(reachedPage + 1, 604)).apply()
                        onPageChanged()
                    }
                    StepperText("+", enabled = reachedPage < 604) {
                        reachedPage += 1
                        KhatmahPlan.prefs(context).edit()
                            .putInt("khatmah.page", minOf(reachedPage + 1, 604)).apply()
                        onPageChanged()
                    }
                }
            }
            Text(
                stringResource(R.string.g1_daily_portion,
                               ceil(604.0 / days).toInt().localizedDigits()),
                fontSize = 14.sp,
                color = NoorColor.accentGold)
            Text(
                if (hasPlan) stringResource(R.string.g1_save_plan)
                else stringResource(R.string.g1_start_plan),
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                color = NoorColor.bgPrimary,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .padding(top = 16.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(NoorColor.accentPrimary, RoundedCornerShape(14.dp))
                    .clickable { onStart(days) }
                    .padding(vertical = 14.dp))
            if (hasPlan) {
                TextButton(onClick = onStop, modifier = Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.g1_stop_plan), color = NoorColor.inkSecondary)
                }
            }
        }
    }
}

@Composable
private fun StepperText(label: String, enabled: Boolean, onClick: () -> Unit) {
    Text(
        label,
        fontSize = 18.sp,
        textAlign = TextAlign.Center,
        color = if (enabled) NoorColor.accentPrimary
                else NoorColor.inkSecondary.copy(alpha = 0.4f),
        modifier = Modifier
            .padding(start = 8.dp)
            .size(32.dp)
            .clip(CircleShape)
            .background(NoorColor.bgElevated, CircleShape)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(top = 3.dp))
}

// MARK: - Daily carousel

/// Fixed-height swipeable slot for the four daily cards, with clearly
/// visible green page dots and a slow 12-second auto-advance — per the
/// iOS TabView + carouselDots.
@Composable
private fun DailyCarousel(
    now: Date,
    entries: List<PrayerEntry>,
    openAthkar: () -> Unit,
    openEventDetail: (IslamicEvent) -> Unit,
    openAllEvents: () -> Unit,
    openHadithDetail: (Pair<String, String>) -> Unit,
) {
    val pagerState = rememberPagerState(pageCount = { 4 })
    LaunchedEffect(Unit) {
        while (true) {
            delay(12_000)
            pagerState.animateScrollToPage((pagerState.currentPage + 1) % 4)
        }
    }
    HorizontalPager(
        state = pagerState,
        pageSpacing = 12.dp,
        modifier = Modifier.padding(top = 12.dp).fillMaxWidth().height(250.dp)
    ) { page ->
        Box(Modifier.fillMaxSize()) {
            when (page) {
                0 -> DailyAyahCard(now)
                1 -> DailyDhikrCard(now, entries, openAthkar)
                2 -> DailyHadithCard(now, openHadithDetail)
                3 -> OnThisDayCard(now, openEventDetail, openAllEvents)
            }
        }
    }
    // Custom page dots in the app colors.
    Row(
        horizontalArrangement = Arrangement.spacedBy(7.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
    ) {
        repeat(4) { index ->
            val active = pagerState.currentPage == index
            val dotSize by animateDpAsState(if (active) 8.dp else 6.dp, label = "dot")
            Box(
                Modifier
                    .size(dotSize)
                    .background(
                        if (active) NoorColor.accentPrimary
                        else NoorColor.inkSecondary.copy(alpha = 0.3f),
                        CircleShape))
        }
    }
}

/// Shared chrome for a carousel page: elevated card, small caption title,
/// share button — uniform height across the four cards.
@Composable
private fun CarouselCard(
    title: String,
    trailing: String? = null,
    onShare: (() -> Unit)? = null,
    onClick: (() -> Unit)? = null,
    content: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit,
) {
    Column(
        Modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(18.dp))
            .background(NoorColor.bgElevated, RoundedCornerShape(18.dp))
            .let { if (onClick != null) it.clickable(onClick = onClick) else it }
            .padding(horizontal = 16.dp, vertical = 10.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            Text(title, fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.inkSecondary)
            Spacer(Modifier.weight(1f))
            if (trailing != null) {
                Text(trailing, fontSize = 12.sp, color = NoorColor.accentGold,
                     modifier = Modifier.padding(end = 4.dp))
            }
            if (onShare != null) ShareIconButton(onShare)
        }
        content()
    }
}

/// Daily ayah — same deterministic pick as iOS (dayOfYear·271 + year mod
/// verse count); text straight from the verified DB, in Amiri.
@Composable
private fun DailyAyahCard(now: Date) {
    val context = LocalContext.current
    val daily by produceState<Pair<Verse, String>?>(initialValue = null) {
        value = withContext(Dispatchers.IO) {
            val db = QuranDb.get(context)
            val today = LocalDate.now()
            val index = (today.dayOfYear * 271 + today.year) % maxOf(db.verseCount(), 1)
            db.verseAt(index)?.let { (verse, arabicName) ->
                // English UI shows the transliterated surah name, like iOS.
                val name = if (isArabicLocale()) arabicName
                    else db.surahs().firstOrNull { it.id == verse.surahId }
                        ?.nameTransliterated ?: arabicName
                verse to name
            }
        }
    }
    val loaded = daily
    val reference = loaded?.let {
        "${it.second} ${it.first.surahId.localizedDigits()}:${it.first.ayah.localizedDigits()}"
    }
    CarouselCard(
        title = stringResource(R.string.g1_daily_ayah),
        onShare = loaded?.let {
            { shareRendered(context, it.first.text, reference ?: "", useQuranFont = true,
                            attribution = "نور Noor · Quran text: Tanzil.net") }
        }
    ) {
        if (loaded != null) {
            Text(
                loaded.first.text,
                fontFamily = QuranFont,
                fontSize = 20.sp,
                lineHeight = 40.sp,
                color = NoorColor.inkPrimary,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(top = 2.dp))
            Spacer(Modifier.weight(1f))
            Text(reference ?: "", fontSize = 12.sp, color = NoorColor.inkSecondary,
                 modifier = Modifier.padding(top = 6.dp))
        }
    }
}

/// Time-aware dhikr: morning after Fajr, evening from Dhuhr, sleep after
/// Isha — keyed to the user's actual prayer times, like iOS dhikrSlot.
@Composable
private fun DailyDhikrCard(now: Date, entries: List<PrayerEntry>, openAthkar: () -> Unit) {
    val context = LocalContext.current
    val athkar by produceState<List<DhikrCategory>>(initialValue = emptyList()) {
        value = withContext(Dispatchers.IO) { AthkarStore.load(context) }
    }
    val slot = remember(athkar, now.time / 60_000, entries) {
        val morningEvening = athkar.firstOrNull { it.title.contains("الصباح") }?.items.orEmpty()
        val sleep = athkar.firstOrNull { it.title == "أذكار النوم" }?.items.orEmpty()
        val times = entries.associate { it.key to it.time }
        val isha = times["isha"]
        val dhuhr = times["dhuhr"]
        val fajr = times["fajr"]
        when {
            isha != null && !now.before(isha) -> R.string.g1_sleep_athkar to sleep
            dhuhr != null && !now.before(dhuhr) -> R.string.g1_evening_athkar to morningEvening
            fajr != null && now.before(fajr) -> R.string.g1_sleep_athkar to sleep
            else -> R.string.g1_morning_athkar to morningEvening
        }
    }
    val dhikr = remember(slot) {
        val pool = slot.second
        if (pool.isEmpty()) null
        else pool[(LocalDate.now().dayOfYear * 31) % pool.size]
    }
    CarouselCard(
        title = stringResource(slot.first),
        onShare = dhikr?.let {
            { shareRendered(context, it.text, "حصن المسلم",
                            attribution = "نور Noor · Hisn al-Muslim") }
        },
        onClick = openAthkar
    ) {
        if (dhikr != null) {
            Text(dhikr.text, fontSize = 16.sp, lineHeight = 30.sp,
                 color = NoorColor.inkPrimary,
                 maxLines = 5, overflow = TextOverflow.Ellipsis,
                 modifier = Modifier.padding(top = 2.dp))
            Spacer(Modifier.weight(1f))
            if (dhikr.count > 1) {
                Text(stringResource(R.string.g1_repeat_times, dhikr.count.localizedDigits()),
                     fontSize = 12.sp, color = NoorColor.accentGold,
                     modifier = Modifier.padding(top = 6.dp))
            }
        }
    }
}

/// Daily hadith: from a downloaded Sahih when available, else the bundled
/// Forty collections — same deterministic picks as iOS.
@Composable
private fun DailyHadithCard(now: Date, openDetail: (Pair<String, String>) -> Unit) {
    val context = LocalContext.current
    val daily by produceState<Pair<String, String>?>(initialValue = null) {
        value = withContext(Dispatchers.IO) {
            val day = LocalDate.now().dayOfYear
            HadithLibrary.daily(context, day)?.let { (hadith, collection) ->
                hadith.arabic to "${collection.nameArabic} · ${hadith.number}"
            } ?: run {
                val items = HadithStore.load(context)
                if (items.isEmpty()) null
                else {
                    val item = items[(day * 13) % items.size]
                    item.arabic to "${item.collectionArabic} · " + context.getString(
                        R.string.g1_hadith_n, item.number.localizedDigits())
                }
            }
        }
    }
    val loaded = daily
    CarouselCard(
        title = stringResource(R.string.g1_daily_hadith),
        trailing = loaded?.second?.substringBefore(" ·"),
        onShare = loaded?.let { { shareRendered(context, it.first, it.second) } },
        onClick = loaded?.let { { openDetail(it) } }
    ) {
        if (loaded != null) {
            Text(loaded.first, fontSize = 16.sp, lineHeight = 30.sp,
                 color = NoorColor.inkPrimary,
                 maxLines = 4, overflow = TextOverflow.Ellipsis,
                 modifier = Modifier.padding(top = 2.dp))
            Spacer(Modifier.weight(1f))
            Text(stringResource(R.string.g1_read_full_hadith), fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.bgPrimary,
                 modifier = Modifier
                     .padding(top = 6.dp)
                     .align(Alignment.CenterHorizontally)
                     .clip(CircleShape)
                     .background(NoorColor.accentPrimary, CircleShape)
                     .clickable { openDetail(loaded) }
                     .padding(horizontal = 14.dp, vertical = 6.dp))
        }
    }
}

/// "On this day" in Islamic history by the Hijri date; falls back to the
/// next upcoming event so the card always has something to show.
@Composable
private fun OnThisDayCard(
    now: Date,
    openEventDetail: (IslamicEvent) -> Unit,
    openAllEvents: () -> Unit,
) {
    val context = LocalContext.current
    val state = remember(now.time / 60_000) {
        val (day, month, _) = Hijri.components(now)
        val todays = IslamicEvent.events(day, month)
        if (todays.isNotEmpty()) Triple(todays, null as Int?, true)
        else {
            // Next event in the Hijri year (approximate 30-day months).
            val today = month * 30 + day
            val upcoming = IslamicEvent.all
                .map { event ->
                    val target = event.month * 30 + event.day
                    val delta = if (target >= today) target - today else target + 360 - today
                    event to delta
                }
                .minByOrNull { it.second }
            Triple(listOfNotNull(upcoming?.first), upcoming?.second, false)
        }
    }
    val (events, inDays, isToday) = state
    val first = events.firstOrNull() ?: return
    CarouselCard(
        title = if (isToday) stringResource(R.string.g1_on_this_day)
                else stringResource(R.string.g1_coming_up),
        onShare = {
            val reference = buildString {
                append("${first.day.localizedDigits()} ${hijriMonthName(first.month)}")
                first.yearHijri?.let {
                    append(" · ")
                    append(context.getString(R.string.g1_year_h, it.localizedDigits()))
                }
            }
            shareRendered(context, first.arabic, reference)
        }
    ) {
        Column(
            Modifier
                .weight(1f)
                .fillMaxWidth()
                .clickable { openEventDetail(first) }
                .padding(top = 2.dp)
        ) {
            Text(first.arabic, fontSize = 15.sp, lineHeight = 26.sp,
                 color = NoorColor.inkPrimary,
                 maxLines = 3, overflow = TextOverflow.Ellipsis)
            Row(modifier = Modifier.padding(top = 4.dp)) {
                first.yearHijri?.let {
                    Text(stringResource(R.string.g1_year_h, it.localizedDigits()), fontSize = 12.sp,
                         color = NoorColor.accentGold,
                         modifier = Modifier.padding(end = 8.dp))
                }
                inDays?.let {
                    Text(stringResource(R.string.g1_in_days_approx, it.localizedDigits()), fontSize = 12.sp,
                         color = NoorColor.accentGold)
                }
            }
        }
        Row(
            horizontalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterHorizontally),
            modifier = Modifier.fillMaxWidth().padding(top = 6.dp)
        ) {
            Text(stringResource(R.string.g1_details), fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.bgPrimary,
                 modifier = Modifier
                     .clip(CircleShape)
                     .background(NoorColor.accentPrimary, CircleShape)
                     .clickable { openEventDetail(first) }
                     .padding(horizontal = 14.dp, vertical = 6.dp))
            Text(stringResource(R.string.g1_all_events), fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.accentPrimary,
                 modifier = Modifier
                     .clip(CircleShape)
                     .background(NoorColor.accentPrimary.copy(alpha = 0.1f), CircleShape)
                     .clickable(onClick = openAllEvents)
                     .padding(horizontal = 14.dp, vertical = 6.dp))
        }
    }
}

// MARK: - Shared bits

@Composable
private fun ProgressBar(
    fraction: Float,
    tint: Color,
    modifier: Modifier = Modifier,
    height: androidx.compose.ui.unit.Dp = 5.dp,
) {
    Box(
        modifier
            .fillMaxWidth()
            .height(height)
            .background(NoorColor.inkPrimary.copy(alpha = 0.07f), CircleShape)
    ) {
        Box(
            Modifier
                .fillMaxWidth(fraction.coerceIn(0f, 1f))
                .height(height)
                .background(tint, CircleShape))
    }
}
