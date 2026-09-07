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
}

public extension View {
    /// Declare the learning area's destinations on the enclosing
    /// `NavigationStack`. Every host that shows `LearnView` must call this
    /// exactly once per stack — twice in one stack makes SwiftUI complain
    /// about a duplicate destination.
    func learnDestinations() -> some View {
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
            }
        }
    }
}
