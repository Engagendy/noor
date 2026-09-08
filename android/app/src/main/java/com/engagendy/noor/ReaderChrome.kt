package com.engagendy.noor

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/// Shared reader-chrome state — the Android twin of iOS `ReaderChrome`
/// (`Modules/QuranReader/Sources/QuranReader/ReaderChrome.swift`).
///
/// Immersive reading: while a Quran reader is open the bottom tab bar
/// follows the reader's CHROME rather than the whole session, exactly as on
/// iOS — tap the page and the top strip AND the tab bar come back together,
/// tap again and both go.
///
/// This is the single source of truth: `MushafScreen` owns `chromeVisible`
/// through this object (it holds NO private copy), so the strip and the bar
/// can never disagree. `QuranScreen` raises/lowers `readerOpen`;
/// `MainActivity` also gates on the Quran tab, so the bar can never be
/// stranded off-screen after a tab switch.
///
/// The tab bar must never RESIZE the reader when it returns: a Madani page is
/// a rigid 15-row grid stretched to the height it gets, so every line would
/// reflow on every tap. `MainActivity` therefore draws it as an overlay above
/// the reader (never in the Scaffold's `bottomBar`, which insets content by
/// design) while the reader keeps the full height.
object ReaderChrome {
    /// True while a Quran reader (Madani page, flow, or ayah-by-ayah) is on
    /// screen.
    var readerOpen by mutableStateOf(false)

    /// True while the reader's chrome (top strip) is showing. Backed by a
    /// `MutableState` so the Madani reader can delegate to it with `by`
    /// instead of keeping — and having to mirror — a local copy.
    ///
    /// Only the Madani reader hides its chrome; the flow / ayah-by-ayah
    /// reader's top bar is permanently visible, so it simply leaves this
    /// `true` and keeps its tab bar.
    val chromeState = mutableStateOf(true)
    var chromeVisible: Boolean
        get() = chromeState.value
        set(value) { chromeState.value = value }

    /// True while the open reader is one whose chrome HIDES — today only the
    /// Madani page reader. Its bar must float over the page (a rigid 15-row
    /// grid would reflow if the bar took height); the flow / ayah-by-ayah
    /// reader keeps a permanently visible top bar, so it keeps a normal
    /// inline tab bar that insets its scrolling text instead of covering it.
    var chromeHides by mutableStateOf(false)

    /// One animation for the strip and the bar, so a tap reads as a single
    /// gesture (the strip cross-fades with `animateFloatAsState`, which uses
    /// exactly this spring by default).
    val fadeSpec = spring<Float>(
        dampingRatio = Spring.DampingRatioNoBouncy,
        stiffness = Spring.StiffnessMedium,
        visibilityThreshold = 0.01f)

    /// Reader appeared: chrome starts visible (the Madani reader auto-hides
    /// it shortly after arrival).
    fun readerAppeared() {
        readerOpen = true
        chromeVisible = true
    }

    /// Reader left by ANY path — drawer exit row, tab switch, system back.
    fun readerDisappeared() {
        readerOpen = false
        chromeVisible = true
        chromeHides = false
    }
}
