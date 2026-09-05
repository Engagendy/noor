import Adhan
import Foundation
import PrayerTimes
import UserNotifications

/// Quiet after-salah nudge: fires `minutes` after each of the five daily
/// prayers and deep-links to the "after the taslim" athkar category.
/// Independent of the adhan toggle; shares the adhan planner's budget.
public struct AthkarReminderScheduler: Sendable {
    public init() {}

    /// UserDefaults keys (identical on Android).
    public static let enabledKey = "athkar.afterSalah"
    public static let minutesKey = "athkar.afterSalahMinutes"
    public static let minuteChoices = [10, 15, 20, 30]
    public static let defaultMinutes = 20
    /// `userInfo["open"]` value the app routes on tap.
    public static let openRoute = "athkar-after-salah"

    /// Cancels every `athkar-` request, then — when enabled — re-adds them.
    /// Runs the same combined plan as the adhan scheduler (adhan config
    /// included) so both fit inside the shared budget.
    public func reschedule(
        enabled: Bool,
        minutes: Int,
        location: PrayerLocation,
        method: CalculationMethodChoice,
        madhab: MadhabChoice,
        adhanEnabled: Bool,
        preAlertMinutes: Int = 0,
        arabic: Bool,
        now: Date = .now
    ) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
            .map(\.identifier).filter { $0.hasPrefix("athkar-") }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        guard enabled else { return }

        let planned = AdhanNotificationPlanner.planAll(
            location: location, method: method, madhab: madhab,
            adhanPrayers: adhanEnabled ? PrayerNotificationPrefs.enabledPrayers() : nil,
            preAlertMinutes: preAlertMinutes, athkarMinutes: minutes, from: now, arabic: arabic)
        for item in planned where item.kind == .athkar {
            let content = UNMutableNotificationContent()
            content.title = arabic ? "أذكار ما بعد الصلاة" : "After-prayer athkar"
            content.body = arabic
                ? "تقبّل الله صلاتك · اضغط لقراءة أذكار ما بعد صلاة \(item.prayerName)"
                : "May Allah accept your prayer · Tap to read the athkar after \(item.prayerName)"
            content.sound = nil
            content.userInfo = ["open": Self.openRoute]
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: item.fireDate)
            try? await center.add(UNNotificationRequest(
                identifier: item.id, content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
        }
    }
}
