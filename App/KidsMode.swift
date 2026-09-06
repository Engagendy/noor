import Foundation

/// Pure kids-mode rules: which surahs a child of a given age sees, how big
/// the text is, how many times each ayah repeats, and the star ledger.
///
/// Everything here is deliberately free of SwiftUI and of any singleton so
/// it can be unit tested, and it is the single source of truth mirrored by
/// the Android build. Kids mode NEVER changes the Quran text — only which
/// surahs are surfaced and how they are presented.
enum KidsMode {
    // MARK: Defaults keys (identical on Android)

    /// Bool, default false.
    static let enabledKey = "kids.enabled"
    /// Int, default 7, valid 4…12.
    static let ageKey = "kids.age"
    /// `[String surahId: Int stars]`, 0…3 per surah.
    static let starsKey = "kids.stars"
    /// Bool, default false — false = memorise (repeats), true = listen
    /// (each ayah once, straight through).
    static let listenModeKey = "kids.listenMode"
    /// Bool, default false. Latches true the first time kids mode is ever
    /// enabled and is NEVER reset — see `reciterOnEnable`.
    static let reciterAppliedKey = "kids.reciterApplied"

    static let defaultAge = 7
    static let ageRange = 4...12
    /// The most stars one surah can earn.
    static let maxStars = 3

    // MARK: Age bands

    enum Band: CaseIterable {
        /// 4–6: Al-Fatiha + the last ten surahs.
        case youngest
        /// 7–9: Al-Fatiha + Juz Amma.
        case middle
        /// 10–12: the whole mushaf.
        case oldest
    }

    /// Ages outside 4…12 clamp into the range rather than failing: a
    /// corrupt or unset default must still open a usable shell.
    static func clampAge(_ age: Int) -> Int {
        min(max(age, ageRange.lowerBound), ageRange.upperBound)
    }

    static func band(age: Int) -> Band {
        switch clampAge(age) {
        case 4...6: .youngest
        case 7...9: .middle
        default: .oldest
        }
    }

    /// Surahs offered to a child of this age, in mushaf order.
    static func surahIds(age: Int) -> [Int] {
        switch band(age: age) {
        case .youngest: [1] + Array(105...114)
        case .middle: [1] + Array(78...114)
        case .oldest: Array(1...114)
        }
    }

    /// Multiplier applied to the reader's Quran text size.
    static func textScale(age: Int) -> Double {
        switch band(age: age) {
        case .youngest: 1.35
        case .middle: 1.2
        case .oldest: 1.0
        }
    }

    /// How many times each ayah is played before moving on.
    static func repeatCount(age: Int) -> Int {
        switch band(age: age) {
        case .youngest: 3
        case .middle: 2
        case .oldest: 1
        }
    }

    /// Repeats actually used: listening never repeats, whatever the age.
    static func repeatCount(age: Int, listenMode: Bool) -> Int {
        listenMode ? 1 : repeatCount(age: age)
    }

    /// The reader only shows the repetition indicator when it means
    /// something — never "1 of 1".
    static func showsRepeatIndicator(age: Int, listenMode: Bool) -> Bool {
        repeatCount(age: age, listenMode: listenMode) > 1
    }

    /// Only the oldest band may leave the ayah-by-ayah layout.
    static func allowsFlowLayout(age: Int) -> Bool {
        band(age: age) == .oldest
    }

    // MARK: Stored settings

    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: enabledKey)
    }

    static func age(defaults: UserDefaults = .standard) -> Int {
        let stored = defaults.object(forKey: ageKey) as? Int
        return clampAge(stored ?? defaultAge)
    }

    static func setAge(_ age: Int, defaults: UserDefaults = .standard) {
        defaults.set(clampAge(age), forKey: ageKey)
    }

    static func setEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: enabledKey)
    }

    /// The reciter to store when kids mode is switched on.
    ///
    /// The Muallim teaching recitation is applied ONCE in the app's
    /// lifetime: `kids.reciterApplied` latches on the first enable and
    /// disabling kids mode never clears it, so a parent who later picks a
    /// different sheikh keeps that choice across disable and re-enable.
    ///
    /// - Parameters:
    ///   - current: what `audio.reciter` holds right now.
    ///   - teaching: `Reciter.husaryMuallim.rawValue` (passed in so this
    ///     type stays free of the audio module).
    /// - Returns: the raw value the caller should store.
    static func reciterOnEnable(current: String, teaching: String,
                                defaults: UserDefaults = .standard) -> String {
        guard !defaults.bool(forKey: reciterAppliedKey) else { return current }
        defaults.set(true, forKey: reciterAppliedKey)
        return teaching
    }

    /// Memorise is the default: the teaching behaviour leads.
    static func isListenMode(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: listenModeKey)
    }

    static func setListenMode(_ listening: Bool, defaults: UserDefaults = .standard) {
        defaults.set(listening, forKey: listenModeKey)
    }

    // MARK: Stars

    /// The whole ledger, surah id → stars earned (0…3).
    static func allStars(defaults: UserDefaults = .standard) -> [Int: Int] {
        let raw = defaults.dictionary(forKey: starsKey) as? [String: Int] ?? [:]
        return raw.reduce(into: [Int: Int]()) { result, pair in
            guard let surahId = Int(pair.key) else { return }
            result[surahId] = min(max(pair.value, 0), maxStars)
        }
    }

    static func stars(surahId: Int, defaults: UserDefaults = .standard) -> Int {
        allStars(defaults: defaults)[surahId] ?? 0
    }

    static func totalStars(defaults: UserDefaults = .standard) -> Int {
        allStars(defaults: defaults).values.reduce(0, +)
    }

    /// One completed play of a surah = one star, up to three. Returns the
    /// new count for that surah (unchanged once it is already at three).
    @discardableResult
    static func awardStar(surahId: Int, defaults: UserDefaults = .standard) -> Int {
        var ledger = allStars(defaults: defaults)
        let updated = min((ledger[surahId] ?? 0) + 1, maxStars)
        ledger[surahId] = updated
        let raw = ledger.reduce(into: [String: Int]()) { result, pair in
            result[String(pair.key)] = pair.value
        }
        defaults.set(raw, forKey: starsKey)
        return updated
    }
}
