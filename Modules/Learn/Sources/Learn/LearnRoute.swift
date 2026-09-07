import SwiftUI

/// Navigation inside the learning area. Value-based so any host stack can
/// deep-link straight to a matn or the guide (the Quran tab does exactly
/// that for its screenshot hook, and Today could later).
public enum LearnRoute: Hashable, Sendable {
    /// The learning area itself: matns + the tajweed guide.
    case home
    /// One matn by `Matn.id`.
    case matn(String)
    case tajweed
    /// The tafsir surfaces. Their screens live in the Tafsir module, which
    /// Learn must NOT import (CLAUDE.md §4: features never import each
    /// other), so the host supplies them to `learnDestinations`.
    case tafsir(TafsirTopic)

    /// Which tafsir surface a `.tafsir` route wants.
    public enum TafsirTopic: Hashable, Sendable {
        /// Browse tafsir by surah, in the edition the user picks.
        case browse
        /// غريب القرآن — the meanings of the difficult words.
        case wordMeanings
    }
}

public extension View {
    /// Declare the learning area's destinations on the enclosing
    /// `NavigationStack`. Every host that shows `LearnView` must call this
    /// exactly once per stack — twice in one stack makes SwiftUI complain
    /// about a duplicate destination.
    /// - Parameter tafsir: builds the screen for a `.tafsir` route. The host
    ///   passes `TafsirBrowserView` (App target); Learn cannot, since it must
    ///   not import a sibling feature module.
    func learnDestinations<TafsirScreen: View>(
        @ViewBuilder tafsir: @escaping (LearnRoute.TafsirTopic) -> TafsirScreen
    ) -> some View {
        navigationDestination(for: LearnRoute.self) { route in
            switch route {
            case .home:
                LearnView()
            case .matn(let id):
                if let matn = MatnStore.matn(id: id) {
                    MatnReaderView(matn: matn)
                }
            case .tajweed:
                TajweedGuideView()
            case .tafsir(let topic):
                tafsir(topic)
            }
        }
    }
}
