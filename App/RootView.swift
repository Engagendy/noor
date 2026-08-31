import ContentDB
import DesignSystem
import QuranReader
import SwiftUI

/// Phase 0 root: verify the bundled Quran DB, then render Surah Al-Fatiha.
/// Replaced by real navigation (Home / Reader / Prayer tabs) in Phase 1.
struct RootView: View {
    enum LoadState {
        case loading
        case ready(QuranDatabase)
        case failed(String)
    }

    @State private var state: LoadState = .loading
    @AppStorage("app.language") private var language = "system"
    @AppStorage("app.theme") private var theme = "system"

    private var effectiveDirection: LayoutDirection {
        switch language {
        case "ar": .rightToLeft
        case "en": .leftToRight
        default: Locale.current.language.characterDirection == .rightToLeft ? .rightToLeft : .leftToRight
        }
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                NoorColor.bgPrimary.ignoresSafeArea()
            case .ready(let database):
                MainTabView(database: database)
            case .failed(let message):
                ContentUnavailableView(
                    "Content unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            }
        }
        .background(NoorColor.bgPrimary)
        // Live language switch: drive locale + layout direction directly so
        // no app restart is needed.
        .environment(\.locale, language == "system" ? .current : Locale(identifier: language))
        .environment(\.layoutDirection, effectiveDirection)
        .preferredColorScheme(theme == "light" ? .light : theme == "dark" ? .dark : nil)
        .task {
            do {
                let database = try QuranDatabase()
                try database.verifyIntegrity()
                state = .ready(database)
            } catch {
                state = .failed("The bundled Quran database failed verification: \(error)")
            }
        }
    }
}
