import ContentDB
import DesignSystem
import SwiftUI
import WidgetKit

/// Daily ayah on paper texture (design 6.7). Same deterministic pick as the
/// Today card; refreshes at midnight. Text loaded from the bundled DB only.
struct DailyAyahEntry: TimelineEntry {
    let date: Date
    let arabic: String
    let reference: String
    let isArabicUI: Bool
}

struct DailyAyahProvider: TimelineProvider {
    static func entry(for date: Date) -> DailyAyahEntry {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let year = calendar.component(.year, from: date)
        let isArabic = WidgetSettings.isArabic
        guard let db = try? QuranDatabase(),
              let total = try? db.verseCount(),
              let daily = try? db.verse(globalIndex: (dayOfYear &* 271 &+ year) % max(total, 1))
        else {
            return DailyAyahEntry(date: date, arabic: "", reference: "", isArabicUI: isArabic)
        }
        return DailyAyahEntry(
            date: date,
            arabic: daily.verse.text,
            reference: "\(daily.surah.displayName(arabicUI: isArabic)) \(daily.verse.surahId):\(daily.verse.ayah)",
            isArabicUI: isArabic)
    }

    func placeholder(in context: Context) -> DailyAyahEntry {
        Self.entry(for: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyAyahEntry) -> Void) {
        completion(Self.entry(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyAyahEntry>) -> Void) {
        let now = Date()
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86400)
        completion(Timeline(entries: [Self.entry(for: now)], policy: .after(midnight)))
    }
}

struct DailyAyahWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyAyahEntry

    init(entry: DailyAyahEntry) {
        self.entry = entry
        FontRegistrar.registerQuranFont()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.isArabicUI ? "آية اليوم" : "DAILY AYAH")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(WidgetTheme.gold)
            Spacer(minLength: 0)
            Text(entry.arabic)
                .font(.custom(NoorFont.quranFontName, size: family == .systemMedium ? 20 : 16))
                .foregroundStyle(WidgetTheme.ink)
                .lineSpacing(6)
                .minimumScaleFactor(0.5)
                .environment(\.layoutDirection, .rightToLeft)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Spacer(minLength: 0)
            Text(entry.reference)
                .font(.system(size: 10))
                .foregroundStyle(WidgetTheme.inkSecondary)
        }
    }
}

struct DailyAyahWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NoorDailyAyah", provider: DailyAyahProvider()) { entry in
            DailyAyahWidgetView(entry: entry)
                .containerBackground(WidgetTheme.paper, for: .widget)
        }
        .configurationDisplayName("Daily Ayah")
        .description("One ayah each day, from the mushaf.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
