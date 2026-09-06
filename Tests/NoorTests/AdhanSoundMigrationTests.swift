import PrayerTimes
import XCTest
@testable import Noor

/// The withdrawn "Adhan (Makkah, Maghrib)" recording. Anyone who had picked
/// it still has `adhanMakkahMaghrib` in UserDefaults, and a notification whose
/// sound names a file no longer in the bundle plays the system default or
/// nothing — so the retired value must resolve to the OTHER Makkah adhan.
final class AdhanSoundMigrationTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "AdhanSoundMigrationTests")!
        defaults.removePersistentDomain(forName: "AdhanSoundMigrationTests")
    }

    func testRetiredMaghribValueResolvesToTheOtherMakkahAdhan() {
        XCTAssertNil(AdhanSound(rawValue: "adhanMakkahMaghrib"))
        XCTAssertEqual(AdhanSound.stored("adhanMakkahMaghrib"), .adhanMakkah)
        XCTAssertNotNil(AdhanSound.stored("adhanMakkahMaghrib").fileName)
    }

    func testUnknownValueFallsBackToTheDefault() {
        XCTAssertEqual(AdhanSound.stored("somethingElse"), .adhanMadinah)
    }

    func testKnownValuesAreUnchanged() {
        for sound in AdhanSound.allCases {
            XCTAssertEqual(AdhanSound.stored(sound.rawValue), sound)
        }
        XCTAssertFalse(AdhanSound.allCases.contains { $0.rawValue == "adhanMakkahMaghrib" })
    }

    func testMigrationRewritesTheStoredValueOnce() {
        defaults.set("adhanMakkahMaghrib", forKey: AdhanSound.defaultsKey)
        XCTAssertTrue(AdhanSound.migrateStoredValue(defaults: defaults))
        XCTAssertEqual(defaults.string(forKey: AdhanSound.defaultsKey),
                       AdhanSound.adhanMakkah.rawValue)
        XCTAssertFalse(AdhanSound.migrateStoredValue(defaults: defaults))
    }

    func testMigrationLeavesAValidChoiceAlone() {
        defaults.set(AdhanSound.adhanAzeez.rawValue, forKey: AdhanSound.defaultsKey)
        XCTAssertFalse(AdhanSound.migrateStoredValue(defaults: defaults))
        XCTAssertEqual(defaults.string(forKey: AdhanSound.defaultsKey),
                       AdhanSound.adhanAzeez.rawValue)
    }

    func testEveryBundledSoundFileExists() throws {
        for sound in AdhanSound.allCases {
            guard let file = sound.fileName else { continue }
            let name = (file as NSString).deletingPathExtension
            let ext = (file as NSString).pathExtension
            XCTAssertNotNil(Bundle.main.url(forResource: name, withExtension: ext),
                            "missing bundled sound \(file)")
        }
    }
}
