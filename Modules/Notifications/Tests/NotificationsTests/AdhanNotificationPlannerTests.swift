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

    /// The Shorouk alert is opt-in through `.sunrise` in the enabled set:
    /// it fires at sunrise, between Fajr and Dhuhr, with no pre-alert and no
    /// athkar reminder, and the default five-prayer plan never contains it.
    func testSunriseAlertOnlyWhenEnabled() {
        let now = Date()
        let withoutSunrise = AdhanNotificationPlanner.plan(
            location: cairo, method: .egyptian, madhab: .shafi, from: now)
        XCTAssertFalse(withoutSunrise.contains { $0.kind == .sunrise })
        XCTAssertFalse(withoutSunrise.contains { $0.id.hasPrefix("sunrise-") })

        let planned = AdhanNotificationPlanner.planAll(
            location: cairo, method: .egyptian, madhab: .shafi,
            adhanPrayers: [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha],
            preAlertMinutes: 10, athkarMinutes: 20, from: now, days: 3, limit: 200)
        let sunrises = planned.filter { $0.kind == .sunrise }
        let fajrs = planned.filter { $0.id.hasPrefix("adhan-fajr-") }.count
        XCTAssertLessThanOrEqual(abs(sunrises.count - fajrs), 1,
                                 "one Shorouk per Fajr (give or take the one already passed today)")
        XCTAssertGreaterThanOrEqual(sunrises.count, 2)
        XCTAssertTrue(sunrises.allSatisfy { $0.id.hasPrefix("sunrise-") })
        XCTAssertFalse(planned.contains { $0.id.contains("pre-adhan-sunrise") })
        XCTAssertFalse(planned.contains { $0.id.contains("athkar-sunrise") })
        XCTAssertEqual(planned.map(\.fireDate), planned.map(\.fireDate).sorted())
        for sunrise in sunrises {
            let day = Calendar.current.startOfDay(for: sunrise.fireDate)
            let fajr = planned.first { $0.id.hasPrefix("adhan-fajr-") && Calendar.current.startOfDay(for: $0.fireDate) == day }
            let dhuhr = planned.first { $0.id.hasPrefix("adhan-dhuhr-") && Calendar.current.startOfDay(for: $0.fireDate) == day }
            if let fajr { XCTAssertGreaterThan(sunrise.fireDate, fajr.fireDate) }
            if let dhuhr { XCTAssertLessThan(sunrise.fireDate, dhuhr.fireDate) }
        }
        // Arabic copy resolves without touching the process locale.
        let arabic = AdhanNotificationPlanner.planAll(
            location: cairo, method: .egyptian, madhab: .shafi,
            adhanPrayers: [.sunrise], from: now, days: 1, limit: 10, arabic: true)
        XCTAssertTrue(arabic.allSatisfy { $0.prayerName == "الشروق" })
    }

    func testCoversMultipleDays() {
        let plan = AdhanNotificationPlanner.plan(location: cairo, method: .egyptian, madhab: .shafi)
        let days = Set(plan.map { Calendar.current.startOfDay(for: $0.fireDate) })
        XCTAssertGreaterThanOrEqual(days.count, 10, "should schedule ~12 days ahead")
    }
}
