package com.engagendy.noor

import android.content.Context
import android.content.res.Configuration
import android.content.res.Resources
import android.os.LocaleList
import androidx.appcompat.app.AppCompatDelegate
import androidx.appcompat.view.ContextThemeWrapper
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.core.os.LocaleListCompat
import java.util.Locale

/// Locale-aware helpers for the bilingual (ar-first, en) UI.
///
/// The UI language is whatever bucket Android resolved the resources to
/// (values = ar default, values-en = English). In composition, read it via
/// the `g1_locale` marker string; outside composition (widgets, receivers,
/// formatters) `Locale.getDefault()` reflects the app language — `NoorLocale`
/// keeps the process default in sync itself (see below), so it no longer
/// depends on the OEM honouring the per-app locale.

fun isArabicLocale(): Boolean = Locale.getDefault().language == "ar"

// MARK: - the app language (single source of truth)
//
// WHY THIS EXISTS. The language used to be driven purely by
// `AppCompatDelegate.setApplicationLocales`. From API 33 that hands the
// choice to the system LocaleManager, and the UI only changes once the
// system applies it AND recreates the activity. Heavily skinned builds
// (MagicOS/Honor, MIUI/Xiaomi, ColorOS/Oppo, One UI/Samsung) delay, batch
// or drop that, so the user tapped "العربية" and kept looking at English.
//
// So: the stored `app.language` pref is now the single source of truth for
// everything drawn INSIDE the app. `NoorLocale.choice` is reactive Compose
// state (same pattern as `NoorColor` / `NoorFont`); `NoorLocaleProvider`
// hands the whole tree a Context whose configuration already carries the
// chosen locale, so every `stringResource` resolves in the new language on
// the very next frame — no activity recreation, no system involvement.
//
// `AppCompatDelegate.setApplicationLocales` is STILL called, because things
// built outside the activity (notifications, widgets, the launcher label)
// are the system's to localise. It is simply no longer what the UI depends on.
object NoorLocale {
    const val PREF_KEY = "app.language"
    const val SYSTEM = "system"

    /// "system" | "ar" | "en" — reactive, so pickers and every
    /// `stringResource` reader recompose the instant it changes.
    var choice by mutableStateOf(SYSTEM)
        private set

    /// Bumped when the DEVICE language changes while `choice == "system"`,
    /// so the provider rebuilds its configuration context.
    var systemVersion by mutableStateOf(0)
        private set

    /// Reads the stored choice and syncs the process default. Safe to call
    /// from `attachBaseContext` (SharedPreferences only needs a base context).
    fun load(context: Context) {
        choice = KhatmahPlan.prefs(context).getString(PREF_KEY, SYSTEM) ?: SYSTEM
        syncProcessDefault()
    }

    /// User action: store the choice, flip the in-app UI immediately, and
    /// tell the system about it for out-of-app surfaces.
    fun set(context: Context, value: String) {
        KhatmahPlan.prefs(context).edit().putString(PREF_KEY, value).apply()
        choice = value
        syncProcessDefault()
        AppCompatDelegate.setApplicationLocales(
            if (value == SYSTEM) LocaleListCompat.getEmptyLocaleList()
            else LocaleListCompat.forLanguageTags(value))
    }

    /// Call from onConfigurationChanged/onResume: "system" must genuinely
    /// follow the device, including a change made while backgrounded.
    fun refreshFromSystem() {
        if (choice != SYSTEM) return
        val before = Locale.getDefault()
        syncProcessDefault()
        if (Locale.getDefault() != before) systemVersion++
    }

    /// The DEVICE locales — read from the system resources, never from our
    /// own (possibly already overridden) configuration.
    private fun deviceLocales(): LocaleList = Resources.getSystem().configuration.locales

    /// Locale list to resolve resources against. For "system" the full
    /// device list is passed so Android picks the best match itself
    /// (e.g. en-GB → values-en); anything unsupported falls back to the
    /// default `values/` bucket, which is Arabic.
    fun locales(): LocaleList = when (choice) {
        SYSTEM -> deviceLocales().takeIf { !it.isEmpty } ?: LocaleList(Locale.getDefault())
        else -> LocaleList(Locale.forLanguageTag(choice))
    }

    /// The language the UI actually RENDERS in. The app ships exactly two
    /// buckets, so anything that is not English resolves to Arabic — this is
    /// what `Locale.getDefault()` is pinned to, keeping formatters, digits
    /// and `displayName()` in step with the strings on screen.
    fun uiLocale(): Locale {
        val first = locales().let { if (it.isEmpty) Locale.getDefault() else it[0] }
        return if (first.language == "en" || first.language == "ar") first else Locale("ar")
    }

    /// Pin the JVM default so non-composable code (widgets, notifications,
    /// `isArabicLocale()`, date/number formatters) agrees with the UI without
    /// waiting for the system. URLs, filenames and cache keys must keep using
    /// `Locale.ROOT` — see CLAUDE.md.
    private fun syncProcessDefault() {
        val locale = uiLocale()
        if (Locale.getDefault() != locale) Locale.setDefault(locale)
    }

    /// Configuration carrying the chosen locale, derived from `base`.
    fun configuration(base: Context): Configuration =
        Configuration(base.resources.configuration).apply {
            setLocales(locales())
            // setLocales resets the direction from locales[0]; the app only
            // has ar/en buckets, so pin it to the bucket we resolve to.
            setLayoutDirection(uiLocale())
        }

    /// For `attachBaseContext`: a base context already in the chosen
    /// language, so dialogs/toasts/AppCompat chrome match the UI.
    fun wrapBase(base: Context): Context {
        load(base)
        return base.createConfigurationContext(configuration(base))
    }
}

/// A ContextThemeWrapper (NOT a bare `createConfigurationContext` result)
/// so `startActivity`, `registerReceiver` etc. still delegate to the
/// Activity underneath — a raw configuration context would need
/// FLAG_ACTIVITY_NEW_TASK. The activity's theme is carried over verbatim.
private class NoorLocaleContext(base: Context, override: Configuration) :
    ContextThemeWrapper(base, 0) {
    init { applyOverrideConfiguration(override) }

    override fun onApplyThemeResource(theme: Resources.Theme, resid: Int, first: Boolean) {
        theme.setTo(baseContext.theme)
    }
}

/// Wraps the whole app in the chosen language. Provides `LocalContext`
/// (so every `stringResource`/`painterResource` resolves in it),
/// `LocalConfiguration` (Compose keys resource reads on it) and
/// `LocalLayoutDirection`. `isArabicUi()` / `noorLayoutDirection()` keep
/// working unchanged, because they read through this same context.
@Composable
fun NoorLocaleProvider(content: @Composable () -> Unit) {
    val base = LocalContext.current
    val choice = NoorLocale.choice
    val systemVersion = NoorLocale.systemVersion
    val localized = remember(base, choice, systemVersion) {
        NoorLocaleContext(base, NoorLocale.configuration(base))
    }
    val configuration = localized.resources.configuration
    val direction =
        if (localized.resources.getString(R.string.g1_locale) == "ar") LayoutDirection.Rtl
        else LayoutDirection.Ltr
    CompositionLocalProvider(
        LocalContext provides localized,
        LocalConfiguration provides configuration,
        LocalLayoutDirection provides direction,
        content = content)
}

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
