import XCTest
@testable import Notifications
@testable import PrayerTimes

final class AdhanNotificationPlannerTests: XCTestCase {
    private let cairo = CityPreset.named("Cairo")

    func testNeverExceedsPendingLimit() {
        let plan = AdhanNotificationPlanner.plan(
            city: cairo, method: .egyptian, madhab: .shafi, days: 30, limit: 60)
        XCTAssertLessThanOrEqual(plan.count, 60)
        XCTAssertLessThanOrEqual(plan.count, 64, "iOS pending-notification hard limit")
    }

    func testAllFireDatesAreInTheFutureAndAscending() {
        let now = Date()
        let plan = AdhanNotificationPlanner.plan(
            city: cairo, method: .egyptian, madhab: .shafi, from: now)
        XCTAssertFalse(plan.isEmpty)
        XCTAssertTrue(plan.allSatisfy { $0.fireDate > now })
        XCTAssertEqual(plan.map(\.fireDate), plan.map(\.fireDate).sorted())
    }

    func testIdentifiersAreUnique() {
        let plan = AdhanNotificationPlanner.plan(city: cairo, method: .egyptian, madhab: .shafi)
        XCTAssertEqual(Set(plan.map(\.id)).count, plan.count)
    }

    func testCoversMultipleDays() {
        let plan = AdhanNotificationPlanner.plan(city: cairo, method: .egyptian, madhab: .shafi)
        let days = Set(plan.map { Calendar.current.startOfDay(for: $0.fireDate) })
        XCTAssertGreaterThanOrEqual(days.count, 10, "should schedule ~12 days ahead")
    }
}
