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
import kotlinx.coroutines.async

/// One EveryAyah reciter — 1:1 port of the iOS `Reciter` enum
/// (Modules/QuranAudio/Sources/QuranAudio/Reciter.swift).
data class ReciterA(
    val id: String,
    val nameEnglish: String,
    val nameArabic: String,
    val flag: String,
    val folder: String,
    val riwayah: Riwayah = Riwayah.HAFS,
    /// Quran Foundation per-ayah path on verses.quran.foundation (verified
    /// 2026-10-03); null = not hosted there. Mirrors iOS `quranFoundationPath`.
    val qfPath: String? = null,
    /// Islamic Network CDN "bitrate/edition" (verified 2026-10-03); null =
    /// not hosted there. Mirrors iOS `islamicNetworkEdition`.
    val inEdition: String? = null,
)

/// Riwayah of a recitation. The mushaf text is always Hafs; Warsh readers
/// are EveryAyah sets with Hafs ayah numbering, so the same files line up.
enum class Riwayah { HAFS, WARSH }

/// Translated readings played after each Arabic ayah (EveryAyah folders,
/// same host + numbering scheme as the reciters). NONE = off.
enum class TranslationVoice(
    val folder: String,
    val nameEnglish: String,
    val nameArabic: String,
    /// Islamic Network CDN "bitrate/edition" fallback (verified 2026-10-03).
    val inEdition: String? = null,
) {
    NONE("", "Off", "إيقاف"),
    ENGLISH("English/Sahih_Intnl_Ibrahim_Walk_192kbps",
            "English · Ibrahim Walk", "الإنجليزية · إبراهيم ووك", "192/en.walk"),
    URDU("translations/urdu_shamshad_ali_khan_46kbps",
         "Urdu · Shamshad Ali Khan", "الأردية · شمشاد علي خان", "64/ur.khan"),
    PERSIAN("translations/Fooladvand_Hedayatfar_40Kbps",
            "Persian · Fooladvand", "الفارسية · فولادوند", "40/fa.hedayatfarfooladvand"),
    BOSNIAN("translations/besim_korkut_ajet_po_ajet",
            "Bosnian · Besim Korkut", "البوسنية · بسيم كوركوت"),
    AZERBAIJANI("translations/azerbaijani/balayev",
                "Azerbaijani · Balayev", "الأذربيجانية · بالاييف");

    companion object {
        fun byName(name: String?): TranslationVoice =
            entries.firstOrNull { it.name == name } ?: NONE
    }
}

/// Where ayah-by-ayah audio comes from — 1:1 with iOS `AudioSources` /
/// `HostHealth` (Modules/QuranAudio/Sources/QuranAudio/AudioSources.swift).
///
/// Four independent hosts serve the same per-ayah files (see LICENSES.md):
/// EveryAyah, its quranicaudio mirror, the Quran Foundation verse CDN and
/// the Islamic Network CDN. The first two cover every reciter; the last two
/// cover the popular ones. On 2026-10-03 both EveryAyah hosts refused
/// connections for hours while the other two answered in ~100 ms, which is
/// why playback never depends on a single host.
object AudioSources {
    const val EVERY_AYAH = "https://everyayah.com/data"
    const val EVERY_AYAH_MIRROR = "https://mirrors.quranicaudio.com/everyayah"
    const val QURAN_FOUNDATION = "https://verses.quran.foundation"
    const val ISLAMIC_NETWORK = "https://cdn.islamic.network/quran/audio"

    /// Hosts that failed recently are tried LAST for this long.
    const val COOLDOWN_MS = 90_000L
    /// A streamed ayah that has not started within this long moves on to
    /// the next host — the "slow" case, as opposed to the "down" case.
    const val PREPARE_TIMEOUT_MS = 12_000L

    /// Ayah count of every surah, in mushaf order (metadata only, not text;
    /// identical to the `surah.ayah_count` column of the bundled DB).
    val ayahCounts = intArrayOf(
        7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128, 111, 110, 98, 135,
        112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73, 54, 45, 83, 182, 88, 75, 85,
        54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13,
        14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42,
        29, 19, 36, 25, 22, 17, 19, 26, 30, 20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11,
        11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6,
    )

    /// 1-based position of the ayah in the whole mushaf (1:1 → 1, 114:6 → 6236).
    fun globalAyahNumber(surah: Int, ayah: Int): Int {
        var total = ayah
        for (index in 0 until (surah - 1).coerceIn(0, ayahCounts.size)) total += ayahCounts[index]
        return total
    }

    private fun fileName(surah: Int, ayah: Int) =
        "%03d%03d.mp3".format(java.util.Locale.ROOT, surah, ayah)

    /// Every URL that may serve this file, in preference order: EveryAyah,
    /// its mirror (same layout), then the Quran Foundation and Islamic
    /// Network CDNs when the voice behind `folder` is hosted there.
    fun candidates(folder: String, surah: Int, ayah: Int): List<String> {
        val file = "$folder/${fileName(surah, ayah)}"
        val list = mutableListOf("$EVERY_AYAH/$file", "$EVERY_AYAH_MIRROR/$file")
        val reciter = Reciters.all.firstOrNull { it.folder == folder }
        val voice = TranslationVoice.entries.firstOrNull { it != TranslationVoice.NONE && it.folder == folder }
        reciter?.qfPath?.let { list += "$QURAN_FOUNDATION/$it/mp3/${fileName(surah, ayah)}" }
        (reciter?.inEdition ?: voice?.inEdition)?.let {
            list += "$ISLAMIC_NETWORK/$it/${globalAyahNumber(surah, ayah)}.mp3"
        }
        return list
    }

    // MARK: - host health (in-memory; a blip must not outlive the session)

    private val downUntil = HashMap<String, Long>()

    private fun host(url: String): String = runCatching { java.net.URI(url).host }.getOrNull() ?: url

    fun markDown(url: String) {
        synchronized(downUntil) { downUntil[host(url)] = System.currentTimeMillis() + COOLDOWN_MS }
    }

    fun markUp(url: String) {
        synchronized(downUntil) { downUntil.remove(host(url)) }
    }

    fun isDown(url: String): Boolean = synchronized(downUntil) {
        val until = downUntil[host(url)] ?: return false
        if (until <= System.currentTimeMillis()) { downUntil.remove(host(url)); return false }
        true
    }

    /// Same candidates, healthy hosts first (relative order preserved).
    fun ordered(urls: List<String>): List<String> =
        urls.filterNot(::isDown) + urls.filter(::isDown)
}

/// Full verified EveryAyah roster — same entries and folders as iOS,
/// with the extra hosts (`qfPath`, `inEdition`) resolved by `AudioSources`.
object Reciters {
    val all = listOf(
        ReciterA("alafasy", "Mishary Alafasy", "مشاري العفاسي", "🇰🇼", "Alafasy_128kbps",
                 qfPath = "Alafasy",
                 inEdition = "128/ar.alafasy"),
        ReciterA("husary", "Mahmoud Al-Husary", "محمود خليل الحصري", "🇪🇬", "Husary_128kbps",
                 inEdition = "128/ar.husary"),
        ReciterA("minshawi", "Mohamed Al-Minshawi", "محمد صديق المنشاوي", "🇪🇬", "Minshawy_Murattal_128kbps",
                 qfPath = "Minshawi/Murattal",
                 inEdition = "128/ar.minshawi"),
        ReciterA("abdulBasit", "Abdul Basit (Murattal)", "عبد الباسط عبد الصمد", "🇪🇬", "Abdul_Basit_Murattal_192kbps",
                 qfPath = "AbdulBaset/Murattal",
                 inEdition = "192/ar.abdulbasitmurattal"),
        ReciterA("ghamdi", "Saad Al-Ghamdi", "سعد الغامدي", "🇸🇦", "Ghamadi_40kbps"),
        ReciterA("sudais", "Abdurrahman As-Sudais", "عبد الرحمن السديس", "🇸🇦", "Abdurrahmaan_As-Sudais_192kbps",
                 qfPath = "Sudais",
                 inEdition = "192/ar.abdurrahmaansudais"),
        ReciterA("muaiqly", "Maher Al-Muaiqly", "ماهر المعيقلي", "🇸🇦", "Maher_AlMuaiqly_64kbps",
                 inEdition = "128/ar.mahermuaiqly"),
        ReciterA("shuraym", "Saud Ash-Shuraym", "سعود الشريم", "🇸🇦", "Saood_ash-Shuraym_128kbps",
                 qfPath = "Shuraym",
                 inEdition = "64/ar.saoodshuraym"),
        ReciterA("ayyoub", "Muhammad Ayyoub", "محمد أيوب", "🇸🇦", "Muhammad_Ayyoub_128kbps",
                 inEdition = "128/ar.muhammadayyoub"),
        ReciterA("shatri", "Abu Bakr Ash-Shatri", "أبو بكر الشاطري", "🇸🇦", "Abu_Bakr_Ash-Shaatree_128kbps",
                 qfPath = "Shatri",
                 inEdition = "128/ar.shaatree"),
        ReciterA("rifai", "Hani Ar-Rifai", "هاني الرفاعي", "🇸🇦", "Hani_Rifai_192kbps",
                 qfPath = "Rifai",
                 inEdition = "64/ar.hanirifai"),
        ReciterA("hudhaify", "Ali Al-Hudhaify", "علي الحذيفي", "🇸🇦", "Hudhaify_128kbps",
                 inEdition = "128/ar.hudhaify"),
        ReciterA("jibreel", "Muhammad Jibreel", "محمد جبريل", "🇪🇬", "Muhammad_Jibreel_128kbps",
                 qfPath = "Jibreel",
                 inEdition = "128/ar.muhammadjibreel"),
        ReciterA("dussary", "Yasser Ad-Dussary", "ياسر الدوسري", "🇸🇦", "Yasser_Ad-Dussary_128kbps"),
        ReciterA("basfar", "Abdullah Basfar", "عبد الله بصفر", "🇸🇦", "Abdullah_Basfar_192kbps",
                 inEdition = "192/ar.abdullahbasfar"),
        ReciterA("sowaid", "Ayman Sowaid", "أيمن سويد", "🇸🇾", "Ayman_Sowaid_64kbps",
                 inEdition = "64/ar.aymanswoaid"),
        ReciterA("tablawi", "Mohammad At-Tablawi", "محمد الطبلاوي", "🇪🇬", "Mohammad_al_Tablaway_128kbps"),
        ReciterA("abdulBasitMujawwad", "Abdul Basit (Mujawwad)", "عبد الباسط (مجوّد)", "🇪🇬", "Abdul_Basit_Mujawwad_128kbps",
                 qfPath = "AbdulBaset/Mujawwad"),
        ReciterA("minshawiMujawwad", "Al-Minshawi (Mujawwad)", "المنشاوي (مجوّد)", "🇪🇬", "Minshawy_Mujawwad_192kbps",
                 qfPath = "Minshawi/Mujawwad",
                 inEdition = "64/ar.minshawimujawwad"),
        ReciterA("salamah", "Yaser Salamah", "ياسر سلامة", "🇪🇬", "Yaser_Salamah_128kbps"),
        ReciterA("qatami", "Nasser Al-Qatami", "ناصر القطامي", "🇸🇦", "Nasser_Alqatami_128kbps"),
        ReciterA("faresAbbad", "Fares Abbad", "فارس عباد", "🇾🇪", "Fares_Abbad_64kbps"),
        ReciterA("ajamy", "Ahmed Al-Ajmi", "أحمد العجمي", "🇸🇦", "Ahmed_ibn_Ali_al-Ajamy_64kbps_QuranExplorer.Com",
                 inEdition = "128/ar.ahmedajamy"),
        ReciterA("muhsinQasim", "Muhsin Al-Qasim", "محسن القاسم", "🇸🇦", "Muhsin_Al_Qasim_192kbps"),
        ReciterA("juhany", "Abdullah Al-Juhany", "عبد الله الجهني", "🇸🇦", "Abdullaah_3awwaad_Al-Juhaynee_128kbps"),
        ReciterA("bukhatir", "Salah Bukhatir", "صلاح بوخاطر", "🇦🇪", "Salaah_AbdulRahman_Bukhatir_128kbps"),
        ReciterA("budair", "Salah Al-Budair", "صلاح البدير", "🇸🇦", "Salah_Al_Budair_128kbps"),
        ReciterA("aliJaber", "Ali Jaber", "علي جابر", "🇸🇦", "Ali_Jaber_64kbps"),
        ReciterA("banna", "Mahmoud Ali Al-Banna", "محمود علي البنا", "🇪🇬", "mahmoud_ali_al_banna_32kbps"),
        ReciterA("matroud", "Abdullah Al-Matroud", "عبد الله المطرود", "🇸🇦", "Abdullah_Matroud_128kbps"),
        ReciterA("abdulKareem", "Muhammad Abdul-Kareem", "محمد عبد الكريم", "", "Muhammad_AbdulKareem_128kbps"),
        ReciterA("husaryMuallim", "Al-Husary (Muallim)", "الحصري (المعلّم)", "🇪🇬", "Husary_Muallim_128kbps"),
        ReciterA("mustafaIsmail", "Mustafa Ismail", "مصطفى إسماعيل", "🇪🇬", "Mustafa_Ismail_48kbps"),
        ReciterA("khalidQahtani", "Khalid Al-Qahtani", "خالد القحطاني", "🇸🇦", "Khaalid_Abdullaah_al-Qahtaanee_192kbps"),
        ReciterA("sahlYassin", "Sahl Yassin", "سهل ياسين", "🇸🇦", "Sahl_Yassin_128kbps"),
        ReciterA("suesy", "Ali Hajjaj Al-Suesy", "علي حجاج السويسي", "🇪🇬", "Ali_Hajjaj_AlSuesy_128kbps"),
        ReciterA("neana", "Ahmed Neana", "أحمد نعينع", "🇪🇬", "Ahmed_Neana_128kbps"),
        ReciterA("alaqimy", "Akram Al-Alaqimy", "أكرم العلاقمي", "🇾🇪", "Akram_AlAlaqimy_128kbps"),
        ReciterA("tunaiji", "Khalifa Al-Tunaiji", "خليفة الطنيجي", "🇦🇪", "khalefa_al_tunaiji_64kbps"),
        ReciterA("akhdar", "Ibrahim Al-Akhdar", "إبراهيم الأخضر", "🇸🇦", "Ibrahim_Akhdar_32kbps",
                 inEdition = "32/ar.ibrahimakhbar"),
        ReciterA("alili", "Aziz Alili", "عزيز عليلي", "🇧🇦", "aziz_alili_128kbps"),
        // Warsh 'an Nafi' — Hafs-numbered EveryAyah files (verified).
        ReciterA("dosaryWarsh", "Ibrahim Al-Dosary (Warsh)", "إبراهيم الدوسري (ورش)", "🇸🇦",
                 "warsh/warsh_ibrahim_aldosary_128kbps", Riwayah.WARSH),
        ReciterA("jazaeryWarsh", "Yassin Al-Jazaery (Warsh)", "ياسين الجزائري (ورش)", "🇩🇿",
                 "warsh/warsh_yassin_al_jazaery_64kbps", Riwayah.WARSH),
    )

    val hafs: List<ReciterA> get() = all.filter { it.riwayah == Riwayah.HAFS }
    val warsh: List<ReciterA> get() = all.filter { it.riwayah == Riwayah.WARSH }

    fun byId(id: String): ReciterA = all.firstOrNull { it.id == id } ?: all[0]
}

/// Same four modes as the iOS QuranAudioPlayer.PlaybackMode.
enum class PlaybackMode { CONTINUOUS, REPEAT_AYAH, PAGE_ONLY, MEMORIZE }

/// Available speeds, like the iOS speed chips.
val PlaybackSpeeds = listOf(0.75f, 1f, 1.25f, 1.5f, 2f)

/// Ayah-by-ayah recitation, continuous through the surah — streams from
/// EveryAyah with the CDN fallbacks (`AudioSources`), like the iOS player. Runs alongside
/// NoorAudioService (foreground MediaSession) so audio survives backgrounding.
object NoorPlayer {
    var reciter by mutableStateOf(Reciters.all[0])
        private set
    /// Translated reading played after each Arabic ayah (NONE = off).
    var translation by mutableStateOf(TranslationVoice.NONE)
        private set
    /// True while the translation segment of the current ayah is playing —
    /// the pill / notification then show the translation voice's name.
    var isPlayingTranslation by mutableStateOf(false)
        private set
    var currentSurah by mutableStateOf(0)
    var currentAyah by mutableStateOf(0)
    var surahName by mutableStateOf("")
    var isPlaying by mutableStateOf(false)
    /// True from ayah request until audio actually starts — drives the
    /// pill's buffering spinner so downloads are visible to the user.
    var isBuffering by mutableStateOf(false)
    /// What the USER wants, as opposed to [isPlaying], which is what the
    /// MediaPlayer is actually doing. While an ayah is still preparing there
    /// is no started player to pause, so a tap in that window has to be
    /// remembered here — otherwise `onPrepared` starts audio that was already
    /// cancelled, and the pill shows the wrong icon.
    private var wantsPlayback = true
    /// MediaPlayer.start() before onPrepared throws IllegalStateException;
    /// the pill is tappable while buffering, so guard every start with this.
    private var prepared = false
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
    /// Repeats of the current ayah already played in MEMORIZE mode — Compose
    /// state so the kids reader can show "repeat 2 of 3" live.
    var memorizeDone by mutableStateOf(0)
        private set

    /// Called (on the main thread) when playback stops because it reached the
    /// end of what the current mode plays with `stopAfterSurah` set. Kids mode
    /// awards its star here; null everywhere else.
    var onSurahFinished: ((Int) -> Unit)? = null

    /// Last ayah of the page playback started on ("this page only" mode).
    private var pageEndAyah = 0

    private var ayahCount = 0
    val currentAyahCount: Int get() = ayahCount

    // MARK: Surah-wide progress (media notification / lock screen)

    /// Rolling mean length of an ayah in the surah being recited, in ms.
    /// Ayah-by-ayah playback has no single file to measure, so the surah's
    /// total is estimated as mean × ayahCount and refined as ayat play —
    /// a bar that measured ONE ayah refilled every few seconds and said
    /// nothing about where in the surah you were. (iOS: meanAyahSeconds.)
    private var measuredMs = 0L
    private val measuredAyat = HashSet<Int>()
    private val meanAyahMs: Long?
        get() = if (measuredAyat.isEmpty()) null else measuredMs / measuredAyat.size

    /// Verified DB text of the ayah being recited — the notification title,
    /// so the words scroll on the lock screen. Cached per surah and loaded
    /// off-main; ayah 1's stored basmala prefix is stripped because the
    /// recording of ayah 1 does not include it (iOS does the same).
    private var textSurah = 0
    @Volatile private var textCache: List<Verse> = emptyList()

    val currentAyahText: String?
        get() {
            if (textSurah != currentSurah) return null
            val verse = textCache.firstOrNull { it.ayah == currentAyah } ?: return null
            val context = appContext ?: return verse.text
            return runCatching { QuranDb.get(context).textWithoutLeadingBasmala(verse) }
                .getOrDefault(verse.text)
        }

    private fun warmAyahText(surah: Int) {
        if (textSurah == surah) return
        val context = appContext ?: return
        prefetchPool.execute {
            val verses = runCatching { QuranDb.get(context).verses(surah) }
                .getOrDefault(emptyList())
            if (verses.isNotEmpty()) {
                textCache = verses
                textSurah = surah
                NoorAudioService.refresh(context)
            }
        }
    }

    private fun resetAyahLengthEstimate() {
        measuredMs = 0L
        measuredAyat.clear()
    }

    /// Folds the audible ayah's real length into the mean, once per ayah.
    /// Translated readings are excluded: a second file over the same ayah is
    /// not a unit of the surah.
    private fun measureCurrentAyah() {
        if (isPlayingTranslation || !prepared) return
        val ayah = currentAyah
        if (ayah <= 0 || ayah in measuredAyat) return
        val length = runCatching { media?.duration ?: 0 }.getOrDefault(0)
        if (length <= 0) return
        measuredAyat.add(ayah)
        measuredMs += length.toLong()
    }

    /// Total length the notification should show for the whole surah, ms,
    /// or 0 while nothing has been measured yet.
    val surahDurationMs: Long
        get() {
            val mean = meanAyahMs ?: return 0L
            return if (ayahCount > 0) mean * ayahCount else 0L
        }

    /// How far through the SURAH we are, ms. The within-ayah part is capped
    /// at one mean so a long ayah can never push past its own share and then
    /// jump backwards.
    val surahPositionMs: Long
        get() {
            measureCurrentAyah()
            val mean = meanAyahMs ?: return 0L
            val into = runCatching { if (prepared) media?.currentPosition ?: 0 else 0 }
                .getOrDefault(0).toLong()
            val elapsed = mean * (currentAyah - 1).coerceAtLeast(0) + into.coerceIn(0L, mean)
            return elapsed.coerceAtMost(surahDurationMs)
        }

    /// Seek on the surah timeline the notification shows: converted back to
    /// an ayah, because seeking a few-second file to minute 12 would just end
    /// it. Dragging the bar therefore moves through the surah, which is what
    /// the bar promises.
    fun seekToSurahMs(positionMs: Long) {
        val mean = meanAyahMs ?: return
        if (mean <= 0 || ayahCount <= 0) return
        val target = ((positionMs / mean).toInt() + 1).coerceIn(1, ayahCount)
        if (target == currentAyah) return
        playAyah(currentSurah, target)
    }
    private var media: MediaPlayer? = null
    /// Last surah:ayah given a second chance after every host failed.
    private var retriedAyah: Pair<Int, Int>? = null
    /// Pending "still not prepared" check for the ayah being streamed.
    private var prepareWatchdog: Runnable? = null
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
        translation = TranslationVoice.byName(prefs.getString("translation", null))
    }

    /// User action only. Restarts the current ayah pair with the new choice.
    fun selectTranslation(value: TranslationVoice) {
        translation = value
        appContext?.getSharedPreferences("audio", Context.MODE_PRIVATE)
            ?.edit()?.putString("translation", value.name)?.apply()
        if (currentSurah != 0) playAyah(currentSurah, currentAyah)
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

    // MARK: - ayah cache + prefetch (iOS: every ayah cached after first
    // play; the next few download while the current one plays, so
    // advancing is instant and replays work offline).

    private val prefetchPool = java.util.concurrent.Executors.newFixedThreadPool(2)

    /// Folders such as "warsh/…" or "translations/…" become one flat
    /// sub-directory ("warsh_…") so every voice is a single directory.
    internal fun cacheFile(folder: String, surah: Int, ayah: Int): java.io.File {
        val dir = java.io.File(appContext!!.cacheDir,
            "recitations/${folder.replace('/', '_')}").apply { mkdirs() }
        return java.io.File(dir,
            "%03d%03d.mp3".format(java.util.Locale.ROOT, surah, ayah))
    }

    /// Downloads one ayah to the cache from the first source that delivers
    /// it (EveryAyah → mirror → Quran Foundation → Islamic Network, dead
    /// hosts tried last). Quiet — failures just mean that ayah streams when
    /// its turn comes.
    internal fun download(folder: String, surah: Int, ayah: Int): Boolean {
        val target = cacheFile(folder, surah, ayah)
        if (target.length() > 1024) return true
        for (source in AudioSources.ordered(AudioSources.candidates(folder, surah, ayah))) {
            try {
                val temp = java.io.File.createTempFile("ayah", ".mp3", target.parentFile)
                val connection = java.net.URL(source)
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
                    if (temp.renameTo(target)) { AudioSources.markUp(source); return true }
                }
                temp.delete()
                // A 404 means this host lacks the file, not that it is down.
                if (connection.responseCode >= 500) AudioSources.markDown(source)
            } catch (_: Exception) {
                // Refused / timed out: skip this host for a while so the
                // next ayah does not wait on it again.
                AudioSources.markDown(source)
            }
        }
        return false
    }

    /// The cached recitation file for one ayah of the current reciter,
    /// downloading it first if needed (any reachable host). Null when
    /// it is not cached and cannot be fetched (offline). Runs on IO.
    /// `withTranslation` also fetches the selected translated reading so
    /// the pair plays gaplessly / offline afterwards (the video share keeps
    /// the default: Arabic recitation only).
    suspend fun ensureAyahFile(
        surah: Int,
        ayah: Int,
        withTranslation: Boolean = false,
    ): java.io.File? =
        kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
            val folder = reciter.folder
            val voice = translation
            if (withTranslation && voice != TranslationVoice.NONE) {
                download(voice.folder, surah, ayah)
            }
            if (download(folder, surah, ayah)) cacheFile(folder, surah, ayah) else null
        }

    /// Warm the next few ayat while the current one plays. `includeCurrent`
    /// also saves the ayah being streamed right now: without it the ayah the
    /// user pressed play on is the one ayah never cached, so replaying it
    /// buffers from the network every time (advanced-to ayat were prefetched).
    private fun prefetch(
        folder: String,
        surah: Int,
        fromAyah: Int,
        includeCurrent: Boolean = false,
    ) {
        for (ayah in (if (includeCurrent) fromAyah else fromAyah + 1)..minOf(fromAyah + 3, ayahCount)) {
            prefetchPool.execute {
                // Skip stale work if the user already moved on to another
                // voice; `folder` itself guarantees path and URL agree.
                if (folder == reciter.folder || folder == translation.folder) {
                    download(folder, surah, ayah)
                }
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
        resetAyahLengthEstimate()
        playAyah(surah, fromAyah)
        if (currentSurah != 0) startService()  // focus denied → nothing to keep alive
    }

    /// Kids mode: play a whole surah from its first ayah, repeating every
    /// ayah [repeat] times, and STOP at the end instead of rolling into the
    /// next surah (the reader awards a star on `onSurahFinished`). The mode
    /// is armed before the first request, so nothing is fetched twice.
    fun playForKids(surah: Int, ayahCount: Int, name: String, repeat: Int) {
        stopAfterSurah = true
        if (repeat > 1) {
            memorizeStart = 1
            memorizeEnd = ayahCount.coerceAtLeast(1)
            memorizePerAyah = repeat
            memorizeDone = 0
            mode = PlaybackMode.MEMORIZE
        } else {
            mode = PlaybackMode.CONTINUOUS
        }
        play(surah, ayahCount, 1, name)
    }

    /// `skipCache` ignores any cached copy for this attempt — set after a
    /// cached file failed to play, so a delete that did not take (read-only
    /// or busy file) cannot bounce playAyah back onto the same bad file.
    /// `translated` plays the translated reading of the same ayah (the second
    /// half of the pair); the highlight stays on the ayah and the mode logic
    /// runs only once the pair is done.
    /// `sourceIndex` picks the host to stream from (see `AudioSources`):
    /// each failure moves to the next one, so one dead or slow CDN never
    /// strands playback.
    private fun playAyah(
        surah: Int,
        ayah: Int,
        sourceIndex: Int = 0,
        skipCache: Boolean = false,
        translated: Boolean = false,
    ) {
        currentSurah = surah; currentAyah = ayah
        warmAyahText(surah)
        wantsPlayback = true
        prepared = false
        isPlayingTranslation = translated
        // Resume point for the Today "continue listening" card — written
        // from user-driven playback only, never from a compose observer.
        appContext?.getSharedPreferences("audio", Context.MODE_PRIVATE)?.edit()
            ?.putInt("audio.lastSurah", surah)?.putInt("audio.lastAyah", ayah)?.apply()
        prepareWatchdog?.let(handler::removeCallbacks)
        media?.release()
        if (!requestFocus()) { media = null; stop(); return }
        // One snapshot for cache path, URL and prefetch.
        val translationVoice = translation
        val folder = if (translated) translationVoice.folder else reciter.folder
        // Healthy hosts first; a host that failed moments ago goes last.
        val sources = AudioSources.ordered(AudioSources.candidates(folder, surah, ayah))
        val source = sources.getOrNull(sourceIndex) ?: sources.last()
        // Set below, before prepareAsync(); read by the error listener so a
        // corrupt cached file is deleted rather than replayed on every retry.
        var cachedSource: java.io.File? = null
        var playedFromCache = false
        // Bad cache file → drop it and stream; host → next host … → one
        // delayed retry (transient network), then stop. Never strand
        // playback on a hiccup. A translation that cannot be fetched is
        // skipped: the Arabic recitation carries on.
        fun fallback() {
            when {
                playedFromCache -> {
                    cachedSource?.delete()
                    playAyah(surah, ayah, skipCache = true, translated = translated)
                }
                sourceIndex + 1 < sources.size ->
                    playAyah(surah, ayah, sourceIndex = sourceIndex + 1,
                             skipCache = true, translated = translated)
                translated -> { isPlayingTranslation = false; afterPair(surah, ayah) }
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
        }
        media = MediaPlayer().apply {
            val player = this
            // The "slow host" case: still buffering after PREPARE_TIMEOUT_MS
            // means this CDN is crawling, not down — remember that and move
            // on, exactly as if it had errored.
            val watchdog = Runnable {
                if (media !== player || NoorPlayer.prepared) return@Runnable
                if (!playedFromCache) AudioSources.markDown(source)
                player.setOnErrorListener(null)
                runCatching { player.reset() }
                fallback()
            }
            prepareWatchdog = watchdog
            setAudioAttributes(audioAttributes)
            setOnPreparedListener {
                handler.removeCallbacks(watchdog)
                if (!playedFromCache) AudioSources.markUp(source)
                NoorPlayer.prepared = true
                NoorPlayer.isBuffering = false
                // Honour a pause made WHILE this ayah was downloading: do not
                // resurrect playback the user already stopped.
                if (!NoorPlayer.wantsPlayback) {
                    NoorPlayer.isPlaying = false
                    NoorAudioService.refresh(appContext)
                    return@setOnPreparedListener
                }
                it.start()
                NoorPlayer.isPlaying = true
                applySpeed()
                NoorAudioService.refresh(appContext)
                // Warm the ayat ahead while this one plays — and this ayah
                // itself when it was streamed, so the replay is instant.
                prefetch(folder, surah, ayah, includeCurrent = !playedFromCache)
                // The translation of THIS ayah is up next — fetch it now so
                // the hand-off is gapless, plus the ones ahead.
                if (!translated && translationVoice != TranslationVoice.NONE) {
                    prefetch(translationVoice.folder, surah, ayah, includeCurrent = true)
                }
            }
            setOnCompletionListener {
                if (sleepDeadline != 0L && System.currentTimeMillis() >= sleepDeadline) {
                    stop(); return@setOnCompletionListener
                }
                // Arabic done → the translated reading of the same ayah,
                // then the normal mode logic once the pair is complete.
                if (!translated && translation != TranslationVoice.NONE) {
                    playAyah(surah, ayah, translated = true)
                    return@setOnCompletionListener
                }
                afterPair(surah, ayah)
            }
            setOnErrorListener { _, _, extra ->
                handler.removeCallbacks(watchdog)
                // Only a timeout says the HOST is unwell; a plain error may
                // just be a file this host does not carry (404).
                if (!playedFromCache && extra == MediaPlayer.MEDIA_ERROR_TIMED_OUT) {
                    AudioSources.markDown(source)
                }
                fallback()
                true
            }
            // Cached copy plays instantly (and offline); otherwise stream
            // and let the cache warm via prefetch for next time.
            cachedSource = runCatching { cacheFile(folder, surah, ayah) }.getOrNull()
            playedFromCache = !skipCache && cachedSource?.let { it.length() > 1024 } == true
            if (playedFromCache) {
                setDataSource(cachedSource!!.path)
            } else {
                setDataSource(source)
                handler.postDelayed(watchdog, AudioSources.PREPARE_TIMEOUT_MS)
            }
            NoorPlayer.isBuffering = true
            prepareAsync()
        }
        NoorAudioService.refresh(appContext)
    }

    /// Mode logic once an ayah (Arabic + optional translation) is done —
    /// shared by the completion listener and the skip-a-broken-translation
    /// path, so both advance identically.
    private fun afterPair(surah: Int, ayah: Int) {
        // "End of surah" chip: stop once the current mode reaches the
        // end of what it plays, instead of repeating/looping again.
        if (stopAfterSurah && atModeEnd()) {
            val finished = surah
            stop()  // clears the chip
            onSurahFinished?.invoke(finished)
            return
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
        // Recorded even with nothing started yet — the ayah may still be
        // preparing, and `onPrepared` reads this.
        wantsPlayback = false
        pausedByFocusLoss = false
        val player = media
        if (player != null && isPlaying && prepared) player.pause()
        isPlaying = false
        NoorAudioService.refresh(appContext)
    }

    fun resume() {
        val player = media ?: return
        if (isPlaying || !requestFocus()) return
        wantsPlayback = true
        resyncRequest++  // deliberate user action: follow the recitation again
        // Still downloading: `onPrepared` will start it. Calling start() on an
        // unprepared MediaPlayer throws, and the pill IS tappable while the
        // spinner shows.
        if (!prepared) { NoorAudioService.refresh(appContext); return }
        player.start(); applySpeed()
        isPlaying = true
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
        resetAyahLengthEstimate()
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
        prepareWatchdog?.let(handler::removeCallbacks)
        media?.release(); media = null
        pausedByFocusLoss = false
        abandonFocus()
        isPlaying = false; isBuffering = false; prepared = false; wantsPlayback = false
        resetAyahLengthEstimate()
        currentSurah = 0; currentAyah = 0
        isPlayingTranslation = false
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

/// Downloads every ayah of one surah for the current reciter (and the
/// selected translated reading, so the pair still plays gaplessly) —
/// 1:1 with the iOS QuranAudio SurahDownloader, on top of the same ayah
/// cache the player already fills as it plays. Offline afterwards.
object SurahDownloader {

    enum class Phase { IDLE, DOWNLOADING, DONE, FAILED }

    var phase by mutableStateOf(Phase.IDLE)
        private set
    var completed by androidx.compose.runtime.mutableIntStateOf(0)
        private set
    var total by androidx.compose.runtime.mutableIntStateOf(0)
        private set

    /// Every file the surah needs: the Arabic recitation, plus the
    /// translated reading when a voice is selected.
    private fun jobs(surah: Int, ayahCount: Int): List<Pair<String, Int>> {
        val voice = NoorPlayer.translation
        return (1..ayahCount.coerceAtLeast(1)).flatMap { ayah ->
            buildList {
                add(NoorPlayer.reciter.folder to ayah)
                if (voice != TranslationVoice.NONE) add(voice.folder to ayah)
            }
        }
    }

    /// True when every file of the surah is already in the cache. Hits the
    /// filesystem once per ayah — callers must stay off the main thread.
    fun isDownloaded(surah: Int, ayahCount: Int): Boolean =
        jobs(surah, ayahCount).all { (folder, ayah) ->
            NoorPlayer.cacheFile(folder, surah, ayah).length() > 1024
        }

    /// Fetches the whole surah, three files at a time — EveryAyah is a
    /// charity service, so the concurrency stays modest (as on iOS).
    suspend fun download(surah: Int, ayahCount: Int) {
        if (phase == Phase.DOWNLOADING) return
        val work = jobs(surah, ayahCount)
        completed = 0
        total = work.size
        phase = Phase.DOWNLOADING
        val failures = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
            var failed = 0
            for (batch in work.chunked(3)) {
                kotlinx.coroutines.coroutineScope {
                    batch.map { (folder, ayah) ->
                        async { NoorPlayer.download(folder, surah, ayah) }
                    }.forEach { if (!it.await()) failed++ }
                }
                kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Main) {
                    completed += batch.size
                }
            }
            failed
        }
        phase = if (failures == 0) Phase.DONE else Phase.FAILED
    }

    /// The panel is reopened on another surah: forget the last run so its
    /// state never describes a surah it did not download.
    fun reset() {
        if (phase != Phase.DOWNLOADING) {
            phase = Phase.IDLE
            completed = 0
            total = 0
        }
    }
}
