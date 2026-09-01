import XCTest
@testable import Noor

final class KhatmahPlanTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "KhatmahPlanTests")!
        defaults.removePersistentDomain(forName: "KhatmahPlanTests")
    }

    func testStartResetsToPageOne() {
        KhatmahPlan.start(days: 30, defaults: defaults)
        XCTAssertEqual(defaults.integer(forKey: "khatmah.goalDays"), 30)
        XCTAssertEqual(defaults.integer(forKey: "khatmah.goalStartPage"), 0)
        XCTAssertEqual(KhatmahPlan.frontier(defaults: defaults), 1)
        XCTAssertEqual(KhatmahPlan.lastRead(defaults: defaults), 0)
    }

    func testFrontierDefaultsToOneWhenUnset() {
        XCTAssertEqual(KhatmahPlan.frontier(defaults: defaults), 1)
    }

    func testFrontierClampsToTotalPages() {
        defaults.set(9_999, forKey: "khatmah.page")
        XCTAssertEqual(KhatmahPlan.frontier(defaults: defaults), KhatmahPlan.totalPages)
    }

    func testDailyPortionMath() {
        let start = Calendar.current.startOfDay(for: Date())
        let plan = KhatmahPlan(goalDays: 30, startDate: start, startPage: 0)
        // Day 1 of 30: ceil(604 * 1 / 30) = 21.
        XCTAssertEqual(plan.dayNumber(now: start), 1)
        XCTAssertEqual(plan.targetPage(now: start), 21)
        XCTAssertEqual(plan.pagesLeftToday(now: start, currentPage: 0), 21)
        XCTAssertEqual(plan.pagesLeftToday(now: start, currentPage: 21), 0)
        // No backlog on day 1.
        XCTAssertEqual(plan.pagesBehind(now: start, currentPage: 0), 0)
    }

    func testBehindScheduleAfterMissedDay() {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let plan = KhatmahPlan(goalDays: 30, startDate: start, startPage: 0)
        let dayThree = calendar.date(byAdding: .day, value: 2, to: start)!
        // Expected by end of day 2: ceil(604 * 2 / 30) = 41.
        XCTAssertEqual(plan.dayNumber(now: dayThree), 3)
        XCTAssertEqual(plan.pagesBehind(now: dayThree, currentPage: 0), 41)
        XCTAssertEqual(plan.pagesBehind(now: dayThree, currentPage: 41), 0)
    }

    func testTargetNeverExceedsTotal() {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let plan = KhatmahPlan(goalDays: 30, startDate: start, startPage: 0)
        let far = calendar.date(byAdding: .day, value: 100, to: start)!
        XCTAssertEqual(plan.targetPage(now: far), KhatmahPlan.totalPages)
        XCTAssertTrue(plan.isFinished(currentPage: 604))
        XCTAssertFalse(plan.isFinished(currentPage: 603))
    }
}
