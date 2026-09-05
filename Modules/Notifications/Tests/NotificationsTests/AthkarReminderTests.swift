import XCTest
@testable import Notifications
@testable import PrayerTimes

final class AthkarReminderTests: XCTestCase {
    private let cairo = CityPreset.named("Cairo").location

    /// Adhan + after-salah reminders + sunnah-fasting reminders must all fit
    /// under iOS's 64 pending requests, for any day of the hijri month.
    func testAdhanPlusAthkarPlusFastingNeverExceedsTheCap() {
        let calendar = Calendar.current
        for dayOffset in 0..<30 {
            let now = calendar.date(byAdding: .day, value: dayOffset, to: Date())!
            let planned = AdhanNotificationPlanner.planAll(
                location: cairo, method: .egyptian, madhab: .shafi,
                adhanPrayers: [.fajr, .dhuhr, .asr, .maghrib, .isha],
                athkarMinutes: 20, from: now)
            let fasting = FastingReminderScheduler.plan(from: now)
            XCTAssertLessThanOrEqual(planned.count, AdhanNotificationPlanner.defaultLimit)
            XCTAssertLessThanOrEqual(
                planned.count + fasting.count, AdhanNotificationPlanner.pendingRequestCap,
                "day +\(dayOffset): combined budget must stay within 64")
            let athkar = planned.filter { $0.kind == .athkar }
            let adhans = planned.filter { $0.kind == .adhan }
            XCTAssertFalse(athkar.isEmpty)
            XCTAssertFalse(adhans.isEmpty)
        }
    }

    /// With pre-alerts too (3 requests per prayer) the cap still holds.
    func testWithPreAlertsStillWithinTheCap() {
        let planned = AdhanNotificationPlanner.planAll(
            location: cairo, method: .egyptian, madhab: .shafi,
            adhanPrayers: [.fajr, .dhuhr, .asr, .maghrib, .isha],
            preAlertMinutes: 10, athkarMinutes: 15)
        XCTAssertLessThanOrEqual(
            planned.count + FastingReminderScheduler.maxPending,
            AdhanNotificationPlanner.pendingRequestCap)
    }

    /// Reminders fire exactly `minutes` after the adhan, for every prayer,
    /// even when adhan notifications are off.
    func testRemindersFollowEachPrayerWithoutAdhan() {
        let now = Date()
        let planned = AdhanNotificationPlanner.planAll(
            location: cairo, method: .egyptian, madhab: .shafi,
            adhanPrayers: nil, athkarMinutes: 30, from: now)
        XCTAssertTrue(planned.allSatisfy { $0.kind == .athkar })
        XCTAssertTrue(planned.allSatisfy { $0.id.hasPrefix("athkar-") })
        XCTAssertTrue(planned.allSatisfy { $0.fireDate > now })
        XCTAssertFalse(planned.contains { $0.id.contains("sunrise") })
        let adhans = AdhanNotificationPlanner.plan(
            location: cairo, method: .egyptian, madhab: .shafi, from: now)
        for (reminder, adhan) in zip(planned, adhans) {
            XCTAssertEqual(reminder.fireDate.timeIntervalSince(adhan.fireDate), 30 * 60, accuracy: 1)
        }
        XCTAssertEqual(Set(planned.map(\.id)).count, planned.count)
    }

    /// When the reminder is off, the adhan window is the full ~12 days.
    func testAdhanWindowUnchangedWhenReminderOff() {
        let planned = AdhanNotificationPlanner.plan(location: cairo, method: .egyptian, madhab: .shafi)
        let days = Set(planned.map { Calendar.current.startOfDay(for: $0.fireDate) })
        XCTAssertGreaterThanOrEqual(days.count, 10)
    }
}
