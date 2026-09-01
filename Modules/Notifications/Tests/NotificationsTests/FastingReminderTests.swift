import XCTest
@testable import Notifications

final class FastingReminderTests: XCTestCase {
    func testRemindersFireTheEveningBeforeAtHalfPastEight() {
        let planned = FastingReminderScheduler.plan(from: Date(), days: 10)
        XCTAssertFalse(planned.isEmpty, "10 days always contain a Monday and Thursday")
        let calendar = Calendar.current
        for (fire, reasonAr, reasonEn) in planned {
            XCTAssertGreaterThan(fire, Date())
            XCTAssertEqual(calendar.component(.hour, from: fire), 20)
            XCTAssertEqual(calendar.component(.minute, from: fire), 30)
            XCTAssertFalse(reasonAr.isEmpty)
            XCTAssertFalse(reasonEn.isEmpty)
            // The fasting day is the day AFTER the reminder.
            let fastingDay = calendar.date(byAdding: .day, value: 1, to: fire)!
            let weekday = calendar.component(.weekday, from: fastingDay)
            let hijriDay = Calendar(identifier: .islamicUmmAlQura).component(.day, from: fastingDay)
            XCTAssertTrue(weekday == 2 || weekday == 5 || (13...15).contains(hijriDay),
                          "reminder must precede a Monday, Thursday, or white day")
        }
    }

    func testPlanIsSortedAndUnique() {
        let planned = FastingReminderScheduler.plan(from: Date(), days: 10)
        let dates = planned.map(\.0)
        XCTAssertEqual(dates, dates.sorted())
        XCTAssertEqual(Set(dates).count, dates.count)
    }
}
