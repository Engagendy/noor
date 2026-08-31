import ContentDB
import DesignSystem
import PrayerTimes
import QuranReader
import SwiftUI

struct MainTabView: View {
    enum Tab: Hashable {
        case today, quran, prayer
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
        }
        .tint(NoorColor.accentPrimary)
    }
}

/// Two-pane on iPad/Mac, stacked on iPhone (plan §5 Phase 1).
struct QuranTab: View {
    let database: QuranDatabase

    @State private var surahs: [Surah] = []
    // Last-read position survives relaunch. (Full SwiftData bookmarks/khatmah
    // come with the Library module.)
    @AppStorage("reader.lastSurah") private var lastSurah = 1
    @State private var selection: Int?

    var body: some View {
        NavigationSplitView {
            SurahListView(surahs: surahs, selection: $selection)
        } detail: {
            if let selection {
                SurahReaderView(database: database, surahId: selection)
                    .id(selection)
            }
        }
        .onAppear {
            surahs = (try? database.allSurahs()) ?? []
            if selection == nil { selection = lastSurah }
        }
        .onChange(of: selection) { _, new in
            if let new { lastSurah = new }
        }
    }
}
