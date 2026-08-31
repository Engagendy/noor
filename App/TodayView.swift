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

    @AppStorage("prayer.city") private var cityName = "Makkah"
    @AppStorage("prayer.method") private var methodRaw = CalculationMethodChoice.moonsightingCommittee.rawValue
    @AppStorage("prayer.madhab") private var madhabRaw = MadhabChoice.shafi.rawValue
    @AppStorage("reader.lastSurah") private var lastSurah = 1

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
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(NoorColor.bgPrimary)
        }
    }

    private func header(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            let hijri = now.formatted(
                Date.FormatStyle(date: .long, calendar: Calendar(identifier: .islamicUmmAlQura)))
            Text("\(hijri) · \(now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))")
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
            city: CityPreset.named(cityName),
            method: CalculationMethodChoice(rawValue: methodRaw) ?? .moonsightingCommittee,
            madhab: MadhabChoice(rawValue: madhabRaw) ?? .shafi,
            date: date)
    }

    private func nextPrayerHero(day: PrayerDay, now: Date) -> some View {
        let next = day.next(at: now)
        let passed = day.passedCount(at: now)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(next.map { String(localized: $0.name).uppercased() } ?? String(localized: "Isha").uppercased())
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
                    Text(surah?.nameTransliterated ?? "Al-Faatiha")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(NoorColor.inkPrimary)
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
                    .environment(\.layoutDirection, .rightToLeft)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text("\(daily.surah.nameTransliterated) \(daily.verse.surahId):\(daily.verse.ayah)")
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
        style.timeZone = TimeZone(identifier: CityPreset.named(cityName).timeZoneIdentifier) ?? .current
        return style
    }
}
