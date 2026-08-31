import Adhan
import Foundation

/// A computed day of prayers for the selected city/method/madhab — shared by
/// the Prayer Times screen and the Today hero card.
public struct PrayerDay {
    public struct Entry: Identifiable {
        public let prayer: Prayer
        public let name: LocalizedStringResource
        public let time: Date
        public var id: Prayer { prayer }
    }

    public let entries: [Entry]
    public let location: PrayerLocation
    private let times: Adhan.PrayerTimes

    public static func compute(
        city: CityPreset,
        method: CalculationMethodChoice,
        madhab: MadhabChoice,
        date: Date = .now
    ) -> PrayerDay? {
        compute(location: city.location, method: method, madhab: madhab, date: date)
    }

    public static func compute(
        location: PrayerLocation,
        method: CalculationMethodChoice,
        madhab: MadhabChoice,
        date: Date = .now
    ) -> PrayerDay? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: location.timeZoneIdentifier) ?? .current
        guard let times = PrayerTimesService().prayerTimes(
            latitude: location.latitude, longitude: location.longitude,
            date: date, calendar: calendar,
            method: method.adhanMethod, madhab: madhab.adhanMadhab
        ) else { return nil }
        let entries: [Entry] = [
            Entry(prayer: .fajr, name: "Fajr", time: times.fajr),
            Entry(prayer: .dhuhr, name: "Dhuhr", time: times.dhuhr),
            Entry(prayer: .asr, name: "Asr", time: times.asr),
            Entry(prayer: .maghrib, name: "Maghrib", time: times.maghrib),
            Entry(prayer: .isha, name: "Isha", time: times.isha),
        ]
        return PrayerDay(entries: entries, location: location, times: times)
    }

    /// The next of the five prayers still ahead of `now` this day, if any.
    public func next(at now: Date) -> Entry? {
        entries.first { $0.time > now }
    }

    /// How many of the five prayers have already passed (for progress segments).
    public func passedCount(at now: Date) -> Int {
        entries.filter { $0.time <= now }.count
    }
}
