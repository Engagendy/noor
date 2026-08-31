import DesignSystem
import SwiftUI

/// Hijri month grid (Umm al-Qura): today ringed, sunnah fasting days
/// (Mon/Thu + the white days 13–15) tinted, event days dotted — tap an
/// event day for its story.
struct HijriCalendarView: View {
    let isArabicUI: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    /// Offset in hijri months from the current month.
    @State private var monthOffset = 0
    @State private var detailEvent: IslamicEvent?

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.locale = locale
        return calendar
    }

    private struct DayCell: Identifiable {
        let id: Int          // hijri day number
        let date: Date
        let isToday: Bool
        let isFastingSunnah: Bool
        let events: [IslamicEvent]
    }

    private func monthStart() -> Date {
        let calendar = self.calendar
        let components = calendar.dateComponents([.year, .month], from: Date())
        let start = calendar.date(from: components) ?? Date()
        return calendar.date(byAdding: .month, value: monthOffset, to: start) ?? start
    }

    private func cells() -> (title: String, leading: Int, days: [DayCell]) {
        let calendar = self.calendar
        let start = monthStart()
        let components = calendar.dateComponents([.year, .month], from: start)
        let hijriMonth = components.month ?? 1
        let hijriYear = components.year ?? 1447
        let range = calendar.range(of: .day, in: .month, for: start) ?? 1..<30
        let monthName = (1...12).contains(hijriMonth)
            ? (isArabicUI ? IslamicEvent.hijriMonthsArabic : IslamicEvent.hijriMonthsEnglish)[hijriMonth - 1]
            : ""
        let title = isArabicUI ? "\(monthName) \(hijriYear.arabicIndic) هـ" : "\(monthName) \(hijriYear) AH"

        let weekdayOfFirst = calendar.component(.weekday, from: start)
        // Leading blanks so day 1 lands under its weekday column.
        let leading = (weekdayOfFirst - calendar.firstWeekday + 7) % 7

        let days: [DayCell] = range.compactMap { day in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: start) else { return nil }
            let weekday = Calendar(identifier: .gregorian).component(.weekday, from: date)
            let isMonThu = weekday == 2 || weekday == 5
            let isWhite = (13...15).contains(day)
            return DayCell(
                id: day,
                date: date,
                isToday: calendar.isDate(date, inSameDayAs: Date()),
                isFastingSunnah: isMonThu || isWhite,
                events: IslamicEvent.events(day: day, month: hijriMonth))
        }
        return (title, leading, days)
    }

    private var weekdaySymbols: [String] {
        let calendar = self.calendar
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    var body: some View {
        let month = cells()
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HStack {
                        Button { monthOffset -= 1 } label: {
                            Image(systemName: "chevron.backward")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Previous month")
                        Spacer()
                        Text(verbatim: month.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(NoorColor.inkPrimary)
                        Spacer()
                        Button { monthOffset += 1 } label: {
                            Image(systemName: "chevron.forward")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Next month")
                    }
                    .foregroundStyle(NoorColor.accentPrimary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                        ForEach(weekdaySymbols, id: \.self) { symbol in
                            Text(verbatim: symbol)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(NoorColor.inkSecondary)
                        }
                        ForEach(0..<month.leading, id: \.self) { _ in Color.clear.frame(height: 44) }
                        ForEach(month.days) { day in
                            Button {
                                if let event = day.events.first { detailEvent = event }
                            } label: {
                                VStack(spacing: 2) {
                                    Text(verbatim: isArabicUI ? day.id.arabicIndic : "\(day.id)")
                                        .font(.system(size: 15, weight: day.isToday ? .bold : .regular).monospacedDigit())
                                        .foregroundStyle(day.isToday ? NoorColor.bgPrimary : NoorColor.inkPrimary)
                                    Circle()
                                        .fill(day.events.isEmpty ? Color.clear : NoorColor.accentGold)
                                        .frame(width: 5, height: 5)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(day.isToday ? NoorColor.accentPrimary
                                              : day.isFastingSunnah ? NoorColor.accentPrimary.opacity(0.09)
                                              : Color.clear))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                    .noorCard()

                    // Legend
                    VStack(alignment: .leading, spacing: 8) {
                        legendRow(color: NoorColor.accentPrimary.opacity(0.2),
                                  text: isArabicUI ? "أيام يُسن صيامها (الاثنين والخميس والأيام البيض ١٣–١٥)"
                                                   : "Sunnah fasting days (Mon, Thu, and the white days 13–15)")
                        HStack(spacing: 8) {
                            Circle().fill(NoorColor.accentGold).frame(width: 7, height: 7)
                            Text(isArabicUI ? "يوم فيه حدث من التاريخ الإسلامي — اضغط عليه"
                                            : "Islamic-history event — tap the day")
                                .font(.system(size: 13))
                                .foregroundStyle(NoorColor.inkSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .noorCard()

                    // This month's events list
                    let monthEvents = month.days.flatMap(\.events)
                    if !monthEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(monthEvents) { event in
                                Button {
                                    detailEvent = event
                                } label: {
                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        Text(verbatim: isArabicUI
                                             ? event.day.arabicIndic : "\(event.day)")
                                            .font(.system(size: 14, weight: .bold).monospacedDigit())
                                            .foregroundStyle(NoorColor.accentGold)
                                            .frame(width: 26)
                                        Text(verbatim: isArabicUI ? event.arabic : event.english)
                                            .font(.system(size: 14))
                                            .foregroundStyle(NoorColor.inkPrimary)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(14)
                        .noorCard()
                    }
                }
                .padding(16)
            }
            .background(NoorColor.bgPrimary)
            .navigationTitle(Text("Hijri Calendar"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if monthOffset != 0 {
                    ToolbarItem(placement: .primaryAction) {
                        Button(isArabicUI ? "اليوم" : "Today") { monthOffset = 0 }
                    }
                }
            }
            .sheet(item: $detailEvent) { event in
                EventDetailSheet(event: event, isArabicUI: isArabicUI)
                    .environment(\.locale, locale)
                    .environment(\.layoutDirection, isArabicUI ? .rightToLeft : .leftToRight)
            }
        }
    }

    private func legendRow(color: Color, text: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4).fill(color).frame(width: 16, height: 16)
            Text(verbatim: text)
                .font(.system(size: 13))
                .foregroundStyle(NoorColor.inkSecondary)
        }
    }
}
