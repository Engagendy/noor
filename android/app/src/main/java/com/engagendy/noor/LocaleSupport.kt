package com.engagendy.noor

import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.LayoutDirection
import java.util.Locale

/// Locale-aware helpers for the bilingual (ar-first, en) UI.
///
/// The UI language is whatever bucket Android resolved the resources to
/// (values = ar default, values-en = English). In composition, read it via
/// the `g1_locale` marker string; outside composition (widgets, receivers,
/// formatters) `Locale.getDefault()` reflects the per-app locale set with
/// AppCompatDelegate.setApplicationLocales.

fun isArabicLocale(): Boolean = Locale.getDefault().language == "ar"

/// True when the RESOLVED resource language is Arabic — drives layout
/// direction so strings and mirroring never disagree.
@Composable
fun isArabicUi(): Boolean = stringResource(R.string.g1_locale) == "ar"

/// Layout direction for the whole app: ar → RTL, en → LTR.
@Composable
fun noorLayoutDirection(): LayoutDirection =
    if (isArabicUi()) LayoutDirection.Rtl else LayoutDirection.Ltr

/// Arabic-Indic digits in Arabic UI, Western digits otherwise —
/// the locale-aware counterpart of `Int.arabicIndic()`.
fun Int.localizedDigits(): String = if (isArabicLocale()) arabicIndic() else toString()

// MARK: - direction-aware arrows
//
// RTL arrow rule: "forward" (go deeper) points LEFT in RTL and RIGHT in
// LTR; "back" is the opposite. Explicit drawables selected per direction —
// no autoMirrored double-mirroring surprises.
object NoorIcons {
    @Composable
    fun forward(): Int =
        if (LocalLayoutDirection.current == LayoutDirection.Rtl) R.drawable.ic_arrow_left
        else R.drawable.ic_arrow_right

    @Composable
    fun back(): Int =
        if (LocalLayoutDirection.current == LayoutDirection.Rtl) R.drawable.ic_arrow_right
        else R.drawable.ic_arrow_left

    /// Disclosure chevron on nav rows — points in the forward direction.
    @Composable
    fun chevronForward(): Int =
        if (LocalLayoutDirection.current == LayoutDirection.Rtl) R.drawable.ic_chevron_left
        else R.drawable.ic_chevron_right

    /// Chevron pointing backward (towards the start edge).
    @Composable
    fun chevronBackward(): Int =
        if (LocalLayoutDirection.current == LayoutDirection.Rtl) R.drawable.ic_chevron_right
        else R.drawable.ic_chevron_left
}

// MARK: - localized display names (data already carries both languages)

/// Surah name: Arabic from the verified DB, or its transliteration in the
/// English UI (name_transliterated from quran.sqlite — like iOS).
fun Surah.displayName(): String = if (isArabicLocale()) nameArabic else nameTransliterated

fun CityPreset.displayName(): String = if (isArabicLocale()) nameArabic else name

fun PrayerEntry.displayName(): String = if (isArabicLocale()) nameArabic else nameEnglish

fun CalculationMethodChoice.displayName(): String =
    if (isArabicLocale()) nameArabic else nameEnglish

fun MadhabChoice.displayName(): String = if (isArabicLocale()) nameArabic else nameEnglish

/// Hijri month names — Arabic list from IslamicEvents, standard
/// transliterations in English (like the iOS islamic-umalqura formatting).
private val hijriMonthsEnglish = listOf(
    "Muharram", "Safar", "Rabi' al-Awwal", "Rabi' al-Thani",
    "Jumada al-Ula", "Jumada al-Akhirah", "Rajab", "Sha'ban",
    "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah",
)

fun hijriMonthName(month: Int): String = when {
    month !in 1..12 -> ""
    isArabicLocale() -> IslamicEvent.hijriMonthsArabic[month - 1]
    else -> hijriMonthsEnglish[month - 1]
}
