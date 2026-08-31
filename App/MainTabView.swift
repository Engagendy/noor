import ContentDB
import DesignSystem
import PrayerTimes
import QuranReader
import SwiftUI

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

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                TodayView(database: database, openReader: { tab = .quran })
            }
            .tabItem { Label("Today", systemImage: "sun.max") }
            .tag(Tab.today)

            QuranTab(database: database)
                .tabItem { Label("Quran", systemImage: "book") }
                .tag(Tab.quran)

            NavigationStack { PrayerTimesView() }
                .tabItem { Label("Prayer", systemImage: "clock") }
                .tag(Tab.prayer)

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(NoorColor.accentPrimary)
    }
}

/// Two-pane on iPad/Mac, stacked on iPhone (plan §5 Phase 1).
struct QuranTab: View {
    let database: QuranDatabase

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
            SurahListView(surahs: surahs, structure: structure, selection: listSelection) { surahId, ayah in
                targetAyah = ayah
                selection = surahId
            }
        } detail: {
            if let selection {
                SurahReaderView(database: database, surahId: selection, scrollToAyah: targetAyah)
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
