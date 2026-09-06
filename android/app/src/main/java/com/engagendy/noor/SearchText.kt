package com.engagendy.noor

/// Shared, diacritic-insensitive text matching for every Arabic search in
/// the app (Quran word search, athkar search).
///
/// `normalizeForSearch` is the SINGLE normalizer — it mirrors iOS
/// QuranSearch / Tools/build_quran_db.py, and the bundled `verse_search`
/// table was built with exactly these rules, so it must never diverge.
/// `QuranDb.normalizeForSearch` delegates here.
///
/// Nothing in this file ever produces text for display: normalization is
/// only used to compare and to locate a match; snippets are always cut out
/// of the ORIGINAL, verified string.
object SearchText {

    /// Strips tashkeel/quranic marks/superscript alef/tatweel and folds
    /// alef and alef-maqsura variants. Display text is never touched.
    fun normalizeForSearch(text: String): String = buildString(text.length) {
        for (ch in text) append(folded(ch) ?: continue)
    }

    /// Normalized text plus, for each normalized character, the index of the
    /// character it came from in `text` — lets a match found in normalized
    /// space be cut out of the original string.
    fun normalizedIndexed(text: String): Pair<String, IntArray> {
        val sb = StringBuilder(text.length)
        val map = IntArray(text.length)
        for (i in text.indices) {
            val f = folded(text[i]) ?: continue
            map[sb.length] = i
            sb.append(f)
        }
        return sb.toString() to map
    }

    private fun folded(ch: Char): Char? {
        val v = ch.code
        if (v in 0x064B..0x065F || v in 0x06D6..0x06ED || v == 0x0670 || v == 0x0640) return null
        return when (v) {
            0x0622, 0x0623, 0x0625, 0x0671 -> 'ا' // alef variants
            0x0649 -> 'ي'                          // alef maqsura → ya
            else -> ch.lowercaseChar()             // English is case-insensitive
        }
    }

    /// True when `text` contains `normalizedQuery` ignoring diacritics/case.
    fun contains(text: String, normalizedQuery: String): Boolean =
        normalizedQuery.isNotEmpty() && normalizeForSearch(text).contains(normalizedQuery)

    /// Where the query matches inside the ORIGINAL text (indices into
    /// `text`), or null. The range is widened over trailing combining marks
    /// so a highlighted word keeps its harakat.
    fun matchRange(text: String, normalizedQuery: String): IntRange? {
        if (normalizedQuery.isEmpty()) return null
        val (norm, map) = normalizedIndexed(text)
        val at = norm.indexOf(normalizedQuery)
        if (at < 0) return null
        val start = map[at]
        var end = map[at + normalizedQuery.length - 1]
        while (end + 1 < text.length && folded(text[end + 1]) == null) end++
        return start..end
    }

    /// Match quality, best (0) first — the Quran search ranking tiers:
    ///  0 = the query is a whole word,
    ///  1 = it starts a word (optionally after the Arabic proclitics
    ///      ال / و / ف / ب / ل / ك, so "رحمن" ranks high in "الرحمن"),
    ///  2 = it sits mid-word.
    /// Returns 3 when there is no match at all.
    fun matchTier(text: String, normalizedQuery: String): Int {
        if (normalizedQuery.isEmpty()) return 3
        val norm = normalizeForSearch(text)
        var from = 0
        var best = 3
        while (true) {
            val at = norm.indexOf(normalizedQuery, from)
            if (at < 0) return best
            val end = at + normalizedQuery.length
            val startsWord = at == 0 || !norm[at - 1].isLetterOrDigit()
            val endsWord = end == norm.length || !norm[end].isLetterOrDigit()
            val tier = when {
                startsWord && endsWord -> 0
                startsWord || afterProclitic(norm, at) -> 1
                else -> 2
            }
            if (tier < best) best = tier
            if (best == 0) return 0
            from = at + 1
        }
    }

    /// True when everything between the start of the word and `at` is one of
    /// the common Arabic proclitics that glue onto the following word.
    private fun afterProclitic(norm: String, at: Int): Boolean {
        var start = at
        while (start > 0 && norm[start - 1].isLetterOrDigit()) start--
        val prefix = norm.substring(start, at)
        return prefix in proclitics
    }

    private val proclitics = setOf(
        "ال", "و", "ف", "ب", "ل", "ك", "وال", "فال", "بال", "لل", "كال", "س", "سي",
    )
}
