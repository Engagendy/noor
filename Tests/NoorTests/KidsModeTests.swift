import ContentDB
import XCTest
@testable import Noor

/// Pure kids-mode rules: the age→content mapping and the star ledger.
/// Per the Quran-integrity rule no Quranic text appears here — the surah
/// metadata used for cross-checks is read from the bundled content DB.
final class KidsModeTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "KidsModeTests")!
        defaults.removePersistentDomain(forName: "KidsModeTests")
    }

    // MARK: Surah sets

    func testYoungestBandIsFatihaPlusLastTen() {
        let expected = [1] + Array(105...114)
        XCTAssertEqual(KidsMode.surahIds(age: 4), expected)
        XCTAssertEqual(KidsMode.surahIds(age: 6), expected)
        XCTAssertEqual(KidsMode.surahIds(age: 5).count, 11)
    }

    func testMiddleBandIsFatihaPlusJuzAmma() {
        let expected = [1] + Array(78...114)
        XCTAssertEqual(KidsMode.surahIds(age: 7), expected)
        XCTAssertEqual(KidsMode.surahIds(age: 9), expected)
        XCTAssertEqual(KidsMode.surahIds(age: 8).count, 38)
    }

    func testOldestBandIsTheWholeMushaf() {
        XCTAssertEqual(KidsMode.surahIds(age: 10), Array(1...114))
        XCTAssertEqual(KidsMode.surahIds(age: 12), Array(1...114))
        XCTAssertEqual(KidsMode.surahIds(age: 11).count, 114)
    }

    func testEveryBandsSurahsExistInTheContentDatabase() throws {
        let ids = Set(try QuranDatabase().allSurahs().map(\.id))
        for age in KidsMode.ageRange {
            for surahId in KidsMode.surahIds(age: age) {
                XCTAssertTrue(ids.contains(surahId), "surah \(surahId) missing (age \(age))")
            }
        }
    }

    func testYoungerBandsAreSubsetsOfOlderOnes() {
        XCTAssertTrue(Set(KidsMode.surahIds(age: 5)).isSubset(of: Set(KidsMode.surahIds(age: 8))))
        XCTAssertTrue(Set(KidsMode.surahIds(age: 8)).isSubset(of: Set(KidsMode.surahIds(age: 11))))
    }

    // MARK: Presentation

    func testTextScalePerBand() {
        XCTAssertEqual(KidsMode.textScale(age: 4), 1.35, accuracy: 0.0001)
        XCTAssertEqual(KidsMode.textScale(age: 6), 1.35, accuracy: 0.0001)
        XCTAssertEqual(KidsMode.textScale(age: 7), 1.2, accuracy: 0.0001)
        XCTAssertEqual(KidsMode.textScale(age: 9), 1.2, accuracy: 0.0001)
        XCTAssertEqual(KidsMode.textScale(age: 10), 1.0, accuracy: 0.0001)
        XCTAssertEqual(KidsMode.textScale(age: 12), 1.0, accuracy: 0.0001)
    }

    func testRepeatCountPerBand() {
        XCTAssertEqual(KidsMode.repeatCount(age: 4), 3)
        XCTAssertEqual(KidsMode.repeatCount(age: 6), 3)
        XCTAssertEqual(KidsMode.repeatCount(age: 7), 2)
        XCTAssertEqual(KidsMode.repeatCount(age: 9), 2)
        XCTAssertEqual(KidsMode.repeatCount(age: 10), 1)
        XCTAssertEqual(KidsMode.repeatCount(age: 12), 1)
    }

    func testListenModeNeverRepeatsAtAnyAge() {
        for age in KidsMode.ageRange {
            XCTAssertEqual(KidsMode.repeatCount(age: age, listenMode: true), 1)
            XCTAssertEqual(KidsMode.repeatCount(age: age, listenMode: false),
                           KidsMode.repeatCount(age: age))
        }
    }

    func testRepeatIndicatorOnlyShowsWhenRepeatsAreRealRepeats() {
        // Listening: never. Memorising: only where the band repeats.
        for age in KidsMode.ageRange {
            XCTAssertFalse(KidsMode.showsRepeatIndicator(age: age, listenMode: true))
        }
        XCTAssertTrue(KidsMode.showsRepeatIndicator(age: 5, listenMode: false))
        XCTAssertTrue(KidsMode.showsRepeatIndicator(age: 8, listenMode: false))
        // 10–12 memorise with no forced repeat, so "1 of 1" never appears.
        XCTAssertFalse(KidsMode.showsRepeatIndicator(age: 11, listenMode: false))
    }

    // MARK: Teaching reciter (one-shot)

    func testTeachingReciterIsAppliedOnTheFirstEnableOnly() {
        XCTAssertFalse(defaults.bool(forKey: KidsMode.reciterAppliedKey))
        // First enable: the parent had the app default, kids mode moves
        // them to the Muallim teaching recitation.
        let first = KidsMode.reciterOnEnable(
            current: "alafasy", teaching: "husaryMuallim", defaults: defaults)
        XCTAssertEqual(first, "husaryMuallim")
        XCTAssertTrue(defaults.bool(forKey: KidsMode.reciterAppliedKey))
    }

    /// The regression this key exists for: enable, parent picks another
    /// sheikh, disable, enable again — their choice must survive.
    func testParentsReciterSurvivesDisablingAndReEnabling() {
        _ = KidsMode.reciterOnEnable(
            current: "alafasy", teaching: "husaryMuallim", defaults: defaults)
        // Parent changes the reciter, then turns kids mode off…
        let parentsChoice = "minshawi"
        KidsMode.setEnabled(false, defaults: defaults)
        // …and back on. Disabling must not have cleared the latch.
        XCTAssertTrue(defaults.bool(forKey: KidsMode.reciterAppliedKey))
        let second = KidsMode.reciterOnEnable(
            current: parentsChoice, teaching: "husaryMuallim", defaults: defaults)
        XCTAssertEqual(second, parentsChoice)
    }

    func testTeachingReciterIsNeverReappliedHoweverManyEnables() {
        var reciter = "alafasy"
        for _ in 0..<5 {
            reciter = KidsMode.reciterOnEnable(
                current: reciter, teaching: "husaryMuallim", defaults: defaults)
        }
        XCTAssertEqual(reciter, "husaryMuallim")
        // A change after the latch is never overwritten.
        reciter = "ghamdi"
        reciter = KidsMode.reciterOnEnable(
            current: reciter, teaching: "husaryMuallim", defaults: defaults)
        XCTAssertEqual(reciter, "ghamdi")
    }

    func testMemoriseIsTheDefaultPlaybackChoice() {
        XCTAssertFalse(KidsMode.isListenMode(defaults: defaults))
        KidsMode.setListenMode(true, defaults: defaults)
        XCTAssertTrue(defaults.bool(forKey: KidsMode.listenModeKey))
        XCTAssertTrue(KidsMode.isListenMode(defaults: defaults))
    }

    func testOnlyTheOldestBandMaySwitchToFlowLayout() {
        XCTAssertFalse(KidsMode.allowsFlowLayout(age: 4))
        XCTAssertFalse(KidsMode.allowsFlowLayout(age: 9))
        XCTAssertTrue(KidsMode.allowsFlowLayout(age: 10))
        XCTAssertTrue(KidsMode.allowsFlowLayout(age: 12))
    }

    // MARK: Age clamping

    func testAgesOutsideTheRangeClampToTheNearestEdge() {
        XCTAssertEqual(KidsMode.clampAge(0), 4)
        XCTAssertEqual(KidsMode.clampAge(3), 4)
        XCTAssertEqual(KidsMode.clampAge(-7), 4)
        XCTAssertEqual(KidsMode.clampAge(13), 12)
        XCTAssertEqual(KidsMode.clampAge(99), 12)
        XCTAssertEqual(KidsMode.clampAge(7), 7)
        // Out-of-range ages still resolve to a usable band.
        XCTAssertEqual(KidsMode.surahIds(age: 2), KidsMode.surahIds(age: 4))
        XCTAssertEqual(KidsMode.surahIds(age: 40), KidsMode.surahIds(age: 12))
        XCTAssertEqual(KidsMode.repeatCount(age: 2), 3)
        XCTAssertEqual(KidsMode.repeatCount(age: 40), 1)
    }

    func testStoredAgeDefaultsToSevenAndClampsOnRead() {
        XCTAssertEqual(KidsMode.age(defaults: defaults), 7)
        defaults.set(99, forKey: KidsMode.ageKey)
        XCTAssertEqual(KidsMode.age(defaults: defaults), 12)
        KidsMode.setAge(1, defaults: defaults)
        XCTAssertEqual(defaults.integer(forKey: KidsMode.ageKey), 4)
    }

    func testKidsModeIsOffByDefault() {
        XCTAssertFalse(KidsMode.isEnabled(defaults: defaults))
        KidsMode.setEnabled(true, defaults: defaults)
        XCTAssertTrue(defaults.bool(forKey: KidsMode.enabledKey))
    }

    // MARK: Stars

    func testEachCompletedPlayAwardsExactlyOneStar() {
        XCTAssertEqual(KidsMode.stars(surahId: 112, defaults: defaults), 0)
        XCTAssertEqual(KidsMode.awardStar(surahId: 112, defaults: defaults), 1)
        XCTAssertEqual(KidsMode.awardStar(surahId: 112, defaults: defaults), 2)
        XCTAssertEqual(KidsMode.stars(surahId: 112, defaults: defaults), 2)
    }

    func testStarsCapAtThreeHoweverManyPlays() {
        for _ in 0..<10 {
            KidsMode.awardStar(surahId: 114, defaults: defaults)
        }
        XCTAssertEqual(KidsMode.stars(surahId: 114, defaults: defaults), KidsMode.maxStars)
        XCTAssertEqual(KidsMode.stars(surahId: 114, defaults: defaults), 3)
    }

    func testStarsAreTrackedPerSurah() {
        KidsMode.awardStar(surahId: 1, defaults: defaults)
        KidsMode.awardStar(surahId: 1, defaults: defaults)
        KidsMode.awardStar(surahId: 113, defaults: defaults)
        XCTAssertEqual(KidsMode.stars(surahId: 1, defaults: defaults), 2)
        XCTAssertEqual(KidsMode.stars(surahId: 113, defaults: defaults), 1)
        XCTAssertEqual(KidsMode.stars(surahId: 114, defaults: defaults), 0)
        XCTAssertEqual(KidsMode.totalStars(defaults: defaults), 3)
    }

    func testTotalStarsNeverExceedsThreePerSurah() {
        for _ in 0..<5 {
            KidsMode.awardStar(surahId: 111, defaults: defaults)
            KidsMode.awardStar(surahId: 112, defaults: defaults)
        }
        XCTAssertEqual(KidsMode.totalStars(defaults: defaults), 6)
    }

    func testCorruptLedgerValuesAreClampedOnRead() {
        defaults.set(["112": 9, "notASurah": 2, "1": -4], forKey: KidsMode.starsKey)
        XCTAssertEqual(KidsMode.stars(surahId: 112, defaults: defaults), 3)
        XCTAssertEqual(KidsMode.stars(surahId: 1, defaults: defaults), 0)
        XCTAssertEqual(KidsMode.totalStars(defaults: defaults), 3)
    }
}
