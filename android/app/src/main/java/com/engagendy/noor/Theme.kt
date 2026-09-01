package com.engagendy.noor

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily

/// Noor design tokens — 1:1 with the iOS DesignSystem (Mushaf light).
object NoorColor {
    val bgPrimary = Color(0xFFFAF6EE)     // paper
    val bgElevated = Color(0xFFFFFFFF)
    val inkPrimary = Color(0xFF1F2933)
    val inkSecondary = Color(0xFF5C6670)
    val accentPrimary = Color(0xFF0E6B5C) // mihrab green
    val accentGold = Color(0xFFBA8A2E)
    val stateReciting = Color(0xFFDCE9E2)
}

val QuranFont = FontFamily(Font(R.font.amiri_quran))
val HafsFont = FontFamily(Font(R.font.uthmanic_hafs))

private val scheme = lightColorScheme(
    primary = NoorColor.accentPrimary,
    background = NoorColor.bgPrimary,
    surface = NoorColor.bgPrimary,
    onBackground = NoorColor.inkPrimary,
    onSurface = NoorColor.inkPrimary,
)

@Composable
fun NoorTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = scheme, typography = Typography(), content = content)
}

/// ٠١٢٣٤٥٦٧٨٩
fun Int.arabicIndic(): String =
    toString().map { c -> if (c.isDigit()) ('٠' + (c - '0')) else c }.joinToString("")
