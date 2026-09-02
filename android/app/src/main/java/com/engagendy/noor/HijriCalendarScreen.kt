package com.engagendy.noor

import android.icu.util.Calendar
import android.icu.util.ULocale
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.util.Date
import kotlinx.coroutines.launch

/// Umm al-Qura hijri arithmetic via ICU — the same calendar the iOS app
/// uses (Calendar(identifier: .islamicUmmAlQura)).
object Hijri {
    private const val LOCALE = "ar-SA@calendar=islamic-umalqura"

    fun calendar(): Calendar = Calendar.getInstance(ULocale(LOCALE))

    /// (day, month 1-based, year) for a date.
    fun components(date: Date = Date()): Triple<Int, Int, Int> {
        val cal = calendar().apply { time = date }
        return Triple(
            cal.get(Calendar.DAY_OF_MONTH),
            cal.get(Calendar.MONTH) + 1,
            cal.get(Calendar.YEAR))
    }
}

private data class HijriDayCell(
    val day: Int,
    val date: Date,
    val isToday: Boolean,
    val isFastingSunnah: Boolean,
    val events: List<IslamicEvent>,
)

private data class HijriMonth(
    val monthName: String,
    val year: Int,
    val leading: Int,
    val days: List<HijriDayCell>,
)

/// Builds one hijri month grid: today ringed, sunnah fasting days
/// (Mon/Thu + the white days 13–15) tinted, event days dotted.
private fun buildMonth(monthOffset: Int): HijriMonth {
    val cal = Hijri.calendar()
    cal.set(Calendar.DAY_OF_MONTH, 1)
    cal.add(Calendar.MONTH, monthOffset)
    val hijriMonth = cal.get(Calendar.MONTH) + 1
    val hijriYear = cal.get(Calendar.YEAR)
    val monthName = hijriMonthName(hijriMonth)
    val dayCount = cal.getActualMaximum(Calendar.DAY_OF_MONTH)

    // Leading blanks so day 1 lands under its weekday column.
    val weekdayOfFirst = cal.get(Calendar.DAY_OF_WEEK)
    val leading = (weekdayOfFirst - cal.firstDayOfWeek + 7) % 7

    val (todayDay, todayMonth, todayYear) = Hijri.components()
    val greg = java.util.Calendar.getInstance()
    val days = (1..dayCount).map { day ->
        cal.set(Calendar.DAY_OF_MONTH, day)
        val date = cal.time
        greg.time = date
        val weekday = greg.get(java.util.Calendar.DAY_OF_WEEK)
        val isMonThu = weekday == java.util.Calendar.MONDAY ||
            weekday == java.util.Calendar.THURSDAY
        HijriDayCell(
            day = day,
            date = date,
            isToday = day == todayDay && hijriMonth == todayMonth && hijriYear == todayYear,
            isFastingSunnah = isMonThu || day in 13..15,
            events = IslamicEvent.events(day, hijriMonth))
    }
    return HijriMonth(monthName, hijriYear, leading, days)
}

/// Sunday-first weekday initials (Umm al-Qura week), per UI language.
private val weekdaySymbolsArabic = listOf("ح", "ن", "ث", "ر", "خ", "ج", "س")
private val weekdaySymbolsEnglish = listOf("S", "M", "T", "W", "T", "F", "S")
private fun weekdaySymbols() =
    if (isArabicLocale()) weekdaySymbolsArabic else weekdaySymbolsEnglish

/// Hijri month grid sheet — 1:1 with the iOS HijriCalendarView.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HijriCalendarSheet(onDismiss: () -> Unit) {
    var monthOffset by remember { mutableIntStateOf(0) }
    var detailEvent by remember { mutableStateOf<IslamicEvent?>(null) }
    val month = remember(monthOffset) { buildMonth(monthOffset) }

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = NoorColor.bgPrimary) {
        Column(
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp)
                .padding(bottom = 32.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(stringResource(R.string.g1_hijri_calendar), fontSize = 17.sp, fontWeight = FontWeight.Bold,
                     color = NoorColor.inkPrimary)
                Spacer(Modifier.weight(1f))
                if (monthOffset != 0) {
                    Text(stringResource(R.string.g1_today), fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                         color = NoorColor.accentPrimary,
                         modifier = Modifier
                             .clickable { monthOffset = 0 }
                             .padding(horizontal = 10.dp, vertical = 8.dp))
                }
            }

            // Month header arrows, direction-aware: PREV sits at the start
            // edge and points outward (right in RTL, left in LTR); NEXT is
            // the mirror — matching iOS HijriCalendarView.
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth().padding(top = 6.dp)
            ) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier.size(44.dp).clip(CircleShape).clickable { monthOffset -= 1 }
                ) {
                    Icon(painterResource(NoorIcons.chevronBackward()),
                         contentDescription = stringResource(R.string.g1_prev_month),
                         tint = NoorColor.accentPrimary,
                         modifier = Modifier.size(20.dp))
                }
                Text(stringResource(R.string.g1_hijri_month_year,
                                    month.monthName, month.year.localizedDigits()),
                     fontSize = 17.sp, fontWeight = FontWeight.SemiBold,
                     color = NoorColor.inkPrimary,
                     textAlign = TextAlign.Center,
                     modifier = Modifier.weight(1f))
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier.size(44.dp).clip(CircleShape).clickable { monthOffset += 1 }
                ) {
                    Icon(painterResource(NoorIcons.chevronForward()),
                         contentDescription = stringResource(R.string.g1_next_month),
                         tint = NoorColor.accentPrimary,
                         modifier = Modifier.size(20.dp))
                }
            }

            // The grid card.
            Column(
                Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp)
                    .background(NoorColor.bgElevated, RoundedCornerShape(18.dp))
                    .padding(12.dp)
            ) {
                Row(Modifier.fillMaxWidth()) {
                    weekdaySymbols().forEach { symbol ->
                        Text(symbol, fontSize = 11.sp, fontWeight = FontWeight.SemiBold,
                             color = NoorColor.inkSecondary,
                             textAlign = TextAlign.Center,
                             modifier = Modifier.weight(1f))
                    }
                }
                val cells: List<HijriDayCell?> =
                    List(month.leading) { null } + month.days
                cells.chunked(7).forEach { week ->
                    Row(Modifier.fillMaxWidth().padding(top = 6.dp)) {
                        week.forEach { cell ->
                            if (cell == null) {
                                Box(Modifier.weight(1f).height(44.dp))
                            } else {
                                Column(
                                    horizontalAlignment = Alignment.CenterHorizontally,
                                    verticalArrangement = Arrangement.Center,
                                    modifier = Modifier
                                        .weight(1f)
                                        .height(44.dp)
                                        .padding(horizontal = 2.dp)
                                        .clip(RoundedCornerShape(10.dp))
                                        .background(
                                            when {
                                                cell.isToday -> NoorColor.accentPrimary
                                                cell.isFastingSunnah ->
                                                    NoorColor.accentPrimary.copy(alpha = 0.09f)
                                                else -> NoorColor.bgElevated
                                            },
                                            RoundedCornerShape(10.dp))
                                        .clickable {
                                            cell.events.firstOrNull()?.let { detailEvent = it }
                                        }
                                ) {
                                    Text(
                                        cell.day.localizedDigits(),
                                        fontSize = 15.sp,
                                        fontWeight = if (cell.isToday) FontWeight.Bold
                                                     else FontWeight.Normal,
                                        color = if (cell.isToday) NoorColor.bgPrimary
                                                else NoorColor.inkPrimary)
                                    Box(
                                        Modifier
                                            .padding(top = 2.dp)
                                            .size(5.dp)
                                            .background(
                                                if (cell.events.isEmpty())
                                                    androidx.compose.ui.graphics.Color.Transparent
                                                else NoorColor.accentGold,
                                                CircleShape))
                                }
                            }
                        }
                        repeat(7 - week.size) { Box(Modifier.weight(1f).height(44.dp)) }
                    }
                }
            }

            // Legend.
            Column(
                Modifier
                    .fillMaxWidth()
                    .padding(top = 12.dp)
                    .background(NoorColor.bgElevated, RoundedCornerShape(18.dp))
                    .padding(14.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(16.dp).background(
                        NoorColor.accentPrimary.copy(alpha = 0.2f), RoundedCornerShape(4.dp)))
                    Text(
                        stringResource(R.string.g1_fasting_legend),
                        fontSize = 13.sp, color = NoorColor.inkSecondary,
                        modifier = Modifier.padding(start = 8.dp))
                }
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.padding(top = 8.dp)
                ) {
                    Box(Modifier.size(7.dp).background(NoorColor.accentGold, CircleShape))
                    Text(
                        stringResource(R.string.g1_event_legend),
                        fontSize = 13.sp, color = NoorColor.inkSecondary,
                        modifier = Modifier.padding(start = 8.dp))
                }
            }

            // This month's events list.
            val monthEvents = month.days.flatMap { it.events }
            if (monthEvents.isNotEmpty()) {
                Column(
                    Modifier
                        .fillMaxWidth()
                        .padding(top = 12.dp)
                        .background(NoorColor.bgElevated, RoundedCornerShape(18.dp))
                        .padding(14.dp)
                ) {
                    monthEvents.forEachIndexed { index, event ->
                        if (index > 0) Spacer(Modifier.height(10.dp))
                        EventRow(event) { detailEvent = event }
                    }
                }
            }
        }
    }

    detailEvent?.let { event ->
        EventDetailSheet(event, onDismiss = { detailEvent = null })
    }
}

@Composable
private fun EventRow(event: IslamicEvent, onClick: () -> Unit) {
    Row(
        verticalAlignment = Alignment.Top,
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick)
    ) {
        Text(event.day.localizedDigits(), fontSize = 14.sp, fontWeight = FontWeight.Bold,
             color = NoorColor.accentGold,
             textAlign = TextAlign.Center,
             modifier = Modifier.size(width = 28.dp, height = 22.dp))
        Text(event.arabic, fontSize = 14.sp, color = NoorColor.inkPrimary,
             lineHeight = 22.sp,
             modifier = Modifier.weight(1f).padding(start = 6.dp))
    }
}

/// Full story of an Islamic-history event, with its own share button —
/// per the iOS EventDetailSheet.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EventDetailSheet(event: IslamicEvent, onDismiss: () -> Unit) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val dateLine = buildString {
        append("${event.day.localizedDigits()} ${hijriMonthName(event.month)}")
        event.yearHijri?.let {
            append(" ")
            append(stringResource(R.string.g1_year_h, it.localizedDigits()))
        }
    }
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = NoorColor.bgPrimary) {
        Column(
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .padding(bottom = 32.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.g1_on_this_day), fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                     color = NoorColor.inkSecondary)
                Spacer(Modifier.weight(1f))
                ShareIconButton {
                    shareRendered(context, event.arabic, dateLine)
                }
            }
            Text(event.arabic, fontSize = 19.sp, fontWeight = FontWeight.SemiBold,
                 lineHeight = 32.sp, color = NoorColor.inkPrimary,
                 modifier = Modifier.padding(top = 6.dp))
            Text(dateLine, fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.accentGold,
                 modifier = Modifier.padding(top = 10.dp))
            HorizontalDivider(
                color = NoorColor.accentGold.copy(alpha = 0.3f),
                modifier = Modifier.padding(vertical = 14.dp))
            Text(event.detailArabic, fontSize = 16.5.sp, lineHeight = 32.sp,
                 color = NoorColor.inkPrimary)
            Text(stringResource(R.string.g1_source, event.sourceArabic), fontSize = 13.sp,
                 color = NoorColor.inkSecondary,
                 modifier = Modifier.padding(top = 14.dp))
        }
    }
}

/// Every curated Islamic-history event, grouped by hijri month — per the
/// iOS AllEventsView.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AllEventsSheet(onDismiss: () -> Unit) {
    var detailEvent by remember { mutableStateOf<IslamicEvent?>(null) }
    val byMonth = remember {
        IslamicEvent.all.groupBy { it.month }
            .toSortedMap()
            .mapValues { (_, events) -> events.sortedBy { it.day } }
    }
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = NoorColor.bgPrimary) {
        Column(
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .padding(bottom = 32.dp)
        ) {
            Text(stringResource(R.string.g1_all_events), fontSize = 17.sp, fontWeight = FontWeight.Bold,
                 color = NoorColor.inkPrimary)
            byMonth.forEach { (month, events) ->
                Text(
                    hijriMonthName(month),
                    fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                    color = NoorColor.accentPrimary,
                    modifier = Modifier.padding(top = 16.dp, bottom = 6.dp))
                events.forEachIndexed { index, event ->
                    if (index > 0) Spacer(Modifier.height(8.dp))
                    EventRow(event) { detailEvent = event }
                }
            }
        }
    }
    detailEvent?.let { event ->
        EventDetailSheet(event, onDismiss = { detailEvent = null })
    }
}

/// 40dp share icon button in the accent color — the shared affordance on
/// every daily card, like the iOS square.and.arrow.up buttons.
@Composable
fun ShareIconButton(onClick: () -> Unit) {
    androidx.compose.material3.Icon(
        painterResource(R.drawable.ic_share),
        contentDescription = stringResource(R.string.g1_share),
        tint = NoorColor.accentPrimary,
        modifier = Modifier
            .size(40.dp)
            .clip(CircleShape)
            .clickable(onClick = onClick)
            .padding(10.dp))
}

/// Renders the branded share card off-main, then opens the share sheet.
fun shareRendered(
    context: android.content.Context,
    arabicText: String,
    reference: String,
    useQuranFont: Boolean = false,
    attribution: String = "نور Noor",
    translation: String? = null,
) {
    kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.IO).launch {
        val bitmap = ShareCard.render(
            context, arabicText, reference,
            attribution = attribution, useQuranFont = useQuranFont, translation = translation)
        kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Main) {
            ShareCard.share(context, bitmap, text = reference)
        }
    }
}
