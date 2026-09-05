import Adhan
import Foundation
import PrayerTimes

/// One planned local notification. Pure data so the scheduling window logic
/// is unit-testable without UserNotifications.
public struct PlannedNotification: Equatable {
    public enum Kind: Equatable {
        case adhan
        /// "N minutes before" alert.
        case preAlert
        /// After-salah athkar nudge, `athkar.afterSalahMinutes` past the adhan.
        case athkar
    }

    public let id: String
    public let prayerName: String
    public let fireDate: Date
    public let timeString: String
    public var kind: Kind = .adhan
}

/// Plans adhan notifications within iOS's 64-pending-request limit
/// (plan §6.4): 5 prayers/day for the next `days` days, capped at `limit`.
public enum AdhanNotificationPlanner {
    /// iOS keeps only the 64 soonest pending requests and silently drops the rest.
    public static let pendingRequestCap = 64
    public static let defaultDays = 12
    /// Leave room for the sunnah-fasting reminders, which share the cap.
    /// Adhans, pre-alerts, and after-salah athkar reminders all draw on this
    /// one budget (56 ≈ 5.5 days when adhan + athkar are both on).
    public static let defaultLimit = pendingRequestCap - FastingReminderScheduler.maxPending

    /// Arabic prayer names for notification copy (String(localized:)
    /// resolves with the PROCESS language, not the in-app choice).
    static let arabicNames: [Adhan.Prayer: String] = [
        .fajr: "الفجر", .sunrise: "الشروق", .dhuhr: "الظهر",
        .asr: "العصر", .maghrib: "المغرب", .isha: "العشاء",
    ]

    public static func plan(
        location: PrayerLocation,
        method: CalculationMethodChoice,
        madhab: MadhabChoice,
        enabledPrayers: Set<Adhan.Prayer> = [.fajr, .dhuhr, .asr, .maghrib, .isha],
        from now: Date = .now,
        days: Int = defaultDays,
        limit: Int = defaultLimit,
        arabic: Bool = false
    ) -> [PlannedNotification] {
        planAll(location: location, method: method, madhab: madhab,
                adhanPrayers: enabledPrayers, from: now, days: days, limit: limit, arabic: arabic)
    }

    /// Plans every prayer-anchored request in one day loop so the combined
    /// count never exceeds `limit`: per prayer, the pre-alert (if any), the
    /// adhan (if that prayer's bell is on and adhan is enabled), and the
    /// after-salah athkar reminder (if `athkarMinutes` is set, for all five
    /// prayers regardless of the adhan toggle).
    public static func planAll(
        location: PrayerLocation,
        method: CalculationMethodChoice,
        madhab: MadhabChoice,
        adhanPrayers: Set<Adhan.Prayer>?,
        preAlertMinutes: Int = 0,
        athkarMinutes: Int? = nil,
        from now: Date = .now,
        days: Int = defaultDays,
        limit: Int = defaultLimit,
        arabic: Bool = false
    ) -> [PlannedNotification] {
        var result: [PlannedNotification] = []
        var formatStyle = Date.FormatStyle(date: .omitted, time: .shortened)
        formatStyle.timeZone = TimeZone(identifier: location.timeZoneIdentifier) ?? .current

        func name(_ prayer: Adhan.Prayer, _ resource: LocalizedStringResource) -> String {
            arabic ? (arabicNames[prayer] ?? String(localized: resource)) : String(localized: resource)
        }

        for dayOffset in 0..<days {
            guard let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: now),
                  let day = PrayerDay.compute(location: location, method: method, madhab: madhab, date: date)
            else { continue }
            for entry in day.entries where entry.time > now {
                let stamp = Int(entry.time.timeIntervalSince1970)
                let prayerName = name(entry.prayer, entry.name)
                let timeString = entry.time.formatted(formatStyle)
                let adhanOn = adhanPrayers?.contains(entry.prayer) ?? false
                if adhanOn && preAlertMinutes > 0 {
                    let preFire = entry.time.addingTimeInterval(TimeInterval(-preAlertMinutes * 60))
                    if preFire > now {
                        guard result.count < limit else { return result }
                        result.append(PlannedNotification(
                            id: "pre-adhan-\(entry.prayer)-\(stamp)", prayerName: prayerName,
                            fireDate: preFire, timeString: timeString, kind: .preAlert))
                    }
                }
                if adhanOn {
                    guard result.count < limit else { return result }
                    result.append(PlannedNotification(
                        id: "adhan-\(entry.prayer)-\(stamp)", prayerName: prayerName,
                        fireDate: entry.time, timeString: timeString, kind: .adhan))
                }
                if let athkarMinutes {
                    guard result.count < limit else { return result }
                    result.append(PlannedNotification(
                        id: "athkar-\(entry.prayer)-\(stamp)", prayerName: prayerName,
                        fireDate: entry.time.addingTimeInterval(TimeInterval(athkarMinutes * 60)),
                        timeString: timeString, kind: .athkar))
                }
            }
        }
        return result
    }
}
