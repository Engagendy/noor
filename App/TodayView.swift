import Athkar
import ContentDB
import QuranReader
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
    @State private var hadiths: [HadithItem] = []
    @State private var showHadithList = false

    enum ShareItem: Identifiable {
        case ayah(Verse, Surah)
        case dhikr(Dhikr)
        case event(IslamicEvent)
        var id: String {
            switch self {
            case .ayah(let verse, _): "a\(verse.id)"
            case .dhikr(let dhikr): "d\(dhikr.id.hashValue)"
            case .event(let event): "e\(event.day)-\(event.month)-\(event.arabic.hashValue)"
            }
        }
    }
    @State private var shareItem: ShareItem?
    @State private var detailEvent: IslamicEvent?
    @State private var showKhatmahGoal = false
    /// Bumped when the plan changes so the card recomputes.
    @State private var khatmahPlanVersion = 0

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
                    khatmahCard(now: context.date)
                    dailyAyahCard(now: context.date)
                    dailyDhikrCard(now: context.date)
                    dailyHadithCard(now: context.date)
                    onThisDayCard(now: context.date)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(NoorColor.bgPrimary)
        }
        .task {
            if athkar.isEmpty { athkar = AthkarStore.load() }
            if hadiths.isEmpty { hadiths = HadithStore.load() }
        }
        .sheet(isPresented: $showHadithList) {
            HadithListView(items: hadiths, isArabicUI: isArabicUI,
                           initial: HadithStore.daily(from: hadiths, date: Date()))
                .environment(\.locale, locale)
                .environment(\.layoutDirection, isArabicUI ? .rightToLeft : .leftToRight)
        }
        .sheet(isPresented: $showKhatmahGoal) {
            KhatmahGoalSheet(currentPage: khatmahMaxPage,
                             onChanged: { khatmahPlanVersion += 1 })
                .environment(\.locale, locale)
                .environment(\.layoutDirection, isArabicUI ? .rightToLeft : .leftToRight)
        }
        .sheet(item: $detailEvent) { event in
            EventDetailSheet(event: event, isArabicUI: isArabicUI)
                .environment(\.locale, locale)
                .environment(\.layoutDirection, isArabicUI ? .rightToLeft : .leftToRight)
        }
        .sheet(item: $shareItem) { item in
            switch item {
            case .ayah(let verse, let surah):
                NoorShareSheet(
                    arabicText: verse.text,
                    reference: "\(surah.displayName(arabicUI: isArabicUI)) · \(verse.surahId):\(verse.ayah)",
                    attribution: "نور Noor · Quran text: Tanzil.net",
                    useQuranFont: true)
                    .presentationDetents([.medium, .large])
            case .dhikr(let dhikr):
                NoorShareSheet(
                    arabicText: dhikr.text,
                    reference: isArabicUI ? "حصن المسلم" : "Hisn al-Muslim",
                    attribution: "نور Noor · Hisn al-Muslim",
                    useQuranFont: false)
                    .presentationDetents([.medium, .large])
            case .event(let event):
                NoorShareSheet(
                    arabicText: isArabicUI ? event.arabic : event.english,
                    reference: eventReference(event),
                    attribution: "نور Noor",
                    useQuranFont: false)
                    .presentationDetents([.medium, .large])
            }
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
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(slot.title)
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(NoorColor.inkSecondary)
                Spacer()
                if let dhikr {
                    Button {
                        shareItem = .dhikr(dhikr)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                            .foregroundStyle(NoorColor.accentPrimary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Share")
                }
            }
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
        .onTapGesture(perform: openAthkar)
        .noorCard()
    }

    /// Daily hadith from the bundled Nawawi + Qudsi collections.
    @ViewBuilder
    private func dailyHadithCard(now: Date) -> some View {
        if let hadith = HadithStore.daily(from: hadiths, date: now) {
            Button { showHadithList = true } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("DAILY HADITH")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(NoorColor.inkSecondary)
                        Spacer()
                        Text(verbatim: isArabicUI ? hadith.collectionArabic : hadith.collectionEnglish)
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.accentGold)
                    }
                    Text(verbatim: hadith.arabic)
                        .font(.system(size: 16))
                        .foregroundStyle(NoorColor.inkPrimary)
                        .lineSpacing(7)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .environment(\.layoutDirection, .rightToLeft)
                    Text(isArabicUI ? "اقرأ الحديث كاملًا ←" : "Read the full hadith →")
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.accentPrimary)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .noorCard()
        }
    }

    private func eventReference(_ event: IslamicEvent) -> String {
        let month = event.monthName(arabicUI: isArabicUI)
        let date = isArabicUI ? "\(event.day.arabicIndic) \(month)" : "\(event.day) \(month)"
        if let year = event.yearHijri {
            return isArabicUI ? "\(date) · سنة \(year.arabicIndic) هـ"
                              : "\(date) · \(year) AH"
        }
        return date
    }

    /// Next event in the Hijri year when today has none — the card always
    /// has something to show.
    private func upcomingEvent(day: Int, month: Int) -> (event: IslamicEvent, inDays: Int)? {
        let today = month * 30 + day
        return IslamicEvent.all
            .map { event -> (IslamicEvent, Int) in
                let target = event.month * 30 + event.day
                let delta = target >= today ? target - today : target + 360 - today
                return (event, delta)
            }
            .min { $0.1 < $1.1 }
            .map { (event: $0.0, inDays: $0.1) }
    }

    /// "On this day" in Islamic history, matched by the Hijri date; falls
    /// back to the next upcoming event.
    @ViewBuilder
    private func onThisDayCard(now: Date) -> some View {
        let hijri = Calendar(identifier: .islamicUmmAlQura).dateComponents([.day, .month], from: now)
        let todays = IslamicEvent.events(day: hijri.day ?? 0, month: hijri.month ?? 0)
        let upcoming = todays.isEmpty
            ? upcomingEvent(day: hijri.day ?? 0, month: hijri.month ?? 0) : nil
        let events = todays.isEmpty ? (upcoming.map { [$0.event] } ?? []) : todays
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(upcoming == nil ? "ON THIS DAY" : "COMING UP IN ISLAMIC HISTORY")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(NoorColor.inkSecondary)
                    Spacer()
                    Button {
                        shareItem = .event(events[0])
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                            .foregroundStyle(NoorColor.accentPrimary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Share")
                }
                ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                    Button {
                        detailEvent = event
                    } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: isArabicUI ? event.arabic : event.english)
                            .font(.system(size: 15))
                            .foregroundStyle(NoorColor.inkPrimary)
                            .lineSpacing(5)
                            .multilineTextAlignment(isArabicUI ? .leading : .leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .environment(\.layoutDirection, isArabicUI ? .rightToLeft : .leftToRight)
                        HStack(spacing: 8) {
                            if let year = event.yearHijri {
                                Text(verbatim: isArabicUI ? "سنة \(year.arabicIndic) هـ" : "\(year) AH")
                            }
                            if let upcoming {
                                Text(verbatim: isArabicUI
                                     ? "بعد \(upcoming.inDays.arabicIndic) يومًا تقريبًا"
                                     : "in about \(upcoming.inDays) days")
                            }
                            Spacer(minLength: 8)
                            Text(isArabicUI ? "التفاصيل" : "Details")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(NoorColor.bgPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(NoorColor.accentPrimary))
                        }
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.accentGold)
                    }
                    .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .noorCard()
        }
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

    /// Khatmah plan: daily portion, behind/ahead, start/change goal.
    @ViewBuilder
    private func khatmahCard(now: Date) -> some View {
        let _ = khatmahPlanVersion
        if let plan = KhatmahPlan.load() {
            let left = plan.pagesLeftToday(now: now, currentPage: khatmahMaxPage)
            let behind = plan.pagesBehind(now: now, currentPage: khatmahMaxPage)
            let target = plan.targetPage(now: now)
            Button { showKhatmahGoal = true } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("KHATMAH PLAN")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(NoorColor.inkSecondary)
                        Spacer()
                        Text(verbatim: isArabicUI
                             ? "اليوم \(plan.dayNumber(now: now).arabicIndic) من \(plan.goalDays.arabicIndic)"
                             : "Day \(plan.dayNumber(now: now)) of \(plan.goalDays)")
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.accentGold)
                    }
                    if plan.isFinished(currentPage: khatmahMaxPage) {
                        Text(isArabicUI ? "ما شاء الله، أتممت الختمة 🎉" : "Masha'Allah — khatmah complete 🎉")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(NoorColor.accentPrimary)
                    } else if left == 0 {
                        Text(isArabicUI ? "أنجزت وِرد اليوم، تقبّل الله" : "Today's portion done — may Allah accept")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(NoorColor.accentPrimary)
                    } else {
                        Text(verbatim: isArabicUI
                             ? "اقرأ إلى صفحة \(target.arabicIndic) · بقيت \(left.arabicIndic) صفحات اليوم"
                             : "Read to page \(target) · \(left) pages left today")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(NoorColor.inkPrimary)
                        if behind > 0 {
                            Text(verbatim: isArabicUI
                                 ? "متأخر بـ \(behind.arabicIndic) صفحات عن الخطة"
                                 : "\(behind) pages behind schedule")
                                .font(NoorFont.caption)
                                .foregroundStyle(NoorColor.accentGold)
                        }
                    }
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(NoorColor.inkPrimary.opacity(0.07))
                            Capsule().fill(NoorColor.accentPrimary)
                                .frame(width: geometry.size.width * CGFloat(min(khatmahMaxPage, 604)) / 604)
                        }
                    }
                    .frame(height: 5)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .noorCard()
        } else {
            Button { showKhatmahGoal = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 15))
                        .foregroundStyle(NoorColor.accentPrimary)
                    Text("Start a khatmah plan")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(NoorColor.inkPrimary)
                    Spacer()
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NoorColor.inkSecondary.opacity(0.6))
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .noorCard()
        }
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
            HStack {
                Text("DAILY AYAH")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(NoorColor.inkSecondary)
                Spacer()
                if let daily {
                    Button {
                        shareItem = .ayah(daily.verse, daily.surah)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                            .foregroundStyle(NoorColor.accentPrimary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Share")
                }
            }
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


/// Full story of an Islamic-history event, with its own share button.
struct EventDetailSheet: View {
    let event: IslamicEvent
    let isArabicUI: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var sharing = false

    private var dateLine: String {
        let month = event.monthName(arabicUI: isArabicUI)
        if isArabicUI {
            let year = event.yearHijri.map { " سنة \($0.arabicIndic) هـ" } ?? ""
            return "\(event.day.arabicIndic) \(month)\(year)"
        }
        let year = event.yearHijri.map { ", \($0) AH" } ?? ""
        return "\(event.day) \(month)\(year)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(verbatim: isArabicUI ? event.arabic : event.english)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(NoorColor.inkPrimary)
                        .lineSpacing(6)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 13))
                        Text(verbatim: dateLine)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(NoorColor.accentGold)
                    Rectangle()
                        .fill(NoorColor.accentGold.opacity(0.3))
                        .frame(height: 0.7)
                    Text(verbatim: isArabicUI ? event.detailArabic : event.detailEnglish)
                        .font(.system(size: 16.5))
                        .foregroundStyle(NoorColor.inkPrimary)
                        .lineSpacing(9)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "text.book.closed")
                            .font(.system(size: 12))
                        Text(verbatim: isArabicUI
                             ? "المصدر: \(event.sourceArabic)"
                             : "Source: \(event.sourceEnglish)")
                            .font(.system(size: 13))
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(NoorColor.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .background(NoorColor.bgPrimary)
            .navigationTitle(Text("ON THIS DAY"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        sharing = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share")
                }
            }
            .sheet(isPresented: $sharing) {
                NoorShareSheet(
                    arabicText: isArabicUI ? event.arabic : event.english,
                    translation: isArabicUI ? nil : nil,
                    reference: dateLine,
                    attribution: "نور Noor",
                    useQuranFont: false)
                    .environment(\.layoutDirection, isArabicUI ? .rightToLeft : .leftToRight)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}


/// Choose the khatmah duration; shows the resulting daily portion live.
struct KhatmahGoalSheet: View {
    let currentPage: Int
    var onChanged: () -> Void
    @State private var days = 30
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }
    private var pagesPerDay: Int {
        Int((Double(KhatmahPlan.totalPages - min(currentPage, 603)) / Double(days)).rounded(.up))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Finish the Quran in")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NoorColor.inkSecondary)
                HStack(spacing: 8) {
                    ForEach([15, 30, 60, 90], id: \.self) { preset in
                        Button {
                            days = preset
                        } label: {
                            Text(verbatim: isArabicUI ? preset.arabicIndic : "\(preset)")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(days == preset ? NoorColor.accentPrimary : NoorColor.bgElevated))
                                .foregroundStyle(days == preset ? NoorColor.bgPrimary : NoorColor.inkPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Stepper(value: $days, in: 3...365) {
                    Text(verbatim: isArabicUI ? "\(days.arabicIndic) يومًا" : "\(days) days")
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(verbatim: isArabicUI
                     ? "وِردك اليومي: نحو \(pagesPerDay.arabicIndic) صفحات"
                     : "Daily portion: about \(pagesPerDay) pages")
                    .font(.system(size: 14))
                    .foregroundStyle(NoorColor.accentGold)
                Button {
                    KhatmahPlan.start(days: days, currentPage: currentPage)
                    onChanged()
                    dismiss()
                } label: {
                    Text("Start plan")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(NoorColor.bgPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: 14).fill(NoorColor.accentPrimary))
                }
                .buttonStyle(.plain)
                if KhatmahPlan.load() != nil {
                    Button {
                        KhatmahPlan.clear()
                        onChanged()
                        dismiss()
                    } label: {
                        Text("Stop plan")
                            .font(.system(size: 15))
                            .foregroundStyle(.red.opacity(0.85))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(20)
            .background(NoorColor.bgPrimary)
            .navigationTitle(Text("KHATMAH PLAN"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if let plan = KhatmahPlan.load() { days = plan.goalDays }
            }
        }
        .presentationDetents([.medium])
    }
}
