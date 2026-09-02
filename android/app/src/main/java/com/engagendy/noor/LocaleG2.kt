package com.engagendy.noor

import java.util.Locale

/// Locale helpers for the Group-2 screens (Quran index/reader, Mushaf,
/// Tafsir, Audio, Hadith, Athkar, Zakat, GoToPage).
///
/// Theme.kt's arabicIndic() is intentionally untouched (shared file, and
/// in-Quran ayah markers stay Arabic-Indic in every locale). These helpers
/// cover UI numbers, which follow the app language like iOS: Arabic-Indic
/// digits in ar, Western digits in en.

/// True when the app UI language is Arabic (AppCompat per-app locales set
/// the default locale, so this tracks the in-app language switch).
fun isArabicUi(): Boolean = Locale.getDefault().language == "ar"

/// ٠١٢٣٤٥٦٧٨٩ in ar, 0123456789 in en.
fun Int.localizedDigits(): String = if (isArabicUi()) arabicIndic() else toString()

/// Localized display name — mirrors iOS Reciter.displayName(arabicUI:).
val ReciterA.localizedName: String
    get() = if (isArabicUi()) nameArabic else nameEnglish

/// The other-language name, shown as the secondary line in the picker.
val ReciterA.secondaryName: String
    get() = if (isArabicUi()) nameEnglish else nameArabic

/// Localized collection name — iOS shows the English forms in en.
val HadithCollection.localizedName: String
    get() = if (isArabicUi()) nameArabic else nameEnglish

/// Download size in MB per collection (digits localized at the call site).
val HadithCollection.sizeMb: Int
    get() = when (this) {
        HadithCollection.BUKHARI -> 14
        HadithCollection.MUSLIM -> 15
    }
