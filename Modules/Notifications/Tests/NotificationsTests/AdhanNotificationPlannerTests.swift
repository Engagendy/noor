import XCTest
@testable import Notifications
@testable import PrayerTimes

final class AdhanNotificationPlannerTests: XCTestCase {
    private let cairo = CityPreset.named("Cairo").location

    func testNeverExceedsPendingLimit() {
        let plan = AdhanNotificationPlanner.plan(
            location: cairo, method: .egyptian, madhab: .shafi, days: 30, limit: 60)
        XCTAssertLessThanOrEqual(plan.count, 60)
        XCTAssertLessThanOrEqual(plan.count, 64, "iOS pending-notification hard limit")
    }

    /// Adhans and sunnah-fasting reminders share iOS's 64-request budget;
    /// walk a full hijri month so every white-day/weekday alignment is covered.
    func testAdhanPlusFastingRemindersStayInsideThePendingCap() {
        let calendar = Calendar.current
        for dayOffset in 0..<30 {
            let now = calendar.date(byAdding: .day, value: dayOffset, to: Date())!
            let adhans = AdhanNotificationPlanner.plan(
                location: cairo, method: .egyptian, madhab: .shafi, from: now)
            let fasting = FastingReminderScheduler.plan(from: now)
            XCTAssertLessThanOrEqual(fasting.count, FastingReminderScheduler.maxPending)
            XCTAssertLessThanOrEqual(
                adhans.count + fasting.count, AdhanNotificationPlanner.pendingRequestCap,
                "day +\(dayOffset): iOS drops everything past the 64th pending request")
        }
    }

    func testAllFireDatesAreInTheFutureAndAscending() {
        let now = Date()
        let plan = AdhanNotificationPlanner.plan(
            location: cairo, method: .egyptian, madhab: .shafi, from: now)
        XCTAssertFalse(plan.isEmpty)
        XCTAssertTrue(plan.allSatisfy { $0.fireDate > now })
        XCTAssertEqual(plan.map(\.fireDate), plan.map(\.fireDate).sorted())
    }

    func testIdentifiersAreUnique() {
        let plan = AdhanNotificationPlanner.plan(location: cairo, method: .egyptian, madhab: .shafi)
        XCTAssertEqual(Set(plan.map(\.id)).count, plan.count)
    }

    func testCoversMultipleDays() {
        let plan = AdhanNotificationPlanner.plan(location: cairo, method: .egyptian, madhab: .shafi)
        let days = Set(plan.map { Calendar.current.startOfDay(for: $0.fireDate) })
        XCTAssertGreaterThanOrEqual(days.count, 10, "should schedule ~12 days ahead")
    }
}
