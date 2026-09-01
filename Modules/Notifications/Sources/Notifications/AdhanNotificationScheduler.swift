import Foundation
import PrayerTimes
import UserNotifications

/// Applies the planner's output to UNUserNotificationCenter. Reschedule on
/// every app launch and settings change so the ~12-day window rolls forward.
public struct AdhanNotificationScheduler: Sendable {
    public init() {}

    /// Requests authorization if needed. Returns whether notifications are allowed.
    public func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false
        }
    }

    public func reschedule(
        location: PrayerLocation,
        method: CalculationMethodChoice,
        madhab: MadhabChoice,
        sound: AdhanSound,
        arabic: Bool = false,
        preAlertMinutes: Int = 0
    ) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        // Pre-alerts double the request count: shrink the day window to
        // stay inside iOS's 64-pending limit (5d*5*2=50 + fasting ≈ 58).
        let days = preAlertMinutes > 0 ? 5 : AdhanNotificationPlanner.defaultDays
        for planned in AdhanNotificationPlanner.plan(
            location: location, method: method, madhab: madhab,
            enabledPrayers: PrayerNotificationPrefs.enabledPrayers(),
            days: days, arabic: arabic) {
            if preAlertMinutes > 0 {
                let preFire = planned.fireDate.addingTimeInterval(TimeInterval(-preAlertMinutes * 60))
                if preFire > Date() {
                    let pre = UNMutableNotificationContent()
                    pre.title = arabic
                        ? "بقي \(preAlertMinutes) دقيقة على صلاة \(planned.prayerName)"
                        : "\(planned.prayerName) in \(preAlertMinutes) minutes"
                    pre.body = "\(planned.prayerName) · \(planned.timeString)"
                    pre.sound = .default
                    let comps = Calendar.current.dateComponents(
                        [.year, .month, .day, .hour, .minute], from: preFire)
                    try? await center.add(UNNotificationRequest(
                        identifier: "pre-\(planned.id)",
                        content: pre,
                        trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
                }
            }
            let content = UNMutableNotificationContent()
            // Calm microcopy per design §7 — no exclamation marks.
            content.title = arabic
                ? "حان وقت صلاة \(planned.prayerName)"
                : String(localized: "It's time for \(planned.prayerName)")
            content.body = "\(planned.prayerName) · \(planned.timeString)"
            if let file = sound.fileName {
                // Bundled adhan clips, all ≤30s (see LICENSES.md).
                content.sound = UNNotificationSound(named: UNNotificationSoundName(file))
            } else {
                content.sound = sound == .silent ? nil : .default
            }
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: planned.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(
                identifier: planned.id, content: content, trigger: trigger))
        }
    }

    public func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
