package com.engagendy.noor

/// Kids mode rules — the ONE place the age bands live, so Android and iOS
/// present the same content to the same child. Deliberately PURE Kotlin (no
/// Android imports): it can be compiled and exercised on its own, and every
/// screen derives from it instead of re-deriving age logic.
///
/// Bands (identical on iOS):
///   4–6   Al-Fatiha + 105…114, text ×1.35, ayah-by-ayah forced, 3 repeats
///   7–9   Al-Fatiha + 78…114 (Juz Amma), ×1.2, ayah-by-ayah forced, 2 repeats
///   10–12 all 114 surahs, ×1.0, ayah-by-ayah by default (flow allowed), no repeat
object KidsMode {
    const val MIN_AGE = 4
    const val MAX_AGE = 12
    const val DEFAULT_AGE = 7

    /// A surah is worth at most three stars: one per completed play.
    const val MAX_STARS = 3

    /// The recitation children learn from (Al-Husary's Muallim edition) —
    /// selected once, when kids mode is first enabled.
    const val TEACHING_RECITER_ID = "husaryMuallim"

    /// Ages offered by the age sheet.
    val ages: List<Int> = (MIN_AGE..MAX_AGE).toList()

    private fun clampAge(age: Int): Int = age.coerceIn(MIN_AGE, MAX_AGE)

    /// The surahs surfaced to a child of [age] — a FILTER over the bundled
    /// mushaf, never a different text.
    fun surahIds(age: Int): List<Int> = when (clampAge(age)) {
        in 4..6 -> listOf(1) + (105..114).toList()
        in 7..9 -> listOf(1) + (78..114).toList()
        else -> (1..114).toList()
    }

    /// Multiplier on the reader's Quran text size.
    fun textScale(age: Int): Float = when (clampAge(age)) {
        in 4..6 -> 1.35f
        in 7..9 -> 1.2f
        else -> 1.0f
    }

    /// How many times each ayah is recited before moving on (1 = no repeat).
    fun repeatCount(age: Int): Int = when (clampAge(age)) {
        in 4..6 -> 3
        in 7..9 -> 2
        else -> 1
    }

    /// Repeats actually used by the reader: "listen" mode plays every ayah
    /// once and runs straight through the surah, whatever the age;
    /// "memorise" (the default) uses the band's repeat count.
    fun repeatCount(age: Int, listenMode: Boolean): Int =
        if (listenMode) 1 else repeatCount(age)

    /// Younger children are held to ayah-by-ayah; only the oldest band may
    /// switch to the continuous flow layout.
    fun allowsFlowLayout(age: Int): Boolean = clampAge(age) >= 10

    /// One completed play of a surah earns one star, capped at three.
    fun awardStar(currentStars: Int): Int =
        (currentStars.coerceAtLeast(0) + 1).coerceAtMost(MAX_STARS)
}
