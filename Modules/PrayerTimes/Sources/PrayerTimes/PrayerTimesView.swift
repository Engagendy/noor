import Adhan
import DesignSystem
import SwiftUI

/// Today's five prayers as a vertical timeline with the next prayer
/// emphasized (design §6.4). Updates minute-level, calmly — no ticking.
public struct PrayerTimesView: View {
    @AppStorage("prayer.city") private var cityName = "Makkah"
    @AppStorage("prayer.method") private var methodRaw = CalculationMethodChoice.moonsightingCommittee.rawValue
    @AppStorage("prayer.madhab") private var madhabRaw = MadhabChoice.shafi.rawValue

    private let service = PrayerTimesService()

    public init() {}

    private var city: CityPreset { CityPreset.named(cityName) }
    private var method: CalculationMethodChoice {
        CalculationMethodChoice(rawValue: methodRaw) ?? .moonsightingCommittee
    }
    private var madhab: MadhabChoice { MadhabChoice(rawValue: madhabRaw) ?? .shafi }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: city.timeZoneIdentifier) ?? .current
        return calendar
    }

    public var body: some View {
        TimelineView(.everyMinute) { context in
            List {
                Section {
                    dateHeader(now: context.date)
                }
                .listRowBackground(Color.clear)

                if let times = times(on: context.date) {
                    Section {
                        prayerRows(times: times, now: context.date)
                    }
                }

                settingsSection
            }
            .scrollContentBackground(.hidden)
            .background(NoorColor.bgPrimary)
            .navigationTitle(Text("Prayer Times"))
        }
    }

    private func times(on date: Date) -> Adhan.PrayerTimes? {
        service.prayerTimes(
            latitude: city.latitude, longitude: city.longitude,
            date: date, calendar: calendar,
            method: method.adhanMethod, madhab: madhab.adhanMadhab)
    }

    private func dateHeader(now: Date) -> some View {
        let hijri = now.formatted(
            Date.FormatStyle(date: .long, calendar: Calendar(identifier: .islamicUmmAlQura)))
        return VStack(alignment: .leading, spacing: 4) {
            Text(hijri)
                .font(NoorFont.sectionHeader)
                .foregroundStyle(NoorColor.inkPrimary)
            Text(now.formatted(date: .complete, time: .omitted))
                .font(NoorFont.caption)
                .foregroundStyle(NoorColor.inkSecondary)
        }
    }

    @ViewBuilder
    private func prayerRows(times: Adhan.PrayerTimes, now: Date) -> some View {
        let next = times.nextPrayer(at: now)
        let rows: [(name: LocalizedStringResource, prayer: Prayer, time: Date)] = [
            ("Fajr", .fajr, times.fajr),
            ("Sunrise", .sunrise, times.sunrise),
            ("Dhuhr", .dhuhr, times.dhuhr),
            ("Asr", .asr, times.asr),
            ("Maghrib", .maghrib, times.maghrib),
            ("Isha", .isha, times.isha),
        ]
        ForEach(rows, id: \.prayer) { row in
            let isNext = row.prayer == next
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.name)
                        .font(isNext ? NoorFont.sectionHeader : .body)
                        .foregroundStyle(isNext ? NoorColor.prayerNext : NoorColor.inkPrimary)
                    if isNext {
                        Text(row.time, format: .relative(presentation: .numeric))
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.inkSecondary)
                    }
                }
                Spacer()
                Text(row.time, format: timeFormat)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(isNext ? NoorColor.prayerNext : NoorColor.inkSecondary)
            }
            .padding(.vertical, isNext ? 8 : 2)
            .listRowBackground(isNext ? NoorColor.stateReciting : Color.clear)
            .accessibilityElement(children: .combine)
        }
    }

    /// Times are shown in the selected city's time zone, not the device's.
    private var timeFormat: Date.FormatStyle {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = TimeZone(identifier: city.timeZoneIdentifier) ?? .current
        return style
    }

    private var settingsSection: some View {
        Section(header: Text("Settings").foregroundStyle(NoorColor.inkSecondary)) {
            Picker(selection: $cityName) {
                ForEach(CityPreset.all) { preset in
                    Text(preset.name).tag(preset.name)
                }
            } label: {
                Text("City")
            }
            Picker(selection: $methodRaw) {
                ForEach(CalculationMethodChoice.allCases) { choice in
                    Text(choice.displayName).tag(choice.rawValue)
                }
            } label: {
                Text("Calculation method")
            }
            Picker(selection: $madhabRaw) {
                ForEach(MadhabChoice.allCases) { choice in
                    Text(choice.displayName).tag(choice.rawValue)
                }
            } label: {
                Text("Asr madhab")
            }
        }
        .listRowBackground(NoorColor.bgElevated)
    }
}

#Preview {
    NavigationStack { PrayerTimesView() }
}

#Preview("AR RTL") {
    NavigationStack { PrayerTimesView() }
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}
