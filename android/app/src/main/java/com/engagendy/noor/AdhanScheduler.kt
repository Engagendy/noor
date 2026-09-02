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

/// Exact adhan alarms via AlarmManager — the Android counterpart of the iOS
/// AdhanNotificationScheduler (UNUserNotificationCenter). Reschedule on every
/// app open, settings change, and device boot so the window rolls forward.
object AdhanScheduler {
    const val CHANNEL_ID = "adhan"
    private const val DAYS_AHEAD = 2
    private const val REQUESTS_PER_DAY = 5

    fun ensureChannel(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val sound = Uri.parse(
            "android.resource://${context.packageName}/${R.raw.adhan_madinah}")
        val channel = NotificationChannel(
            CHANNEL_ID, "الأذان", NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "تنبيهات مواقيت الصلاة"
            setSound(sound, AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build())
        }
        manager.createNotificationChannel(channel)
    }

    /// Schedules the next ~2 days of prayers as exact alarms.
    fun reschedule(context: Context) {
        ensureChannel(context)
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val canExact = Build.VERSION.SDK_INT < 31 || alarmManager.canScheduleExactAlarms()

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
                if (!entry.time.after(now)) {
                    // Stale slot from a previous schedule — clear it.
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
    }
}

/// Fires at prayer time: posts the adhan notification, then rolls the
/// scheduling window forward.
class AdhanAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AdhanScheduler.ensureChannel(context)
        val nameArabic = intent.getStringExtra("nameArabic") ?: return
        val timeString = intent.getStringExtra("timeString") ?: ""
        // Calm microcopy like iOS — no exclamation marks.
        val notification = android.app.Notification.Builder(context, AdhanScheduler.CHANNEL_ID)
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
