package com.engagendy.noor

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
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
    private var appContext: Context? = null
    private val handler by lazy { android.os.Handler(android.os.Looper.getMainLooper()) }
    private val sleepStop = Runnable { stop() }

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

    private fun url(host: String, surah: Int, ayah: Int) =
        "%s/%s/%03d%03d.mp3".format(host, reciter.folder, surah, ayah)

    fun play(surah: Int, ayahCount: Int, fromAyah: Int, name: String, pageEnd: Int = 0) {
        this.ayahCount = ayahCount
        surahName = name
        pageEndAyah = pageEnd
        memorizeDone = 0
        playAyah(surah, fromAyah)
        startService()
    }

    private fun playAyah(surah: Int, ayah: Int, mirror: Boolean = false) {
        currentSurah = surah; currentAyah = ayah
        // Resume point for the Today "continue listening" card — written
        // from user-driven playback only, never from a compose observer.
        appContext?.getSharedPreferences("audio", Context.MODE_PRIVATE)?.edit()
            ?.putInt("audio.lastSurah", surah)?.putInt("audio.lastAyah", ayah)?.apply()
        media?.release()
        val host = if (mirror) "https://mirrors.quranicaudio.com/everyayah"
                   else "https://everyayah.com/data"
        media = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
            setOnPreparedListener {
                it.start()
                NoorPlayer.isPlaying = true
                applySpeed()
                NoorAudioService.refresh(appContext)
            }
            setOnCompletionListener {
                if (sleepDeadline != 0L && System.currentTimeMillis() >= sleepDeadline) {
                    stop(); return@setOnCompletionListener
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
                        else stop()  // stopAfterSurah: surah end always stops here
                }
            }
            setOnErrorListener { _, _, _ ->
                if (!mirror) playAyah(surah, ayah, mirror = true) else stop()
                true
            }
            setDataSource(url(host, surah, ayah))
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

    fun toggle() {
        val player = media ?: return
        if (isPlaying) player.pause() else { player.start(); applySpeed() }
        isPlaying = !isPlaying
        NoorAudioService.refresh(appContext)
    }

    fun next() { if (currentAyah < ayahCount) playAyah(currentSurah, currentAyah + 1) }
    fun previous() { if (currentAyah > 1) playAyah(currentSurah, currentAyah - 1) }

    fun stop() {
        media?.release(); media = null
        isPlaying = false; currentSurah = 0; currentAyah = 0
        handler.removeCallbacks(sleepStop)
        sleepDeadline = 0L
        appContext?.let { it.stopService(Intent(it, NoorAudioService::class.java)) }
    }

    private fun startService() {
        val context = appContext ?: return
        val intent = Intent(context, NoorAudioService::class.java)
        if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent)
        else context.startService(intent)
    }
}
