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

    /// The five daily prayers, in order. Drives "next prayer", progress,
    /// adhans and after-salah reminders.
    public let entries: [Entry]
    /// Shorouk — the end of Fajr time. Not a prayer, so it is kept out of
    /// `entries`; the timeline shows it and it has its own notification.
    public let sunrise: Entry
    public let location: PrayerLocation
    private let times: Adhan.PrayerTimes

    /// Everything the Prayer Times screen lists: the five prayers with
    /// sunrise slotted after Fajr.
    public var timelineEntries: [Entry] {
        var list = entries
        if let index = list.firstIndex(where: { $0.prayer == .fajr }) {
            list.insert(sunrise, at: index + 1)
        } else {
            list.insert(sunrise, at: 0)
        }
        return list
    }

    public static func compute(
        city: CityPreset,
        method: CalculationMethodChoice,
        madhab: MadhabChoice,
        date: Date = .now,
        defaults: UserDefaults = .standard
    ) -> PrayerDay? {
        compute(location: city.location, method: method, madhab: madhab,
                date: date, defaults: defaults)
    }

    /// `defaults` supplies the manual per-prayer offsets (`prayer.adj.*`):
    /// the app passes `.standard`; widgets run in their own sandbox and must
    /// pass `NoorShared.defaults`, where `syncFromApp()` mirrors the keys.
    public static func compute(
        location: PrayerLocation,
        method: CalculationMethodChoice,
        madhab: MadhabChoice,
        date: Date = .now,
        defaults: UserDefaults = .standard
    ) -> PrayerDay? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: location.timeZoneIdentifier) ?? .current
        guard let times = PrayerTimesService().prayerTimes(
            latitude: location.latitude, longitude: location.longitude,
            date: date, calendar: calendar,
            method: method.adhanMethod, madhab: madhab.adhanMadhab
        ) else { return nil }
        // Manual per-prayer offsets (match the local mosque exactly).
        func adjusted(_ time: Date, _ key: String) -> Date {
            time.addingTimeInterval(TimeInterval(
                defaults.integer(forKey: "prayer.adj.\(key)") * 60))
        }
        let entries: [Entry] = [
            Entry(prayer: .fajr, name: "Fajr", time: adjusted(times.fajr, "fajr")),
            Entry(prayer: .dhuhr, name: "Dhuhr", time: adjusted(times.dhuhr, "dhuhr")),
            Entry(prayer: .asr, name: "Asr", time: adjusted(times.asr, "asr")),
            Entry(prayer: .maghrib, name: "Maghrib", time: adjusted(times.maghrib, "maghrib")),
            Entry(prayer: .isha, name: "Isha", time: adjusted(times.isha, "isha")),
        ]
        let sunrise = Entry(prayer: .sunrise, name: "Sunrise", time: times.sunrise)
        return PrayerDay(entries: entries, sunrise: sunrise, location: location, times: times)
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
