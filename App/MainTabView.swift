import ContentDB
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
        case today, quran, prayer, settings
    }

    let database: QuranDatabase
    // NOOR_TAB launch env var selects the initial tab (UI tests, screenshots).
    @State private var tab: Tab = switch ProcessInfo.processInfo.environment["NOOR_TAB"] {
        case "quran": .quran
        case "prayer": .prayer
        default: .today
    }
    @State private var player = QuranAudioPlayer()
    @State private var translations = TranslationStore()
    @State private var library = try? LibraryStore()

    // Prayer settings — observed so adhan notifications reschedule on change.
    @AppStorage("prayer.city") private var cityName = "Makkah"
    @AppStorage("prayer.method") private var methodRaw = CalculationMethodChoice.moonsightingCommittee.rawValue
    @AppStorage("prayer.madhab") private var madhabRaw = MadhabChoice.shafi.rawValue
    @AppStorage("prayer.sound") private var soundRaw = AdhanSound.adhanShort.rawValue
    @AppStorage("notifications.enabled") private var notificationsEnabled = false
    @AppStorage("prayer.useCustom") private var useCustomLocation = false
    @AppStorage("notif.fajr") private var notifFajr = true
    @AppStorage("notif.dhuhr") private var notifDhuhr = true
    @AppStorage("notif.asr") private var notifAsr = true
    @AppStorage("notif.maghrib") private var notifMaghrib = true
    @AppStorage("notif.isha") private var notifIsha = true
    @AppStorage("app.language") private var appLanguage = "system"
    @AppStorage("prayer.customLabel") private var customLabel = ""

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                TodayView(database: database, openReader: { tab = .quran })
            }
            .tabItem { Label("Today", systemImage: "sun.max") }
            .tag(Tab.today)

            QuranTab(database: database, player: player, translations: translations, library: library)
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
            }
            .tabItem { Label("Prayer", systemImage: "clock") }
            .tag(Tab.prayer)

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(NoorColor.accentPrimary)
        .task {
            syncWidgets()
            await rescheduleNotifications()
        }
        .onChange(of: [cityName, methodRaw, madhabRaw, soundRaw,
                       String(notificationsEnabled), String(useCustomLocation),
                       String(notifFajr), String(notifDhuhr), String(notifAsr),
                       String(notifMaghrib), String(notifIsha),
                       appLanguage, customLabel]) {
            syncWidgets()
            Task { await rescheduleNotifications() }
        }
    }

    /// Mirrors settings into the app group and refreshes the widgets.
    private func syncWidgets() {
        NoorShared.syncFromApp()
        WidgetCenter.shared.reloadAllTimelines()
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
            sound: AdhanSound(rawValue: soundRaw) ?? .adhanShort)
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
        }
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
