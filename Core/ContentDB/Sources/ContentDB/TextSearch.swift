import Foundation

/// Shared, content-agnostic search helpers: one Arabic folding rule for the
/// whole app (Quran verses, surah names, athkar), plus the match ranking and
/// snippet building that every search screen presents.
///
/// The folding rules mirror `Tools/build_quran_db.py` (and the Android
/// `QuranDb.normalizeForSearch` / `CityDb.fold`): strip tashkeel, Quranic
/// annotation marks, the superscript alef and tatweel; unify the alef
/// variants and alef-maqsura. `QuranDatabase.normalizeForSearch` is a thin
/// wrapper over `ArabicSearch.fold` so the DB column and every in-memory
/// search agree by construction.
public enum ArabicSearch {
    /// How well a match sits inside the text it was found in — the ranking
    /// tier used to order results (lower is better).
    public enum MatchTier: Int, Comparable, Hashable, Sendable {
        /// The query is a standalone word (both sides are word boundaries).
        case wholeWord = 0
        /// The query starts a word but continues into it ("rahm" in "rahman").
        case wordPrefix = 1
        /// The query starts mid-word ("hman" in "rahman").
        case partial = 2

        public static func < (lhs: MatchTier, rhs: MatchTier) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    // MARK: - Folding

    /// Folds one scalar for search. Returns nil for scalars that are dropped
    /// (diacritics, Quranic marks, tatweel).
    private static func fold(scalar: UnicodeScalar,
                             caseInsensitive: Bool,
                             foldingDigits: Bool) -> UnicodeScalar? {
        let value = scalar.value
        // Tashkeel + Quranic annotation marks + superscript alef + tatweel.
        if (0x064B...0x065F).contains(value) || (0x06D6...0x06ED).contains(value)
            || value == 0x0670 || value == 0x0640 {
            return nil
        }
        switch value {
        case 0x0622, 0x0623, 0x0625, 0x0671:
            return UnicodeScalar(0x0627)!  // alef variants → bare alef
        case 0x0649:
            return UnicodeScalar(0x064A)!  // alef maqsura → ya
        default:
            break
        }
        if foldingDigits {
            // Arabic-Indic (٠-٩) and extended Arabic-Indic (۰-۹) → ASCII.
            if (0x0660...0x0669).contains(value) {
                return UnicodeScalar(value - 0x0660 + 0x30)!
            }
            if (0x06F0...0x06F9).contains(value) {
                return UnicodeScalar(value - 0x06F0 + 0x30)!
            }
        }
        if caseInsensitive, scalar.properties.isUppercase {
            // Length-preserving lowercase: keep the scalar when the lowercase
            // form is not a single scalar, so index maps stay 1:1.
            let lower = String(Character(scalar)).lowercased().unicodeScalars
            if lower.count == 1 { return lower.first }
        }
        return scalar
    }

    /// Folded form of `text`: Arabic diacritics/marks removed, alef and ya
    /// variants unified, Arabic-Indic digits normalized and (by default)
    /// case folded. Latin text is only case folded.
    public static func fold(_ text: String,
                            caseInsensitive: Bool = true,
                            foldingDigits: Bool = true) -> String {
        var out = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if let folded = fold(scalar: scalar,
                                 caseInsensitive: caseInsensitive,
                                 foldingDigits: foldingDigits) {
                out.append(folded)
            }
        }
        return String(out)
    }

    /// A folded string that remembers where each folded scalar came from, so
    /// a match found in folded space can be highlighted in the original text.
    public struct FoldedText: Sendable {
        public let scalars: [UnicodeScalar]
        /// `sources[i]` is the index in the original string of the character
        /// that produced `scalars[i]`.
        let sources: [String.Index]
        public let original: String

        public var string: String { String(String.UnicodeScalarView(scalars)) }
        public var isEmpty: Bool { scalars.isEmpty }
    }

    public static func folded(_ text: String) -> FoldedText {
        var scalars: [UnicodeScalar] = []
        var sources: [String.Index] = []
        scalars.reserveCapacity(text.unicodeScalars.count)
        sources.reserveCapacity(text.unicodeScalars.count)
        var index = text.startIndex
        while index < text.endIndex {
            for scalar in text[index].unicodeScalars {
                if let folded = fold(scalar: scalar, caseInsensitive: true, foldingDigits: true) {
                    scalars.append(folded)
                    sources.append(index)
                }
            }
            index = text.index(after: index)
        }
        return FoldedText(scalars: scalars, sources: sources, original: text)
    }

    // MARK: - Matching

    private static func isWordScalar(_ scalar: UnicodeScalar) -> Bool {
        CharacterSet.alphanumerics.contains(scalar)
    }

    /// The first occurrence of `query` inside `text`, compared in folded
    /// space, reported as a range of the *original* text plus its tier.
    /// Returns nil when the query does not occur (or is empty once folded).
    public static func firstMatch(of query: String, in text: String)
        -> (range: Range<String.Index>, tier: MatchTier)? {
        let needle = Array(fold(query).unicodeScalars)
        guard !needle.isEmpty else { return nil }
        let haystack = folded(text)
        guard let start = search(needle, in: haystack.scalars) else { return nil }
        let end = start + needle.count
        let lower = haystack.sources[start]
        let upper = text.index(after: haystack.sources[end - 1])
        let before = start > 0 ? haystack.scalars[start - 1] : nil
        let after = end < haystack.scalars.count ? haystack.scalars[end] : nil
        let startsWord = before.map { !isWordScalar($0) } ?? true
        let endsWord = after.map { !isWordScalar($0) } ?? true
        let tier: MatchTier = startsWord ? (endsWord ? .wholeWord : .wordPrefix) : .partial
        return (lower..<upper, tier)
    }

    /// Cheap containment test in folded space (no index mapping).
    public static func contains(_ query: String, in text: String) -> Bool {
        let needle = Array(fold(query).unicodeScalars)
        guard !needle.isEmpty else { return false }
        return search(needle, in: Array(fold(text).unicodeScalars)) != nil
    }

    /// Tier of the best match of `query` in an already-folded haystack, or nil.
    public static func tier(of query: String, inFolded haystack: [UnicodeScalar]) -> MatchTier? {
        let needle = Array(fold(query).unicodeScalars)
        guard !needle.isEmpty, let start = search(needle, in: haystack) else { return nil }
        let end = start + needle.count
        let before = start > 0 ? haystack[start - 1] : nil
        let after = end < haystack.count ? haystack[end] : nil
        let startsWord = before.map { !isWordScalar($0) } ?? true
        let endsWord = after.map { !isWordScalar($0) } ?? true
        return startsWord ? (endsWord ? .wholeWord : .wordPrefix) : .partial
    }

    /// Naive substring search — needles are user queries (short) and
    /// haystacks are one ayah/dhikr, so this stays well under a frame.
    private static func search(_ needle: [UnicodeScalar], in haystack: [UnicodeScalar]) -> Int? {
        guard !needle.isEmpty, haystack.count >= needle.count else { return nil }
        let last = haystack.count - needle.count
        var start = 0
        while start <= last {
            var offset = 0
            while offset < needle.count, haystack[start + offset] == needle[offset] {
                offset += 1
            }
            if offset == needle.count { return start }
            start += 1
        }
        return nil
    }

    // MARK: - Snippets

    /// A window of text centred on the match, split so the view can
    /// emphasise the matched run. Text is never altered — only sliced.
    public struct Snippet: Hashable, Sendable {
        public let before: String
        public let match: String
        public let after: String
        public let truncatedStart: Bool
        public let truncatedEnd: Bool

        public init(before: String, match: String, after: String,
                    truncatedStart: Bool, truncatedEnd: Bool) {
            self.before = before
            self.match = match
            self.after = after
            self.truncatedStart = truncatedStart
            self.truncatedEnd = truncatedEnd
        }

        /// Plain, unemphasised rendering (accessibility labels, tests).
        public var plain: String {
            (truncatedStart ? "…" : "") + before + match + after + (truncatedEnd ? "…" : "")
        }
    }

    /// Window of `text` around the first match of `query`, with roughly
    /// `context` characters on each side, cut at word boundaries.
    public static func snippet(for text: String, matching query: String,
                               context: Int = 34) -> Snippet? {
        guard let match = firstMatch(of: query, in: text) else { return nil }
        var start = text.index(match.range.lowerBound,
                               offsetBy: -context,
                               limitedBy: text.startIndex) ?? text.startIndex
        var end = text.index(match.range.upperBound,
                             offsetBy: context,
                             limitedBy: text.endIndex) ?? text.endIndex
        let truncatedStart = start != text.startIndex
        let truncatedEnd = end != text.endIndex
        // Do not cut a word in half: pull the window in to whitespace.
        if truncatedStart,
           let space = text[start..<match.range.lowerBound].firstIndex(where: \.isWhitespace) {
            start = text.index(after: space)
        }
        if truncatedEnd,
           let space = text[match.range.upperBound..<end].lastIndex(where: \.isWhitespace) {
            end = space
        }
        return Snippet(
            before: String(text[start..<match.range.lowerBound]),
            match: String(text[match.range]),
            after: String(text[match.range.upperBound..<end]),
            truncatedStart: truncatedStart,
            truncatedEnd: truncatedEnd)
    }
}

// MARK: - Quran references

/// A parsed "2:255"-style reference typed into a search field.
public struct QuranReference: Hashable, Sendable {
    public let surahId: Int
    /// Nil when only a surah number was typed.
    public let ayah: Int?

    public init(surahId: Int, ayah: Int?) {
        self.surahId = surahId
        self.ayah = ayah
    }

    /// Accepted forms: `2`, `2:255`, `2 255`, `2-255`, `2.255`, and any of
    /// these written with Arabic-Indic (٢:٢٥٥) or extended Arabic-Indic
    /// digits. Returns nil when the text is not a reference at all, or when
    /// the surah number is out of range.
    public static func parse(_ text: String, surahCount: Int = 114) -> QuranReference? {
        let folded = ArabicSearch.fold(text).trimmingCharacters(in: .whitespaces)
        guard !folded.isEmpty else { return nil }
        var numbers: [Int] = []
        var current = ""
        for character in folded {
            if character.isASCII, character.isNumber {
                current.append(character)
            } else if character.isWhitespace || ":-.،,؛".contains(character) {
                if !current.isEmpty, let value = Int(current) { numbers.append(value) }
                current = ""
            } else {
                return nil  // any other character → not a reference
            }
        }
        if !current.isEmpty, let value = Int(current) { numbers.append(value) }
        // `surahCount` can legitimately be 0 while a view is still loading
        // its surah list — compare, never build a range.
        guard let surah = numbers.first, surah >= 1, surah <= surahCount else { return nil }
        switch numbers.count {
        case 1: return QuranReference(surahId: surah, ayah: nil)
        case 2:
            let ayah = numbers[1]
            return ayah >= 1 ? QuranReference(surahId: surah, ayah: ayah) : nil
        default: return nil
        }
    }
}

// MARK: - Surah name search

public enum SurahSearch {
    /// Surahs whose Arabic name, transliteration, English meaning or number
    /// matches `query`, best matches first. Matching is diacritic- and
    /// case-insensitive, so "the cow", "Cow", "baqara" and "بقرة" all find
    /// surah 2.
    public static func matches(_ surahs: [Surah], query: String) -> [Surah] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return surahs }
        // A bare number (or reference) is a jump, not a name search.
        if let reference = QuranReference.parse(trimmed) {
            return surahs.filter { $0.id == reference.surahId }
        }
        let scored: [(surah: Surah, rank: Int)] = surahs.compactMap { surah in
            guard let rank = rank(surah, query: trimmed) else { return nil }
            return (surah, rank)
        }
        return scored
            .sorted { $0.rank != $1.rank ? $0.rank < $1.rank : $0.surah.id < $1.surah.id }
            .map(\.surah)
    }

    /// Best (lowest) tier over every name of the surah, or nil for no match.
    /// 0 = an exact name, 1 = a name starts with the query, 2 = a word inside
    /// a name starts with it, 3 = anywhere inside a name.
    static func rank(_ surah: Surah, query: String) -> Int? {
        var best: Int?
        for name in names(of: surah) {
            guard let rank = rank(name: name, query: query) else { continue }
            best = min(best ?? rank, rank)
        }
        return best
    }

    private static func names(of surah: Surah) -> [String] {
        var names = [surah.nameArabic, surah.nameTransliterated, surah.nameEnglish]
        // "Al-Baqara" typed as "albaqara", "The Cow" typed as "cow".
        let compact = surah.nameTransliterated.filter { $0.isLetter || $0.isNumber }
        if compact != surah.nameTransliterated { names.append(compact) }
        let english = surah.nameEnglish.lowercased()
        if english.hasPrefix("the ") { names.append(String(surah.nameEnglish.dropFirst(4))) }
        // The Arabic name without its definite article ("بقرة").
        let arabic = ArabicSearch.fold(surah.nameArabic)
        if arabic.hasPrefix("ال"), arabic.count > 3 { names.append(String(arabic.dropFirst(2))) }
        return names
    }

    private static func rank(name: String, query: String) -> Int? {
        let foldedName = ArabicSearch.fold(name)
        let foldedQuery = ArabicSearch.fold(query)
        guard !foldedQuery.isEmpty else { return nil }
        if foldedName == foldedQuery { return 0 }
        if foldedName.hasPrefix(foldedQuery) { return 1 }
        switch ArabicSearch.tier(of: query, inFolded: Array(foldedName.unicodeScalars)) {
        case .wholeWord, .wordPrefix: return 2
        case .partial: return 3
        case nil: return nil
        }
    }
}
