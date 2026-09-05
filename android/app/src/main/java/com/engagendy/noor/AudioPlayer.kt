package com.engagendy.noor

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/// One EveryAyah reciter — 1:1 port of the iOS `Reciter` enum
/// (Modules/QuranAudio/Sources/QuranAudio/Reciter.swift).
data class ReciterA(
    val id: String,
    val nameEnglish: String,
    val nameArabic: String,
    val flag: String,
    val folder: String,
)

/// Full verified EveryAyah roster — same 31 entries and folders as iOS.
object Reciters {
    val all = listOf(
        ReciterA("alafasy", "Mishary Alafasy", "مشاري العفاسي", "🇰🇼", "Alafasy_128kbps"),
        ReciterA("husary", "Mahmoud Al-Husary", "محمود خليل الحصري", "🇪🇬", "Husary_128kbps"),
        ReciterA("minshawi", "Mohamed Al-Minshawi", "محمد صديق المنشاوي", "🇪🇬", "Minshawy_Murattal_128kbps"),
        ReciterA("abdulBasit", "Abdul Basit (Murattal)", "عبد الباسط عبد الصمد", "🇪🇬", "Abdul_Basit_Murattal_192kbps"),
        ReciterA("ghamdi", "Saad Al-Ghamdi", "سعد الغامدي", "🇸🇦", "Ghamadi_40kbps"),
        ReciterA("sudais", "Abdurrahman As-Sudais", "عبد الرحمن السديس", "🇸🇦", "Abdurrahmaan_As-Sudais_192kbps"),
        ReciterA("muaiqly", "Maher Al-Muaiqly", "ماهر المعيقلي", "🇸🇦", "Maher_AlMuaiqly_64kbps"),
        ReciterA("shuraym", "Saud Ash-Shuraym", "سعود الشريم", "🇸🇦", "Saood_ash-Shuraym_128kbps"),
        ReciterA("ayyoub", "Muhammad Ayyoub", "محمد أيوب", "🇸🇦", "Muhammad_Ayyoub_128kbps"),
        ReciterA("shatri", "Abu Bakr Ash-Shatri", "أبو بكر الشاطري", "🇸🇦", "Abu_Bakr_Ash-Shaatree_128kbps"),
        ReciterA("rifai", "Hani Ar-Rifai", "هاني الرفاعي", "🇸🇦", "Hani_Rifai_192kbps"),
        ReciterA("hudhaify", "Ali Al-Hudhaify", "علي الحذيفي", "🇸🇦", "Hudhaify_128kbps"),
        ReciterA("jibreel", "Muhammad Jibreel", "محمد جبريل", "🇪🇬", "Muhammad_Jibreel_128kbps"),
        ReciterA("dussary", "Yasser Ad-Dussary", "ياسر الدوسري", "🇸🇦", "Yasser_Ad-Dussary_128kbps"),
        ReciterA("basfar", "Abdullah Basfar", "عبد الله بصفر", "🇸🇦", "Abdullah_Basfar_192kbps"),
        ReciterA("sowaid", "Ayman Sowaid", "أيمن سويد", "🇸🇾", "Ayman_Sowaid_64kbps"),
        ReciterA("tablawi", "Mohammad At-Tablawi", "محمد الطبلاوي", "🇪🇬", "Mohammad_al_Tablaway_128kbps"),
        ReciterA("abdulBasitMujawwad", "Abdul Basit (Mujawwad)", "عبد الباسط (مجوّد)", "🇪🇬", "Abdul_Basit_Mujawwad_128kbps"),
        ReciterA("minshawiMujawwad", "Al-Minshawi (Mujawwad)", "المنشاوي (مجوّد)", "🇪🇬", "Minshawy_Mujawwad_192kbps"),
        ReciterA("salamah", "Yaser Salamah", "ياسر سلامة", "🇪🇬", "Yaser_Salamah_128kbps"),
        ReciterA("qatami", "Nasser Al-Qatami", "ناصر القطامي", "🇸🇦", "Nasser_Alqatami_128kbps"),
        ReciterA("faresAbbad", "Fares Abbad", "فارس عباد", "🇾🇪", "Fares_Abbad_64kbps"),
        ReciterA("ajamy", "Ahmed Al-Ajmi", "أحمد العجمي", "🇸🇦", "Ahmed_ibn_Ali_al-Ajamy_64kbps_QuranExplorer.Com"),
        ReciterA("muhsinQasim", "Muhsin Al-Qasim", "محسن القاسم", "🇸🇦", "Muhsin_Al_Qasim_192kbps"),
        ReciterA("juhany", "Abdullah Al-Juhany", "عبد الله الجهني", "🇸🇦", "Abdullaah_3awwaad_Al-Juhaynee_128kbps"),
        ReciterA("bukhatir", "Salah Bukhatir", "صلاح بوخاطر", "🇦🇪", "Salaah_AbdulRahman_Bukhatir_128kbps"),
        ReciterA("budair", "Salah Al-Budair", "صلاح البدير", "🇸🇦", "Salah_Al_Budair_128kbps"),
        ReciterA("aliJaber", "Ali Jaber", "علي جابر", "🇸🇦", "Ali_Jaber_64kbps"),
        ReciterA("banna", "Mahmoud Ali Al-Banna", "محمود علي البنا", "🇪🇬", "mahmoud_ali_al_banna_32kbps"),
        ReciterA("matroud", "Abdullah Al-Matroud", "عبد الله المطرود", "🇸🇦", "Abdullah_Matroud_128kbps"),
        ReciterA("abdulKareem", "Muhammad Abdul-Kareem", "محمد عبد الكريم", "", "Muhammad_AbdulKareem_128kbps"),
    )

    fun byId(id: String): ReciterA = all.firstOrNull { it.id == id } ?: all[0]
}

/// Same four modes as the iOS QuranAudioPlayer.PlaybackMode.
enum class PlaybackMode { CONTINUOUS, REPEAT_AYAH, PAGE_ONLY, MEMORIZE }

/// Available speeds, like the iOS speed chips.
val PlaybackSpeeds = listOf(0.75f, 1f, 1.25f, 1.5f, 2f)

/// Ayah-by-ayah recitation, continuous through the surah — streams from
/// EveryAyah with the mirrors fallback, like the iOS player. Runs alongside
/// NoorAudioService (foreground MediaSession) so audio survives backgrounding.
object NoorPlayer {
    var reciter by mutableStateOf(Reciters.all[0])
        private set
    var currentSurah by mutableStateOf(0)
    var currentAyah by mutableStateOf(0)
    var surahName by mutableStateOf("")
    var isPlaying by mutableStateOf(false)
    /// True from ayah request until audio actually starts — drives the
    /// pill's buffering spinner so downloads are visible to the user.
    var isBuffering by mutableStateOf(false)
    var mode by mutableStateOf(PlaybackMode.CONTINUOUS)
        private set
    var speed by mutableFloatStateOf(1f)
        private set

    /// Sleep timer deadline (epoch millis, 0 = off) — like iOS sleepDeadline.
    var sleepDeadline by androidx.compose.runtime.mutableLongStateOf(0L)
        private set
    /// Stop when the surah ends (iOS "End of surah" sleep chip).
    var stopAfterSurah by mutableStateOf(false)

    /// Memorize loop (iOS MemorizeRangeSheet): ayah range + repeats per ayah.
    var memorizeStart by mutableStateOf(1)
        private set
    var memorizeEnd by mutableStateOf(5)
        private set
    var memorizePerAyah by mutableStateOf(3)
        private set
    private var memorizeDone = 0

    /// Last ayah of the page playback started on ("this page only" mode).
    private var pageEndAyah = 0

    private var ayahCount = 0
    val currentAyahCount: Int get() = ayahCount
    private var media: MediaPlayer? = null
    /// Last surah:ayah given a second chance after both hosts failed.
    private var retriedAyah: Pair<Int, Int>? = null
    private var appContext: Context? = null
    private val handler by lazy { android.os.Handler(android.os.Looper.getMainLooper()) }
    private val sleepStop = Runnable { stop() }

    // MARK: - audio focus (iOS: AVAudioSession .playback category + interruption
    // notifications). Share the speaker politely: pause for calls / other
    // players, duck under navigation prompts, resume when focus returns.

    private val audioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build()
    private var hasFocus = false
    /// True while paused by a transient loss so GAIN resumes only what we paused.
    private var pausedByFocusLoss = false
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        val player = media ?: return@OnAudioFocusChangeListener
        when (change) {
            AudioManager.AUDIOFOCUS_LOSS -> {
                // Another app took over for good — pause and let go; the user
                // resumes from the pill/notification (which re-requests focus).
                pausedByFocusLoss = false
                if (isPlaying) pause()
                abandonFocus()
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                // Flag AFTER pause() — pause() clears it (see its doc).
                if (isPlaying) { pause(); pausedByFocusLoss = true }
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK ->
                runCatching { player.setVolume(0.2f, 0.2f) }
            AudioManager.AUDIOFOCUS_GAIN -> {
                runCatching { player.setVolume(1f, 1f) }
                if (pausedByFocusLoss) { pausedByFocusLoss = false; resume() }
            }
        }
    }
    private val focusRequest: AudioFocusRequest by lazy {
        AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(audioAttributes)
            .setOnAudioFocusChangeListener(focusListener, handler)
            .build()
    }

    /// Requests focus (idempotent). False means the system refused — e.g. an
    /// active phone call — so playback must not start.
    private fun requestFocus(): Boolean {
        if (hasFocus) return true
        val manager = appContext?.getSystemService(AudioManager::class.java) ?: return true
        hasFocus = manager.requestAudioFocus(focusRequest) ==
            AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        return hasFocus
    }

    private fun abandonFocus() {
        if (!hasFocus) return
        hasFocus = false
        appContext?.getSystemService(AudioManager::class.java)
            ?.abandonAudioFocusRequest(focusRequest)
    }

    /// Called once from MainActivity — restores persisted choices.
    fun init(context: Context) {
        if (appContext != null) return
        appContext = context.applicationContext
        val prefs = context.getSharedPreferences("audio", Context.MODE_PRIVATE)
        reciter = Reciters.byId(prefs.getString("reciter", "alafasy") ?: "alafasy")
        speed = prefs.getFloat("speed", 1f)
    }

    /// User actions only — never call from a compose observer.
    fun selectReciter(r: ReciterA) {
        reciter = r
        appContext?.getSharedPreferences("audio", Context.MODE_PRIVATE)
            ?.edit()?.putString("reciter", r.id)?.apply()
        // Restart the current ayah with the new voice.
        if (currentSurah != 0) playAyah(currentSurah, currentAyah)
    }

    fun selectSpeed(value: Float) {
        speed = value
        appContext?.getSharedPreferences("audio", Context.MODE_PRIVATE)
            ?.edit()?.putFloat("speed", value)?.apply()
        applySpeed()
    }

    fun selectMode(value: PlaybackMode) {
        mode = value
        if (value != PlaybackMode.MEMORIZE) memorizeDone = 0
    }

    /// iOS setSleepTimer(minutes:) — null cancels.
    fun setSleepTimer(minutes: Int?) {
        handler.removeCallbacks(sleepStop)
        if (minutes == null) { sleepDeadline = 0L; return }
        sleepDeadline = System.currentTimeMillis() + minutes * 60_000L
        handler.postDelayed(sleepStop, minutes * 60_000L)
    }

    /// iOS startMemorize(start:end:perAyah:) — loops the range, repeating
    /// each ayah perAyah times.
    fun startMemorize(start: Int, end: Int, perAyah: Int) {
        memorizeStart = start.coerceAtLeast(1)
        memorizeEnd = end.coerceAtLeast(memorizeStart)
        memorizePerAyah = perAyah.coerceAtLeast(1)
        memorizeDone = 0
        mode = PlaybackMode.MEMORIZE
        if (currentSurah != 0) playAyah(currentSurah, memorizeStart)
    }

    /// Takes the reciter explicitly (not `reciter`) so the URL and the cache
    /// path for one request always come from the same snapshot, even if the
    /// user switches reciter while a download is in flight.
    private fun url(host: String, voice: ReciterA, surah: Int, ayah: Int) =
        "%s/%s/%03d%03d.mp3".format(java.util.Locale.ROOT, host, voice.folder, surah, ayah)

    // MARK: - ayah cache + prefetch (iOS: every ayah cached after first
    // play; the next few download while the current one plays, so
    // advancing is instant and replays work offline).

    private val prefetchPool = java.util.concurrent.Executors.newFixedThreadPool(2)

    private fun cacheFile(voice: ReciterA, surah: Int, ayah: Int): java.io.File {
        val dir = java.io.File(appContext!!.cacheDir,
            "recitations/${voice.folder}").apply { mkdirs() }
        return java.io.File(dir,
            "%03d%03d.mp3".format(java.util.Locale.ROOT, surah, ayah))
    }

    /// Downloads one ayah to the cache (main host, then mirror). Quiet —
    /// failures just mean that ayah streams when its turn comes.
    private fun download(voice: ReciterA, surah: Int, ayah: Int): Boolean {
        val target = cacheFile(voice, surah, ayah)
        if (target.length() > 1024) return true
        for (host in listOf("https://everyayah.com/data",
                            "https://mirrors.quranicaudio.com/everyayah")) {
            try {
                val temp = java.io.File.createTempFile("ayah", ".mp3", target.parentFile)
                val connection = java.net.URL(url(host, voice, surah, ayah))
                    .openConnection() as java.net.HttpURLConnection
                connection.connectTimeout = 10_000
                connection.readTimeout = 20_000
                // Only cache a real, complete audio body: a captive-portal
                // HTML page or a stream cut short would otherwise be saved
                // and replayed (and fail) forever.
                val type = connection.contentType.orEmpty().lowercase(java.util.Locale.ROOT)
                val ok = connection.responseCode == 200 &&
                    (type.startsWith("audio/") || type.startsWith("application/octet-stream"))
                val copied = if (ok) connection.inputStream.use { input ->
                    temp.outputStream().use { input.copyTo(it) }
                } else -1L
                val expected = connection.contentLengthLong
                connection.disconnect()
                if (ok && copied > 1024 && (expected <= 0 || copied == expected)) {
                    if (temp.renameTo(target)) return true
                }
                temp.delete()
            } catch (_: Exception) { /* try mirror / stream later */ }
        }
        return false
    }

    /// The cached recitation file for one ayah of the current reciter,
    /// downloading it first if needed (main host, then mirror). Null when
    /// it is not cached and cannot be fetched (offline). Runs on IO.
    suspend fun ensureAyahFile(surah: Int, ayah: Int): java.io.File? =
        kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
            val voice = reciter
            if (download(voice, surah, ayah)) cacheFile(voice, surah, ayah) else null
        }

    /// Warm the next few ayat while the current one plays. `includeCurrent`
    /// also saves the ayah being streamed right now: without it the ayah the
    /// user pressed play on is the one ayah never cached, so replaying it
    /// buffers from the network every time (advanced-to ayat were prefetched).
    private fun prefetch(
        voice: ReciterA,
        surah: Int,
        fromAyah: Int,
        includeCurrent: Boolean = false,
    ) {
        for (ayah in (if (includeCurrent) fromAyah else fromAyah + 1)..minOf(fromAyah + 3, ayahCount)) {
            prefetchPool.execute {
                // Skip stale work if the user already moved on to another
                // voice; `voice` itself guarantees path and URL agree.
                if (reciter.id == voice.id) download(voice, surah, ayah)
            }
        }
    }

    fun play(surah: Int, ayahCount: Int, fromAyah: Int, name: String, pageEnd: Int = 0) {
        // Warm the surah table off-main so the next-surah hand-off at the end
        // of a continuous surah never queries the DB on the main thread.
        if (surahMeta == null) prefetchPool.execute { surahInfo(surah) }
        this.ayahCount = ayahCount
        surahName = name
        pageEndAyah = pageEnd
        memorizeDone = 0
        playAyah(surah, fromAyah)
        if (currentSurah != 0) startService()  // focus denied → nothing to keep alive
    }

    /// `skipCache` ignores any cached copy for this attempt — set after a
    /// cached file failed to play, so a delete that did not take (read-only
    /// or busy file) cannot bounce playAyah back onto the same bad file.
    private fun playAyah(
        surah: Int,
        ayah: Int,
        mirror: Boolean = false,
        skipCache: Boolean = false,
    ) {
        currentSurah = surah; currentAyah = ayah
        // Resume point for the Today "continue listening" card — written
        // from user-driven playback only, never from a compose observer.
        appContext?.getSharedPreferences("audio", Context.MODE_PRIVATE)?.edit()
            ?.putInt("audio.lastSurah", surah)?.putInt("audio.lastAyah", ayah)?.apply()
        media?.release()
        if (!requestFocus()) { media = null; stop(); return }
        val host = if (mirror) "https://mirrors.quranicaudio.com/everyayah"
                   else "https://everyayah.com/data"
        val voice = reciter  // one snapshot for cache path, URL and prefetch
        // Set below, before prepareAsync(); read by the error listener so a
        // corrupt cached file is deleted rather than replayed on every retry.
        var cachedSource: java.io.File? = null
        var playedFromCache = false
        media = MediaPlayer().apply {
            setAudioAttributes(audioAttributes)
            setOnPreparedListener {
                it.start()
                NoorPlayer.isPlaying = true
                NoorPlayer.isBuffering = false
                applySpeed()
                NoorAudioService.refresh(appContext)
                // Warm the ayat ahead while this one plays — and this ayah
                // itself when it was streamed, so the replay is instant.
                prefetch(voice, surah, ayah, includeCurrent = !playedFromCache)
            }
            setOnCompletionListener {
                if (sleepDeadline != 0L && System.currentTimeMillis() >= sleepDeadline) {
                    stop(); return@setOnCompletionListener
                }
                // "End of surah" chip: stop once the current mode reaches the
                // end of what it plays, instead of repeating/looping again.
                if (stopAfterSurah && atModeEnd()) {
                    stop(); return@setOnCompletionListener  // stop() clears the chip
                }
                when (mode) {
                    PlaybackMode.REPEAT_AYAH -> playAyah(surah, ayah)
                    PlaybackMode.MEMORIZE -> {
                        memorizeDone += 1
                        when {
                            memorizeDone < memorizePerAyah -> playAyah(surah, ayah)
                            ayah < minOf(memorizeEnd, ayahCount) -> {
                                memorizeDone = 0
                                playAyah(surah, ayah + 1)
                            }
                            else -> {
                                // Loop the range again from the start.
                                memorizeDone = 0
                                playAyah(surah, memorizeStart)
                            }
                        }
                    }
                    PlaybackMode.PAGE_ONLY -> {
                        val last = if (pageEndAyah in 1..ayahCount) pageEndAyah else ayahCount
                        if (currentAyah < last) playAyah(surah, currentAyah + 1) else stop()
                    }
                    PlaybackMode.CONTINUOUS ->
                        if (currentAyah < ayahCount) playAyah(surah, currentAyah + 1)
                        else advanceToNextSurah()
                }
            }
            setOnErrorListener { _, _, _ ->
                // Bad cache file → drop it and stream; host → mirror → one
                // delayed retry (transient network), then stop. Never
                // strand playback on a hiccup.
                when {
                    playedFromCache -> {
                        cachedSource?.delete()
                        playAyah(surah, ayah, skipCache = true)
                    }
                    !mirror -> playAyah(surah, ayah, mirror = true)
                    retriedAyah != surah to ayah -> {
                        retriedAyah = surah to ayah
                        handler.postDelayed({
                            if (currentSurah == surah && currentAyah == ayah) {
                                playAyah(surah, ayah)
                            }
                        }, 2500)
                    }
                    else -> stop()
                }
                true
            }
            // Cached copy plays instantly (and offline); otherwise stream
            // and let the cache warm via prefetch for next time.
            cachedSource = runCatching { cacheFile(voice, surah, ayah) }.getOrNull()
            playedFromCache = !skipCache && cachedSource?.let { it.length() > 1024 } == true
            if (playedFromCache) {
                setDataSource(cachedSource!!.path)
            } else {
                setDataSource(url(host, voice, surah, ayah))
            }
            NoorPlayer.isBuffering = true
            prepareAsync()
        }
        NoorAudioService.refresh(appContext)
    }

    /// PlaybackParams throws unless the player is prepared; guard with isPlaying.
    private fun applySpeed() {
        val player = media ?: return
        if (!isPlaying) return
        try {
            player.playbackParams = player.playbackParams.setSpeed(speed)
        } catch (_: IllegalStateException) { /* not yet prepared */ }
    }

    fun toggle() { if (isPlaying) pause() else resume() }

    /// Pauses without touching focus — used by the user, by focus loss and
    /// by the becoming-noisy receiver (headphones unplugged). `pause()` clears
    /// the auto-resume flag so a user-initiated pause is never undone by a
    /// later AUDIOFOCUS_GAIN; the transient-loss path re-arms it afterwards.
    fun pause() {
        val player = media ?: return
        if (!isPlaying) return
        pausedByFocusLoss = false
        player.pause()
        isPlaying = false
        NoorAudioService.refresh(appContext)
    }

    fun resume() {
        val player = media ?: return
        if (isPlaying || !requestFocus()) return
        player.start(); applySpeed()
        isPlaying = true
        resyncRequest++  // deliberate user action: follow the recitation again
        NoorAudioService.refresh(appContext)
    }

    /// True when the ayah that just finished is the last one the current mode
    /// would play before looping or advancing — the "End of surah" stop point.
    private fun atModeEnd(): Boolean = when (mode) {
        // A single repeated ayah has no further ayah: stop after this pass.
        PlaybackMode.REPEAT_AYAH -> true
        // Let the last ayah of the range finish its repeats first.
        PlaybackMode.MEMORIZE ->
            currentAyah >= minOf(memorizeEnd, ayahCount) &&
                memorizeDone + 1 >= memorizePerAyah
        PlaybackMode.PAGE_ONLY ->
            currentAyah >= (if (pageEndAyah in 1..ayahCount) pageEndAyah else ayahCount)
        PlaybackMode.CONTINUOUS -> currentAyah >= ayahCount
    }

    /// Surah metadata for the next-surah flow, read once from the bundled DB
    /// (iOS gets the same from the reader's `surahAdvance` closure; reading
    /// the DB here means every entry point flows, not only the reader).
    /// Written from the prefetch pool, read on the main thread at surah end.
    @Volatile private var surahMeta: List<Surah>? = null

    private fun surahInfo(id: Int): Surah? {
        val context = appContext ?: return null
        val list = surahMeta
            ?: runCatching { QuranDb.get(context).surahs() }.getOrNull()?.also { surahMeta = it }
        return list?.firstOrNull { it.id == id }
    }

    /// End of the surah in continuous mode: roll into the next one (iOS
    /// QuranAudioPlayer.advanceAfterFinish). The "End of surah" chip is
    /// checked before this, so it still stops here when the user asked it to.
    private fun advanceToNextSurah() {
        val next = surahInfo(currentSurah + 1)
        if (next == null) { stop(); return }  // end of the mushaf
        ayahCount = next.ayahCount
        surahName = next.nameArabic
        pageEndAyah = 0
        memorizeDone = 0
        playAyah(next.id, 1)
    }

    fun next() {
        if (currentAyah < ayahCount) playAyah(currentSurah, currentAyah + 1)
        else if (mode == PlaybackMode.CONTINUOUS) advanceToNextSurah()
        resyncRequest++
    }

    fun previous() {
        if (currentAyah > 1) playAyah(currentSurah, currentAyah - 1)
        resyncRequest++
    }

    /// Bumped whenever the user drives the player by hand (transport buttons,
    /// resume, or tapping the pill's ayah reference). The reader watches this
    /// and snaps back to the ayah being recited — swiping pages away from the
    /// recitation stops the auto page-flip, and this is how it is re-armed.
    var resyncRequest by mutableStateOf(0)
        private set

    /// "Take me back to what is playing" — used by the pill's ayah reference.
    fun syncToCurrent() { if (currentSurah != 0) resyncRequest++ }

    fun stop() {
        media?.release(); media = null
        pausedByFocusLoss = false
        abandonFocus()
        isPlaying = false; isBuffering = false; currentSurah = 0; currentAyah = 0
        handler.removeCallbacks(sleepStop)
        sleepDeadline = 0L
        stopAfterSurah = false
        appContext?.let { it.stopService(Intent(it, NoorAudioService::class.java)) }
    }

    private fun startService() {
        val context = appContext ?: return
        val intent = Intent(context, NoorAudioService::class.java)
        if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent)
        else context.startService(intent)
    }
}
