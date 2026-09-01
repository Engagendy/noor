import ContentDB
import Athkar
import DesignSystem
import Library
import Notifications
import PrayerTimes
import Qibla
import QuranAudio
import QuranReader
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
        default: .today
    }
    @State private var player = QuranAudioPlayer()
    @State private var quranOpenRequest: Int?
    /// Open the reader at an exact mushaf page (continue / khatmah).
    @State private var quranOpenPage: Int?
    @State private var quranOpenTarget: ReaderTarget?
    @State private var translations = TranslationStore()
    @State private var library = try? LibraryStore()

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

    var body: some View {
        mainTabs
            .tint(NoorColor.accentPrimary)
            .modifier(TabLifecycle(
                player: player, tab: $tab,
                openPendingPage: openPendingPage,
                syncWidgets: syncWidgets,
                reschedule: { await rescheduleNotifications() },
                watched: [cityName, methodRaw, madhabRaw, soundRaw,
                          String(notificationsEnabled), String(useCustomLocation),
                          String(notifFajr), String(notifDhuhr), String(notifAsr),
                          String(notifMaghrib), String(notifIsha),
                          appLanguage, customLabel, String(fastingReminders)]))
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
                    openAthkar: { tab = .athkar })
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
                AthkarView()
                    .safeAreaInset(edge: .bottom, spacing: 8) { globalPill }
            }
                .tabItem { Label("Athkar", systemImage: "sparkles") }
                .tag(Tab.athkar)

            NavigationStack {
                HadithTab()
                    .safeAreaInset(edge: .bottom, spacing: 8) { globalPill }
            }
                .tabItem { Label("Hadith", systemImage: "text.book.closed") }
                .tag(Tab.hadith)
        }
    }

    /// Siri "read my wird": consume the pending page request.
    private func openPendingPage() {
        let defaults = UserDefaults.standard
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
        guard notificationsEnabled else {
            scheduler.cancelAll()
            return
        }
        guard await scheduler.requestAuthorization() else {
            notificationsEnabled = false
            return
        }
        await scheduler.reschedule(
            location: PrayerLocation.current(),
            method: CalculationMethodChoice(rawValue: methodRaw) ?? .moonsightingCommittee,
            madhab: MadhabChoice(rawValue: madhabRaw) ?? .shafi,
            sound: AdhanSound(rawValue: soundRaw) ?? .adhanMadinah,
            arabic: isArabicNotifications)
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
                if phase == .active { openPendingPage() }
                // Push reading progress to iCloud when leaving the front.
                if phase == .background || phase == .inactive { CloudSync.pushLocal() }
            }
            .task {
                if ProcessInfo.processInfo.environment["NOOR_TEST_LA"] == "1" {
                    NotificationCenter.default.post(name: .noorToggleLiveActivity, object: nil)
                }
                CloudSync.start()
                syncWidgets()
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
    @State private var compactPath: [ReaderTarget] = []
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
        compactPath = [ReaderTarget(surahId: surahId, ayah: ayah)]
    }

    private var listView: some View {
        SurahListView(
            surahs: surahs,
            structure: structure,
            selection: $selection,
            openReference: open,
            searchVerses: { query in
                (try? database.searchVerses(query)) ?? []
            },
            bookmarks: (library?.bookmarks ?? []).map {
                BookmarkRef(surahId: $0.surahId, ayah: $0.ayah, createdAt: $0.createdAt)
            },
            onRemoveBookmark: { ref in
                library?.remove(BookmarkItem(surahId: ref.surahId, ayah: ref.ayah, createdAt: ref.createdAt))
            })
            #if os(iOS)
            // Bars are declared per screen (stack-level modifiers don't
            // reach pushed destinations): index = own header + tabs.
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.visible, for: .tabBar)
            #endif
    }

    private func reader(surahId: Int, ayah: Int?) -> some View {
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
            })
            .id("\(surahId)-\(ayah ?? 0)")
    }

    var body: some View {
        Group {
            #if os(iOS)
            if sizeClass == .compact {
                NavigationStack(path: $compactPath) {
                    listView
                        .navigationDestination(for: ReaderTarget.self) { target in
                            reader(surahId: target.surahId, ayah: target.ayah)
                        }
                }

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
        }
        .onChange(of: openRequest) { _, _ in consumeOpenRequest() }
        .onChange(of: openPageRequest) { _, _ in consumeOpenRequest() }
        .onChange(of: openTarget) { _, _ in consumeOpenRequest() }
    }

    private var splitView: some View {
        NavigationSplitView {
            listView
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
