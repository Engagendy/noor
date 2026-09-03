#if os(iOS)
import ActivityKit
import Foundation
import Notifications
import PrayerTimes

/// Starts (or refreshes) the next-prayer Live Activity; ends stale ones.
@MainActor
enum PrayerLiveActivityController {
    static func toggle() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            UserDefaults.standard.set(false, forKey: "liveactivity.on")
            return
        }
        let defaults = UserDefaults.standard
        // True toggle: if one is running, end it and report off.
        let existing = Activity<NoorPrayerAttributes>.activities
        if !existing.isEmpty {
            for activity in existing {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            defaults.set(false, forKey: "liveactivity.on")
            return
        }
        guard let next = nextPrayer() else { return }
        let attributes = NoorPrayerAttributes(city: next.location.label, isArabic: next.arabic)
        do {
            _ = try Activity.request(attributes: attributes, content: content(for: next.planned))
            defaults.set(true, forKey: "liveactivity.on")
        } catch {
            defaults.set(false, forKey: "liveactivity.on")
        }
    }

    /// Rolls a running activity forward to the next prayer once the adhan
    /// time has passed (otherwise the lock screen keeps a stale, expired
    /// card). Call on foreground and whenever an adhan is delivered.
    static func refresh() async {
        let running = Activity<NoorPrayerAttributes>.activities
        guard !running.isEmpty else { return }
        guard let next = nextPrayer() else {
            for activity in running {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            UserDefaults.standard.set(false, forKey: "liveactivity.on")
            return
        }
        let updated = content(for: next.planned)
        for activity in running where activity.content.state != updated.state {
            await activity.update(updated)
        }
    }

    private struct NextPrayer {
        let planned: PlannedNotification
        let location: PrayerLocation
        let arabic: Bool
    }

    private static func nextPrayer() -> NextPrayer? {
        let defaults = UserDefaults.standard
        let location = PrayerLocation.current()
        let method = CalculationMethodChoice(
            rawValue: defaults.string(forKey: "prayer.method") ?? "") ?? .moonsightingCommittee
        let madhab = MadhabChoice(rawValue: defaults.string(forKey: "prayer.madhab") ?? "") ?? .shafi
        let arabic = defaults.string(forKey: "app.language") == "ar"
            || (defaults.string(forKey: "app.language") ?? "system") == "system"
                && Locale.current.language.languageCode?.identifier == "ar"
        guard let planned = AdhanNotificationPlanner.plan(
            location: location, method: method, madhab: madhab, days: 2, limit: 1,
            arabic: arabic).first
        else { return nil }
        return NextPrayer(planned: planned, location: location, arabic: arabic)
    }

    private static func content(
        for planned: PlannedNotification
    ) -> ActivityContent<NoorPrayerAttributes.ContentState> {
        .init(
            state: .init(prayerName: planned.prayerName, time: planned.fireDate),
            staleDate: planned.fireDate.addingTimeInterval(300))
    }
}
#endif
