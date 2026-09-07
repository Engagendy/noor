import ContentDB
import Athkar
import DesignSystem
import Learn
import Library
import Notifications
import PrayerTimes
import Qibla
import QuranAudio
import QuranReader
import Tafsir
import SwiftUI
import Translations
import WidgetKit

struct MainTabView: View {
    enum Tab: Hashable {
        case today, quran, prayer, athkar, hadith
    }

    let database: QuranDatabase
    // NOOR_TAB launch env var selects the initial tab (UI tests, screenshots).
    @State private var tab: Tab = switch ProcessInfo.processInfo.environment["NOOR_TAB"] {
        case "quran": .quran
        case "prayer": .prayer
        case "athkar": .athkar
        case "hadith": .hadith
        default: .today
    }
    @State private var player = QuranAudioPlayer()
    /// Screenshot/UI-test hook: NOOR_RECITER_SHEET=1 opens the reciter
    /// picker (with its pinned "Translation audio" row) at launch.
    @State private var showReciterSheetHook =
        ProcessInfo.processInfo.environment["NOOR_RECITER_SHEET"] == "1"
    @Environment(\.locale) private var locale
    @State private var quranOpenRequest: Int?
    /// Open the reader at an exact mushaf page (continue / khatmah).
    @State private var quranOpenPage: Int?
    @State private var quranOpenTarget: ReaderTarget?
    /// Athkar category to push after a reminder tap (exact json title).
    @State private var athkarOpenCategory: String?
    @State private var translations = TranslationStore()
    @AppStorage("translation.id") private var translationId = "en.sahih"
    @State private var library = LibraryStore.sharedInstance

    // Prayer settings — observed so adhan notifications reschedule on change.
    @AppStorage("prayer.city") private var cityName = "Makkah"
    @AppStorage("prayer.method") private var methodRaw = CalculationMethodChoice.moonsightingCommittee.rawValue
    @AppStorage("prayer.madhab") private var madhabRaw = MadhabChoice.shafi.rawValue
    @AppStorage("prayer.sound") private var soundRaw = AdhanSound.adhanMadinah.rawValue
    @AppStorage("notifications.enabled") private var notificationsEnabled = false
    @AppStorage("prayer.useCustom") private var useCustomLocation = false
    @AppStorage("notif.fajr") private var notifFajr = true
    @AppStorage("notif.dhuhr") private var notifDhuhr = true
    @AppStorage("notif.asr") private var notifAsr = true
    @AppStorage("notif.maghrib") private var notifMaghrib = true
    @AppStorage("notif.isha") private var notifIsha = true
    @AppStorage("app.language") private var appLanguage = "system"
    @AppStorage("prayer.customLabel") private var customLabel = ""
    @AppStorage("fasting.reminders") private var fastingReminders = false
    @AppStorage("prayer.prealert") private var preAlertMinutes = 0
    // Manual per-prayer minute offsets: PrayerDay.compute applies them, so
    // a change must reschedule or the adhan fires at the unadjusted time.
    @AppStorage("prayer.adj.fajr") private var adjFajr = 0
    @AppStorage("prayer.adj.dhuhr") private var adjDhuhr = 0
    @AppStorage("prayer.adj.asr") private var adjAsr = 0
    @AppStorage("prayer.adj.maghrib") private var adjMaghrib = 0
    @AppStorage("prayer.adj.isha") private var adjIsha = 0
    // Offline city-database selection (cached fields mirrored to widgets).
    @AppStorage("prayer.cityId") private var cityId = 0
    @AppStorage("prayer.cityName") private var selectedCityName = ""
    @AppStorage("prayer.cityNameAr") private var selectedCityNameAr = ""
    @AppStorage("prayer.cityCountry") private var selectedCityCountry = ""
    @AppStorage("prayer.cityLat") private var selectedCityLat = 0.0
    @AppStorage("prayer.cityLon") private var selectedCityLon = 0.0
    @AppStorage("prayer.cityTz") private var selectedCityTz = ""
    @AppStorage("prayer.customLabelAr") private var customLabelAr = ""
    // After-salah athkar reminder — independent of the adhan toggle.
    @AppStorage(AthkarReminderScheduler.enabledKey) private var athkarAfterSalah = false
    @AppStorage(AthkarReminderScheduler.minutesKey) private var athkarAfterSalahMinutes
        = AthkarReminderScheduler.defaultMinutes

    var body: some View {
        mainTabs
            .tint(NoorColor.accentPrimary)
            .sheet(isPresented: $showReciterSheetHook) {
                let arabicUI = locale.language.languageCode?.identifier == "ar"
                ReciterPickerSheet(
                    selection: Binding(
                        get: { player.reciter.rawValue },
                        set: { player.reciter = Reciter(rawValue: $0) ?? .alafasy }),
                    translationSelection: Binding(
                        get: { player.translationVoice.rawValue },
                        set: { player.translationVoice = TranslationVoice(rawValue: $0) ?? .none }),
                    isArabicUI: arabicUI)
                    .environment(\.layoutDirection, arabicUI ? .rightToLeft : .leftToRight)
            }
            .onChange(of: translationId) { _, _ in
                // Swap the loaded edition and fetch it right away.
                translations = TranslationStore()
                Task { await translations.download() }
            }
            .modifier(TabLifecycle(
                player: player, tab: $tab,
                openPendingPage: openPendingPage,
                syncWidgets: syncWidgets,
                reschedule: { await rescheduleNotifications() },
                watched: [cityName, methodRaw, madhabRaw, soundRaw,
                          String(notificationsEnabled), String(useCustomLocation),
                          String(notifFajr), String(notifDhuhr), String(notifAsr),
                          String(notifMaghrib), String(notifIsha),
                          appLanguage, customLabel, String(fastingReminders),
                          String(preAlertMinutes),
                          String(adjFajr), String(adjDhuhr), String(adjAsr),
                          String(adjMaghrib), String(adjIsha),
                          String(cityId), selectedCityName, selectedCityNameAr,
                          selectedCityCountry, String(selectedCityLat),
                          String(selectedCityLon), selectedCityTz, customLabelAr,
                          String(athkarAfterSalah), String(athkarAfterSalahMinutes)]))
    }

    private var mainTabs: some View {
        TabView(selection: $tab) {
            NavigationStack {
                TodayView(
                    database: database,
                    openReader: {
                        tab = .quran
                        let page = UserDefaults.standard.integer(forKey: "reader.lastPage")
                        if page > 0 {
                            quranOpenPage = page
                        } else {
                            quranOpenRequest = max(1, UserDefaults.standard.integer(forKey: "reader.lastSurah"))
                        }
                    },
                    openPage: { page in
                        tab = .quran
                        quranOpenPage = page
                    },
                    openListening: { surah, ayah in
                        tab = .quran
                        quranOpenTarget = ReaderTarget(surahId: surah, ayah: ayah)
                    },
                    openAthkar: { tab = .athkar },
                    openPrayer: { tab = .prayer })
                    .safeAreaInset(edge: .bottom, spacing: 8) { globalPill }
            }
            .tabItem { Label("Today", systemImage: "sun.max") }
            .tag(Tab.today)

            QuranTab(database: database, player: player, translations: translations,
                     library: library, openRequest: $quranOpenRequest,
                     openPageRequest: $quranOpenPage,
                     openTarget: $quranOpenTarget)
                .tabItem { Label("Quran", systemImage: "book") }
                .tag(Tab.quran)

            NavigationStack {
                PrayerTimesView()
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            NavigationLink {
                                QiblaView()
                            } label: {
                                Image(systemName: "safari")
                                    .foregroundStyle(NoorColor.accentPrimary)
                            }
                            .accessibilityLabel("Qibla")
                        }
                    }
                    .safeAreaInset(edge: .bottom, spacing: 8) { globalPill }
            }
            .tabItem { Label("Prayer", systemImage: "clock") }
            .tag(Tab.prayer)

            NavigationStack {
                AthkarView(openCategory: $athkarOpenCategory)
                    .safeAreaInset(edge: .bottom, spacing: 8) { globalPill }
            }
                .tabItem { Label("Athkar", systemImage: "sparkles") }
                .tag(Tab.athkar)
                // Never two voices: athkar recordings pause the reciter, and
                // starting the reciter silences any athkar recording.
                .onAppear {
                    AthkarAudioPlayer.shared.pauseOthers = { [player] in
                        if player.isPlaying { player.togglePlayPause() }
                    }
                }
                .onChange(of: player.isPlaying) { _, playing in
                    if playing { AthkarAudioPlayer.shared.stop() }
                }

            NavigationStack {
                HadithTab()
                    .safeAreaInset(edge: .bottom, spacing: 8) { globalPill }
            }
                .tabItem { Label("Hadith", systemImage: "text.book.closed") }
                .tag(Tab.hadith)
        }
    }

    /// Siri "read my wird" / notification taps: consume pending routes.
    /// Also runs on first appearance so a cold start from a notification
    /// (delegate fires before this view exists) still lands on the target.
    private func openPendingPage() {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: "pending.openRoute") == AthkarReminderScheduler.openRoute {
            defaults.removeObject(forKey: "pending.openRoute")
            tab = .athkar
            athkarOpenCategory = AthkarView.afterSalahCategory
        }
        let page = defaults.integer(forKey: "pending.openPage")
        guard page > 0 else { return }
        defaults.set(0, forKey: "pending.openPage")
        tab = .quran
        quranOpenPage = page
    }

    /// Player pill shown above the tab bar while recitation runs (the
    /// reader has its own copy inside the Quran tab).
    @ViewBuilder
    private var globalPill: some View {
        if player.current != nil {
            AudioPillView(player: player)
                .environment(\.layoutDirection, .leftToRight)
                .padding(.bottom, 4)
        }
    }

    /// Mirrors settings into the app group and refreshes the widgets.
    private func syncWidgets() {
        NoorShared.syncFromApp()
        WidgetCenter.shared.reloadAllTimelines()
        CloudSync.pushLocal()
    }

    private var isArabicNotifications: Bool {
        appLanguage == "ar"
            || (appLanguage == "system"
                && Locale.current.language.languageCode?.identifier == "ar")
    }

    private func rescheduleNotifications() async {
        let scheduler = AdhanNotificationScheduler()
        let location = PrayerLocation.current()
        let method = CalculationMethodChoice(rawValue: methodRaw) ?? .moonsightingCommittee
        let madhab = MadhabChoice(rawValue: madhabRaw) ?? .shafi
        // Adhan, fasting, and after-salah athkar are independent toggles:
        // each scheduler only ever removes its own prefix (`adhan-`/
        // `pre-adhan-`, `fasting-`, `athkar-`), so turning one off never
        // drops the others.
        if !notificationsEnabled {
            await scheduler.cancelAll()
        }
        // Cancelling the fasting/athkar requests must run even when EVERY
        // toggle is off — these calls are the only paths that remove them.
        // (An early `guard` here once skipped the fasting cancel; keep the
        // disable calls ahead of any return.)
        guard notificationsEnabled || fastingReminders || athkarAfterSalah else {
            await FastingReminderScheduler().reschedule(
                arabic: isArabicNotifications, enabled: false)
            await AthkarReminderScheduler().reschedule(
                enabled: false, minutes: athkarAfterSalahMinutes,
                location: location, method: method, madhab: madhab,
                adhanEnabled: false, arabic: isArabicNotifications)
            return
        }
        // Disabling must never depend on authorization succeeding: with
        // permission revoked in iOS Settings the guard below returns early,
        // and a reminder switched off here would otherwise survive and fire
        // the moment permission is granted again.
        if !fastingReminders {
            await FastingReminderScheduler().reschedule(
                arabic: isArabicNotifications, enabled: false)
        }
        if !athkarAfterSalah {
            await AthkarReminderScheduler().reschedule(
                enabled: false, minutes: athkarAfterSalahMinutes,
                location: location, method: method, madhab: madhab,
                adhanEnabled: false, arabic: isArabicNotifications)
        }
        guard await scheduler.requestAuthorization() else {
            notificationsEnabled = false
            return
        }
        // One `now` for both schedulers: each plans against the same 56-item
        // budget, and a prayer passing between the two calls would otherwise
        // shift one plan by a prayer and let the pair exceed it by one.
        let now = Date()
        // Both adhan and athkar plan from the same day loop with one shared
        // budget (56 + fasting's 8 = iOS's 64), so pass the athkar offset
        // to the adhan scheduler even though it only schedules adhans.
        let athkarMinutes = athkarAfterSalah ? athkarAfterSalahMinutes : nil
        if notificationsEnabled {
            await scheduler.reschedule(
                location: location, method: method, madhab: madhab,
                sound: AdhanSound.stored(soundRaw),
                arabic: isArabicNotifications,
                preAlertMinutes: preAlertMinutes,
                athkarMinutes: athkarMinutes, now: now)
        }
        await AthkarReminderScheduler().reschedule(
            enabled: athkarAfterSalah, minutes: athkarAfterSalahMinutes,
            location: location, method: method, madhab: madhab,
            adhanEnabled: notificationsEnabled, preAlertMinutes: preAlertMinutes,
            arabic: isArabicNotifications, now: now)
        await FastingReminderScheduler().reschedule(
            arabic: isArabicNotifications, enabled: fastingReminders)
    }
}

/// Cross-cutting app lifecycle: iCloud sync, widget mirroring,
/// notification rescheduling, Siri pending-page handling. Extracted so
/// MainTabView.body stays type-checkable.
private struct TabLifecycle: ViewModifier {
    let player: QuranAudioPlayer
    @Binding var tab: MainTabView.Tab
    let openPendingPage: () -> Void
    let syncWidgets: () -> Void
    let reschedule: () async -> Void
    let watched: [String]
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .noorOpenPendingPage)) { _ in
                openPendingPage()
            }
            #if os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: .noorToggleLiveActivity)) { _ in
                Task { await PrayerLiveActivityController.toggle() }
            }
            #endif
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    openPendingPage()
                    // Roll a running Live Activity past an adhan that already
                    // fired; end it when nothing is left to count down to.
                    #if os(iOS)
                    Task { await PrayerLiveActivityController.refresh() }
                    #endif
                }
                // Push reading progress to iCloud when leaving the front.
                if phase == .background || phase == .inactive { CloudSync.pushLocal() }
            }
            .task {
                if ProcessInfo.processInfo.environment["NOOR_TEST_LA"] == "1" {
                    NotificationCenter.default.post(name: .noorToggleLiveActivity, object: nil)
                }
                CloudSync.start()
                syncWidgets()
                // Cold start from a notification tap: the route was stored
                // before this view existed.
                openPendingPage()
                await reschedule()
            }
            .onChange(of: watched) {
                syncWidgets()
                Task { await reschedule() }
            }
    }
}

/// Reader destination: a surah, optionally scrolled to an ayah.
struct ReaderTarget: Identifiable, Hashable {
    let surahId: Int
    let ayah: Int?
    var id: String { "\(surahId)-\(ayah ?? 0)" }
}

/// Two-pane on iPad/Mac; explicit push navigation on iPhone (programmatic
/// List selection does not reliably push in a collapsed split view).
struct QuranTab: View {
    let database: QuranDatabase
    let player: QuranAudioPlayer
    let translations: TranslationStore
    let library: LibraryStore?
    @Binding var openRequest: Int?
    @Binding var openPageRequest: Int?
    @Binding var openTarget: ReaderTarget?

    @State private var surahs: [Surah] = []
    @State private var structure: QuranStructure?
    @State private var pageLayout = try? PageLayoutDatabase()
    @AppStorage("reader.lastSurah") private var lastSurah = 1
    @State private var selection: Int?
    @State private var targetAyah: Int?
    /// Type-erased so the Quran stack can push both the reader and the
    /// learning area from one path.
    @State private var compactPath = NavigationPath()
    /// iPad/Mac: the learning area is a sheet — the split view's detail pane
    /// belongs to the reader.
    @State private var showLearn = false
    /// Written by `SurahReaderView` as the user toggles the chrome.
    private let readerChrome = ReaderChrome.shared
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    /// Screenshot/UI-test hook: NOOR_OPEN=<surahId> pushes the reader.
    private var autoOpenSurah: Int? {
        ProcessInfo.processInfo.environment["NOOR_OPEN"].flatMap(Int.init)
    }

    private func open(_ surahId: Int, _ ayah: Int?) {
        lastSurah = surahId
        targetAyah = ayah
        selection = surahId
        compactPath = NavigationPath()
        compactPath.append(ReaderTarget(surahId: surahId, ayah: ayah))
    }

    private func listView(onLearn: @escaping () -> Void) -> some View {
        SurahListView(
            surahs: surahs,
            structure: structure,
            selection: $selection,
            openReference: open,
            searchVerses: { query in
                (try? database.searchVerseResults(query)) ?? .empty
            },
            bookmarks: (library?.bookmarks ?? []).map {
                BookmarkRef(surahId: $0.surahId, ayah: $0.ayah, createdAt: $0.createdAt)
            },
            onRemoveBookmark: { ref in
                library?.remove(BookmarkItem(surahId: ref.surahId, ayah: ref.ayah, createdAt: ref.createdAt))
            },
            onOpenLearn: onLearn)
            #if os(iOS)
            // Bars are declared per screen (stack-level modifiers don't
            // reach pushed destinations): index = own header + tabs.
            .toolbar(.hidden, for: .navigationBar)
            #endif
    }

    /// `exit` is nil in the split view, where the reader is the detail pane
    /// and there is nothing to pop.
    private func reader(surahId: Int, ayah: Int?, exit: (() -> Void)? = nil) -> some View {
        SurahReaderView(
            database: database,
            surahId: surahId,
            scrollToAyah: ayah,
            player: player,
            translations: translations,
            layout: pageLayout,
            bookmarkedRefs: Set((library?.bookmarks ?? []).map(\.id)),
            onToggleBookmark: { bookmarkSurah, bookmarkAyah in
                library?.toggle(surahId: bookmarkSurah, ayah: bookmarkAyah)
            },
            onExitReader: exit)
            .id("\(surahId)-\(ayah ?? 0)")
    }

    var body: some View {
        Group {
            #if os(iOS)
            if sizeClass == .compact {
                NavigationStack(path: $compactPath) {
                    listView(onLearn: { compactPath.append(LearnRoute.home) })
                        .navigationDestination(for: ReaderTarget.self) { target in
                            reader(surahId: target.surahId, ayah: target.ayah,
                                   exit: { compactPath = NavigationPath() })
                        }
                        .learnDestinations { topic in tafsirScreen(topic) }
                }
                // The reader is immersive, but its tab bar follows the
                // reader's CHROME rather than the whole session — a
                // deliberate divergence from Android, which hides its bar
                // for the entire session because it has a system back
                // button. iOS has none, and with the navigation bar hidden
                // the interactive edge-swipe back is gone too, so the fully
                // immersive state would leave the drawer's "Back to Quran"
                // row as the only way out. Tap the page and the top strip
                // and the tab bar come back together; tap again and both go.
                // Do not "fix" the two platforms back into symmetry.
                //
                // `.toolbar(…, for: .tabBar)` declared INSIDE the pushed
                // reader never took effect (the index below it declares
                // .visible in the same stack, and iOS 26's floating tab bar
                // keeps winning), so the tab's own root drives it.
                // `ReaderChrome` is the single source of truth the reader
                // itself writes — the iOS twin of Android's `ReaderChrome`.
                // `readerOpen` guards the hidden case: a `.hidden`
                // preference declared here applies to the TabView as a
                // whole, even while another tab is selected, so tapping a
                // tab from inside the reader would otherwise leave EVERY
                // tab without a bar.
                .toolbar(compactPath.isEmpty || !readerChrome.readerOpen
                         || readerChrome.chromeVisible ? .visible : .hidden,
                         for: .tabBar)

            } else {
                splitView
            }
            #else
            splitView
            #endif
        }
        .onAppear {
            surahs = (try? database.allSurahs()) ?? []
            structure = try? database.structure()
            if selection == nil { selection = lastSurah }
            consumeOpenRequest()
            if let auto = autoOpenSurah { open(auto, nil) }
            openLearnForScreenshots()
        }
        .onChange(of: openRequest) { _, _ in consumeOpenRequest() }
        .onChange(of: openPageRequest) { _, _ in consumeOpenRequest() }
        .onChange(of: openTarget) { _, _ in consumeOpenRequest() }
    }

    /// The Learn hub's tafsir destinations. They live in the Tafsir module
    /// (Learn must not import a sibling feature), and both go through the one
    /// `TafsirService` — same CDN bundles, same cache as the ayah sheet.
    @ViewBuilder
    private func tafsirScreen(_ topic: LearnRoute.TafsirTopic) -> some View {
        switch topic {
        case .browse:
            TafsirBrowserView()
        case .wordMeanings:
            TafsirBrowserView(edition: .gharib)
        }
    }

    /// Screenshot/UI-test hook: NOOR_LEARN=1 pushes the learning area,
    /// =matn its first matn (or =<matn id> a named one), =tajweed the guide,
    /// =tafsir the tafsir browser, =gharib the word meanings.
    private func openLearnForScreenshots() {
        guard compactPath.isEmpty,
              let mode = ProcessInfo.processInfo.environment["NOOR_LEARN"]
        else { return }
        compactPath.append(LearnRoute.home)
        switch mode {
        case "matn":
            if let id = MatnStore.load().first?.id { compactPath.append(LearnRoute.matn(id)) }
        case "tajweed":
            compactPath.append(LearnRoute.tajweed)
        case "tafsir", "gharib":
            let wordMeanings = mode == "gharib"
            compactPath.append(LearnRoute.tafsir(wordMeanings ? .wordMeanings : .browse))
            // NOOR_TAFSIR_SURAH=2 also opens that surah, for the screenshots.
            if let surah = ProcessInfo.processInfo.environment["NOOR_TAFSIR_SURAH"]
                .flatMap(Int.init) {
                let slug = wordMeanings
                    ? TafsirEdition.gharib.slug
                    : (ProcessInfo.processInfo.environment["NOOR_TAFSIR_EDITION"]
                       ?? UserDefaults.standard.string(forKey: "tafsir.edition")
                       ?? TafsirEdition.all[0].slug)
                compactPath.append(TafsirSurahRoute(surahId: surah, slug: slug))
            }
        default:
            // Any matn by id, e.g. NOOR_LEARN=bayquniyyah.
            if MatnStore.matn(id: mode) != nil { compactPath.append(LearnRoute.matn(mode)) }
        }
    }

    private var splitView: some View {
        NavigationSplitView {
            listView(onLearn: { showLearn = true })
                .sheet(isPresented: $showLearn) {
                    NavigationStack {
                        LearnView().learnDestinations { topic in tafsirScreen(topic) }
                    }
                }
        } detail: {
            if let selection {
                reader(surahId: selection, ayah: targetAyah)
            }
        }
        .onChange(of: selection) { _, new in
            // Sidebar taps on iPad write the binding directly.
            if let new { lastSurah = new }
        }
    }
}


extension QuranTab {
    /// Today's Continue Reading card requests a direct open at the resume point.
    fileprivate func consumeOpenRequest() {
        if let target = openTarget {
            openTarget = nil
            open(target.surahId, target.ayah)
            return
        }
        // Page requests resolve to the exact (surah, ayah) that page starts
        // with, so the reader lands on that precise mushaf page.
        if let page = openPageRequest {
            // Keep the request until the structure is loaded (onAppear
            // retries) — consuming early dropped taps on cold tab switches.
            guard let structure else { return }
            openPageRequest = nil
            if let start = structure.pageStarts.first(where: { $0.idx == page }) {
                open(start.surahId, start.ayah)
            }
            return
        }
        guard let request = openRequest else { return }
        openRequest = nil
        open(request, nil)
    }
}
