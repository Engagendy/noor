import ContentDB
import DesignSystem
import QuranAudio
import QuranReader
import SwiftUI

/// The kids reader: one surah, ayah by ayah, scaled to the age band, with
/// a single big play/pause control and a clear repetition indicator.
///
/// Deliberately missing (and unreachable): share, video share, bookmark,
/// tafsir, copy, long-press actions, page numbers, juz labels, go-to-page.
/// The ayah actions sheet is never constructed here.
struct KidsReaderView: View {
    let database: QuranDatabase
    let surahId: Int
    let autoplay: Bool
    let age: Int
    let player: QuranAudioPlayer
    /// Fired after a star is written so the shell refreshes its header.
    let onStarEarned: () -> Void

    @State private var surah: Surah?
    @State private var verses: [Verse] = []
    /// Basmala straight from the DB (surah 1 ayah 1) — never a literal.
    @State private var basmala: String?
    @State private var useFlowLayout = false
    @State private var sawLastAyah = false
    @State private var celebrate = false
    @AppStorage("reader.fontSize") private var baseFontSize = 26.0
    /// Listen (straight through) vs memorise (age-band repeats) — the
    /// child's own choice from the shell's Sound sheet.
    @AppStorage(KidsMode.listenModeKey) private var listenMode = false
    @Environment(\.locale) private var locale

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }
    private var repeatCount: Int { KidsMode.repeatCount(age: age, listenMode: listenMode) }
    private var showsRepeatIndicator: Bool {
        KidsMode.showsRepeatIndicator(age: age, listenMode: listenMode)
    }
    /// Age-scaled Quran text size, kept inside a sane drawing range.
    private var fontSize: CGFloat {
        min(max(baseFontSize * KidsMode.textScale(age: age), 20), 56)
    }
    private var isThisSurah: Bool { player.current?.surah == surahId }
    private var currentAyah: Int? { isThisSurah ? player.current?.ayah : nil }

    var body: some View {
        VStack(spacing: 0) {
            ayahScroll
            controls
        }
        .background(NoorColor.bgPrimary)
        .navigationTitle(Text(verbatim: isArabicUI
                              ? (surah?.nameArabic ?? "")
                              : (surah?.nameTransliterated ?? "")))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        #endif
        .task {
            load()
            if autoplay, !verses.isEmpty { start() }
        }
        .onDisappear {
            if isThisSurah { player.stop() }
        }
        .onChange(of: player.current) { _, _ in checkCompletion() }
        .overlay {
            if celebrate { celebration }
        }
    }

    // MARK: Content

    private var ayahScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if useFlowLayout {
                    flowText
                } else {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if let basmala, surahId != 1 {
                            Text(basmala)
                                .font(NoorFont.quran(size: fontSize * 0.9))
                                .foregroundStyle(NoorColor.accentPrimary)
                                .arabicBlock(alignment: .center)
                                .padding(.bottom, 10)
                        }
                        ForEach(verses) { verse in
                            ayahCard(verse).id("k\(verse.ayah)")
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 18)
                }
            }
            .onChange(of: currentAyah) { _, ayah in
                guard let ayah, !useFlowLayout else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo("k\(ayah)", anchor: .center)
                }
            }
        }
    }

    /// Flowing layout — offered only to the oldest band (10–12).
    private var flowText: some View {
        let joined = verses.reduce(Text(verbatim: "")) { partial, verse in
            partial
                + Text(displayText(verse))
                + Text(verbatim: "  \u{2067}﴿\(verse.ayah.arabicIndic)﴾\u{2069}  ")
                    .foregroundStyle(NoorColor.accentGold)
        }
        return VStack(spacing: 14) {
            if let basmala, surahId != 1 {
                Text(basmala)
                    .font(NoorFont.quran(size: fontSize * 0.9))
                    .foregroundStyle(NoorColor.accentPrimary)
                    .arabicBlock(alignment: .center)
            }
            joined
                .font(NoorFont.quran(size: fontSize))
                .foregroundStyle(NoorColor.inkPrimary)
                .lineSpacing(fontSize * NoorMetrics.quranLineSpacingFactor)
                .arabicBlock()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 18)
    }

    private func ayahCard(_ verse: Verse) -> some View {
        let isReciting = currentAyah == verse.ayah
        return VStack(alignment: .leading, spacing: 8) {
            (Text(displayText(verse))
                + Text(verbatim: "  \u{2067}﴿\(verse.ayah.arabicIndic)﴾\u{2069}")
                    .font(NoorFont.quran(size: fontSize * 0.6))
                    .foregroundStyle(NoorColor.accentGold))
                .font(NoorFont.quran(size: fontSize))
                .foregroundStyle(isReciting ? NoorColor.accentPrimary : NoorColor.inkPrimary)
                .lineSpacing(fontSize * NoorMetrics.quranLineSpacingFactor)
                .arabicBlock()
            if isReciting, showsRepeatIndicator {
                repetitionDots
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isReciting ? NoorColor.stateReciting : Color.clear)
        )
        .animation(.easeInOut(duration: 0.25), value: isReciting)
        // No tap, no long press: the ayah actions sheet must be unreachable.
        .accessibilityElement(children: .combine)
    }

    /// Which repetition of the current ayah is playing, as dots + words.
    private var repetitionDots: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                ForEach(1...max(repeatCount, 1), id: \.self) { index in
                    Circle()
                        .fill(index <= player.memorizeRepeat
                              ? NoorColor.accentPrimary
                              : NoorColor.accentPrimary.opacity(0.22))
                        .frame(width: 9, height: 9)
                }
            }
            Text("Repetition \(player.memorizeRepeat) of \(repeatCount)")
                .font(NoorFont.caption)
                .foregroundStyle(NoorColor.inkSecondary)
        }
        .environment(\.layoutDirection, .leftToRight)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Repetition \(player.memorizeRepeat) of \(repeatCount)"))
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 10) {
            if KidsMode.allowsFlowLayout(age: age) {
                Picker(selection: $useFlowLayout) {
                    Text("Ayah by ayah").tag(false)
                    Text("Flowing text").tag(true)
                } label: {
                    Text("Reading mode")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
                .accessibilityLabel(Text("Reading mode"))
            }
            Button {
                if isThisSurah {
                    player.togglePlayPause()
                } else {
                    start()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isThisSurah && player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .bold))
                    (isThisSurah && player.isPlaying ? Text("Pause") : Text("Play"))
                        .font(.system(size: 19, weight: .semibold))
                }
                .foregroundStyle(NoorColor.bgPrimary)
                .padding(.horizontal, 34)
                .frame(minHeight: 60)
                .background(Capsule().fill(NoorColor.accentPrimary))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isThisSurah && player.isPlaying ? Text("Pause") : Text("Play surah"))
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(NoorColor.bgPrimary)
    }

    private var celebration: some View {
        VStack(spacing: 18) {
            StarRow(earned: KidsMode.stars(surahId: surahId), size: 44)
            Text("Well done!")
                .font(NoorFont.screenTitle)
                .foregroundStyle(NoorColor.inkPrimary)
        }
        .padding(36)
        .background(RoundedRectangle(cornerRadius: 26).fill(NoorColor.bgElevated))
        .shadow(color: NoorColor.inkPrimary.opacity(0.12), radius: 24)
        .transition(.scale.combined(with: .opacity))
        .allowsHitTesting(false)
    }

    // MARK: Logic

    private func load() {
        surah = (try? database.allSurahs())?.first { $0.id == surahId }
        verses = (try? database.verses(surahId: surahId)) ?? []
        // At-Tawbah has no basmala; Al-Fatiha's ayah 1 IS the basmala.
        basmala = surahId == 9 ? nil : (try? database.verses(surahId: 1))?.first?.text
    }

    /// The stored ayah-1 text carries the basmala for 111 surahs and this
    /// view draws its own line — strip the leading copy FOR DISPLAY only
    /// (see BasmalaPrefix; the DB is never modified).
    private func displayText(_ verse: Verse) -> String {
        guard verse.ayah == 1, surahId != 1, let basmala else { return verse.text }
        return BasmalaPrefix.strippingLeadingBasmala(from: verse.text, basmala: basmala)
    }

    private func start() {
        guard !verses.isEmpty, let surah else { return }
        sawLastAyah = false
        if repeatCount > 1 {
            // Memorize mode gives us "each ayah N times, in order" for
            // free; it wraps back to ayah 1 at the end, which is one of
            // the two completion signals handled below.
            player.mode = .memorize
            player.play(surah: surahId, ayahCount: verses.count, from: 1,
                        title: surah.nameTransliterated, arabicTitle: surah.nameArabic)
            player.startMemorize(start: 1, end: verses.count, perAyah: repeatCount)
        } else {
            // Listening: each ayah once, gaplessly, stopping at the end of
            // THIS surah (pageOnly bounded by the last ayah) — kids mode
            // never rolls on into the next surah.
            player.mode = .pageOnly
            player.play(surah: surahId, ayahCount: verses.count, from: 1,
                        title: surah.nameTransliterated, arabicTitle: surah.nameArabic,
                        pageEndAyah: verses.count)
        }
    }

    /// A surah played to completion earns one star (three max).
    ///
    /// Two completion signals, one per playback mode: memorize wraps back
    /// to ayah 1 (and sets `current` there before any audio for it loads,
    /// so stopping is silent), while pageOnly simply stops at the last
    /// ayah and clears `current`.
    private func checkCompletion() {
        guard verses.count > 1 else { return }
        if let reference = player.current, reference.surah == surahId,
           reference.ayah == verses.count {
            sawLastAyah = true
            return
        }
        guard sawLastAyah else { return }
        let wrapped = player.current.map { $0.surah == surahId && $0.ayah == 1 } ?? false
        guard wrapped || player.current == nil else { return }
        sawLastAyah = false
        if wrapped { player.stop() }
        KidsMode.awardStar(surahId: surahId)
        onStarEarned()
        withAnimation(.spring(duration: 0.4)) { celebrate = true }
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.easeOut(duration: 0.4)) { celebrate = false }
        }
    }
}

#Preview("Kids reader — EN LTR") {
    if let db = try? QuranDatabase() {
        NavigationStack {
            KidsReaderView(database: db, surahId: 112, autoplay: false, age: 5,
                           player: QuranAudioPlayer(), onStarEarned: {})
        }
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.layoutDirection, .leftToRight)
    }
}

#Preview("Kids reader — AR RTL") {
    if let db = try? QuranDatabase() {
        NavigationStack {
            KidsReaderView(database: db, surahId: 112, autoplay: false, age: 11,
                           player: QuranAudioPlayer(), onStarEarned: {})
        }
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
    }
}
