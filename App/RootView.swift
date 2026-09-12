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
    @AppStorage("onboarded") private var onboarded = false
    @AppStorage("app.language") private var storedLanguage = "system"
    /// NOOR_LANG env overrides (screenshots/UI tests — sim defaults race).
    private var language: String {
        ProcessInfo.processInfo.environment["NOOR_LANG"] ?? storedLanguage
    }
    @AppStorage("app.theme") private var theme = "system"
    /// Interface font family (Settings → App font). Shared key with Android.
    @AppStorage(NoorAppFont.defaultsKey) private var uiFontRaw = NoorAppFont.fallback.rawValue
    @AppStorage(KidsMode.enabledKey) private var kidsEnabled = false

    /// The resolved interface language — one type owns the direction, the
    /// endonym, the formatting locale and the face (see `NoorLanguage`).
    private var resolvedLanguage: NoorLanguage { NoorLanguage.resolve(language) }

    var body: some View {
        Group {
            switch state {
            case .loading:
                NoorColor.bgPrimary.ignoresSafeArea()
            case .ready(let database):
                // Kids mode replaces the whole app shell: no tabs, no
                // Settings, nothing to wander into.
                if kidsEnabled {
                    KidsShellView(database: database, exitKids: { kidsEnabled = false })
                } else {
                    MainTabView(database: database)
                }
            case .failed(let message):
                ContentUnavailableView(
                    "Content unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(verbatim: message)
                )
            }
        }
        .background(NoorColor.bgPrimary)
        // Live language switch via environment only (never AppleLanguages —
        // process/environment direction mismatch mirrors the rendering).
        // .id forces a full re-layout so the direction flip is immediate.
        // The font family is part of the identity for the same reason as the
        // language: NoorFont's tokens are read imperatively, so only a full
        // re-layout makes a change land everywhere at once.
        //
        // It is applied to the app shell ONLY, and deliberately BEFORE the
        // overlay: onboarding is the one screen whose whole job is to change
        // this identity. Inside it, the id changed on every tap of the
        // language grid, so SwiftUI tore the onboarding down and built a new
        // one — `step` went back to the first card and the tap read as
        // "nothing happened". Onboarding carries its own locale and
        // direction (see OnboardingView) and so needs no re-identification.
        .id("\(language)|\(uiFontRaw)")
        .overlay {
            if !onboarded && !showSplash {
                OnboardingView(done: Binding(
                    get: { onboarded },
                    set: { onboarded = $0 }))
                    .transition(.opacity)
                    .zIndex(1)
            }
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        // Not `Locale.current` even for "system": the resolved language is
        // the one whose strings are shown, so it must also be the one that
        // formats the numbers and dates beside them.
        .environment(\.locale, resolvedLanguage.locale)
        // App-wide default face — text that sets no font of its own (and
        // there is plenty) follows the setting through this.
        .environment(\.font, NoorFont.body)
        .onChange(of: "\(uiFontRaw)|\(language)", initial: true) { _, _ in
            NoorAppFont.invalidateCache()
            NoorLanguage.invalidateCache()
            // The language is in here too because it can change the FACE:
            // an Urdu interface is drawn in Nastaliq whatever family is
            // chosen, and the UIKit chrome has to be told.
            NoorAppFont.applyChromeAppearance()
        }
        .environment(\.layoutDirection, resolvedLanguage.layoutDirection)
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
