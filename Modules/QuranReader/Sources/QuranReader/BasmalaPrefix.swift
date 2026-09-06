import Foundation

/// Display-only handling of the basmala that the bundled Quran text carries
/// INSIDE ayah 1.
///
/// Data quirk (verified against the bundled `quran.sqlite`, 2026-09-06):
/// 111 of the 114 `ayah = 1` rows begin with the basmala followed by a single
/// space, then the ayah's own words. The exceptions are surah 9 (At-Tawbah,
/// which has no basmala at all) and surahs 95 and 97, whose stored basmala
/// carries one extra combining mark on the first letter — so a fixed
/// character count would silently fail on them. Surah 1 (Al-Fatiha) ayah 1 IS
/// the basmala and nothing else: in the Hafs count it is a counted ayah, and
/// it must be rendered as an ordinary numbered ayah, never stripped.
///
/// The reader draws its own basmala line above ayah 1, so at those two call
/// sites (flow "Mushaf" layout and "Ayah by ayah" layout) the stored prefix
/// would show a second time. This helper removes it FOR DISPLAY ONLY. The
/// database is never modified and the text is never rewritten: everything
/// returned here is a verbatim suffix of the stored, checksummed row.
///
/// Caveat — 27:30 (Sulayman's letter) contains the basmala MID-VERSE. Only a
/// LEADING occurrence is ever removed, and only where the caller has already
/// decided that a separate basmala line is being rendered, so that ayah (and
/// any other mid-verse occurrence) is untouched.
public enum BasmalaPrefix {
    /// Arabic combining marks that vary between otherwise identical copies of
    /// the basmala in the source text (harakat, Quranic annotation signs,
    /// superscript alef, tatweel). Ignored when matching the prefix.
    private static func isSkippableMark(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x0640,             // tatweel
             0x064B...0x065F,    // harakat + extended marks
             0x0670,             // superscript alef
             0x06D6...0x06ED:    // Quranic annotation signs
            return true
        default:
            return false
        }
    }

    /// Returns `text` without a LEADING basmala and its single following
    /// space, or `text` unchanged when it does not start with one.
    ///
    /// - Parameters:
    ///   - text: the stored ayah text, verbatim from the content DB.
    ///   - basmala: the reference basmala, itself read from the DB (surah 1
    ///     ayah 1) — never a literal in source, per the Quran-integrity rule.
    ///     Matching ignores combining marks so orthographic variants of the
    ///     same words (surahs 95 and 97) are recognised too.
    public static func strippingLeadingBasmala(from text: String, basmala: String) -> String {
        let target: [Unicode.Scalar] = basmala.unicodeScalars.filter { !isSkippableMark($0) }
        guard !target.isEmpty else { return text }

        var matched = 0
        var index = text.unicodeScalars.startIndex
        let end = text.unicodeScalars.endIndex
        while index < end {
            let scalar = text.unicodeScalars[index]
            if isSkippableMark(scalar) {
                index = text.unicodeScalars.index(after: index)
                continue
            }
            if matched == target.count {
                // The basmala matched in full: the ayah's own words must be
                // separated from it by exactly one space.
                guard scalar == " " else { return text }
                let bodyStart = text.unicodeScalars.index(after: index)
                return String(text.unicodeScalars[bodyStart...])
            }
            guard scalar == target[matched] else {
                return text
            }
            matched += 1
            index = text.unicodeScalars.index(after: index)
        }
        // Text IS the basmala with nothing after it (surah 1 ayah 1) — keep it.
        return text
    }
}
