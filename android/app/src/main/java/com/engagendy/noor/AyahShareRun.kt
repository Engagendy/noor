package com.engagendy.noor

import android.content.Context

/// A run of consecutive ayat shared as ONE card and ONE video — the port of
/// the iOS `ShareAyahSheet` range picker.
///
/// A single short ayah makes a video of a second or two, which is not worth
/// posting; extending the run fills a status without leaving the passage.
object AyahShareRun {

    /// Most ayat one card / video may carry. Past a handful the text shrinks
    /// to nothing in a 9:16 frame, and a status has a length limit anyway.
    const val MAX = 10

    /// How many ayat can be taken from [ayah] onwards without leaving the
    /// surah, capped at [MAX]. 1 means the stepper has nothing to offer.
    fun available(surah: Surah, ayah: Int): Int =
        (surah.ayahCount - ayah + 1).coerceIn(1, MAX)

    /// The run itself, read off the verified DB. Blocking — call from IO.
    fun verses(context: Context, surahId: Int, from: Int, count: Int): List<Verse> =
        QuranDb.get(context).verses(surahId)
            .filter { it.ayah >= from && it.ayah < from + count.coerceAtLeast(1) }

    /// Verbatim DB texts laid end to end, each closed by the ayah-number
    /// marker the reader already draws between verses. Nothing Quranic is
    /// built, reshaped or typed here — only stored texts placed in order.
    fun cardText(verses: List<Verse>): String =
        verses.joinToString(" ") { "${it.text} ⁧﴿${it.ayah.arabicIndic()}﴾⁩" }

    /// "Surah Al-Baqarah · 2:255" for one ayah, "· 2:255-259" for a run.
    fun reference(context: Context, surah: Surah, verses: List<Verse>): String {
        val prefix = context.getString(R.string.g2_surah_prefix, surah.nameArabic)
        val first = verses.firstOrNull()?.ayah ?: 1
        val last = verses.lastOrNull()?.ayah ?: first
        val span = if (first == last) first.localizedDigits()
            else "${first.localizedDigits()}-${last.localizedDigits()}"
        return "$prefix · ${surah.id.localizedDigits()}:$span"
    }

    /// Plain-text form for the clipboard.
    fun clipText(surah: Surah, verses: List<Verse>): String {
        val first = verses.firstOrNull()?.ayah ?: 1
        val last = verses.lastOrNull()?.ayah ?: first
        val span = if (first == last) "$first" else "$first-$last"
        return "${cardText(verses)} — ${surah.id}:$span"
    }
}
