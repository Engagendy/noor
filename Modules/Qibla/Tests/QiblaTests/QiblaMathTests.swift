import XCTest
@testable import Qibla

final class QiblaMathTests: XCTestCase {
    func testKnownBearings() {
        // Cairo → Makkah is roughly southeast (~136°).
        XCTAssertEqual(QiblaMath.bearing(fromLatitude: 30.0444, longitude: 31.2357), 136, accuracy: 3)
        // London → Makkah is roughly east-southeast (~119°).
        XCTAssertEqual(QiblaMath.bearing(fromLatitude: 51.5074, longitude: -0.1278), 119, accuracy: 3)
        // Jakarta → Makkah is roughly west-northwest (~295°).
        XCTAssertEqual(QiblaMath.bearing(fromLatitude: -6.2088, longitude: 106.8456), 295, accuracy: 3)
    }

    func testAtKaabaBearingIsDefined() {
        let bearing = QiblaMath.bearing(fromLatitude: 21.4225, longitude: 39.8262)
        XCTAssertTrue((0..<360).contains(bearing))
    }
}
