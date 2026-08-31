import XCTest
@testable import Athkar

final class AthkarStoreTests: XCTestCase {
    func testBundledAthkarLoad() {
        let categories = AthkarStore.load()
        XCTAssertGreaterThan(categories.count, 100)
        XCTAssertTrue(categories.contains { $0.category.contains("الصباح") })
        for category in categories {
            XCTAssertFalse(category.items.isEmpty, category.category)
            XCTAssertTrue(category.items.allSatisfy { $0.count >= 1 && !$0.text.isEmpty })
        }
    }
}
