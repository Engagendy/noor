package com.engagendy.noor

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/// Recorded athkar (Hisn al-Muslim, narrated by Hamad Al-Duraihim), one MP3
/// per dhikr plus one per chapter. Files are fetched once and kept under
/// filesDir/athkar-audio — NOT cacheDir — so a dhikr heard once stays
/// available offline for good (offline-first). Storage screen owns cleanup.
object AthkarAudio {
    private const val HOST = "https://www.hisnmuslim.com/audio/ar/"
    private const val MIRROR = "https://raw.githubusercontent.com/rn0x/Adhkar-json/main/audio/"
    private const val MIN_BYTES = 1024L

    fun dir(context: Context): File = File(context.filesDir, "athkar-audio")

    /// Returns the cached file, downloading it (host first, then mirror) when
    /// missing. Null only when nothing is cached and every source failed —
    /// i.e. offline on a first visit.
    suspend fun ensureLocal(context: Context, file: String): File? = withContext(Dispatchers.IO) {
        val dir = dir(context).also { it.mkdirs() }
        val target = File(dir, file)
        if (target.isFile && target.length() > MIN_BYTES) return@withContext target
        for (base in listOf(HOST, MIRROR)) {
            if (download(base + file, target)) return@withContext target
        }
        null
    }

    /// Temp file + atomic rename so a torn download never masquerades as a
    /// finished one; validates HTTP 200 and a sane size (>1 KB — the hosts
    /// answer some missing files with tiny HTML pages).
    private fun download(url: String, target: File): Boolean {
        val tmp = File(target.parentFile, target.name + ".part")
        var connection: HttpURLConnection? = null
        try {
            connection = (URL(url).openConnection() as HttpURLConnection).apply {
                connectTimeout = 15_000
                readTimeout = 30_000
                instanceFollowRedirects = true
            }
            if (connection.responseCode != HttpURLConnection.HTTP_OK) return false
            val declared = connection.contentLengthLong
            if (declared in 0..MIN_BYTES) return false
            connection.inputStream.use { input -> tmp.outputStream().use { input.copyTo(it) } }
            if (tmp.length() <= MIN_BYTES || (declared > 0 && tmp.length() != declared)) {
                tmp.delete(); return false
            }
            if (tmp.renameTo(target)) return true
            tmp.delete(); return false
        } catch (_: Exception) {
            tmp.delete(); return false
        } finally {
            connection?.disconnect()
        }
    }
}

/// Minimal one-file MediaPlayer for the athkar recordings — deliberately
/// separate from NoorPlayer (no notification, no queue, no timing). Only one
/// voice at a time: starting a dhikr pauses the Quran recitation, and
/// NoorPlayer taking focus back pauses this one via the focus listener.
object AthkarPlayer {
    /// Id of the item being loaded or played (dhikr index or "chapter"); null when idle.
    var nowPlayingId by mutableStateOf<String?>(null)
        private set
    var isLoading by mutableStateOf(false)
        private set
    var isPlaying by mutableStateOf(false)
        private set

    private var media: MediaPlayer? = null
    private var appContext: Context? = null
    private var hasFocus = false
    private val handler = Handler(Looper.getMainLooper())
    private val audioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build()
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        when (change) {
            AudioManager.AUDIOFOCUS_LOSS -> stop()
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> pause()
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK ->
                runCatching { media?.setVolume(0.2f, 0.2f) }
            AudioManager.AUDIOFOCUS_GAIN -> runCatching { media?.setVolume(1f, 1f) }
        }
    }
    private val focusRequest: AudioFocusRequest by lazy {
        AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(audioAttributes)
            .setOnAudioFocusChangeListener(focusListener, handler)
            .build()
    }

    /// Marks `id` as loading so the card can show a spinner while
    /// `AthkarAudio.ensureLocal` runs; cleared by `play`/`cancelLoading`/`stop`.
    fun beginLoading(context: Context, id: String) {
        appContext = context.applicationContext
        releaseMedia()
        nowPlayingId = id
        isLoading = true
        isPlaying = false
    }

    /// Download failed or was superseded — only clears if `id` is still current.
    fun cancelLoading(id: String) {
        if (nowPlayingId != id) return
        nowPlayingId = null
        isLoading = false
    }

    /// Starts `file` as `id`. Returns false if focus was refused (phone call)
    /// or the file would not open, in which case state is reset to idle.
    fun play(context: Context, file: File, id: String): Boolean {
        appContext = context.applicationContext
        releaseMedia()
        nowPlayingId = id
        isLoading = false
        if (NoorPlayer.isPlaying) NoorPlayer.pause()
        if (!requestFocus()) { nowPlayingId = null; return false }
        val player = MediaPlayer()
        return try {
            player.setAudioAttributes(audioAttributes)
            player.setDataSource(file.absolutePath)
            player.setOnCompletionListener { stop() }
            player.setOnErrorListener { _, _, _ -> stop(); true }
            player.prepare()
            player.start()
            media = player
            isPlaying = true
            true
        } catch (_: Exception) {
            player.release()
            nowPlayingId = null
            isPlaying = false
            abandonFocus()
            false
        }
    }

    fun toggle() { if (isPlaying) pause() else resume() }

    fun pause() {
        val player = media ?: return
        if (!isPlaying) return
        runCatching { player.pause() }
        isPlaying = false
    }

    fun resume() {
        val player = media ?: return
        if (isPlaying || !requestFocus()) return
        if (NoorPlayer.isPlaying) NoorPlayer.pause()
        runCatching { player.start() }
        isPlaying = true
    }

    /// Idle: releases the player and gives focus back.
    fun stop() {
        releaseMedia()
        nowPlayingId = null
        isLoading = false
        isPlaying = false
        abandonFocus()
    }

    private fun releaseMedia() {
        media?.let { runCatching { it.stop() }; it.release() }
        media = null
    }

    private fun requestFocus(): Boolean {
        if (hasFocus) return true
        val manager = appContext?.getSystemService(AudioManager::class.java) ?: return true
        hasFocus = manager.requestAudioFocus(focusRequest) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        return hasFocus
    }

    private fun abandonFocus() {
        if (!hasFocus) return
        hasFocus = false
        appContext?.getSystemService(AudioManager::class.java)?.abandonAudioFocusRequest(focusRequest)
    }
}
