import Foundation
import PrayerTimes

/// One planned local notification. Pure data so the scheduling window logic
/// is unit-testable without UserNotifications.
public struct PlannedNotification: Equatable {
    public let id: String
    public let prayerName: String
    public let fireDate: Date
    public let timeString: String
}

/// Plans adhan notifications within iOS's 64-pending-request limit
/// (plan §6.4): 5 prayers/day for the next `days` days, capped at `limit`.
public enum AdhanNotificationPlanner {
    public static let defaultDays = 12
    public static let defaultLimit = 60

    public static func plan(
        location: PrayerLocation,
        method: CalculationMethodChoice,
        madhab: MadhabChoice,
        from now: Date = .now,
        days: Int = defaultDays,
        limit: Int = defaultLimit
    ) -> [PlannedNotification] {
        var result: [PlannedNotification] = []
        var formatStyle = Date.FormatStyle(date: .omitted, time: .shortened)
        formatStyle.timeZone = TimeZone(identifier: location.timeZoneIdentifier) ?? .current

        for dayOffset in 0..<days {
            guard let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: now),
                  let day = PrayerDay.compute(location: location, method: method, madhab: madhab, date: date)
            else { continue }
            for entry in day.entries where entry.time > now {
                guard result.count < limit else { return result }
                result.append(PlannedNotification(
                    id: "adhan-\(entry.prayer)-\(Int(entry.time.timeIntervalSince1970))",
                    prayerName: String(localized: entry.name),
                    fireDate: entry.time,
                    timeString: entry.time.formatted(formatStyle)))
            }
        }
        return result
    }
}
