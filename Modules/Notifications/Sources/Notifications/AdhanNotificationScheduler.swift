import Foundation
import PrayerTimes
import UserNotifications

/// Applies the planner's output to UNUserNotificationCenter. Reschedule on
/// every app launch and settings change so the ~12-day window rolls forward.
public struct AdhanNotificationScheduler: Sendable {
    public init() {}

    /// Requests authorization if needed. Returns whether notifications are allowed.
    public func requestAuthorization() async -> Bool {
        // Screenshot/UI-test hook: never raise the system permission alert.
        if ProcessInfo.processInfo.environment["NOOR_NO_PERMISSION_PROMPT"] == "1" { return false }
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

    /// `athkarMinutes` is the after-salah reminder offset when that toggle is
    /// on: the reminders are scheduled by `AthkarReminderScheduler`, but they
    /// share the pending budget, so the planner must count them here too.
    public func reschedule(
        location: PrayerLocation,
        method: CalculationMethodChoice,
        madhab: MadhabChoice,
        sound: AdhanSound,
        arabic: Bool = false,
        preAlertMinutes: Int = 0,
        athkarMinutes: Int? = nil,
        now: Date = .now
    ) async {
        let center = UNUserNotificationCenter.current()
        await cancelAll()

        // One shared budget: pre-alerts, adhans, and athkar reminders are
        // planned together so the sum (plus fasting's 8) stays under 64.
        let planned = AdhanNotificationPlanner.planAll(
            location: location, method: method, madhab: madhab,
            adhanPrayers: PrayerNotificationPrefs.enabledPrayers(),
            preAlertMinutes: preAlertMinutes, athkarMinutes: athkarMinutes, from: now, arabic: arabic)
        for item in planned {
            let content = UNMutableNotificationContent()
            switch item.kind {
            case .preAlert:
                content.title = arabic
                    ? "بقي \(preAlertMinutes) دقيقة على صلاة \(item.prayerName)"
                    : "\(item.prayerName) in \(preAlertMinutes) minutes"
                content.body = "\(item.prayerName) · \(item.timeString)"
                content.sound = .default
            case .adhan:
                // Calm microcopy per design §7 — no exclamation marks.
                content.title = arabic
                    ? "حان وقت صلاة \(item.prayerName)"
                    : String(localized: "It's time for \(item.prayerName)")
                content.body = "\(item.prayerName) · \(item.timeString)"
                if let file = sound.fileName {
                    // Bundled adhan clips, all ≤30s (see LICENSES.md).
                    content.sound = UNNotificationSound(named: UNNotificationSoundName(file))
                } else {
                    content.sound = sound == .silent ? nil : .default
                }
            case .athkar:
                continue
            }
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: item.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(
                identifier: item.id, content: content, trigger: trigger))
        }
    }

    /// Removes only adhan and pre-adhan requests so other schedulers'
    /// pending notifications (e.g. `fasting-*`, `athkar-*`) survive.
    public func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let ids = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix("adhan-") || $0.hasPrefix("pre-adhan-") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
