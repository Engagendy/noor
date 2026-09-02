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
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/// Notification sound for the adhan — mirrors the iOS `AdhanSound` enum
/// (same raw values under "prayer.sound"). Madinah/melodic/Azeez are the
/// exact audio bundled on iOS (converted caf → m4a/mp3).
enum class AdhanSoundChoice(val id: String, val nameArabic: String, val resId: Int?) {
    MADINAH("adhanMadinah", "أذان المدينة", R.raw.adhan_madinah),
    MELODIC("adhanMelodic", "أذان منغّم", R.raw.adhan_melodic),
    AZEEZ("adhanAzeez", "أذان عزيز", R.raw.adhan_azeez),
    BELL("bell", "جرس", null),
    SILENT("silent", "صامت", null);

    companion object {
        fun current(context: Context): AdhanSoundChoice {
            val id = KhatmahPlan.prefs(context).getString("prayer.sound", null)
            return entries.firstOrNull { it.id == id } ?: MADINAH
        }
    }
}

/// Exact adhan alarms via AlarmManager — the Android counterpart of the iOS
/// AdhanNotificationScheduler (UNUserNotificationCenter). Reschedule on every
/// app open, settings change, and device boot so the window rolls forward.
object AdhanScheduler {
    const val REMINDER_CHANNEL_ID = "reminders"
    private const val DAYS_AHEAD = 2
    private const val REQUESTS_PER_DAY = 5
    /// Request codes 200.. are the sunnah-fasting eve reminders.
    private const val FASTING_BASE = 200

    /// Channel sounds are immutable after creation, so each adhan sound gets
    /// its own channel and the receiver posts to the selected one.
    fun channelId(choice: AdhanSoundChoice) = "adhan.${choice.id}"

    fun ensureChannel(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        val audio = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .build()
        for (choice in AdhanSoundChoice.entries) {
            if (manager.getNotificationChannel(channelId(choice)) != null) continue
            val channel = NotificationChannel(
                channelId(choice), "الأذان — ${choice.nameArabic}",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "تنبيهات مواقيت الصلاة"
                when {
                    choice.resId != null -> setSound(Uri.parse(
                        "android.resource://${context.packageName}/${choice.resId}"), audio)
                    choice == AdhanSoundChoice.SILENT -> setSound(null, null)
                    // BELL keeps the system default notification sound.
                }
            }
            manager.createNotificationChannel(channel)
        }
        if (manager.getNotificationChannel(REMINDER_CHANNEL_ID) == null) {
            manager.createNotificationChannel(NotificationChannel(
                REMINDER_CHANNEL_ID, "تذكيرات",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply { description = "تذكير صيام السنّة" })
        }
        // Pre-1.0 single-sound channel; superseded by the per-sound set.
        manager.deleteNotificationChannel("adhan")
    }

    /// Schedules the next ~2 days of prayers as exact alarms.
    fun reschedule(context: Context) {
        ensureChannel(context)
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val canExact = Build.VERSION.SDK_INT < 31 || alarmManager.canScheduleExactAlarms()

        val noorPrefs = KhatmahPlan.prefs(context)
        val notificationsEnabled = noorPrefs.getBoolean("notifications.enabled", true)
        val fastingEnabled = notificationsEnabled &&
            noorPrefs.getBoolean("fasting.reminders", false)
        val prefs = PrayerPrefs(context)
        val city = prefs.city
        val zone = TimeZone.getTimeZone(city.timeZone)
        val now = Date()
        val formatter = SimpleDateFormat("h:mm a", Locale("ar")).apply { timeZone = zone }

        var slot = 0
        for (dayOffset in 0..DAYS_AHEAD) {
            val day = Calendar.getInstance(zone).apply {
                time = now
                add(Calendar.DAY_OF_YEAR, dayOffset)
            }.time
            for (entry in PrayerEngine.today(prefs, day)) {
                val requestCode = slot++
                val intent = Intent(context, AdhanAlarmReceiver::class.java).apply {
                    action = "com.engagendy.noor.ADHAN"
                    putExtra("nameArabic", entry.nameArabic)
                    putExtra("timeString", formatter.format(entry.time))
                }
                val pending = PendingIntent.getBroadcast(
                    context, requestCode, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                if (!notificationsEnabled || !entry.time.after(now)) {
                    // Disabled, or a stale slot from a previous schedule.
                    alarmManager.cancel(pending)
                    continue
                }
                if (canExact) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, entry.time.time, pending)
                } else {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, entry.time.time, pending)
                }
            }
        }
        // Cancel any leftover slots beyond what we just scheduled.
        while (slot < (DAYS_AHEAD + 1) * REQUESTS_PER_DAY) {
            val pending = PendingIntent.getBroadcast(
                context, slot++, Intent(context, AdhanAlarmReceiver::class.java)
                    .apply { action = "com.engagendy.noor.ADHAN" },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            alarmManager.cancel(pending)
        }

        // Sunnah-fasting eve reminders (Monday & Thursday): a nudge at 20:00
        // the evening before, rolling forward with the same window.
        for (dayOffset in 0..DAYS_AHEAD) {
            val eve = Calendar.getInstance(zone).apply {
                time = now
                add(Calendar.DAY_OF_YEAR, dayOffset)
                set(Calendar.HOUR_OF_DAY, 20)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val tomorrow = (eve.clone() as Calendar)
                .apply { add(Calendar.DAY_OF_YEAR, 1) }
                .get(Calendar.DAY_OF_WEEK)
            val dayName = when (tomorrow) {
                Calendar.MONDAY -> "الاثنين"
                Calendar.THURSDAY -> "الخميس"
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
    }
}

/// Fires at prayer time: posts the adhan notification, then rolls the
/// scheduling window forward.
class AdhanAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AdhanScheduler.ensureChannel(context)
        if (intent.action == "com.engagendy.noor.FASTING") {
            val dayName = intent.getStringExtra("dayName") ?: return
            val notification = android.app.Notification
                .Builder(context, AdhanScheduler.REMINDER_CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_sparkle)
                .setContentTitle("صيام السنّة غدًا")
                .setContentText("غدًا $dayName — من أيام صيام التطوع")
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
        val channel = AdhanScheduler.channelId(AdhanSoundChoice.current(context))
        // Calm microcopy like iOS — no exclamation marks.
        val notification = android.app.Notification.Builder(context, channel)
            .setSmallIcon(R.drawable.ic_clock)
            .setContentTitle("حان وقت صلاة $nameArabic")
            .setContentText("$nameArabic · $timeString")
            .setContentIntent(PendingIntent.getActivity(
                context, 0, Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            .setAutoCancel(true)
            .build()
        context.getSystemService(NotificationManager::class.java)
            .notify(nameArabic.hashCode(), notification)
        AdhanScheduler.reschedule(context)
        // A prayer just passed — the home widgets show the next one now.
        NoorWidgets.refresh(context)
    }
}

/// Alarms don't survive a reboot — reschedule when the device boots.
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            AdhanScheduler.reschedule(context)
        }
    }
}
