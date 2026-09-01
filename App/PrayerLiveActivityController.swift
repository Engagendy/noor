#if os(iOS)
import ActivityKit
import Foundation
import Notifications
import PrayerTimes

/// Starts (or refreshes) the next-prayer Live Activity; ends stale ones.
@MainActor
enum PrayerLiveActivityController {
    static func toggle() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // End existing activities first (refresh semantics).
        for activity in Activity<NoorPrayerAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        let defaults = UserDefaults.standard
        let location = PrayerLocation.current()
        let method = CalculationMethodChoice(
            rawValue: defaults.string(forKey: "prayer.method") ?? "") ?? .moonsightingCommittee
        let madhab = MadhabChoice(rawValue: defaults.string(forKey: "prayer.madhab") ?? "") ?? .shafi
        guard let next = AdhanNotificationPlanner.plan(
            location: location, method: method, madhab: madhab, days: 2, limit: 1).first
        else { return }
        let attributes = NoorPrayerAttributes(city: location.label)
        let state = NoorPrayerAttributes.ContentState(
            prayerName: next.prayerName, time: next.fireDate)
        _ = try? Activity.request(
            attributes: attributes,
            content: .init(state: state, staleDate: next.fireDate.addingTimeInterval(300)))
    }
}
#endif
