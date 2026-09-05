import XCTest
@testable import ContentDB

final class CityDatabaseTests: XCTestCase {
    func testLatinSearchMatchesWordStartsLargestFirst() throws {
        let db = try CityDatabase()
        let results = try db.search("abu dh")
        XCTAssertEqual(results.first?.name, "Abu Dhabi")
        XCTAssertEqual(results.first?.nameArabic, "أبوظبي")
        XCTAssertEqual(results.first?.countryName(locale: Locale(identifier: "en")), "United Arab Emirates")
    }

    func testArabicSearchUsesArabicNames() throws {
        let db = try CityDatabase()
        XCTAssertEqual(try db.search("القاهرة").first?.name, "Cairo")
    }

    func testAccentsAreFolded() throws {
        let db = try CityDatabase()
        XCTAssertTrue(try db.search("Málaga").contains { $0.name == "Málaga" })
    }

    func testNearestFindsMakkah() throws {
        let db = try CityDatabase()
        let nearest = try db.nearest(latitude: 21.4225, longitude: 39.8262, limit: 3)
        XCTAssertEqual(nearest.first?.name, "Makkah")
    }

    func testCountriesAndCitiesInCountry() throws {
        let db = try CityDatabase()
        let countries = try db.countries(locale: Locale(identifier: "en"))
        XCTAssertGreaterThan(countries.count, 200)
        XCTAssertEqual(try db.cities(inCountry: "EG").first?.name, "Cairo")
    }
}
