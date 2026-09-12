import Athkar
import XCTest

/// Favourite athkar: keyed on the recording's file name (the only stable,
/// unique field a dhikr has), stored as a set that survives a relaunch.
@MainActor
final class AthkarFavoritesTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "AthkarFavoritesTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    /// The key is the audio file name, and it is unique across the data —
    /// text is not (four rows repeat one), position is not stable.
    func testKeyIsTheAudioFileName() {
        let categories = AthkarStore.load()
        let items = categories.flatMap(\.items)
        XCTAssertFalse(items.isEmpty, "bundled athkar.json must load")
        var keys: Set<String> = []
        for dhikr in items {
            let key = AthkarFavorites.key(for: dhikr)
            XCTAssertEqual(key, dhikr.audio)
            XCTAssertNotNil(key, "every bundled dhikr must be favouritable")
            if let key { keys.insert(key) }
        }
        XCTAssertEqual(keys.count, items.count, "audio file names must be unique")
    }

    func testToggleAddsThenRemoves() {
        let favorites = AthkarFavorites(defaults: defaults, cloud: nil)
        let dhikr = try! XCTUnwrap(AthkarStore.load().first?.items.first)
        let key = try! XCTUnwrap(AthkarFavorites.key(for: dhikr))
        XCTAssertFalse(favorites.isFavorite(dhikr))

        favorites.toggle(dhikr)
        XCTAssertTrue(favorites.isFavorite(dhikr))
        XCTAssertTrue(favorites.isFavorite(key))
        XCTAssertEqual(favorites.keys, [key])

        favorites.toggle(dhikr)
        XCTAssertFalse(favorites.isFavorite(dhikr))
        XCTAssertTrue(favorites.keys.isEmpty)
    }

    func testFavoritesSurviveAReload() {
        let first = AthkarFavorites(defaults: defaults, cloud: nil)
        first.toggle("75.mp3")
        first.toggle("76.mp3")
        first.toggle("75.mp3")

        let reloaded = AthkarFavorites(defaults: defaults, cloud: nil)
        XCTAssertEqual(reloaded.keys, ["76.mp3"])
        XCTAssertEqual(defaults.stringArray(forKey: AthkarFavorites.storageKey), ["76.mp3"])
        XCTAssertEqual(AthkarFavorites.storageKey, "athkar.favorites",
                       "the storage key is shared with iCloud KVS and Android")
    }
}
