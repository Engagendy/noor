import ContentDB
import DesignSystem
import QuranAudio
import SwiftUI

/// The whole app while `kids.enabled` is true: two tabs (Read, My athkar),
/// a star header, and a grown-up control that leaves kids mode behind the
/// parental gate. Nothing here can reach Settings, sharing, bookmarks or
/// any other adult surface — that is the point of the mode.
///
/// It lives in the app target on purpose: it composes QuranReader-adjacent
/// rendering, QuranAudio and Athkar, and feature modules never import each
/// other (CLAUDE.md §Engineering conventions).
struct KidsShellView: View {
    let database: QuranDatabase
    /// Runs after the grown-up gate succeeds: back to the normal app.
    let exitKids: () -> Void

    enum Tab: Hashable { case read, athkar }

    @State private var tab: Tab = .read
    @State private var player = QuranAudioPlayer()
    @State private var surahs: [Surah] = []
    @State private var path: [KidsReaderRoute] = []
    /// Screenshot/UI-test hook: NOOR_KIDS_GATE=1 presents the grown-up gate.
    @State private var showGate =
        ProcessInfo.processInfo.environment["NOOR_KIDS_GATE"] == "1"
    /// Screenshot/UI-test hook: NOOR_KIDS_SETTINGS=1 presents the child's
    /// settings sheet (language, listen/memorise, reciter).
    @State private var showKidsSettings =
        ProcessInfo.processInfo.environment["NOOR_KIDS_SETTINGS"] == "1"
    /// Bumped after every star award so the header and cards re-read the
    /// ledger (defaults are not observable).
    @State private var starsVersion = 0
    @AppStorage(KidsMode.ageKey) private var storedAge = KidsMode.defaultAge
    @Environment(\.locale) private var locale

    private var age: Int { KidsMode.clampAge(storedAge) }
    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    private var visibleSurahs: [Surah] {
        let allowed = Set(KidsMode.surahIds(age: age))
        return surahs.filter { allowed.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if path.isEmpty { header }
            TabView(selection: $tab) {
                readTab
                    .tabItem { Label("Read", systemImage: "book") }
                    .tag(Tab.read)
                NavigationStack {
                    KidsAthkarView()
                }
                .tabItem { Label("My athkar", systemImage: "sparkles") }
                .tag(Tab.athkar)
            }
            .tint(NoorColor.accentPrimary)
        }
        .background(NoorColor.bgPrimary)
        .onAppear {
            surahs = (try? database.allSurahs()) ?? []
            // Screenshot/UI-test hooks, same family as NOOR_TAB / NOOR_OPEN.
            if ProcessInfo.processInfo.environment["NOOR_KIDS_TAB"] == "athkar" {
                tab = .athkar
            }
            let env = ProcessInfo.processInfo.environment
            // NOOR_KIDS_OPEN=<surahId> pushes the reader; NOOR_KIDS_PLAY
            // pushes it and starts the recitation.
            if let surahId = (env["NOOR_KIDS_OPEN"] ?? env["NOOR_KIDS_PLAY"])
                .flatMap(Int.init), path.isEmpty {
                path = [KidsReaderRoute(surahId: surahId,
                                        autoplay: env["NOOR_KIDS_PLAY"] != nil)]
            }
        }
        .sheet(isPresented: $showGate) {
            ParentalGateView(
                onSuccess: {
                    showGate = false
                    player.stop()
                    exitKids()
                },
                onCancel: { showGate = false })
                .environment(\.locale, locale)
                .environment(\.layoutDirection, isArabicUI ? .rightToLeft : .leftToRight)
        }
        // The child's own controls (language, listen/memorise, reciter) —
        // never behind the gate.
        .sheet(isPresented: $showKidsSettings) {
            KidsSettingsSheet(age: age, onDone: { showKidsSettings = false })
                .environment(\.locale, locale)
                .environment(\.layoutDirection, isArabicUI ? .rightToLeft : .leftToRight)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                EightPointStar()
                    .fill(NoorColor.accentGold)
                    .frame(width: 22, height: 22)
                Text(verbatim: isArabicUI
                     ? KidsMode.totalStars().arabicIndic
                     : String(KidsMode.totalStars()))
                    .font(.noorScaled(22, weight: .semibold))
                    .foregroundStyle(NoorColor.inkPrimary)
                Text("Your stars")
                    .font(NoorFont.caption)
                    .foregroundStyle(NoorColor.inkSecondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Your stars"))
            .accessibilityValue(Text(verbatim: String(KidsMode.totalStars())))
            .id(starsVersion)

            Spacer()

            Button {
                showKidsSettings = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Settings")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(NoorColor.accentGold)
                .padding(.horizontal, 14)
                .frame(minHeight: NoorMetrics.minTapTarget)
                .background(Capsule().fill(NoorColor.accentGold.opacity(0.14)))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Settings"))

            Button {
                showGate = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "lock")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Grown-ups")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(NoorColor.accentPrimary)
                .padding(.horizontal, 14)
                .frame(minHeight: NoorMetrics.minTapTarget)
                .background(Capsule().fill(NoorColor.accentPrimary.opacity(0.12)))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Grown-ups"))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(NoorColor.bgPrimary)
    }

    // MARK: Read tab

    private var readTab: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(visibleSurahs) { surah in
                        KidsSurahCard(
                            surah: surah,
                            stars: KidsMode.stars(surahId: surah.id),
                            isArabicUI: isArabicUI,
                            onOpen: { path.append(KidsReaderRoute(surahId: surah.id, autoplay: false)) },
                            onPlay: { path.append(KidsReaderRoute(surahId: surah.id, autoplay: true)) })
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .id(starsVersion)
            }
            .scrollContentBackground(.hidden)
            .background(NoorColor.bgPrimary)
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .navigationDestination(for: KidsReaderRoute.self) { route in
                KidsReaderView(
                    database: database,
                    surahId: route.surahId,
                    autoplay: route.autoplay,
                    age: age,
                    player: player,
                    onStarEarned: { starsVersion += 1 })
            }
        }
    }
}

/// A pushed kids reader: which surah, and whether to start reciting at once.
struct KidsReaderRoute: Hashable {
    let surahId: Int
    let autoplay: Bool
}

// MARK: - Surah card

/// One big, calm surah card: number, Arabic name, ayah count, stars, and a
/// play button large enough for small fingers.
struct KidsSurahCard: View {
    let surah: Surah
    let stars: Int
    let isArabicUI: Bool
    let onOpen: () -> Void
    let onPlay: () -> Void
    /// `String(localized:)` follows the PROCESS language; the app switches
    /// language through the environment, so every lookup must be given the
    /// environment locale explicitly (CLAUDE.md / RootView).
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 14) {
            SurahNumberBadge(surah.id)

            // Centred so the card reads the same in both directions: the
            // Arabic name is the child's anchor, the meta line sits under it.
            VStack(spacing: 6) {
                Text(surah.nameArabic)
                    .font(NoorFont.quran(size: 30))
                    .foregroundStyle(NoorColor.inkPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .arabicBlock(alignment: .center)
                HStack(spacing: 10) {
                    if !isArabicUI {
                        Text(verbatim: surah.nameTransliterated)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(NoorColor.inkSecondary)
                    }
                    // Arabic-Indic numerals in the Arabic UI, as everywhere
                    // else in the app (SurahRow does the same).
                    Text(verbatim: isArabicUI
                         ? "\(surah.ayahCount.arabicIndic) آية"
                         : String(localized: "\(surah.ayahCount) ayat", locale: locale))
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.inkSecondary)
                    StarRow(earned: stars, size: 16)
                }
            }
            .frame(maxWidth: .infinity)

            Button(action: onPlay) {
                ZStack {
                    Circle()
                        .fill(NoorColor.accentPrimary)
                        .frame(width: 52, height: 52)
                    Image(systemName: "play.fill")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(NoorColor.bgPrimary)
                }
                .frame(width: 60, height: 60)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Play surah"))
        }
        .padding(16)
        .noorCard()
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: isArabicUI ? surah.nameArabic : surah.nameTransliterated))
        .accessibilityValue(Text("\(stars) of \(KidsMode.maxStars) stars"))
    }
}

#Preview("Kids card — EN") {
    if let db = try? QuranDatabase(), let surahs = try? db.allSurahs() {
        VStack(spacing: 14) {
            ForEach(surahs.filter { [1, 112, 114].contains($0.id) }) { surah in
                KidsSurahCard(surah: surah, stars: surah.id % 4, isArabicUI: false,
                              onOpen: {}, onPlay: {})
            }
        }
        .padding()
        .background(NoorColor.bgPrimary)
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.layoutDirection, .leftToRight)
    }
}

#Preview("Kids card — AR RTL") {
    if let db = try? QuranDatabase(), let surahs = try? db.allSurahs() {
        VStack(spacing: 14) {
            ForEach(surahs.filter { [1, 112, 114].contains($0.id) }) { surah in
                KidsSurahCard(surah: surah, stars: surah.id % 4, isArabicUI: true,
                              onOpen: {}, onPlay: {})
            }
        }
        .padding()
        .background(NoorColor.bgPrimary)
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
    }
}
