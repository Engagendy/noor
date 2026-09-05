package com.engagendy.noor

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.provider.Settings
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/// Exact adhan alarms via AlarmManager — the Android counterpart of the iOS
/// AdhanNotificationScheduler (UNUserNotificationCenter). Reschedule on every
/// app open, settings change, and device boot so the window rolls forward.
///
/// Notification sound is a channel property fixed at creation, so each
/// AdhanSound gets its own channel ("adhan.MADINAH" …); the receiver posts
/// to the channel matching the current preference.
object AdhanScheduler {
    private const val DAYS_AHEAD = 2
    // 5 adhans + 5 pre-alerts per day.
    private const val REQUESTS_PER_DAY = 10
    private const val PREALERT_BASE = 1000
    /// Request codes 200.. are the sunnah-fasting eve reminders.
    private const val FASTING_BASE = 200
    /// Request code for the home-widget refresh tick.
    private const val WIDGET_BASE = 300
    /// Request codes 400.. are the after-salah athkar reminders: one per
    /// prayer per day within DAYS_AHEAD (5 × 3 = 15 codes).
    private const val ATHKAR_BASE = 400
    private const val ATHKAR_PER_DAY = 5
    const val ATHKAR_ACTION = "com.engagendy.noor.ATHKAR"
    const val ATHKAR_CHANNEL_ID = "athkar"
    /// Content-intent request code for the athkar tap (distinct from the
    /// adhan/fasting taps, which share requestCode 0 and no extras).
    const val ATHKAR_OPEN_REQUEST = 4001
    /// Inexact window: no exact-alarm permission needed, battery-friendly.
    /// MainActivity extra naming the screen a notification tap opens.
    const val EXTRA_OPEN = "open"
    const val OPEN_ATHKAR_AFTER_SALAH = "athkar_after_salah"
    /// Exact category title in assets/athkar.json.
    const val ATHKAR_AFTER_SALAH_TITLE = "الأذكار بعد السلام من الصلاة"
    /// Widgets show a countdown, so they need a tick of their own; anything
    /// finer drains the battery for a surface that is only read at a glance.
    private const val WIDGET_TICK_MS = 5 * 60_000L
    const val WIDGET_ACTION = "com.engagendy.noor.WIDGET_REFRESH"

    /// Channel IDs are versioned: a channel's sound is immutable once created,
    /// so any change to how the sound URI is built needs a new ID (and the old
    /// one deleted in ensureChannels) for existing installs to pick it up.
    /// v2: name-based resource URI (v1 baked in the numeric R.raw ID, which
    /// shifts between builds and pointed old channels at the wrong resource).
    fun channelId(sound: AdhanSound): String = "adhan.${sound.name}.v2"

    /// Whether adhans can fire on the minute. False only on Android 12/12L
    /// when the user revoked "Alarms & reminders" (API 33+ holds
    /// USE_EXACT_ALARM from the manifest); alarms then degrade to inexact.
    fun canScheduleExact(context: Context): Boolean =
        Build.VERSION.SDK_INT < 31 ||
            context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()

    /// System screen where the user grants "Alarms & reminders" for Noor.
    fun exactAlarmSettingsIntent(context: Context): Intent =
        Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
               Uri.parse("package:${context.packageName}"))
    const val PREALERT_CHANNEL_ID = "prealert"
    const val REMINDER_CHANNEL_ID = "reminders"

    fun ensureChannels(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        // Legacy channels from earlier releases — superseded by per-sound
        // channels, then by v2 IDs whose sound URI survives resource renumbering.
        manager.deleteNotificationChannel("adhan")
        for (sound in AdhanSound.entries) manager.deleteNotificationChannel("adhan.${sound.name}")
        for (sound in AdhanSound.entries) {
            val id = channelId(sound)
            if (manager.getNotificationChannel(id) != null) continue
            val importance = if (sound == AdhanSound.SILENT)
                NotificationManager.IMPORTANCE_LOW else NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(
                id,
                context.getString(R.string.g1_channel_adhan, context.getString(sound.nameRes)),
                importance
            ).apply {
                description = context.getString(R.string.g1_channel_adhan_desc)
                when {
                    // Name-based URI: numeric resource IDs are not stable across
                    // app updates, but the channel (and its sound) is immutable.
                    sound.rawRes != null -> setSound(
                        Uri.parse("android.resource://${context.packageName}/raw/" +
                            context.resources.getResourceEntryName(sound.rawRes)),
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                            .build())
                    sound == AdhanSound.SILENT -> setSound(null, null)
                    // BELL keeps the system default notification sound.
                }
            }
            manager.createNotificationChannel(channel)
        }
        if (manager.getNotificationChannel(PREALERT_CHANNEL_ID) == null) {
            manager.createNotificationChannel(NotificationChannel(
                PREALERT_CHANNEL_ID, context.getString(R.string.g1_channel_prealert),
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply { description = context.getString(R.string.g1_channel_prealert_desc) })
        }
        if (manager.getNotificationChannel(REMINDER_CHANNEL_ID) == null) {
            manager.createNotificationChannel(NotificationChannel(
                REMINDER_CHANNEL_ID, context.getString(R.string.g1_channel_reminders),
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply { description = context.getString(R.string.g1_channel_reminders_desc) })
        }
        if (manager.getNotificationChannel(ATHKAR_CHANNEL_ID) == null) {
            // Silent by design: a nudge minutes after the adhan, not another adhan.
            manager.createNotificationChannel(NotificationChannel(
                ATHKAR_CHANNEL_ID, context.getString(R.string.feat_channel_athkar),
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = context.getString(R.string.feat_channel_athkar_desc)
                setSound(null, null)
            })
        }
    }

    /// Schedules the next ~2 days of prayers (and optional pre-alerts) as
    /// exact alarms, honoring the master toggle and per-prayer bells.
    fun reschedule(context: Context) {
        ensureChannels(context)
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val canExact = canScheduleExact(context)

        val noorPrefs = KhatmahPlan.prefs(context)
        val notificationsEnabled = noorPrefs.getBoolean("notifications.enabled", true)
        // Fasting reminders are their own toggle on iOS (MainTabView keys them
        // off "fasting.reminders" alone), so the adhan master switch must not
        // silence them here either.
        val fastingEnabled = noorPrefs.getBoolean("fasting.reminders", false)
        val prefs = PrayerPrefs(context)
        val city = prefs.location
        val zone = TimeZone.getTimeZone(city.timeZone)
        val now = Date()
        val preAlert = prefs.preAlertMinutes
        val formatter = SimpleDateFormat("h:mm a", Locale.getDefault()).apply { timeZone = zone }

        fun pending(requestCode: Int, build: (Intent.() -> Unit)? = null): PendingIntent {
            val intent = Intent(context, AdhanAlarmReceiver::class.java).apply {
                action = "com.engagendy.noor.ADHAN"
                build?.invoke(this)
            }
            return PendingIntent.getBroadcast(
                context, requestCode, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        fun schedule(at: Date, pendingIntent: PendingIntent) {
            if (canExact) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, at.time, pendingIntent)
            } else {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, at.time, pendingIntent)
            }
        }

        var slot = 0
        for (dayOffset in 0..DAYS_AHEAD) {
            val day = Calendar.getInstance(zone).apply {
                time = now
                add(Calendar.DAY_OF_YEAR, dayOffset)
            }.time
            for (entry in PrayerEngine.today(prefs, day)) {
                val adhanCode = slot
                val preCode = PREALERT_BASE + slot
                slot++
                val enabled = notificationsEnabled && prefs.notificationEnabled(entry.key)
                // Adhan itself.
                val adhanPending = pending(adhanCode) {
                    putExtra("nameArabic", entry.displayName())
                    putExtra("timeString", formatter.format(entry.time))
                }
                if (enabled && entry.time.after(now)) {
                    schedule(entry.time, adhanPending)
                } else {
                    alarmManager.cancel(adhanPending)
                }
                // Gentle pre-adhan reminder.
                val preTime = Date(entry.time.time - preAlert * 60_000L)
                val prePending = pending(preCode) {
                    putExtra("nameArabic", entry.displayName())
                    putExtra("timeString", formatter.format(entry.time))
                    putExtra("preAlertMinutes", preAlert)
                }
                if (enabled && preAlert > 0 && preTime.after(now)) {
                    schedule(preTime, prePending)
                } else {
                    alarmManager.cancel(prePending)
                }
            }
        }
        // Cancel any leftover slots beyond what we just scheduled.
        while (slot < (DAYS_AHEAD + 1) * REQUESTS_PER_DAY / 2) {
            alarmManager.cancel(pending(slot))
            alarmManager.cancel(pending(PREALERT_BASE + slot))
            slot++
        }

        // Sunnah-fasting eve reminders (Monday, Thursday & the white days
        // 13–15 hijri, matching iOS FastingReminderScheduler): a nudge at
        // 20:30 the evening before, rolling forward with the same window.
        // Fasting follows the user's own civil day, so this uses the DEVICE
        // zone — not the prayer city's zone (a traveller keeping the Makkah
        // preset must still be nudged at 20:30 where they actually are).
        for (dayOffset in 0..DAYS_AHEAD) {
            val eve = Calendar.getInstance().apply {
                time = now
                add(Calendar.DAY_OF_YEAR, dayOffset)
                set(Calendar.HOUR_OF_DAY, 20)
                set(Calendar.MINUTE, 30)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val next = (eve.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, 1) }
            val hijriDay = Hijri.components(next.time).first
            val dayName = when {
                hijriDay in 13..15 ->
                    context.getString(R.string.prayer_fasting_white_day, hijriDay)
                next.get(Calendar.DAY_OF_WEEK) == Calendar.MONDAY ->
                    context.getString(R.string.g1_monday)
                next.get(Calendar.DAY_OF_WEEK) == Calendar.THURSDAY ->
                    context.getString(R.string.g1_thursday)
                else -> null
            }
            val intent = Intent(context, AdhanAlarmReceiver::class.java).apply {
                action = "com.engagendy.noor.FASTING"
                putExtra("dayName", dayName)
            }
            val pending = PendingIntent.getBroadcast(
                context, FASTING_BASE + dayOffset, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            if (fastingEnabled && dayName != null && eve.time.after(now)) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, eve.timeInMillis, pending)
            } else {
                alarmManager.cancel(pending)
            }
        }

        scheduleAthkarReminders(context, alarmManager, prefs, now)
        scheduleWidgetRefresh(context)
    }

    /// After-salah athkar reminder N minutes after each of the five daily
    /// prayers (iOS AthkarReminderScheduler; keys "athkar.afterSalah" and
    /// "athkar.afterSalahMinutes"). Independent of the adhan master toggle
    /// and the per-prayer bells. Inexact with a 10-minute window — needs no
    /// exact-alarm permission. Every code is cancelled when off.
    private fun scheduleAthkarReminders(
        context: Context, alarmManager: AlarmManager, prefs: PrayerPrefs, now: Date,
    ) {
        val noorPrefs = KhatmahPlan.prefs(context)
        val enabled = noorPrefs.getBoolean("athkar.afterSalah", false)
        val minutes = noorPrefs.getInt("athkar.afterSalahMinutes", 20).coerceIn(1, 120)
        val zone = TimeZone.getTimeZone(prefs.location.timeZone)
        for (dayOffset in 0..DAYS_AHEAD) {
            val day = Calendar.getInstance(zone).apply {
                time = now
                add(Calendar.DAY_OF_YEAR, dayOffset)
            }.time
            val entries = if (enabled) PrayerEngine.today(prefs, day) else emptyList()
            for (index in 0 until ATHKAR_PER_DAY) {
                val entry = entries.getOrNull(index)
                val pending = PendingIntent.getBroadcast(
                    context, ATHKAR_BASE + dayOffset * ATHKAR_PER_DAY + index,
                    Intent(context, AdhanAlarmReceiver::class.java).apply {
                        action = ATHKAR_ACTION
                        putExtra("prayerKey", entry?.key)
                    },
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                val at = entry?.let { it.time.time + minutes * 60_000L }
                if (enabled && at != null && at > now.time) {
                    // Inexact (batched, no exact-alarm permission) but Doze-exempt:
                    // setWindow is deferred to the next maintenance window once the
                    // phone dozes after Isha, which is exactly when this fires.
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
                } else {
                    alarmManager.cancel(pending)
                }
            }
        }
    }

    /// Home widgets must keep their countdown and next-prayer name honest
    /// even when every notification toggle is off, so their refresh tick is
    /// armed independently of the adhan alarms above. Fires at the earlier of
    /// the tick, the next prayer, and local midnight (the daily-ayah rollover)
    /// — and stays cancelled while no widget is placed.
    fun scheduleWidgetRefresh(context: Context) {
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val pending = PendingIntent.getBroadcast(
            context, WIDGET_BASE,
            Intent(context, AdhanAlarmReceiver::class.java).apply { action = WIDGET_ACTION },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        if (!NoorWidgets.hasPlacedWidgets(context)) {
            alarmManager.cancel(pending)
            return
        }
        val prefs = PrayerPrefs(context)
        val zone = TimeZone.getTimeZone(prefs.location.timeZone)
        val now = Date()
        val midnight = Calendar.getInstance(zone).apply {
            time = now
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val nextPrayer = PrayerEngine.next(PrayerEngine.today(prefs, now), now)
            ?.time?.time?.plus(1_000L) ?: Long.MAX_VALUE
        val at = minOf(now.time + WIDGET_TICK_MS, nextPrayer, midnight)
        // Inexact: a glanceable countdown never justifies an exact alarm.
        alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
    }
}

/// Fires at prayer time: posts the adhan notification, then rolls the
/// scheduling window forward.
class AdhanAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == AdhanScheduler.WIDGET_ACTION) {
            NoorWidgets.refresh(context)
            return
        }
        AdhanScheduler.ensureChannels(context)
        if (intent.action == AdhanScheduler.ATHKAR_ACTION) {
            // Prayer name resolved NOW from resources, like the adhan title,
            // so it follows the per-app locale in force when it fires.
            val prayerKey = intent.getStringExtra("prayerKey") ?: return
            val nameRes = when (prayerKey) {
                "fajr" -> R.string.g1_fajr
                "dhuhr" -> R.string.g1_dhuhr
                "asr" -> R.string.g1_asr
                "maghrib" -> R.string.g1_maghrib
                "isha" -> R.string.g1_isha
                else -> return
            }
            val prayerName = context.getString(nameRes)
            val open = Intent(context, MainActivity::class.java).apply {
                putExtra(AdhanScheduler.EXTRA_OPEN, AdhanScheduler.OPEN_ATHKAR_AFTER_SALAH)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val notification = android.app.Notification
                .Builder(context, AdhanScheduler.ATHKAR_CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_sparkle)
                .setContentTitle(context.getString(R.string.feat_athkar_after_salah))
                .setContentText(context.getString(R.string.feat_athkar_after_salah_text, prayerName))
                .setContentIntent(PendingIntent.getActivity(
                    context, AdhanScheduler.ATHKAR_OPEN_REQUEST, open,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
                .setAutoCancel(true)
                .build()
            context.getSystemService(NotificationManager::class.java)
                .notify("athkar-after-salah".hashCode(), notification)
            AdhanScheduler.reschedule(context)
            return
        }
        if (intent.action == "com.engagendy.noor.FASTING") {
            val dayName = intent.getStringExtra("dayName") ?: return
            val notification = android.app.Notification
                .Builder(context, AdhanScheduler.REMINDER_CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_sparkle)
                .setContentTitle(context.getString(R.string.g1_fasting_title))
                .setContentText(context.getString(R.string.g1_fasting_text, dayName))
                .setContentIntent(PendingIntent.getActivity(
                    context, 0, Intent(context, MainActivity::class.java),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
                .setAutoCancel(true)
                .build()
            context.getSystemService(NotificationManager::class.java)
                .notify(dayName.hashCode(), notification)
            AdhanScheduler.reschedule(context)
            return
        }
        val nameArabic = intent.getStringExtra("nameArabic") ?: return
        val timeString = intent.getStringExtra("timeString") ?: ""
        val preAlert = intent.getIntExtra("preAlertMinutes", 0)
        val isPreAlert = preAlert > 0
        val channel = if (isPreAlert) AdhanScheduler.PREALERT_CHANNEL_ID
            else AdhanScheduler.channelId(PrayerPrefs(context).sound)
        // Calm microcopy like iOS — no exclamation marks.
        val title = if (isPreAlert) context.getString(R.string.g1_prealert_title, nameArabic)
            else context.getString(R.string.g1_adhan_title, nameArabic)
        val text = if (isPreAlert)
            context.getString(R.string.g1_prealert_text,
                              preAlert.localizedDigits(), timeString)
            else "$nameArabic · $timeString"
        val notification = android.app.Notification.Builder(context, channel)
            .setSmallIcon(R.drawable.ic_clock)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(PendingIntent.getActivity(
                context, 0, Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            .setAutoCancel(true)
            .build()
        context.getSystemService(NotificationManager::class.java)
            .notify(if (isPreAlert) "pre-$nameArabic".hashCode() else nameArabic.hashCode(),
                    notification)
        if (!isPreAlert) {
            AdhanScheduler.reschedule(context)
            // A prayer just passed — the home widgets show the next one now.
            NoorWidgets.refresh(context)
        }
    }
}

/// Alarms don't survive a reboot, an app update, or the user revoking
/// "Alarms & reminders" (Android 12+ cancels every alarm and force-stops the
/// app). Re-arm on all of those, plus when the permission is granted back
/// (upgrade inexact → exact) and when the device clock/time-zone changes
/// (the scheduled window was computed against the old zone).
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED -> {
                AdhanScheduler.reschedule(context)
                NoorWidgets.refresh(context)
            }
        }
    }
}
