import Foundation
import UserNotifications

/// Evening-before reminders for sunnah fasting days: Mondays, Thursdays,
/// and the white days (13–15 hijri). At most ~8 pending — fits alongside
/// the adhan window inside iOS's 64-request cap.
public struct FastingReminderScheduler {
    public init() {}

    /// (fireDate, arabic reason, english reason) for the next `days` days.
    public static func plan(from now: Date = .now, days: Int = 10) -> [(Date, String, String)] {
        let gregorian = Calendar.current
        let hijri = Calendar(identifier: .islamicUmmAlQura)
        var result: [(Date, String, String)] = []
        for offset in 1...days {
            guard let day = gregorian.date(byAdding: .day, value: offset, to: now) else { continue }
            let weekday = gregorian.component(.weekday, from: day)
            let hijriDay = hijri.component(.day, from: day)
            var reasonAr: String?
            var reasonEn: String?
            if (13...15).contains(hijriDay) {
                reasonAr = "غدًا من الأيام البيض (\(hijriDay) هجريًا) — يُسنّ صيامه"
                reasonEn = "Tomorrow is a white day (\(hijriDay)h) — fasting is Sunnah"
            } else if weekday == 2 {
                reasonAr = "غدًا الاثنين — تُعرض فيه الأعمال ويُسنّ صيامه"
                reasonEn = "Tomorrow is Monday — deeds are presented; fasting is Sunnah"
            } else if weekday == 5 {
                reasonAr = "غدًا الخميس — تُعرض فيه الأعمال ويُسنّ صيامه"
                reasonEn = "Tomorrow is Thursday — deeds are presented; fasting is Sunnah"
            }
            guard let reasonAr, let reasonEn else { continue }
            // Remind the evening before, 20:30 local.
            guard let evening = gregorian.date(byAdding: .day, value: -1, to: day),
                  let fire = gregorian.date(bySettingHour: 20, minute: 30, second: 0, of: evening),
                  fire > now else { continue }
            result.append((fire, reasonAr, reasonEn))
        }
        return result
    }

    public func reschedule(arabic: Bool, enabled: Bool) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
            .map(\.identifier).filter { $0.hasPrefix("fasting-") }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        guard enabled else { return }
        for (fire, reasonAr, reasonEn) in Self.plan() {
            let content = UNMutableNotificationContent()
            content.title = arabic ? "تذكير بصيام السنة" : "Sunnah fasting reminder"
            content.body = arabic ? reasonAr : reasonEn
            content.sound = .default
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(
                identifier: "fasting-\(Int(fire.timeIntervalSince1970))",
                content: content, trigger: trigger))
        }
    }
}
