package com.engagendy.noor

import android.media.AudioAttributes
import android.media.MediaPlayer
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

data class ReciterA(val id: String, val nameArabic: String, val folder: String)

/// Same verified EveryAyah roster as iOS (subset now; full port later).
object Reciters {
    val all = listOf(
        ReciterA("alafasy", "مشاري العفاسي", "Alafasy_128kbps"),
        ReciterA("husary", "محمود خليل الحصري", "Husary_128kbps"),
        ReciterA("minshawi", "محمد صديق المنشاوي", "Minshawy_Murattal_128kbps"),
        ReciterA("abdulbasit", "عبد الباسط عبد الصمد", "Abdul_Basit_Murattal_192kbps"),
        ReciterA("ghamdi", "سعد الغامدي", "Ghamadi_40kbps"),
        ReciterA("sudais", "عبد الرحمن السديس", "Abdurrahmaan_As-Sudais_192kbps"),
        ReciterA("shuraym", "سعود الشريم", "Saood_ash-Shuraym_128kbps"),
        ReciterA("hudhaify", "علي الحذيفي", "Hudhaify_128kbps"),
        ReciterA("dussary", "ياسر الدوسري", "Yasser_Ad-Dussary_128kbps"),
    )
}

/// Ayah-by-ayah recitation, continuous through the surah — streams from
/// EveryAyah with the mirrors fallback, like the iOS player.
object NoorPlayer {
    var reciter by mutableStateOf(Reciters.all[0])
    var currentSurah by mutableStateOf(0)
    var currentAyah by mutableStateOf(0)
    var surahName by mutableStateOf("")
    var isPlaying by mutableStateOf(false)
    private var ayahCount = 0
    private var media: MediaPlayer? = null

    private fun url(host: String, surah: Int, ayah: Int) =
        "%s/%s/%03d%03d.mp3".format(host, reciter.folder, surah, ayah)

    fun play(surah: Int, ayahCount: Int, fromAyah: Int, name: String) {
        this.ayahCount = ayahCount
        surahName = name
        playAyah(surah, fromAyah)
    }

    private fun playAyah(surah: Int, ayah: Int, mirror: Boolean = false) {
        currentSurah = surah; currentAyah = ayah
        media?.release()
        val host = if (mirror) "https://mirrors.quranicaudio.com/everyayah"
                   else "https://everyayah.com/data"
        media = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
            setOnPreparedListener { it.start(); NoorPlayer.isPlaying = true }
            setOnCompletionListener {
                if (currentAyah < ayahCount) playAyah(surah, currentAyah + 1) else stop()
            }
            setOnErrorListener { _, _, _ ->
                if (!mirror) playAyah(surah, ayah, mirror = true) else stop()
                true
            }
            setDataSource(url(host, surah, ayah))
            prepareAsync()
        }
    }

    fun toggle() {
        val player = media ?: return
        if (isPlaying) player.pause() else player.start()
        isPlaying = !isPlaying
    }

    fun next() { if (currentAyah < ayahCount) playAyah(currentSurah, currentAyah + 1) }
    fun previous() { if (currentAyah > 1) playAyah(currentSurah, currentAyah - 1) }

    fun stop() {
        media?.release(); media = null
        isPlaying = false; currentSurah = 0; currentAyah = 0
    }
}
