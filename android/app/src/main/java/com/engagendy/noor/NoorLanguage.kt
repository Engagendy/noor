package com.engagendy.noor

import java.util.Locale

/// Every interface language the app offers, and everything that follows from
/// the choice: the endonym for the picker, the writing direction, the script,
/// the digits, and the locale the app formats with.
///
/// This is the single place that knows "Arabic is right-to-left". Before the
/// eight new languages the app asked `language == "ar"` in about thirty
/// places, which is the same question only while Arabic is the only RTL
/// language on the list — Urdu and Persian make it wrong. Ask
/// `isRtlUi()` / `noorLayoutDirection()` (LocaleSupport.kt) instead of
/// comparing language codes.
///
/// Note the deliberate *non*-generalisation: `isArabicUi()` / `isArabicLocale()`
/// at the call sites that pick **content** (the Arabic hadith text vs its
/// English translation, an Arabic surah name vs its transliteration, the
/// Arabic weekday/hijri month names, the Arabic countdown grammar) still mean
/// Arabic and only Arabic. A Bengali interface reads the English translation;
/// it does not suddenly read Arabic because Bengali happens to be non-Latin.
///
/// Codes are the BCP-47 tags used by `res/values-<code>/`, by
/// `res/xml/locales_config.xml`, and — verbatim — by the iOS `NoorLanguage`
/// enum. The order is the iOS order, and it is the order the pickers show.
enum class NoorLanguage(
    val code: String,
    /// The language's own name, in its own language and script. A language
    /// picker that lists "Bengali" to a Bengali speaker who cannot read the
    /// current interface language is useless, so these are NEVER localised
    /// and never routed through `strings.xml`.
    val endonym: String,
    /// Right-to-left languages. Arabic script (ar, ur, fa) here; Bengali,
    /// like the Latin-script languages, is left-to-right.
    val isRtl: Boolean,
    /// Scripts where Latin letter tracking damages the word rather than
    /// opening it up (cursive or mark-stacking).
    val usesLatinScript: Boolean,
    /// Zero of the digit set this language writes numbers in — for the few
    /// places that build a numeral by hand rather than through a formatter.
    /// `null` means Western digits (no transformation).
    ///
    /// Mirrors iOS `NoorLanguage.digitZero` exactly: Urdu and Persian take
    /// the eastern Arabic-Indic forms (۱۲۳), Bengali its own (১২৩) — which is
    /// also what the translated Urdu/Persian/Bengali strings themselves are
    /// written with, so a screen never shows two numeral systems at once.
    /// The Latin-script languages get Western digits.
    ///
    /// Arabic keeps ٠١٢ here because the Arabic UI has always compensated
    /// explicitly (`Int.arabicIndic()`), and `localizedDigits()` is that
    /// compensation. Changing it would change every shipped Arabic screen.
    val digitZero: Char?,
) {
    AR("ar", "العربية", isRtl = true, usesLatinScript = false, digitZero = '٠'),
    EN("en", "English", isRtl = false, usesLatinScript = true, digitZero = null),
    ID("id", "Bahasa Indonesia", isRtl = false, usesLatinScript = true, digitZero = null),
    UR("ur", "اردو", isRtl = true, usesLatinScript = false, digitZero = '۰'),
    FA("fa", "فارسی", isRtl = true, usesLatinScript = false, digitZero = '۰'),
    TR("tr", "Türkçe", isRtl = false, usesLatinScript = true, digitZero = null),
    MS("ms", "Bahasa Melayu", isRtl = false, usesLatinScript = true, digitZero = null),
    BN("bn", "বাংলা", isRtl = false, usesLatinScript = false, digitZero = '০'),
    FR("fr", "Français", isRtl = false, usesLatinScript = true, digitZero = null),
    ES("es", "Español", isRtl = false, usesLatinScript = true, digitZero = null);

    /// The CLDR numbering system this language's FORMATTERS must use, as a
    /// BCP-47 `-u-nu-` extension. This is the formatter half of `digitZero`
    /// and it exists for the same reason: a prayer time in Western digits
    /// beside a label written in ۱۲۳ reads as a rendering bug.
    ///
    /// Only two overrides, exactly as iOS: CLDR gives Urdu and Bengali
    /// Western digits, and both the translated strings and `digitZero` use
    /// their own. Persian already gets ۰۱۲ from CLDR.
    ///
    /// Note what is NOT here: Arabic. CLDR gives `ar` Western digits and the
    /// app has always compensated with explicit `Int.arabicIndic()` calls on
    /// the Arabic strings. Switching `ar` to `arab` would change every time
    /// and date on the shipped Arabic screens — a separate, reviewable
    /// change, not a side effect of adding eight languages.
    private val numberingSystem: String?
        get() = when (this) {
            UR -> "arabext"
            BN -> "beng"
            else -> null
        }

    /// BCP-47 tag including the numbering system, if any.
    val bcp47: String
        get() = numberingSystem?.let { "$code-u-nu-$it" } ?: code

    /// The locale to resolve resources and format dates/times against.
    val locale: Locale get() = Locale.forLanguageTag(bcp47)

    /// Urdu is drawn in Noto Nastaliq Urdu whatever the user picked in the
    /// font picker (see `NoorFont.family`): the five Naskh families in the
    /// picker render Urdu, but no Urdu reader accepts Naskh for running text.
    val forcesNastaliq: Boolean get() = this == UR

    /// Nastaliq's line box is ~2.5em against Readex Pro's ~1.3em, so an Urdu
    /// row measured for a Naskh face clips the kashida sweep top and bottom.
    /// iOS sets Urdu interface text at 0.72× nominal for the same reason;
    /// on Android this rides on `LocalDensity.fontScale` so it reaches the
    /// hundreds of call sites that pass an explicit `fontSize = N.sp`.
    /// Arabic *content* is exempted — see `ArabicDirection` in LocaleSupport.
    val uiFontScale: Float get() = if (this == UR) 0.72f else 1f

    /// Slightly gentler in the language pickers, where the endonym is the
    /// whole point and there is room for it (iOS uses 0.85× there too).
    val pickerFontScale: Float get() = if (this == UR) 0.85f else 1f

    companion object {
        val DEFAULT = AR

        /// Java still stores the OBSOLETE ISO-639 codes: `Locale("id").language`
        /// is `"in"`, not `"id"` (likewise Hebrew `iw`, Yiddish `ji`). Every
        /// comparison below goes through this, because without it Indonesian
        /// matches nothing, `uiLocale()` falls back to the default bucket, and
        /// the Indonesian user gets the whole app in Arabic — which is exactly
        /// what the first Indonesian screenshot showed.
        private fun normalize(language: String): String = when (language) {
            "in" -> "id"
            "iw" -> "he"
            "ji" -> "yi"
            else -> language
        }

        /// Resolve a BCP-47 tag / language code. Unknown → null.
        fun from(code: String?): NoorLanguage? {
            if (code.isNullOrBlank()) return null
            val lang = normalize(Locale.forLanguageTag(code).language.ifEmpty { code })
            return entries.firstOrNull { it.code == lang }
        }

        fun from(locale: Locale): NoorLanguage? {
            val lang = normalize(locale.language)
            return entries.firstOrNull { it.code == lang }
        }

        /// The language the app is currently DRAWN in, outside composition.
        /// `NoorLocale` pins the JVM default to the resolved UI language, so
        /// this agrees with the strings on screen.
        fun current(): NoorLanguage = from(Locale.getDefault()) ?: DEFAULT
    }
}
