import Foundation

/// A khatmah goal: finish the mushaf (604 pages) in a chosen number of days.
/// Pure math over UserDefaults state — the Today card renders the result.
struct KhatmahPlan {
    static let totalPages = 604

    let goalDays: Int
    let startDate: Date
    let startPage: Int

    /// Loads the active plan, if one was started.
    static func load(defaults: UserDefaults = .standard) -> KhatmahPlan? {
        let days = defaults.integer(forKey: "khatmah.goalDays")
        guard days > 0 else { return nil }
        let start = defaults.double(forKey: "khatmah.goalStart")
        return KhatmahPlan(
            goalDays: days,
            startDate: Date(timeIntervalSince1970: start),
            startPage: defaults.integer(forKey: "khatmah.goalStartPage"))
    }

    /// A khatmah always covers the whole mushaf: start at page 1.
    static func start(days: Int, defaults: UserDefaults = .standard) {
        defaults.set(days, forKey: "khatmah.goalDays")
        defaults.set(Date().timeIntervalSince1970, forKey: "khatmah.goalStart")
        defaults.set(0, forKey: "khatmah.goalStartPage")
        defaults.set(1, forKey: "khatmah.page")  // frontier: first unread page
    }

    /// Next unread page of the plan (the frontier).
    static func frontier(defaults: UserDefaults = .standard) -> Int {
        let stored = defaults.integer(forKey: "khatmah.page")
        return stored > 0 ? min(stored, totalPages) : 1
    }

    /// Last page actually read within the plan.
    static func lastRead(defaults: UserDefaults = .standard) -> Int {
        max(0, frontier(defaults: defaults) - 1)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.set(0, forKey: "khatmah.goalDays")
    }

    /// Completed khatmahs (count persists; dates for future history UI).
    static func completions(defaults: UserDefaults = .standard) -> Int {
        defaults.integer(forKey: "khatmah.completions")
    }

    /// Records the completion once, then a new plan can begin.
    static func recordCompletion(defaults: UserDefaults = .standard) {
        guard defaults.integer(forKey: "khatmah.goalDays") > 0 else { return }
        defaults.set(completions(defaults: defaults) + 1, forKey: "khatmah.completions")
        var dates = defaults.array(forKey: "khatmah.completionDates") as? [Double] ?? []
        dates.append(Date().timeIntervalSince1970)
        defaults.set(dates, forKey: "khatmah.completionDates")
        clear(defaults: defaults)
    }

    /// 1-based day number within the plan (day 1 = start day).
    func dayNumber(now: Date) -> Int {
        let days = Calendar.current.dateComponents(
            [.day], from: Calendar.current.startOfDay(for: startDate),
            to: Calendar.current.startOfDay(for: now)).day ?? 0
        return days + 1
    }

    var pagesPerDay: Double {
        Double(Self.totalPages - startPage) / Double(goalDays)
    }

    /// Page the reader should reach by the END of the given day to stay on
    /// schedule.
    func targetPage(now: Date) -> Int {
        let day = min(dayNumber(now: now), goalDays)
        return min(Self.totalPages, startPage + Int((Double(day) * pagesPerDay).rounded(.up)))
    }

    /// Pages still to read today (0 = on/ahead of schedule for today).
    func pagesLeftToday(now: Date, currentPage: Int) -> Int {
        max(0, targetPage(now: now) - max(currentPage, startPage))
    }

    /// Positive = behind schedule by that many pages (vs yesterday's target).
    func pagesBehind(now: Date, currentPage: Int) -> Int {
        let day = dayNumber(now: now)
        guard day > 1 else { return 0 }
        let expectedYesterday = min(Self.totalPages,
            startPage + Int((Double(min(day - 1, goalDays)) * pagesPerDay).rounded(.up)))
        return max(0, expectedYesterday - max(currentPage, startPage))
    }

    func isFinished(currentPage: Int) -> Bool {
        currentPage >= Self.totalPages
    }

    /// Estimated finish day given current pace vs the goal.
    func daysRemaining(now: Date) -> Int {
        max(0, goalDays - dayNumber(now: now) + 1)
    }
}
