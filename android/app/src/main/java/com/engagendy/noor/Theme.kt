package com.engagendy.noor

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight

/// One resolved set of design tokens (light "Mushaf" or dark "Tahajjud").
private data class Palette(
    val bgPrimary: Color,
    val bgElevated: Color,
    val inkPrimary: Color,
    val inkSecondary: Color,
    val accentPrimary: Color,
    val accentGold: Color,
    val stateReciting: Color,
    val isDark: Boolean,
)

// Hex pairs 1:1 with iOS Core/DesignSystem NoorColors.swift
// (02-DESIGN-GUIDELINES.md §2: Light = "Mushaf", Dark = "Tahajjud").
private val LightPalette = Palette(
    bgPrimary = Color(0xFFFAF6EE),           // paper
    bgElevated = Color(0xFFFFFFFF),
    inkPrimary = Color(0xFF1F2933),
    inkSecondary = Color(0xFF5C6670),
    accentPrimary = Color(0xFF0E6B5C),       // mihrab green
    accentGold = Color(0xFFB98A2F),
    stateReciting = Color(0x1F0E6B5C),       // accent @ 12%
    isDark = false,
)

private val DarkPalette = Palette(
    bgPrimary = Color(0xFF0F1512),
    bgElevated = Color(0xFF1A211D),
    inkPrimary = Color(0xFFEDE7DA),
    inkSecondary = Color(0xFF9AA49E),
    accentPrimary = Color(0xFF4FB3A0),
    accentGold = Color(0xFFD8B25E),
    stateReciting = Color(0x294FB3A0),       // accent @ 16%
    isDark = true,
)

/// Noor design tokens — 1:1 with the iOS DesignSystem.
///
/// Reactive: properties read from a `mutableStateOf` palette, so every
/// composable that touches `NoorColor.x` recomposes when `apply` switches
/// the theme — call sites are unchanged and switching is instant.
object NoorColor {
    private val palette = mutableStateOf(LightPalette)

    val bgPrimary: Color get() = palette.value.bgPrimary
    val bgElevated: Color get() = palette.value.bgElevated
    val inkPrimary: Color get() = palette.value.inkPrimary
    val inkSecondary: Color get() = palette.value.inkSecondary
    val accentPrimary: Color get() = palette.value.accentPrimary
    val accentGold: Color get() = palette.value.accentGold
    val stateReciting: Color get() = palette.value.stateReciting

    /// True when the dark ("Tahajjud") palette is active. State-backed, so
    /// reading it in composition subscribes to theme switches.
    val isDark: Boolean get() = palette.value.isDark

    /// Resolve the stored `app.theme` value ("system"/"light"/"dark")
    /// against the current system appearance and switch the palette.
    fun apply(theme: String, systemDark: Boolean) {
        val dark = theme == "dark" || (theme != "light" && systemDark)
        palette.value = if (dark) DarkPalette else LightPalette
    }
}

val QuranFont = FontFamily(Font(R.font.amiri_quran))
val HafsFont = FontFamily(Font(R.font.uthmanic_hafs))

// MARK: - Interface font
//
// The five families the user can pick for the INTERFACE. They never touch
// Quran rendering: QuranFont (Amiri Quran), HafsFont (KFGQPC Uthmanic Hafs)
// and the downloaded QCF page fonts stay exactly as they are.
//
// All five files are bundled UNMODIFIED from google/fonts (SIL OFL 1.1) —
// see LICENSES.md. Do NOT subset or re-hint them: the OFL forbids a modified
// build from keeping a Reserved Font Name (IBM Plex reserves "Plex"), so any
// subsetting would force a rename.

/// The four weights the design actually uses (SemiBold and Bold carry almost
/// all of it), resolved from whatever weights a family ships.
private val UI_WEIGHTS = listOf(
    FontWeight.Normal, FontWeight.Medium, FontWeight.SemiBold, FontWeight.Bold)

/// One variable file covers every weight — no per-weight statics needed.
/// `fontVariationSettings` is API 26+, which is our minSdk.
@OptIn(ExperimentalTextApi::class)
private fun variableFamily(res: Int): FontFamily = FontFamily(
    UI_WEIGHTS.map { w ->
        Font(res, w, variationSettings = FontVariation.Settings(FontVariation.weight(w.weight)))
    })

/// Interface font families, shared 1:1 with iOS via the `ui.font` pref.
enum class NoorFontChoice(
    val id: String,
    /// Font names are proper nouns: never localised, never translated.
    /// Rendered in its own family in the picker so the choice is visible.
    val displayName: String,
    /// The family's own name written in Arabic — the picker's second line,
    /// so the Arabic shaping can be judged too. Deliberately NOT Quranic
    /// text (hard rule 1). Same strings as iOS `NoorAppFont.arabicSample`.
    val arabicSample: String,
) {
    READEX_PRO("readexPro", "Readex Pro", "ريدكس برو"),
    IBM_PLEX_SANS_ARABIC("ibmPlexSansArabic", "IBM Plex Sans Arabic", "آي بي إم بلكس"),
    TAJAWAL("tajawal", "Tajawal", "تجوال"),
    ALMARAI("almarai", "Almarai", "المراعي"),
    CAIRO("cairo", "Cairo", "القاهرة");

    /// Built lazily so only the chosen family (plus any previewed in the
    /// picker) is ever parsed.
    val family: FontFamily by lazy {
        when (this) {
            // Variable files: one unmodified TTF, every weight exact.
            READEX_PRO -> variableFamily(R.font.readex_pro)
            CAIRO -> variableFamily(R.font.cairo)
            // Statics, one file per weight — exact match for all four.
            IBM_PLEX_SANS_ARABIC -> FontFamily(
                Font(R.font.ibm_plex_sans_arabic_regular, FontWeight.Normal),
                Font(R.font.ibm_plex_sans_arabic_medium, FontWeight.Medium),
                Font(R.font.ibm_plex_sans_arabic_semibold, FontWeight.SemiBold),
                Font(R.font.ibm_plex_sans_arabic_bold, FontWeight.Bold))
            // Tajawal has no SemiBold: SemiBold -> Bold (700), which is what
            // Compose's own weight matcher picks for 600 anyway, and keeps
            // the design's main emphasis weight actually emphatic.
            TAJAWAL -> FontFamily(
                Font(R.font.tajawal_regular, FontWeight.Normal),
                Font(R.font.tajawal_medium, FontWeight.Medium),
                Font(R.font.tajawal_bold, FontWeight.SemiBold),
                Font(R.font.tajawal_bold, FontWeight.Bold))
            // Almarai ships only Light/Regular/Bold/ExtraBold: Medium ->
            // Regular and SemiBold -> Bold (again the default matcher's
            // choice); ExtraBold is left out, it is heavier than the design.
            ALMARAI -> FontFamily(
                Font(R.font.almarai_regular, FontWeight.Normal),
                Font(R.font.almarai_regular, FontWeight.Medium),
                Font(R.font.almarai_bold, FontWeight.SemiBold),
                Font(R.font.almarai_bold, FontWeight.Bold))
        }
    }

    companion object {
        val DEFAULT = READEX_PRO
        fun from(id: String?): NoorFontChoice =
            entries.firstOrNull { it.id == id } ?: DEFAULT
    }
}

/// Interface font token — reactive in exactly the same way as `NoorColor`:
/// every composable that reads `NoorFont.family` recomposes when `apply`
/// switches it, so the picker restyles the app with no restart.
object NoorFont {
    private val current = mutableStateOf(NoorFontChoice.DEFAULT)

    val choice: NoorFontChoice get() = current.value
    val family: FontFamily get() = current.value.family

    /// Resolve the stored `ui.font` value and switch the family.
    fun apply(id: String?) {
        current.value = NoorFontChoice.from(id)
    }
}

/// Material's default type scale with every style moved onto [family].
/// (Material3's MaterialTheme provides `bodyLarge` as LocalTextStyle, so this
/// is what plain `Text(...)` calls inherit.)
private fun typographyFor(family: FontFamily): Typography {
    val d = Typography()
    // Compose's legacy font padding pads every line box by the FACE's ascent
    // and descent. Arabic faces built for tall marks (Cairo most of all)
    // report far more than a Latin face, so the padding inflates every line
    // until fixed-height rows overlap — the tab label rode up over its icon
    // and the Today cards ran into each other. Pinning it off makes the line
    // box follow the specified size instead of the face's own metrics.
    fun androidx.compose.ui.text.TextStyle.fit() = copy(
        fontFamily = family,
        platformStyle = androidx.compose.ui.text.PlatformTextStyle(
            includeFontPadding = false))
    return Typography(
        displayLarge = d.displayLarge.fit(),
        displayMedium = d.displayMedium.fit(),
        displaySmall = d.displaySmall.fit(),
        headlineLarge = d.headlineLarge.fit(),
        headlineMedium = d.headlineMedium.fit(),
        headlineSmall = d.headlineSmall.fit(),
        titleLarge = d.titleLarge.fit(),
        titleMedium = d.titleMedium.fit(),
        titleSmall = d.titleSmall.fit(),
        bodyLarge = d.bodyLarge.fit(),
        bodyMedium = d.bodyMedium.fit(),
        bodySmall = d.bodySmall.fit(),
        labelLarge = d.labelLarge.fit(),
        labelMedium = d.labelMedium.fit(),
        labelSmall = d.labelSmall.fit(),
    )
}

@Composable
fun NoorTheme(content: @Composable () -> Unit) {
    // Built inside composition so it tracks NoorColor's palette state.
    val scheme = if (NoorColor.isDark) {
        darkColorScheme(
            primary = NoorColor.accentPrimary,
            background = NoorColor.bgPrimary,
            surface = NoorColor.bgPrimary,
            surfaceContainer = NoorColor.bgElevated,
            surfaceContainerHigh = NoorColor.bgElevated,
            surfaceContainerLow = NoorColor.bgElevated,
            onBackground = NoorColor.inkPrimary,
            onSurface = NoorColor.inkPrimary,
            onSurfaceVariant = NoorColor.inkSecondary,
        )
    } else {
        lightColorScheme(
            primary = NoorColor.accentPrimary,
            background = NoorColor.bgPrimary,
            surface = NoorColor.bgPrimary,
            surfaceContainer = NoorColor.bgElevated,
            surfaceContainerHigh = NoorColor.bgElevated,
            surfaceContainerLow = NoorColor.bgElevated,
            onBackground = NoorColor.inkPrimary,
            onSurface = NoorColor.inkPrimary,
            onSurfaceVariant = NoorColor.inkSecondary,
        )
    }
    // Reads NoorFont.family inside composition, so a font change
    // rebuilds the type scale and restyles the app instantly.
    MaterialTheme(colorScheme = scheme, typography = typographyFor(NoorFont.family),
                  content = content)
}

/// ٠١٢٣٤٥٦٧٨٩
fun Int.arabicIndic(): String =
    toString().map { c -> if (c.isDigit()) ('٠' + (c - '0')) else c }.joinToString("")
