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
///
/// Notification sound is a channel property fixed at creation, so each
/// AdhanSound gets its own channel ("adhan.MADINAH" …); the receiver posts
/// to the channel matching the current preference.
object AdhanScheduler {
    private const val DAYS_AHEAD = 2
    // 5 adhans + 5 pre-alerts per day.
    private const val REQUESTS_PER_DAY = 10
    private const val PREALERT_BASE = 1000

    fun channelId(sound: AdhanSound): String = "adhan.${sound.name}"
    const val PREALERT_CHANNEL_ID = "prealert"

    fun ensureChannels(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        // Legacy channel from earlier releases — superseded by per-sound channels.
        manager.deleteNotificationChannel("adhan")
        for (sound in AdhanSound.entries) {
            val id = channelId(sound)
            if (manager.getNotificationChannel(id) != null) continue
            val importance = if (sound == AdhanSound.SILENT)
                NotificationManager.IMPORTANCE_LOW else NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(
                id, "الأذان — ${sound.nameArabic}", importance
            ).apply {
                description = "تنبيهات مواقيت الصلاة"
                when {
                    sound.rawRes != null -> setSound(
                        Uri.parse("android.resource://${context.packageName}/${sound.rawRes}"),
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
                PREALERT_CHANNEL_ID, "تنبيه قبل الصلاة", NotificationManager.IMPORTANCE_DEFAULT
            ).apply { description = "تذكير لطيف قبل الأذان" })
        }
    }

    /// Schedules the next ~2 days of prayers (and optional pre-alerts) as
    /// exact alarms, honoring the per-prayer bell toggles.
    fun reschedule(context: Context) {
        ensureChannels(context)
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val canExact = Build.VERSION.SDK_INT < 31 || alarmManager.canScheduleExactAlarms()

        val prefs = PrayerPrefs(context)
        val city = prefs.city
        val zone = TimeZone.getTimeZone(city.timeZone)
        val now = Date()
        val preAlert = prefs.preAlertMinutes
        val formatter = SimpleDateFormat("h:mm a", Locale("ar")).apply { timeZone = zone }

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
                val enabled = prefs.notificationEnabled(entry.key)
                // Adhan itself.
                val adhanPending = pending(adhanCode) {
                    putExtra("nameArabic", entry.nameArabic)
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
                    putExtra("nameArabic", entry.nameArabic)
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
    }
}

/// Fires at prayer time: posts the adhan notification, then rolls the
/// scheduling window forward.
class AdhanAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AdhanScheduler.ensureChannels(context)
        val nameArabic = intent.getStringExtra("nameArabic") ?: return
        val timeString = intent.getStringExtra("timeString") ?: ""
        val preAlert = intent.getIntExtra("preAlertMinutes", 0)
        val isPreAlert = preAlert > 0
        val channel = if (isPreAlert) AdhanScheduler.PREALERT_CHANNEL_ID
            else AdhanScheduler.channelId(PrayerPrefs(context).sound)
        // Calm microcopy like iOS — no exclamation marks.
        val title = if (isPreAlert) "اقتربت صلاة $nameArabic"
            else "حان وقت صلاة $nameArabic"
        val text = if (isPreAlert) "بعد ${preAlert.arabicIndic()} دقائق · $timeString"
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

/// Alarms don't survive a reboot — reschedule when the device boots.
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            AdhanScheduler.reschedule(context)
        }
    }
}
