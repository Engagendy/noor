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
    @State private var showSplash = true
    @AppStorage("app.language") private var storedLanguage = "system"
    /// NOOR_LANG env overrides (screenshots/UI tests — sim defaults race).
    private var language: String {
        ProcessInfo.processInfo.environment["NOOR_LANG"] ?? storedLanguage
    }
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
        .overlay {
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        // Live language switch via environment only (never AppleLanguages —
        // process/environment direction mismatch mirrors the rendering).
        // .id forces a full re-layout so the direction flip is immediate.
        .id(language)
        .environment(\.locale, language == "system" ? .current : Locale(identifier: language))
        .environment(\.layoutDirection, effectiveDirection)
        .preferredColorScheme(theme == "light" ? .light : theme == "dark" ? .dark : nil)
        .task {
            let start = ContinuousClock.now
            do {
                let database = try QuranDatabase()
                // Off the main thread — a blocked main thread freezes the
                // splash animation mid-draw.
                try await Task.detached(priority: .userInitiated) {
                    try database.verifyIntegrity()
                }.value
                state = .ready(database)
            } catch {
                state = .failed("The bundled Quran database failed verification: \(error)")
            }
            // Guarantee the intro a full animation window (calm fade, §5).
            let elapsed = start.duration(to: .now)
            let remaining = .seconds(2.2) - elapsed
            if remaining > .zero {
                try? await Task.sleep(for: remaining)
            }
            withAnimation(.easeInOut(duration: 0.5)) { showSplash = false }
        }
    }
}
