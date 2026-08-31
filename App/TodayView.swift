import Athkar
import ContentDB
import DesignSystem
import PrayerTimes
import SwiftUI

/// Home / Today per design 1e — quick-glance posture, max 4 cards.
/// The Daily Hadith card joins when the Sunnah module lands.
struct TodayView: View {
    let database: QuranDatabase
    /// Switches the tab bar to the Quran tab (Continue Reading card).
    let openReader: () -> Void
    /// Switches to the Athkar tab (Daily Dhikr card).
    let openAthkar: () -> Void
    @State private var athkar: [DhikrCategory] = []

    @AppStorage("prayer.city") private var cityName = "Makkah"
    @AppStorage("prayer.method") private var methodRaw = CalculationMethodChoice.moonsightingCommittee.rawValue
    @AppStorage("prayer.madhab") private var madhabRaw = MadhabChoice.shafi.rawValue
    @AppStorage("reader.lastSurah") private var lastSurah = 1
    @AppStorage("khatmah.maxPage") private var khatmahMaxPage = 0
    @Environment(\.locale) private var locale

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    /// String(localized:) uses the process language; resolve in the app's.
    private func localizedName(_ resource: LocalizedStringResource) -> String {
        var resource = resource
        resource.locale = locale
        return String(localized: resource)
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header(now: context.date)
                    if let day = prayerDay(date: context.date) {
                        nextPrayerHero(day: day, now: context.date)
                    }
                    continueReadingCard
                    dailyAyahCard(now: context.date)
                    dailyDhikrCard(now: context.date)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(NoorColor.bgPrimary)
        }
        .task {
            if athkar.isEmpty { athkar = AthkarStore.load() }
        }
    }

    /// Time-aware dhikr: morning after Fajr, evening from Dhuhr, sleep
    /// after Isha — keyed to the user's actual prayer times.
    private func dhikrSlot(now: Date) -> (title: LocalizedStringKey, pool: [Dhikr]) {
        let morningEvening = athkar.first { $0.category.contains("الصباح") }?.items ?? []
        let sleep = athkar.first { $0.category == "أذكار النوم" }?.items ?? []
        guard let day = prayerDay(date: now) else { return ("MORNING ATHKAR", morningEvening) }
        let times = Dictionary(uniqueKeysWithValues: day.entries.map { ($0.prayer, $0.time) })
        if let isha = times[.isha], now >= isha { return ("SLEEP ATHKAR", sleep) }
        if let dhuhr = times[.dhuhr], now >= dhuhr { return ("EVENING ATHKAR", morningEvening) }
        if let fajr = times[.fajr], now < fajr { return ("SLEEP ATHKAR", sleep) }
        return ("MORNING ATHKAR", morningEvening)
    }

    private func dailyDhikrCard(now: Date) -> some View {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: now) ?? 1
        let slot = dhikrSlot(now: now)
        let pool = slot.pool
        let dhikr = pool.isEmpty ? nil : pool[(dayOfYear &* 31) % pool.count]
        return Button(action: openAthkar) {
            VStack(alignment: .leading, spacing: 6) {
                Text(slot.title)
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(NoorColor.inkSecondary)
                if let dhikr {
                    Text(dhikr.text)
                        .font(.system(size: 16))
                        .foregroundStyle(NoorColor.inkPrimary)
                        .lineSpacing(6)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .environment(\.layoutDirection, .rightToLeft)
                    if dhikr.count > 1 {
                        Text("Repeat \(dhikr.count)×")
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.accentGold)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .noorCard()
    }

    private func header(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            var hijriStyle = Date.FormatStyle(date: .long, calendar: Calendar(identifier: .islamicUmmAlQura))
            let _ = hijriStyle.locale = locale
            var gregStyle = Date.FormatStyle().weekday(.wide).month(.abbreviated).day()
            let _ = gregStyle.locale = locale
            Text("\(now.formatted(hijriStyle)) · \(now.formatted(gregStyle))")
                .font(NoorFont.caption)
                .foregroundStyle(NoorColor.inkSecondary)
            Text("As-salamu alaykum")
                .font(NoorFont.screenTitle)
                .foregroundStyle(NoorColor.inkPrimary)
        }
        .padding(.bottom, 4)
    }

    private func prayerDay(date: Date) -> PrayerDay? {
        PrayerDay.compute(
            location: PrayerLocation.current(),
            method: CalculationMethodChoice(rawValue: methodRaw) ?? .moonsightingCommittee,
            madhab: MadhabChoice(rawValue: madhabRaw) ?? .shafi,
            date: date)
    }

    private func nextPrayerHero(day: PrayerDay, now: Date) -> some View {
        let next = day.next(at: now)
        let passed = day.passedCount(at: now)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(next.map { localizedName($0.name).uppercased() } ?? localizedName("Isha").uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1.5)
                    .opacity(0.85)
                Spacer()
                if let next {
                    Text(next.time, format: cityTimeFormat)
                        .font(.system(size: 13).monospacedDigit())
                        .opacity(0.85)
                }
            }
            if let next {
                Text(next.time, format: .relative(presentation: .numeric))
                    .font(.system(size: 34, weight: .semibold))
            } else {
                Text("All prayers done for today")
                    .font(.system(size: 22, weight: .semibold))
            }
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(.white.opacity(index < passed ? 0.9 : 0.35))
                        .frame(height: 3)
                }
            }
            .padding(.top, 12)
            HStack {
                ForEach(day.entries) { entry in
                    Text(entry.name)
                        .font(.system(size: 10.5))
                        .opacity(0.8)
                    if entry.prayer != .isha { Spacer() }
                }
            }
            .padding(.top, 2)
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(NoorColor.accentPrimary)
                .shadow(color: NoorColor.accentPrimary.opacity(0.22), radius: 9, y: 6)
        )
        .accessibilityElement(children: .combine)
    }

    private var continueReadingCard: some View {
        let surah = (try? database.allSurahs().first { $0.id == lastSurah }) ?? nil
        return Button(action: openReader) {
            HStack(spacing: 14) {
                Image(systemName: "book")
                    .font(.system(size: 19))
                    .foregroundStyle(NoorColor.accentGold)
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 12).fill(NoorColor.accentGold.opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("CONTINUE READING")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(NoorColor.inkSecondary)
                    Text(surah?.displayName(arabicUI: isArabicUI) ?? "")
                        .font(isArabicUI ? NoorFont.quran(size: 18) : .system(size: 16, weight: .semibold))
                        .foregroundStyle(NoorColor.inkPrimary)
                    if khatmahMaxPage > 0 {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(NoorColor.inkPrimary.opacity(0.07))
                                Capsule().fill(NoorColor.accentGold)
                                    .frame(width: geometry.size.width * CGFloat(khatmahMaxPage) / 604)
                            }
                        }
                        .frame(height: 3)
                        .padding(.top, 6)
                        Text(verbatim: isArabicUI
                             ? "الختمة · صفحة \(khatmahMaxPage.arabicIndic) من ٦٠٤"
                             : "Khatmah · page \(khatmahMaxPage) of 604")
                            .font(.system(size: 11))
                            .foregroundStyle(NoorColor.inkSecondary)
                            .padding(.top, 2)
                    }
                }
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NoorColor.inkSecondary)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .noorCard()
    }

    private func dailyAyahCard(now: Date) -> some View {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: now) ?? 1
        let year = Calendar.current.component(.year, from: now)
        let total = (try? database.verseCount()) ?? 6236
        let index = (dayOfYear &* 271 &+ year) % max(total, 1)
        let daily = try? database.verse(globalIndex: index)
        return VStack(alignment: .leading, spacing: 6) {
            Text("DAILY AYAH")
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(NoorColor.inkSecondary)
            if let daily {
                Text(daily.verse.text)
                    .font(NoorFont.quran(size: 21))
                    .foregroundStyle(NoorColor.inkPrimary)
                    .lineSpacing(12)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, .rightToLeft)
                Text(verbatim: "\u{200F}\(daily.surah.displayName(arabicUI: isArabicUI)) \(daily.verse.surahId):\(daily.verse.ayah)")
                    .font(NoorFont.caption)
                    .foregroundStyle(NoorColor.inkSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .noorCard()
    }

    private var cityTimeFormat: Date.FormatStyle {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = TimeZone(identifier: PrayerLocation.current().timeZoneIdentifier) ?? .current
        return style
    }
}
