package com.engagendy.noor

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDirection
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

// MARK: - Arabic content inside an English UI
//
// Arabic-only content (Quran ayat, hadith, athkar/duas, Arabic names,
// Arabic tafsir) must ALWAYS read right-to-left and start at the right
// edge, whatever the UI language. Compose resolves an unset paragraph
// direction from LocalLayoutDirection — so in the English UI an Arabic
// paragraph was laid out LTR: left-aligned, with ayah-number glyphs and
// punctuation falling on the wrong side. Two helpers, used together:
//
//  - `ArabicDirection` / `ArabicBlock` flip LocalLayoutDirection for a
//    subtree, so Rows put badges/share buttons on the right and Columns
//    start-align to the right (row structure that is UI chrome — card
//    titles, back/share bars — stays in the UI direction).
//  - `arabicText()` is the TextStyle for every Arabic `Text`: Rtl paragraph
//    direction + Start alignment (= right edge). Pass `TextAlign.Center`
//    / `Justify` where the design already centres or justifies.
//
// In the Arabic UI both are no-ops in effect (direction is already RTL).

/// Provide RTL layout direction to `content` without adding a layout node —
/// drop-in inside any Row/Column/LazyColumn item.
@Composable
fun ArabicDirection(content: @Composable () -> Unit) {
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl, content = content)
}

/// A full-width RTL Column for an Arabic content block.
@Composable
fun ArabicBlock(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    ArabicDirection {
        Column(modifier.fillMaxWidth(), content = content)
    }
}

/// TextStyle for Arabic-only text: RTL paragraph direction, aligned to the
/// paragraph start (the right edge). Give the Text `fillMaxWidth()` so the
/// alignment has room to act.
// Passing `style =` to Text REPLACES LocalTextStyle, so the interface font
// has to be carried explicitly here or these call sites fall back to the
// platform default. Call sites that render Quran text pass an explicit
// `fontFamily =` param, which still wins over the style.
fun arabicText(align: TextAlign = TextAlign.Start): TextStyle =
    TextStyle(textDirection = TextDirection.Rtl, textAlign = align,
              fontFamily = NoorFont.family)

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
