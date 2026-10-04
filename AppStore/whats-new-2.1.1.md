# What's New — 2.1.1 (iOS build 26, Android code 21)

Everything since 2.1.0, the build on the stores. The reader and player fixes are iOS; the recitation and Shorouk items are on both platforms.

## English

Fixed:
• Pause, then resume: the recitation now actually resumes. Resuming used to silently stop again half a second later — the athkar player was switching off the shared audio session underneath it.
• Ayah-by-ayah mode now follows the recitation, keeping the ayah being recited in view. This also fixes opening from search, a bookmark or a juz, which used to land at the top of the surah instead of on your ayah.
• The bottom bar no longer stays over the page after you leave the Quran tab and come back.
• Recitations keep downloading when the usual audio server is down: two more sources (Quran Foundation and Islamic Network) are tried automatically, and a slow server is skipped instead of leaving the player waiting.

New:
• Shorouk (sunrise) now appears on the prayer timeline after Fajr, with its own optional alert telling you that Fajr time has ended.
• Tap the surah · ayah line in the player to jump back to the ayah being recited after scrolling away.
• The player shows a spinner while an ayah is still downloading, instead of a play button that cannot act yet.
• The reading mode panel lets you pick the translation itself, not just switch it on — the same list as Settings, so the two always agree.
• While a recitation plays in Mushaf mode, the page follows it and keeps the ayah being recited in view.
