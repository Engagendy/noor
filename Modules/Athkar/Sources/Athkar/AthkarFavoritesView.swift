import DesignSystem
import SwiftUI

/// Every favourited dhikr, each with its chapter beneath it. A row keeps
/// the card's play, share and favourite controls, so a favourite can be
/// dropped from here; tapping the text opens the chapter scrolled to that
/// dhikr with the same brief flash a search hit gets.
struct AthkarFavoritesView: View {
    let categories: [DhikrCategory]
    /// Screenshot/UI-test hook: open the first favourite's chapter on arrival.
    var autoOpenFirst = false
    @State private var favorites = AthkarFavorites.shared
    @State private var pushed: Target?
    @State private var sharing: Entry?
    @Environment(\.locale) private var locale
    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }
    private let audio = AthkarAudioPlayer.shared

    struct Entry: Identifiable, Hashable {
        let key: String
        let category: DhikrCategory
        let dhikr: Dhikr
        let itemIndex: Int
        var id: String { key }
    }

    private struct Target: Identifiable, Hashable {
        let category: DhikrCategory
        let highlightIndex: Int
        var id: String { "\(category.id)#\(highlightIndex)" }
    }

    /// Favourites in book order (chapter, then position), resolved against
    /// the bundled data — a key whose dhikr no longer exists is skipped.
    private var entries: [Entry] {
        var out: [Entry] = []
        for category in categories {
            for (index, dhikr) in category.items.enumerated() {
                guard let key = AthkarFavorites.key(for: dhikr), favorites.isFavorite(key) else { continue }
                out.append(Entry(key: key, category: category, dhikr: dhikr, itemIndex: index))
            }
        }
        return out
    }

    var body: some View {
        let entries = entries
        return ScrollView {
            if entries.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            DhikrCard(
                                dhikr: entry.dhikr,
                                done: 0,
                                audioState: entry.dhikr.audio == nil ? nil : DhikrCard.AudioState(
                                    isActive: audio.nowPlaying == entry.key,
                                    isPlaying: audio.nowPlaying == entry.key && audio.isPlaying,
                                    isLoading: audio.nowPlaying == entry.key && audio.isLoading,
                                    failed: audio.failed == entry.key),
                                showsProgress: false,
                                isFavorite: true,
                                onTap: { pushed = Target(category: entry.category, highlightIndex: entry.itemIndex) },
                                onShare: { sharing = entry },
                                onPlay: entry.dhikr.audio.map { file in
                                    { audio.play(file: file, id: entry.key) }
                                },
                                onFavorite: { favorites.toggle(entry.key) })
                            Text(verbatim: entry.category.displayTitle(arabicUI: isArabicUI))
                                .font(NoorFont.caption)
                                .foregroundStyle(NoorColor.accentGold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }
                    }
                }
                .padding(16)
                .animation(.easeInOut(duration: 0.2), value: entries.map(\.key))
            }
        }
        .onDisappear { audio.stop() }
        .sheet(item: $sharing) { entry in
            NoorShareSheet(
                arabicText: entry.dhikr.text,
                reference: entry.category.category,
                attribution: "نور Noor · حصن المسلم",
                useQuranFont: false,
                videoOption: DhikrVideoComposer.shareOption(for: entry.dhikr, arabicUI: isArabicUI))
                .environment(\.locale, locale)
        }
        .navigationDestination(item: $pushed) { target in
            DhikrListView(category: target.category, highlightIndex: target.highlightIndex)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .background(NoorColor.bgPrimary)
        .navigationTitle(Text("Favourites"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            guard autoOpenFirst, let first = entries.first else { return }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            pushed = Target(category: first.category, highlightIndex: first.itemIndex)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart")
                .font(.system(size: 36))
                .foregroundStyle(NoorColor.accentGold)
            Text("No favourite athkar yet")
                .font(.noorScaled(17, weight: .semibold))
                .foregroundStyle(NoorColor.inkPrimary)
            Text("Tap the heart on any dhikr to keep it here.")
                .font(NoorFont.caption)
                .foregroundStyle(NoorColor.inkSecondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.top, 96)
        // Interface text follows the interface direction, not the RTL the
        // Arabic cards would use.
        .noorInterfaceDirection()
    }
}

#Preview("Favourites AR-RTL") {
    NavigationStack { AthkarFavoritesView(categories: AthkarStore.load()) }
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Favourites EN-LTR") {
    NavigationStack { AthkarFavoritesView(categories: AthkarStore.load()) }
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.layoutDirection, .leftToRight)
}
