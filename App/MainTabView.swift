import ContentDB
import DesignSystem
import Notifications
import PrayerTimes
import Qibla
import QuranAudio
import QuranReader
import SwiftUI
import Translations

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

    // Prayer settings — observed so adhan notifications reschedule on change.
    @AppStorage("prayer.city") private var cityName = "Makkah"
    @AppStorage("prayer.method") private var methodRaw = CalculationMethodChoice.moonsightingCommittee.rawValue
    @AppStorage("prayer.madhab") private var madhabRaw = MadhabChoice.shafi.rawValue
    @AppStorage("prayer.sound") private var soundRaw = AdhanSound.adhanShort.rawValue
    @AppStorage("notifications.enabled") private var notificationsEnabled = false

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                TodayView(database: database, openReader: { tab = .quran })
            }
            .tabItem { Label("Today", systemImage: "sun.max") }
            .tag(Tab.today)

            QuranTab(database: database, player: player, translations: translations)
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
        .task { await rescheduleNotifications() }
        .onChange(of: [cityName, methodRaw, madhabRaw, soundRaw, String(notificationsEnabled)]) {
            Task { await rescheduleNotifications() }
        }
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
            city: CityPreset.named(cityName),
            method: CalculationMethodChoice(rawValue: methodRaw) ?? .moonsightingCommittee,
            madhab: MadhabChoice(rawValue: madhabRaw) ?? .shafi,
            sound: AdhanSound(rawValue: soundRaw) ?? .adhanShort)
    }
}

/// Two-pane on iPad/Mac, stacked on iPhone (plan §5 Phase 1).
struct QuranTab: View {
    let database: QuranDatabase
    let player: QuranAudioPlayer
    let translations: TranslationStore

    @State private var surahs: [Surah] = []
    @State private var structure: QuranStructure?
    // Last-read position survives relaunch. (Full SwiftData bookmarks/khatmah
    // come with the Library module.)
    @AppStorage("reader.lastSurah") private var lastSurah = 1
    @State private var selection: Int?
    @State private var targetAyah: Int?

    /// Picking from the surah list clears any pending ayah target; the Juz
    /// tab sets its target before writing selection directly.
    private var listSelection: Binding<Int?> {
        Binding(
            get: { selection },
            set: { newValue in
                targetAyah = nil
                selection = newValue
            })
    }

    var body: some View {
        NavigationSplitView {
            SurahListView(
                surahs: surahs,
                structure: structure,
                selection: listSelection,
                openReference: { surahId, ayah in
                    targetAyah = ayah
                    selection = surahId
                },
                searchVerses: { query in
                    (try? database.searchVerses(query)) ?? []
                })
        } detail: {
            if let selection {
                SurahReaderView(
                    database: database,
                    surahId: selection,
                    scrollToAyah: targetAyah,
                    player: player,
                    translations: translations)
                    .id("\(selection)-\(targetAyah ?? 0)")
            }
        }
        .onAppear {
            surahs = (try? database.allSurahs()) ?? []
            structure = try? database.structure()
            if selection == nil { selection = lastSurah }
        }
        .onChange(of: selection) { _, new in
            if let new { lastSurah = new }
        }
    }
}
