package com.engagendy.noor

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.IBinder

/// Foreground media service — keeps recitation alive in the background and
/// surfaces lock-screen / notification transport controls via MediaSession.
/// Mirrors the iOS MPNowPlayingInfoCenter + remote-command setup.
class NoorAudioService : Service() {

    companion object {
        const val CHANNEL_ID = "recitation"
        private const val NOTIFICATION_ID = 7
        private const val ACTION_TOGGLE = "com.engagendy.noor.audio.TOGGLE"
        private const val ACTION_NEXT = "com.engagendy.noor.audio.NEXT"
        private const val ACTION_PREVIOUS = "com.engagendy.noor.audio.PREVIOUS"
        private const val ACTION_STOP = "com.engagendy.noor.audio.STOP"

        private var instance: NoorAudioService? = null

        /// Called by NoorPlayer whenever playback state changes.
        fun refresh(context: Context?) {
            instance?.updateNotification()
        }
    }

    private var session: MediaSession? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        ensureChannel()
        session = MediaSession(this, "NoorRecitation").apply {
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() { if (!NoorPlayer.isPlaying) NoorPlayer.toggle() }
                override fun onPause() { if (NoorPlayer.isPlaying) NoorPlayer.toggle() }
                override fun onSkipToNext() { NoorPlayer.next() }
                override fun onSkipToPrevious() { NoorPlayer.previous() }
                override fun onStop() { NoorPlayer.stop() }
            })
            isActive = true
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_TOGGLE -> NoorPlayer.toggle()
            ACTION_NEXT -> NoorPlayer.next()
            ACTION_PREVIOUS -> NoorPlayer.previous()
            ACTION_STOP -> { NoorPlayer.stop(); return START_NOT_STICKY }
        }
        startForeground(NOTIFICATION_ID, buildNotification())
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        session?.release(); session = null
        instance = null
        super.onDestroy()
    }

    private fun ensureChannel() {
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "التلاوة", NotificationManager.IMPORTANCE_LOW)
                .apply { description = "التحكم في تشغيل التلاوة"; setSound(null, null) })
    }

    fun updateNotification() {
        if (NoorPlayer.currentSurah == 0) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return
        }
        updateSessionState()
        getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, buildNotification())
    }

    private fun updateSessionState() {
        val state = if (NoorPlayer.isPlaying) PlaybackState.STATE_PLAYING
                    else PlaybackState.STATE_PAUSED
        session?.setPlaybackState(
            PlaybackState.Builder()
                .setActions(
                    PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or
                    PlaybackState.ACTION_PLAY_PAUSE or PlaybackState.ACTION_STOP or
                    PlaybackState.ACTION_SKIP_TO_NEXT or
                    PlaybackState.ACTION_SKIP_TO_PREVIOUS)
                .setState(state, PlaybackState.PLAYBACK_POSITION_UNKNOWN,
                          if (NoorPlayer.isPlaying) NoorPlayer.speed else 0f)
                .build())
        session?.setMetadata(
            android.media.MediaMetadata.Builder()
                .putString(android.media.MediaMetadata.METADATA_KEY_TITLE,
                           "${NoorPlayer.surahName} · آية ${NoorPlayer.currentAyah.arabicIndic()}")
                .putString(android.media.MediaMetadata.METADATA_KEY_ARTIST,
                           NoorPlayer.reciter.nameArabic)
                .build())
    }

    private fun servicePending(action: String, code: Int): PendingIntent =
        PendingIntent.getService(
            this, code, Intent(this, NoorAudioService::class.java).setAction(action),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    private fun buildNotification(): Notification {
        fun action(icon: Int, title: String, pendingAction: String, code: Int) =
            Notification.Action.Builder(
                android.graphics.drawable.Icon.createWithResource(this, icon),
                title, servicePending(pendingAction, code)).build()

        val playPause = if (NoorPlayer.isPlaying)
            action(R.drawable.ic_pause, "إيقاف مؤقت", ACTION_TOGGLE, 1)
        else
            action(R.drawable.ic_play, "تشغيل", ACTION_TOGGLE, 1)

        val style = Notification.MediaStyle()
            .setShowActionsInCompactView(0, 1, 2)
        session?.sessionToken?.let { style.setMediaSession(it) }

        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_book)
            .setContentTitle("${NoorPlayer.surahName} · آية ${NoorPlayer.currentAyah.arabicIndic()}")
            .setContentText(NoorPlayer.reciter.nameArabic)
            .setContentIntent(PendingIntent.getActivity(
                this, 0, Intent(this, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            .addAction(action(R.drawable.ic_prev, "السابق", ACTION_PREVIOUS, 2))
            .addAction(playPause)
            .addAction(action(R.drawable.ic_next, "التالي", ACTION_NEXT, 3))
            .addAction(action(R.drawable.ic_close, "إغلاق", ACTION_STOP, 4))
            .setStyle(style)
            .setOngoing(NoorPlayer.isPlaying)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .build()
    }
}
