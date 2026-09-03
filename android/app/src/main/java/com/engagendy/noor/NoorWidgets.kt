package com.engagendy.noor

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.text.Layout
import android.text.StaticLayout
import android.text.TextDirectionHeuristics
import android.text.TextPaint
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.res.ResourcesCompat
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalSize
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import java.text.SimpleDateFormat
import java.time.LocalDate
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/// Widget palette — 1:1 with the iOS Widgets/NoorWidgets.swift WidgetTheme
/// (design 1i: small on paper, wide row on Tahajjud dark).
private object WTheme {
    val paper = Color(0xFFFAF6EE)
    val ink = Color(0xFF1F2933)
    val inkSecondary = Color(0xFF5C6670)
    val green = Color(0xFF0E6B5C)
    val gold = Color(0xFFB98A2F)
    val darkBG = Color(0xFF0F1512)
    val darkInk = Color(0xFFEDE7DA)
    val darkSecondary = Color(0xFF9AA49E)
    val teal = Color(0xFF4FB3A0)
    val tealPill = Color(0x294FB3A0)   // teal @16 %
    val segmentOff = Color(0x241F2933) // ink @14 %
}

private fun Color.provider() = ColorProvider(this)

private data class WidgetPrayer(val name: String, val time: String, val isNext: Boolean)

private data class NextPrayerData(
    val todayLabel: String,
    val city: String,
    val nextName: String,
    val nextTime: String,
    val remaining: String,
    val passedCount: Int,
    val times: List<WidgetPrayer>,
)

/// Same engine + prefs the app uses (PrayerPrefs city/method/madhab).
private fun computeNextPrayer(context: Context): NextPrayerData {
    val prefs = PrayerPrefs(context)
    val city = prefs.location
    val now = Date()
    val todayEntries = PrayerEngine.today(prefs, now)
    // After Isha there is no remaining prayer today: fall back to tomorrow and
    // draw tomorrow's rows too, so the highlighted row is the one in the header.
    val todayNext = PrayerEngine.next(todayEntries, now)
    val tomorrowEntries =
        if (todayNext == null) PrayerEngine.today(prefs, Date(now.time + 86_400_000L))
        else emptyList()
    val entries = if (tomorrowEntries.isEmpty()) todayEntries else tomorrowEntries
    val next = todayNext ?: tomorrowEntries.firstOrNull()
    val formatter = SimpleDateFormat("h:mm", Locale.getDefault()).apply {
        timeZone = TimeZone.getTimeZone(city.timeZone)
    }
    if (next == null) {
        // High-latitude polar day/night: the engine has no times to show.
        return NextPrayerData(
            todayLabel = context.getString(R.string.g1_today),
            city = city.displayName(),
            nextName = context.getString(R.string.prayer_high_latitude_short),
            nextTime = "",
            remaining = context.getString(R.string.prayer_high_latitude_short),
            passedCount = 0,
            times = emptyList())
    }
    val remainingMinutes = ((next.time.time - now.time) / 60_000L).coerceAtLeast(0)
    val clock = "${(remainingMinutes / 60).toInt().localizedDigits()}:" +
        String.format(java.util.Locale.ROOT, "%02d", remainingMinutes % 60).map {
            if (it.isDigit() && isArabicLocale()) '٠' + (it - '0') else it
        }.joinToString("")
    return NextPrayerData(
        todayLabel = context.getString(R.string.g1_today),
        city = city.displayName(),
        nextName = next.displayName(),
        nextTime = formatter.format(next.time),
        remaining = context.getString(R.string.g1_widget_in, clock),
        passedCount = if (tomorrowEntries.isEmpty()) entries.count { !it.time.after(now) } else 0,
        times = entries.map {
            WidgetPrayer(it.displayName(), formatter.format(it.time), it.key == next.key)
        })
}

/// Next-prayer widget: paper small + always-dark medium row (design 1i).
class NextPrayerWidget : GlanceAppWidget() {
    companion object {
        private val SMALL = DpSize(120.dp, 120.dp)
        private val WIDE = DpSize(260.dp, 120.dp)
    }

    override val sizeMode = SizeMode.Responsive(setOf(SMALL, WIDE))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val data = withContext(Dispatchers.IO) { computeNextPrayer(context) }
        provideContent {
            GlanceTheme {
                if (LocalSize.current.width >= WIDE.width) DarkRowWidget(data)
                else PaperSmallWidget(data)
            }
        }
    }
}

/// Small: green prayer label, remaining, time, five progress segments.
@androidx.compose.runtime.Composable
private fun PaperSmallWidget(data: NextPrayerData) {
    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(WTheme.paper.provider())
            .cornerRadius(18.dp)
            .clickable(actionStartActivity<MainActivity>())
            .padding(14.dp)
    ) {
        Text(
            data.nextName,
            style = TextStyle(
                color = WTheme.green.provider(),
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold))
        Text(
            data.remaining,
            style = TextStyle(
                color = WTheme.ink.provider(),
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold))
        Text(
            data.nextTime,
            style = TextStyle(color = WTheme.inkSecondary.provider(), fontSize = 12.sp))
        Spacer(GlanceModifier.defaultWeight())
        Row(GlanceModifier.fillMaxWidth()) {
            repeat(5) { index ->
                if (index > 0) Spacer(GlanceModifier.width(4.dp))
                Box(
                    GlanceModifier
                        .defaultWeight()
                        .height(3.dp)
                        .cornerRadius(2.dp)
                        .background(
                            (if (index < data.passedCount) WTheme.green
                             else WTheme.segmentOff).provider())
                ) {}
            }
        }
    }
}

/// Wide: always Tahajjud dark — TODAY row, next prayer in a teal pill.
@androidx.compose.runtime.Composable
private fun DarkRowWidget(data: NextPrayerData) {
    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(WTheme.darkBG.provider())
            .cornerRadius(18.dp)
            .clickable(actionStartActivity<MainActivity>())
            .padding(14.dp)
    ) {
        Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(
                data.todayLabel,
                style = TextStyle(
                    color = WTheme.teal.provider(), fontSize = 12.sp, fontWeight = FontWeight.Bold))
            Spacer(GlanceModifier.width(8.dp))
            Text(
                data.remaining,
                style = TextStyle(
                    color = WTheme.teal.provider(), fontSize = 12.sp, fontWeight = FontWeight.Bold))
            Spacer(GlanceModifier.defaultWeight())
            Text(
                data.city,
                style = TextStyle(color = WTheme.darkSecondary.provider(), fontSize = 11.sp))
        }
        Spacer(GlanceModifier.defaultWeight())
        Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            data.times.forEachIndexed { index, item ->
                if (index > 0) Spacer(GlanceModifier.defaultWeight())
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = GlanceModifier
                        .cornerRadius(10.dp)
                        .background(
                            (if (item.isNext) WTheme.tealPill else Color.Transparent).provider())
                        .padding(horizontal = 7.dp, vertical = 4.dp)
                ) {
                    Text(
                        item.name,
                        style = TextStyle(
                            color = (if (item.isNext) WTheme.teal else WTheme.darkSecondary).provider(),
                            fontSize = 11.sp,
                            fontWeight = if (item.isNext) FontWeight.Bold else FontWeight.Normal))
                    Text(
                        item.time,
                        style = TextStyle(
                            color = WTheme.darkInk.provider(),
                            fontSize = 13.sp,
                            fontWeight = if (item.isNext) FontWeight.Bold else FontWeight.Medium))
                }
            }
        }
    }
}

class NextPrayerWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = NextPrayerWidget()

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        AdhanScheduler.scheduleWidgetRefresh(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        AdhanScheduler.scheduleWidgetRefresh(context)
    }
}

// MARK: — Daily ayah

private data class DailyAyahData(val bitmap: Bitmap?, val reference: String)

/// Same deterministic pick as the Today card and iOS DailyAyahWidget:
/// (dayOfYear·271 + year) mod verse count — text only from the verified DB.
private fun computeDailyAyah(context: Context, widthPx: Int): DailyAyahData {
    val db = QuranDb.get(context)
    val today = LocalDate.now()
    val index = (today.dayOfYear * 271 + today.year) % maxOf(db.verseCount(), 1)
    val (verse, surahName) = db.verseAt(index) ?: return DailyAyahData(null, "")
    val name = if (isArabicLocale()) surahName
        else db.surahs().firstOrNull { it.id == verse.surahId }?.nameTransliterated ?: surahName
    return DailyAyahData(
        bitmap = renderQuranBitmap(context, verse.text, widthPx),
        reference = "$name ${verse.surahId.localizedDigits()}:${verse.ayah.localizedDigits()}")
}

/// Glance can't use custom fonts, so the ayah renders to a bitmap with the
/// bundled Amiri Quran font (the only verified flow-mode font — CLAUDE.md).
private fun renderQuranBitmap(context: Context, text: String, widthPx: Int): Bitmap? {
    val typeface = ResourcesCompat.getFont(context, R.font.amiri_quran) ?: return null
    val maxHeightPx = (widthPx * 0.62f).toInt()
    var textSize = widthPx / 13f
    var layout: StaticLayout
    do {
        val paint = TextPaint().apply {
            this.typeface = typeface
            this.textSize = textSize
            color = android.graphics.Color.argb(0xFF, 0x1F, 0x29, 0x33) // ink
            isAntiAlias = true
        }
        layout = StaticLayout.Builder
            .obtain(text, 0, text.length, paint, widthPx)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .setTextDirection(TextDirectionHeuristics.RTL)
            .setLineSpacing(0f, 1.35f)
            .build()
        textSize *= 0.88f
    } while (layout.height > maxHeightPx && textSize > 8f)
    val bitmap = Bitmap.createBitmap(widthPx, layout.height, Bitmap.Config.ARGB_8888)
    layout.draw(Canvas(bitmap))
    return bitmap
}

/// Daily ayah on paper (iOS design 6.7): gold label, ayah, reference.
class DailyAyahWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val data = withContext(Dispatchers.IO) { computeDailyAyah(context, 760) }
        provideContent {
            GlanceTheme {
                Column(
                    modifier = GlanceModifier
                        .fillMaxSize()
                        .background(WTheme.paper.provider())
                        .cornerRadius(18.dp)
                        .clickable(actionStartActivity<MainActivity>())
                        .padding(14.dp)
                ) {
                    Text(
                        context.getString(R.string.g1_daily_ayah),
                        style = TextStyle(
                            color = WTheme.gold.provider(),
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold))
                    Spacer(GlanceModifier.defaultWeight())
                    data.bitmap?.let {
                        Image(
                            provider = ImageProvider(it),
                            contentDescription = data.reference,
                            modifier = GlanceModifier.fillMaxWidth())
                    }
                    Spacer(GlanceModifier.defaultWeight())
                    Text(
                        data.reference,
                        style = TextStyle(color = WTheme.inkSecondary.provider(), fontSize = 10.sp))
                }
            }
        }
    }
}

class DailyAyahWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = DailyAyahWidget()

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        AdhanScheduler.scheduleWidgetRefresh(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        AdhanScheduler.scheduleWidgetRefresh(context)
    }
}

/// Push fresh data to every placed widget — called on app open, after
/// onboarding/settings changes, when an adhan alarm fires, and from the
/// widget refresh tick (`AdhanScheduler.scheduleWidgetRefresh`), which every
/// refresh re-arms so the countdown keeps up regardless of the notification
/// toggles. The OS hourly `updatePeriodMillis` is only a backstop.
object NoorWidgets {
    fun refresh(context: Context) {
        val app = context.applicationContext
        CoroutineScope(Dispatchers.Default).launch {
            NextPrayerWidget().updateAll(app)
            DailyAyahWidget().updateAll(app)
            AdhanScheduler.scheduleWidgetRefresh(app)
        }
    }

    /// True while at least one Noor widget sits on a home screen — the tick
    /// is armed only then, and cancelled once the last one is removed.
    fun hasPlacedWidgets(context: Context): Boolean {
        val manager = AppWidgetManager.getInstance(context) ?: return false
        return listOf(NextPrayerWidgetReceiver::class.java, DailyAyahWidgetReceiver::class.java)
            .any { manager.getAppWidgetIds(ComponentName(context, it)).isNotEmpty() }
    }
}
