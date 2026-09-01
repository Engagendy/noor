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
        let location = PrayerLocation.current()
        let method = CalculationMethodChoice(
            rawValue: defaults.string(forKey: "prayer.method") ?? "") ?? .moonsightingCommittee
        let madhab = MadhabChoice(rawValue: defaults.string(forKey: "prayer.madhab") ?? "") ?? .shafi
        let arabic = defaults.string(forKey: "app.language") == "ar"
            || (defaults.string(forKey: "app.language") ?? "system") == "system"
                && Locale.current.language.languageCode?.identifier == "ar"
        guard let next = AdhanNotificationPlanner.plan(
            location: location, method: method, madhab: madhab, days: 2, limit: 1,
            arabic: arabic).first
        else { return }
        let attributes = NoorPrayerAttributes(city: location.label, isArabic: arabic)
        let state = NoorPrayerAttributes.ContentState(
            prayerName: next.prayerName, time: next.fireDate)
        do {
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: next.fireDate.addingTimeInterval(300)))
            defaults.set(true, forKey: "liveactivity.on")
        } catch {
            defaults.set(false, forKey: "liveactivity.on")
        }
    }
}
#endif
