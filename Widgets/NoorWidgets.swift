import AppIntents
import PrayerTimes
import SwiftUI
import WidgetKit

// MARK: - Configuration

enum CityChoice: String, AppEnum {
    case appSetting = "App setting"
    case makkah = "Makkah", madinah = "Madinah", cairo = "Cairo", riyadh = "Riyadh",
         dubai = "Dubai", sharjah = "Sharjah", istanbul = "Istanbul", london = "London",
         newYork = "New York", karachi = "Karachi", jakarta = "Jakarta",
         kualaLumpur = "Kuala Lumpur"

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "City")
    // AppIntents metadata extraction requires a literal dictionary here.
    static let caseDisplayRepresentations: [CityChoice: DisplayRepresentation] = [
        .appSetting: "App setting", .makkah: "Makkah", .madinah: "Madinah",
        .cairo: "Cairo", .riyadh: "Riyadh", .dubai: "Dubai", .sharjah: "Sharjah",
        .istanbul: "Istanbul", .london: "London", .newYork: "New York",
        .karachi: "Karachi", .jakarta: "Jakarta", .kualaLumpur: "Kuala Lumpur",
    ]
}

struct PrayerWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Prayer Times"
    static let description = IntentDescription("Next prayer countdown.")

    @Parameter(title: "City", default: .appSetting)
    var city: CityChoice
}

// MARK: - Shared app settings (via the app group)

enum WidgetSettings {
    static var isArabic: Bool {
        let lang = NoorShared.defaults.string(forKey: "app.language") ?? "system"
        if lang == "ar" { return true }
        if lang == "en" { return false }
        return Locale.current.language.languageCode?.identifier == "ar"
    }

    static func location(for choice: CityChoice) -> PrayerLocation {
        if choice == .appSetting {
            return PrayerLocation.current(defaults: NoorShared.defaults)
        }
        return CityPreset.named(choice.rawValue).location
    }

    static var method: CalculationMethodChoice {
        CalculationMethodChoice(
            rawValue: NoorShared.defaults.string(forKey: "prayer.method") ?? "") ?? .moonsightingCommittee
    }

    static var madhab: MadhabChoice {
        MadhabChoice(rawValue: NoorShared.defaults.string(forKey: "prayer.madhab") ?? "") ?? .shafi
    }

    static func prayerName(_ entry: PrayerDay.Entry, arabic: Bool) -> String {
        guard arabic else { return String(localized: entry.name) }
        switch entry.prayer {
        case .fajr: return "الفجر"
        case .dhuhr: return "الظهر"
        case .asr: return "العصر"
        case .maghrib: return "المغرب"
        case .isha: return "العشاء"
        default: return String(localized: entry.name)
        }
    }

    static func cityLabel(_ location: PrayerLocation, arabic: Bool) -> String {
        guard !location.isCustom else { return location.label }
        return CityPreset.named(location.label).displayName(arabicUI: arabic)
    }
}

// MARK: - Timeline

struct PrayerEntry: TimelineEntry {
    let date: Date
    let cityName: String
    let nextName: String
    let nextTime: Date
    let passedCount: Int
    let times: [(name: String, time: Date, isNext: Bool)]
    let isArabic: Bool
}

struct PrayerProvider: AppIntentTimelineProvider {
    private func entry(for choice: CityChoice, at date: Date) -> PrayerEntry? {
        let location = WidgetSettings.location(for: choice)
        let arabic = WidgetSettings.isArabic
        let method = WidgetSettings.method
        let madhab = WidgetSettings.madhab
        guard let day = PrayerDay.compute(location: location, method: method, madhab: madhab, date: date)
        else { return nil }
        let next = day.next(at: date)
            ?? PrayerDay.compute(location: location, method: method, madhab: madhab,
                                 date: date.addingTimeInterval(86400))?.entries.first
        guard let next else { return nil }
        return PrayerEntry(
            date: date,
            cityName: WidgetSettings.cityLabel(location, arabic: arabic),
            nextName: WidgetSettings.prayerName(next, arabic: arabic),
            nextTime: next.time,
            passedCount: day.passedCount(at: date),
            times: day.entries.map {
                (WidgetSettings.prayerName($0, arabic: arabic), $0.time, $0.prayer == next.prayer)
            },
            isArabic: arabic)
    }

    func placeholder(in context: Context) -> PrayerEntry {
        entry(for: .appSetting, at: .now)
            ?? PrayerEntry(date: .now, cityName: "Makkah", nextName: "Fajr",
                           nextTime: .now.addingTimeInterval(3600), passedCount: 0,
                           times: [], isArabic: false)
    }

    func snapshot(for configuration: PrayerWidgetIntent, in context: Context) async -> PrayerEntry {
        entry(for: configuration.city, at: .now) ?? placeholder(in: context)
    }

    func timeline(for configuration: PrayerWidgetIntent, in context: Context) async -> Timeline<PrayerEntry> {
        let now = Date()
        var entries: [PrayerEntry] = []
        var cursor = now
        for _ in 0..<6 {
            guard let entry = entry(for: configuration.city, at: cursor) else { break }
            entries.append(entry)
            cursor = entry.nextTime.addingTimeInterval(1)
        }
        return Timeline(entries: entries.isEmpty ? [placeholder(in: context)] : entries,
                        policy: .after(cursor))
    }
}

// MARK: - Theme (design 1i: small on paper, medium on Tahajjud dark)

enum WidgetTheme {
    static let paper = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.059, green: 0.082, blue: 0.071, alpha: 1)   // #0F1512
            : UIColor(red: 0.980, green: 0.965, blue: 0.933, alpha: 1)   // #FAF6EE
    })
    static let ink = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.929, green: 0.906, blue: 0.855, alpha: 1)   // #EDE7DA
            : UIColor(red: 0.122, green: 0.161, blue: 0.200, alpha: 1)   // #1F2933
    })
    static let inkSecondary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.604, green: 0.643, blue: 0.620, alpha: 1)   // #9AA49E
            : UIColor(red: 0.361, green: 0.400, blue: 0.439, alpha: 1)   // #5C6670
    })
    static let green = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.310, green: 0.702, blue: 0.627, alpha: 1)   // #4FB3A0
            : UIColor(red: 0.055, green: 0.420, blue: 0.361, alpha: 1)   // #0E6B5C
    })
    static let gold = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.847, green: 0.698, blue: 0.369, alpha: 1)   // #D8B25E
            : UIColor(red: 0.725, green: 0.541, blue: 0.184, alpha: 1)   // #B98A2F
    })
    // Fixed Tahajjud tones for the always-dark medium widget (design 1i).
    static let darkBG = Color(red: 0.059, green: 0.082, blue: 0.071)
    static let darkInk = Color(red: 0.929, green: 0.906, blue: 0.855)
    static let darkSecondary = Color(red: 0.604, green: 0.643, blue: 0.620)
    static let teal = Color(red: 0.310, green: 0.702, blue: 0.627)
}

// MARK: - Views (design 1i)

/// Small: green prayer label, countdown, time, five progress segments.
struct NextPrayerSmallView: View {
    let entry: PrayerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.nextName.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(WidgetTheme.green)
            Text(entry.nextTime, style: .timer)
                .font(.system(size: 26, weight: .bold).monospacedDigit())
                .foregroundStyle(WidgetTheme.ink)
            Text(entry.nextTime, style: .time)
                .font(.system(size: 12))
                .foregroundStyle(WidgetTheme.inkSecondary)
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(index < entry.passedCount
                              ? WidgetTheme.green
                              : WidgetTheme.ink.opacity(0.14))
                        .frame(height: 3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, entry.isArabic ? .rightToLeft : .leftToRight)
    }
}

/// Medium: always Tahajjud dark — TODAY row, next prayer in a teal pill.
struct TodayPrayersMediumView: View {
    let entry: PrayerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.isArabic ? "اليوم" : "TODAY")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(WidgetTheme.teal)
                Text(entry.nextTime, style: .timer)
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .foregroundStyle(WidgetTheme.teal)
                Spacer()
                Text(entry.cityName)
                    .font(.system(size: 11))
                    .foregroundStyle(WidgetTheme.darkSecondary)
            }
            HStack {
                ForEach(entry.times, id: \.name) { item in
                    VStack(spacing: 2) {
                        Text(item.name)
                            .font(.system(size: 11, weight: item.isNext ? .bold : .regular))
                            .foregroundStyle(item.isNext ? WidgetTheme.teal : WidgetTheme.darkSecondary)
                        Text(item.time, style: .time)
                            .font(.system(size: 13, weight: item.isNext ? .bold : .semibold).monospacedDigit())
                            .foregroundStyle(WidgetTheme.darkInk)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 7)
                    .background(item.isNext ? WidgetTheme.teal.opacity(0.16) : .clear,
                                in: RoundedRectangle(cornerRadius: 10))
                    if item.name != entry.times.last?.name { Spacer(minLength: 0) }
                }
            }
        }
        .environment(\.layoutDirection, entry.isArabic ? .rightToLeft : .leftToRight)
    }
}

// MARK: - Widgets

struct NextPrayerWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "NoorNextPrayer", intent: PrayerWidgetIntent.self, provider: PrayerProvider()
        ) { entry in
            NextPrayerWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Prayer")
        .description("Countdown to the next prayer.")
        #if os(iOS)
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryRectangular, .accessoryCircular, .accessoryInline])
        #else
        .supportedFamilies([.systemSmall, .systemMedium])
        #endif
    }
}

struct NextPrayerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry

    var body: some View {
        switch family {
        case .systemMedium:
            TodayPrayersMediumView(entry: entry)
                .containerBackground(WidgetTheme.darkBG, for: .widget)
        #if os(iOS)
        case .accessoryRectangular:
            LockRectangularView(entry: entry)
                .containerBackground(.clear, for: .widget)
        case .accessoryCircular:
            LockCircularView(entry: entry)
                .containerBackground(.clear, for: .widget)
        case .accessoryInline:
            // Inline: single line next to the clock.
            Text(verbatim: "\(entry.nextName) \(entry.nextTime.formatted(date: .omitted, time: .shortened))")
                .containerBackground(.clear, for: .widget)
        #endif
        default:
            NextPrayerSmallView(entry: entry)
                .containerBackground(WidgetTheme.paper, for: .widget)
        }
    }
}

#if os(iOS)
/// Lock screen rectangular: prayer name, time, live countdown.
struct LockRectangularView: View {
    let entry: PrayerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: entry.isArabic ? "الصلاة القادمة" : "NEXT PRAYER")
                .font(.system(size: 11, weight: .semibold))
                .opacity(0.75)
            HStack(spacing: 6) {
                Text(verbatim: entry.nextName)
                    .font(.system(size: 16, weight: .bold))
                Text(entry.nextTime, style: .time)
                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
                    .opacity(0.9)
            }
            Text(entry.nextTime, style: .timer)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .opacity(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, entry.isArabic ? .rightToLeft : .leftToRight)
    }
}

/// Lock screen circular: gauge of the day's prayers + next prayer name.
struct LockCircularView: View {
    let entry: PrayerEntry

    var body: some View {
        Gauge(value: Double(entry.passedCount), in: 0...5) {
            Image(systemName: "moon.stars.fill")
        } currentValueLabel: {
            VStack(spacing: 0) {
                Text(verbatim: String(entry.nextName.prefix(6)))
                    .font(.system(size: 11, weight: .bold))
                    .minimumScaleFactor(0.6)
                Text(entry.nextTime, style: .time)
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .minimumScaleFactor(0.6)
            }
        }
        .gaugeStyle(.accessoryCircular)
    }
}
#endif

@main
struct NoorWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NextPrayerWidget()
        DailyAyahWidget()
    }
}
