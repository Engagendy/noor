import XCTest
@testable import PrayerTimes

final class PrayerDayTests: XCTestCase {
    private let cairo = CityPreset.named("Cairo").location

    /// Shorouk is listed between Fajr and Dhuhr, but stays out of the five
    /// `entries` that drive "next prayer", progress, adhans and reminders.
    func testSunriseIsOnTheTimelineButNotAPrayer() throws {
        let day = try XCTUnwrap(PrayerDay.compute(
            location: cairo, method: .egyptian, madhab: .shafi))
        XCTAssertEqual(day.entries.map(\.prayer), [.fajr, .dhuhr, .asr, .maghrib, .isha])
        XCTAssertEqual(day.timelineEntries.map(\.prayer),
                       [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha])
        XCTAssertEqual(day.sunrise.prayer, .sunrise)
        XCTAssertGreaterThan(day.sunrise.time, day.entries[0].time)
        XCTAssertLessThan(day.sunrise.time, day.entries[1].time)
        // Sunrise never becomes "next" and never counts toward progress.
        let justAfterFajr = day.entries[0].time.addingTimeInterval(60)
        XCTAssertEqual(day.next(at: justAfterFajr)?.prayer, .dhuhr)
        XCTAssertEqual(day.passedCount(at: day.sunrise.time.addingTimeInterval(60)), 1)
    }

    /// Manual offsets move the prayer, never the astronomical sunrise.
    func testManualOffsetsDoNotShiftSunrise() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "PrayerDayTests"))
        defaults.removePersistentDomain(forName: "PrayerDayTests")
        let base = try XCTUnwrap(PrayerDay.compute(
            location: cairo, method: .egyptian, madhab: .shafi, defaults: defaults))
        defaults.set(10, forKey: "prayer.adj.fajr")
        let shifted = try XCTUnwrap(PrayerDay.compute(
            location: cairo, method: .egyptian, madhab: .shafi, defaults: defaults))
        XCTAssertEqual(shifted.entries[0].time.timeIntervalSince(base.entries[0].time), 600, accuracy: 1)
        XCTAssertEqual(shifted.sunrise.time, base.sunrise.time)
        defaults.removePersistentDomain(forName: "PrayerDayTests")
    }

    func testPrayerNotificationPrefsIncludeSunrise() {
        let defaults = UserDefaults(suiteName: "PrayerDayTests.prefs")!
        defaults.removePersistentDomain(forName: "PrayerDayTests.prefs")
        XCTAssertTrue(PrayerNotificationPrefs.isEnabled(.sunrise, defaults: defaults), "on by default")
        XCTAssertTrue(PrayerNotificationPrefs.enabledPrayers(defaults: defaults).contains(.sunrise))
        PrayerNotificationPrefs.setEnabled(false, for: .sunrise, defaults: defaults)
        XCTAssertFalse(PrayerNotificationPrefs.enabledPrayers(defaults: defaults).contains(.sunrise))
        XCTAssertEqual(PrayerNotificationPrefs.keys[.sunrise], "notif.sunrise")
        defaults.removePersistentDomain(forName: "PrayerDayTests.prefs")
    }
}
