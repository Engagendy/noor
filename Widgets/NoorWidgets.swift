import AppIntents
import PrayerTimes
import SwiftUI
import WidgetKit

// MARK: - Configuration (city picked on the widget itself — no app group needed)

enum CityChoice: String, AppEnum {
    case makkah = "Makkah", madinah = "Madinah", cairo = "Cairo", riyadh = "Riyadh",
         dubai = "Dubai", istanbul = "Istanbul", london = "London",
         newYork = "New York", karachi = "Karachi", jakarta = "Jakarta",
         kualaLumpur = "Kuala Lumpur"

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "City")
    // AppIntents metadata extraction requires a literal dictionary here.
    static let caseDisplayRepresentations: [CityChoice: DisplayRepresentation] = [
        .makkah: "Makkah", .madinah: "Madinah", .cairo: "Cairo", .riyadh: "Riyadh",
        .dubai: "Dubai", .istanbul: "Istanbul", .london: "London",
        .newYork: "New York", .karachi: "Karachi", .jakarta: "Jakarta",
        .kualaLumpur: "Kuala Lumpur",
    ]
}

struct PrayerWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Prayer Times"
    static let description = IntentDescription("Next prayer countdown for your city.")

    @Parameter(title: "City", default: .makkah)
    var city: CityChoice
}

// MARK: - Timeline

struct PrayerEntry: TimelineEntry {
    let date: Date
    let cityName: String
    let nextName: String
    let nextTime: Date
    let times: [(name: String, time: Date, isNext: Bool)]
}

struct PrayerProvider: AppIntentTimelineProvider {
    private func entry(for cityName: String, at date: Date) -> PrayerEntry? {
        let city = CityPreset.named(cityName)
        guard let day = PrayerDay.compute(
            location: city.location, method: .moonsightingCommittee, madhab: .shafi, date: date)
            ?? PrayerDay.compute(
                location: city.location, method: .moonsightingCommittee, madhab: .shafi,
                date: date.addingTimeInterval(86400))
        else { return nil }
        let next = day.next(at: date)
            ?? PrayerDay.compute(
                location: city.location, method: .moonsightingCommittee, madhab: .shafi,
                date: date.addingTimeInterval(86400))?.entries.first
        guard let next else { return nil }
        return PrayerEntry(
            date: date,
            cityName: city.name,
            nextName: String(localized: next.name),
            nextTime: next.time,
            times: day.entries.map { (String(localized: $0.name), $0.time, $0.prayer == next.prayer) })
    }

    func placeholder(in context: Context) -> PrayerEntry {
        entry(for: "Makkah", at: .now)
            ?? PrayerEntry(date: .now, cityName: "Makkah", nextName: "Fajr",
                           nextTime: .now.addingTimeInterval(3600), times: [])
    }

    func snapshot(for configuration: PrayerWidgetIntent, in context: Context) async -> PrayerEntry {
        entry(for: configuration.city.rawValue, at: .now) ?? placeholder(in: context)
    }

    func timeline(for configuration: PrayerWidgetIntent, in context: Context) async -> Timeline<PrayerEntry> {
        let now = Date()
        var entries: [PrayerEntry] = []
        var cursor = now
        // One entry now + one right after each upcoming prayer today.
        for _ in 0..<6 {
            guard let entry = entry(for: configuration.city.rawValue, at: cursor) else { break }
            entries.append(entry)
            cursor = entry.nextTime.addingTimeInterval(1)
        }
        return Timeline(entries: entries.isEmpty ? [placeholder(in: context)] : entries,
                        policy: .after(cursor))
    }
}

// MARK: - Views

struct NextPrayerSmallView: View {
    let entry: PrayerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.nextName.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Color(red: 0.05, green: 0.42, blue: 0.36))
            Text(entry.nextTime, style: .timer)
                .font(.system(size: 26, weight: .bold).monospacedDigit())
            Text(entry.nextTime, style: .time)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(entry.cityName)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TodayPrayersMediumView: View {
    let entry: PrayerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(entry.nextName) · ")
                    .font(.system(size: 13, weight: .bold))
                + Text(entry.nextTime, style: .timer)
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                Spacer()
                Text(entry.cityName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(Color(red: 0.05, green: 0.42, blue: 0.36))
            HStack {
                ForEach(entry.times, id: \.name) { item in
                    VStack(spacing: 2) {
                        Text(item.name)
                            .font(.system(size: 11, weight: item.isNext ? .bold : .regular))
                        Text(item.time, style: .time)
                            .font(.system(size: 12, weight: item.isNext ? .bold : .semibold).monospacedDigit())
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(item.isNext ? Color(red: 0.05, green: 0.42, blue: 0.36).opacity(0.14) : .clear,
                                in: RoundedRectangle(cornerRadius: 8))
                    if item.name != entry.times.last?.name { Spacer(minLength: 0) }
                }
            }
        }
    }
}

// MARK: - Widgets

struct NextPrayerWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "NoorNextPrayer", intent: PrayerWidgetIntent.self, provider: PrayerProvider()
        ) { entry in
            NextPrayerWidgetView(entry: entry)
                .containerBackground(Color(red: 0.98, green: 0.965, blue: 0.933), for: .widget)
        }
        .configurationDisplayName("Next Prayer")
        .description("Countdown to the next prayer.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NextPrayerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry

    var body: some View {
        switch family {
        case .systemMedium: TodayPrayersMediumView(entry: entry)
        default: NextPrayerSmallView(entry: entry)
        }
    }
}

@main
struct NoorWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NextPrayerWidget()
    }
}
