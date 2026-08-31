import XCTest
@testable import PrayerTimes

final class PrayerTimesServiceTests: XCTestCase {
    func testComputesFiveTimesForCairo() throws {
        let service = PrayerTimesService()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Africa/Cairo")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 31))!

        let times = try XCTUnwrap(service.prayerTimes(
            latitude: 30.0444, longitude: 31.2357, date: date, calendar: calendar))

        XCTAssertLessThan(times.fajr, times.sunrise)
        XCTAssertLessThan(times.sunrise, times.dhuhr)
        XCTAssertLessThan(times.dhuhr, times.asr)
        XCTAssertLessThan(times.asr, times.maghrib)
        XCTAssertLessThan(times.maghrib, times.isha)
    }
}
