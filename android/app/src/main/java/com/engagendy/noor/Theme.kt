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
    MaterialTheme(colorScheme = scheme, typography = Typography(), content = content)
}

/// ٠١٢٣٤٥٦٧٨٩
fun Int.arabicIndic(): String =
    toString().map { c -> if (c.isDigit()) ('٠' + (c - '0')) else c }.joinToString("")
