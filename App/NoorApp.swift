import DesignSystem
import PrayerTimes
import SwiftUI

@main
struct NoorApp: App {
    init() {
        FontRegistrar.registerQuranFont()
        // Migration: we briefly wrote AppleLanguages for in-app language;
        // that mirrors rendering when it disagrees with the environment.
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }

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
                Text(cityName)
            }
        }
    }
}
#endif
