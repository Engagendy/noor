import Adhan
import Foundation

/// Phase 0 stub — on-device prayer time calculation via adhan-swift.
/// Fully implemented (methods, madhab, notifications) in Phase 1.
public struct PrayerTimesService: Sendable {
    public init() {}

    public func prayerTimes(
        latitude: Double,
        longitude: Double,
        date: Date = .now,
        calendar: Calendar = .current,
        method: CalculationMethod = .moonsightingCommittee,
        madhab: Madhab = .shafi
    ) -> PrayerTimes? {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        var params = method.params
        params.madhab = madhab
        return PrayerTimes(
            coordinates: Coordinates(latitude: latitude, longitude: longitude),
            date: components,
            calculationParameters: params
        )
    }
}
