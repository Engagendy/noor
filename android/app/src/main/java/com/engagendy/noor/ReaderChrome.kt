package com.engagendy.noor

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/// Immersive reading. The iOS reader hides the tab bar outright
/// (`SurahReaderView`: `.toolbar(.hidden, for: .tabBar)`) and navigates with
/// its own back button; Android kept the tab bar because both readers live
/// inside the top-level Scaffold. That costs real reading area: a Madani page
/// is a rigid 15-row grid stretched to the height it is given, so every pixel
/// the tab bar takes shrinks every line of the mushaf.
///
/// `QuranScreen` raises this while either reader is open and lowers it on
/// dispose; `MainActivity` also gates it on the Quran tab, so the tab bar can
/// never be stranded off-screen.
object ReaderChrome {
    var readerOpen by mutableStateOf(false)
}
