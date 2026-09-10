package com.engagendy.noor

import android.content.Context
import android.content.res.Configuration
import android.content.res.Resources
import android.os.LocaleList
import androidx.appcompat.app.AppCompatDelegate
import androidx.appcompat.view.ContextThemeWrapper
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.material3.Text
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDirection
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.core.os.LocaleListCompat
import java.util.Locale

/// Locale-aware helpers for the ten-language (ar-first) UI.
///
/// The UI language is whatever bucket Android resolved the resources to
/// (values = ar default, values-<code> for the other nine — see
/// `NoorLanguage`, and `res/xml/locales_config.xml`, which MUST list every
/// one of them). In composition, read it via
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

    /// "system" or a `NoorLanguage.code` — reactive, so pickers and every
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

    /// The language the UI actually RENDERS in — always one of the ten
    /// `NoorLanguage` cases. This is what `Locale.getDefault()` is pinned to,
    /// keeping formatters, digits and `displayName()` in step with the
    /// strings on screen.
    ///
    /// Anything the app has no bucket for resolves to Arabic, because
    /// unqualified `values/` is Arabic: the fallback here and the fallback
    /// the resource resolver performs must be the same language or the
    /// direction and the strings disagree.
    fun uiLocale(): Locale {
        val list = locales()
        for (i in 0 until list.size()) {
            NoorLanguage.from(list[i])?.let { return it.locale }
        }
        return NoorLanguage.DEFAULT.locale
    }

    /// The resolved interface language, outside composition.
    fun language(): NoorLanguage = NoorLanguage.from(uiLocale()) ?: NoorLanguage.DEFAULT

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
            // setLocales resets the direction from locales[0]; pin it to the
            // bucket we actually resolve to, which for an unsupported device
            // language is not locales[0] at all.
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
    // Read the language from the RESOLVED resources, never from the pref:
    // the two disagree whenever the device language has no bucket here, and
    // the strings on screen are what the direction has to match.
    val language = NoorLanguage.from(localized.resources.getString(R.string.g1_locale))
        ?: NoorLanguage.DEFAULT
    val direction = if (language.isRtl) LayoutDirection.Rtl else LayoutDirection.Ltr
    // Urdu is drawn in Nastaliq, whose line box is ~2.5em. Scaling
    // `fontScale` is the only lever that reaches every `fontSize = N.sp`
    // written at a call site; `ArabicDirection`/`ArabicBlock` undo it for
    // Arabic content, which is not in Nastaliq. 1f for the other nine, so
    // this is a no-op everywhere else.
    val baseDensity = LocalDensity.current
    val density = remember(baseDensity, language) {
        if (language.uiFontScale == 1f) baseDensity
        else Density(baseDensity.density, baseDensity.fontScale * language.uiFontScale)
    }
    CompositionLocalProvider(
        LocalContext provides localized,
        LocalConfiguration provides configuration,
        LocalLayoutDirection provides direction,
        LocalDensity provides density,
        LocalBaseDensity provides baseDensity,
        LocalNoorLanguage provides language,
        content = content)
}

/// The interface language, for composables. Provided by `NoorLocaleProvider`;
/// the default is only ever seen by a preview that forgot the provider.
val LocalNoorLanguage = staticCompositionLocalOf { NoorLanguage.DEFAULT }

/// The base (unscaled) density, so Arabic content can opt out of the Urdu
/// interface font scale. Provided alongside it above.
private val LocalBaseDensity = compositionLocalOf<Density?> { null }

/// The interface language, read from the RESOLVED resource bucket so it can
/// never disagree with the strings on screen.
@Composable
fun noorUiLanguage(): NoorLanguage =
    NoorLanguage.from(stringResource(R.string.g1_locale)) ?: NoorLanguage.DEFAULT

/// True when the RESOLVED resource language is Arabic.
///
/// This is the ARABIC question, not the right-to-left question. Use it only
/// where Arabic *content* is being chosen (Arabic hadith text vs its English
/// translation, an Arabic name vs its transliteration). For layout, ask
/// `isRtlUi()` — Urdu and Persian are right-to-left and are not Arabic.
@Composable
fun isArabicUi(): Boolean = stringResource(R.string.g1_locale) == "ar"

/// True when the interface language is written right-to-left: ar, ur, fa.
@Composable
fun isRtlUi(): Boolean = noorUiLanguage().isRtl

/// Layout direction for the whole app.
@Composable
fun noorLayoutDirection(): LayoutDirection =
    if (isRtlUi()) LayoutDirection.Rtl else LayoutDirection.Ltr

/// This number written in the interface language's own digits — the
/// locale-aware counterpart of `Int.arabicIndic()`.
///
/// Arabic ٠١٢, Urdu and Persian the eastern forms ۰۱۲, Bengali ০১২, and
/// Western digits for the five Latin-script languages. The set matches the
/// digits the translated strings are written with, so a screen never shows
/// two numeral systems side by side. See `NoorLanguage.digitZero`.
fun Int.localizedDigits(): String {
    val zero = NoorLanguage.current().digitZero ?: return toString()
    if (zero == '\u0660') return arabicIndic()
    return toString().map { if (it in '0'..'9') zero + (it - '0') else it }.joinToString("")
}

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
    // Also undoes the Urdu interface font scale: this subtree is Arabic
    // content in an Arabic face, not Nastaliq, so it must be set at the size
    // the design asks for. A no-op in the other nine languages.
    val base = LocalBaseDensity.current ?: LocalDensity.current
    CompositionLocalProvider(
        LocalLayoutDirection provides LayoutDirection.Rtl,
        LocalDensity provides base,
        content = content)
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
// `arabicFamily`, NOT `family`: this is Arabic CONTENT. In an Urdu interface
// `NoorFont.family` is Noto Nastaliq Urdu, which is a Nastaliq face for Urdu
// running text — the Quran, hadith and athkar Arabic must stay in the Naskh
// family the user chose, in every one of the ten interface languages.
fun arabicText(align: TextAlign = TextAlign.Start): TextStyle =
    TextStyle(textDirection = TextDirection.Rtl, textAlign = align,
              fontFamily = NoorFont.arabicFamily)

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

/// Prayer names are the one "ar vs en data pair" that is NOT content: they
/// are UI labels, they are in `Tools/i18n/GLOSSARY.md` for all ten languages,
/// and `strings.xml` already carries them per bucket. So this resolves the
/// resource rather than picking between the two hardcoded strings — Fajr is
/// "Icha"/"Yatsı"/"এশা" in the interface language, not English-for-everyone.
/// (`nameArabic`/`nameEnglish` stay on the model: the widget and the adhan
/// notification are built outside the activity and pass them through.)
val PrayerEntry.nameRes: Int
    get() = when (key) {
        "fajr" -> R.string.g1_fajr
        "dhuhr" -> R.string.g1_dhuhr
        "asr" -> R.string.g1_asr
        "maghrib" -> R.string.g1_maghrib
        else -> R.string.g1_isha
    }

fun PrayerEntry.displayName(context: Context): String = context.getString(nameRes)

@Composable
fun PrayerEntry.displayName(): String = stringResource(nameRes)

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

// MARK: - the language picker
//
// One component, used by onboarding, Settings and the kids sheet, so the
// three can never drift apart. Every language is written in ITS OWN language
// and script (`NoorLanguage.endonym`) and is NEVER routed through
// `strings.xml`: a picker that offers "Bengali" to a Bengali speaker who
// cannot read the current interface language is useless.

/// Wrapping grid of language chips. `selectedId` is `NoorLocale.choice`
/// ("system" or a language code).
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun NoorLanguageChips(
    selectedId: String,
    includeSystem: Boolean = true,
    onSelect: (String) -> Unit,
) {
    val options = buildList {
        if (includeSystem) add(NoorLocale.SYSTEM to stringResource(R.string.g1_lang_system))
        NoorLanguage.entries.forEach { add(it.code to it.endonym) }
    }
    // The chips are laid out in the READING direction of the current
    // interface language, like every other row in the app.
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        options.forEach { (id, label) ->
            val selected = id == selectedId
            val language = NoorLanguage.from(id)
            Text(
                label,
                // Endonyms are drawn in their own script. Urdu needs
                // Nastaliq or اردو is set in a Naskh face on the very row
                // whose job is to show the user what Urdu looks like.
                fontFamily = if (language?.forcesNastaliq == true) NastaliqFont else null,
                fontSize = (14 * (language?.pickerFontScale ?: 1f)).sp,
                // Nastaliq draws far above and below the baseline; give the
                // chip a line box that fits it rather than letting the row
                // clip the kashida sweep.
                lineHeight = if (language?.forcesNastaliq == true) 30.sp else TextUnit.Unspecified,
                fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                color = if (selected) NoorColor.accentPrimary else NoorColor.inkSecondary,
                modifier = Modifier
                    // Clip BEFORE clickable so the ripple follows the corner.
                    .clip(RoundedCornerShape(10.dp))
                    .background(
                        if (selected) NoorColor.stateReciting else NoorColor.bgPrimary,
                        RoundedCornerShape(10.dp))
                    .clickable { onSelect(id) }
                    .padding(horizontal = 10.dp, vertical = 7.dp))
        }
    }
}
