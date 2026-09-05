import DesignSystem
import Notifications
import PrayerTimes
import QuranReader
import SwiftUI
import UserNotifications

@main
struct NoorApp: App {
    init() {
        FontRegistrar.registerQuranFont()
        // Migration: we briefly wrote AppleLanguages for in-app language;
        // that mirrors rendering when it disagrees with the environment.
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        // Adhan must sound even when the app is frontmost.
        UNUserNotificationCenter.current().delegate = NoorNotificationDelegate.shared
        PageFontStore.purgeStaleCaches()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                #if os(macOS)
                // A comfortable reading window; the mushaf needs height.
                .frame(minWidth: 900, minHeight: 640)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1150, height: 800)
        #endif

        #if os(macOS)
        // Menu-bar prayer countdown (design 1j / plan §2 Mac strategy).
        MenuBarExtra {
            MenuBarPrayerView()
        } label: {
            MenuBarCountdownLabel()
        }
        #endif
    }
}

#if os(macOS)
struct MenuBarCountdownLabel: View {
    @AppStorage("prayer.city") private var cityName = "Makkah"
    @AppStorage("prayer.method") private var methodRaw = CalculationMethodChoice.moonsightingCommittee.rawValue
    @AppStorage("prayer.madhab") private var madhabRaw = MadhabChoice.shafi.rawValue

    var body: some View {
        TimelineView(.everyMinute) { context in
            if let day = PrayerDay.compute(
                location: PrayerLocation.current(),
                method: CalculationMethodChoice(rawValue: methodRaw) ?? .moonsightingCommittee,
                madhab: MadhabChoice(rawValue: madhabRaw) ?? .shafi,
                date: context.date),
               let next = day.next(at: context.date) {
                let minutes = max(0, Int(next.time.timeIntervalSince(context.date) / 60))
                Text("\(String(localized: next.name)) −\(minutes / 60):\(String(format: "%02d", minutes % 60))")
            } else {
                Image(systemName: "moon.stars")
            }
        }
    }
}

struct MenuBarPrayerView: View {
    @AppStorage("prayer.city") private var cityName = "Makkah"
    @AppStorage("prayer.method") private var methodRaw = CalculationMethodChoice.moonsightingCommittee.rawValue
    @AppStorage("prayer.madhab") private var madhabRaw = MadhabChoice.shafi.rawValue

    var body: some View {
        TimelineView(.everyMinute) { context in
            if let day = PrayerDay.compute(
                location: PrayerLocation.current(),
                method: CalculationMethodChoice(rawValue: methodRaw) ?? .moonsightingCommittee,
                madhab: MadhabChoice(rawValue: madhabRaw) ?? .shafi,
                date: context.date) {
                let next = day.next(at: context.date)
                ForEach(day.entries) { entry in
                    let mark = entry.prayer == next?.prayer ? " ◂" : ""
                    Text("\(String(localized: entry.name))  \(entry.time.formatted(date: .omitted, time: .shortened))\(mark)")
                }
                Divider()
                Text(verbatim: PrayerLocation.current().displayName(arabicUI: false))
            }
        }
    }
}
#endif


/// Presents adhan notifications (banner + sound) while the app is open and
/// routes taps (after-salah athkar reminder → Athkar tab, category pushed).
final class NoorNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NoorNotificationDelegate()

    /// Stores the route in defaults (survives a cold start, where
    /// MainTabView does not exist yet) and pokes the live UI if it does.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
              let route = response.notification.request.content.userInfo["open"] as? String
        else { return }
        switch route {
        case AthkarReminderScheduler.openRoute:
            UserDefaults.standard.set(route, forKey: "pending.openRoute")
            await MainActor.run {
                NotificationCenter.default.post(name: .noorOpenPendingPage, object: nil)
            }
        default:
            break
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // The adhan just fired: move the Live Activity to the next prayer.
        #if os(iOS)
        await PrayerLiveActivityController.refresh()
        #endif
        return [.banner, .sound, .list]
    }
}
