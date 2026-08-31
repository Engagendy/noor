import XCTest
@testable import Library

final class LibraryStoreTests: XCTestCase {
    @MainActor
    func testToggleAndRemove() throws {
        let store = try LibraryStore(inMemory: true)
        XCTAssertTrue(store.bookmarks.isEmpty)

        store.toggle(surahId: 2, ayah: 255)
        XCTAssertTrue(store.isBookmarked(surahId: 2, ayah: 255))
        XCTAssertEqual(store.bookmarks.count, 1)

        store.toggle(surahId: 1, ayah: 1)
        XCTAssertEqual(store.bookmarks.count, 2)

        // Toggling again removes.
        store.toggle(surahId: 2, ayah: 255)
        XCTAssertFalse(store.isBookmarked(surahId: 2, ayah: 255))

        store.remove(store.bookmarks[0])
        XCTAssertTrue(store.bookmarks.isEmpty)
    }
}
