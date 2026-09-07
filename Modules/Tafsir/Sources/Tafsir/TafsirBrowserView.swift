import ContentDB
import DesignSystem
import SwiftUI

/// Browse tafsir by surah, from the Learn hub — until now tafsir was
/// reachable only by tapping a single ayah in the reader, which is no way to
/// read a surah through.
///
/// It adds NO network path and NO cache of its own: everything goes through
/// `TafsirService.loadSurah`, which reads the same per-ayah cache the ayah
/// sheet fills and, when a surah is missing, fetches the same per-surah CDN
/// bundle the offline pack download already uses.
public struct TafsirBrowserView: View {
    /// `nil` — the tafsir browser: the edition is the user's, chosen here and
    /// remembered in the same `tafsir.edition` default the ayah sheet uses.
    /// Non-nil — a single-purpose entry (the hub's word meanings), which
    /// never shows a picker and never touches that default.
    private let fixedEdition: TafsirEdition?

    public init(edition: TafsirEdition? = nil) {
        self.fixedEdition = edition
    }

    @AppStorage("tafsir.edition") private var editionSlug = TafsirEdition.all[0].slug
    @Environment(\.locale) private var locale
    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    @State private var surahs: [Surah] = []

    private var edition: TafsirEdition { fixedEdition ?? TafsirEdition.named(editionSlug) }

    public var body: some View {
        List {
            if fixedEdition == nil {
                Section {
                    Picker(selection: $editionSlug) {
                        ForEach(TafsirEdition.all) { candidate in
                            Text(verbatim: candidate.displayName).tag(candidate.slug)
                        }
                    } label: {
                        Text("Tafsir edition")
                    }
                    .listRowBackground(Color.clear)
                } footer: {
                    Text("Your choice is remembered, and is the same one the ayah sheet uses.")
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.inkSecondary)
                }
            }

            Section {
                ForEach(surahs) { surah in
                    NavigationLink(value: TafsirSurahRoute(surahId: surah.id, slug: edition.slug)) {
                        surahRow(surah)
                    }
                    .listRowBackground(Color.clear)
                }
            } header: {
                Text("Choose a surah").foregroundStyle(NoorColor.inkSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(NoorColor.bgPrimary)
        .navigationTitle(fixedEdition == nil ? Text("Tafsir") : Text("Quranic word meanings"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(for: TafsirSurahRoute.self) { route in
            // The screen looks its own surah up rather than reading this
            // view's `surahs`: a deep link can push the route before the
            // list has loaded, and that rendered a blank screen.
            TafsirSurahView(surahId: route.surahId, edition: TafsirEdition.named(route.slug),
                            isWordMeanings: fixedEdition != nil)
        }
        .onAppear {
            if surahs.isEmpty {
                surahs = (try? QuranDatabase().allSurahs()) ?? []
            }
        }
    }

    private func surahRow(_ surah: Surah) -> some View {
        HStack(spacing: 12) {
            Text(verbatim: isArabicUI ? surah.id.arabicIndic : "\(surah.id)")
                .font(NoorFont.caption.monospacedDigit())
                .foregroundStyle(NoorColor.accentGold)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: surah.displayName(arabicUI: isArabicUI))
                    .font(.noorScaled(16, weight: .semibold))
                    .foregroundStyle(NoorColor.inkPrimary)
                if isArabicUI {
                    Text(verbatim: "\(surah.ayahCount.arabicIndic) آية")
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.inkSecondary)
                } else {
                    Text("\(surah.ayahCount) ayat")
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.inkSecondary)
                }
            }
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

/// Pushed destination inside the browser. It carries the edition slug so the
/// open surah keeps the edition it was opened with even if the picker moves.
public struct TafsirSurahRoute: Hashable, Sendable {
    let surahId: Int
    let slug: String

    /// Public so a host can deep-link straight into one surah (the
    /// screenshot hook does; a "tafsir of this surah" link could later).
    public init(surahId: Int, slug: String) {
        self.surahId = surahId
        self.slug = slug
    }
}

/// One surah's tafsir, ayah after ayah, as a continuous screen.
struct TafsirSurahView: View {
    let surahId: Int
    let edition: TafsirEdition
    /// Word-meaning editions gloss only the ayat that need it, so their gaps
    /// are expected and the screen says so instead of looking broken.
    let isWordMeanings: Bool

    @Environment(\.locale) private var locale
    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    @State private var service = TafsirService()
    @State private var surah: Surah?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                switch service.surahState {
                case .idle:
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                case .downloading:
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("Downloading this surah's tafsir…")
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.inkSecondary)
                        Text("It is kept on the device, so this surah opens offline next time.")
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.inkSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                case .ready(let entries) where entries.isEmpty:
                    ContentUnavailableView {
                        Label("Tafsir", systemImage: "text.book.closed")
                    } description: {
                        Text("This edition has nothing for this surah.")
                    }
                    .padding(.top, 30)
                case .ready(let entries):
                    if isWordMeanings {
                        Text("Only the ayat with words worth glossing appear here.")
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.inkSecondary)
                    }
                    LazyVStack(alignment: .leading, spacing: 22) {
                        ForEach(entries) { entry in
                            entryView(entry)
                        }
                    }
                    footer(count: entries.count)
                case .failed(let message):
                    ContentUnavailableView {
                        Label("Tafsir unavailable", systemImage: "wifi.slash")
                    } description: {
                        Text("Check your connection and try again. (\(message))")
                    }
                    .padding(.top, 30)
                }
            }
            .padding(20)
            // Clears the floating tab bar the Quran tab draws over the page.
            .padding(.bottom, 80)
        }
        .background(NoorColor.bgPrimary)
        .navigationTitle(Text(verbatim: surah?.displayName(arabicUI: isArabicUI) ?? ""))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            if surah == nil {
                surah = (try? QuranDatabase().allSurahs())?.first { $0.id == surahId }
            }
        }
        .task(id: edition.slug) {
            await service.loadSurah(edition: edition, surah: surahId)
        }
    }

    private func entryView(_ entry: TafsirService.Entry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AyahEndMarker(entry.ayah, size: 26)
                Text(verbatim: "\(surahId):\(entry.ayah)")
                    .font(NoorFont.caption.monospacedDigit())
                    .foregroundStyle(NoorColor.inkSecondary)
            }
            // `.leading` only: it is already direction-aware, so
            // `isArabicUI ? .trailing : .leading` would flip twice and strand
            // Arabic against the left edge (the lesson from the matn reader).
            .frame(maxWidth: .infinity, alignment: .leading)

            // One Text per paragraph: a single multi-thousand-character
            // Arabic string hits a SwiftUI layout path that drops shaping
            // and bidi (seen with Ibn Kathir 3:7).
            ForEach(Array(paragraphs(of: entry.text).enumerated()), id: \.offset) { _, paragraph in
                paragraphView(paragraph)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Ayah \(entry.ayah)"))
    }

    /// The deliberate serif of `NoorFont.tafsir` (design §3) in both scripts;
    /// Arabic is an `arabicBlock` so it stays right-anchored even in the
    /// English interface, and is `Text(verbatim:)` — tafsir must never go
    /// through a localisation lookup.
    @ViewBuilder
    private func paragraphView(_ paragraph: String) -> some View {
        if edition.isArabic {
            Text(verbatim: paragraph)
                .font(NoorFont.tafsir)
                .foregroundStyle(NoorColor.inkPrimary)
                .lineSpacing(9)
                .textSelection(.enabled)
                .arabicBlock()
        } else {
            Text(verbatim: paragraph)
                .font(NoorFont.tafsir)
                .foregroundStyle(NoorColor.inkPrimary)
                .lineSpacing(6)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    private func paragraphs(of text: String) -> [String] {
        let parts = text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? [text] : parts
    }

    @ViewBuilder
    private func footer(count: Int) -> some View {
        VStack(spacing: 4) {
            Label("Available offline", systemImage: "checkmark.circle")
                .font(NoorFont.caption)
                .foregroundStyle(NoorColor.accentPrimary)
            if isArabicUI {
                Text(verbatim: "\(edition.displayName) · \(count.arabicIndic)")
            } else {
                Text(verbatim: "\(edition.displayName) · \(count)")
            }
        }
        .font(NoorFont.caption)
        .foregroundStyle(NoorColor.inkSecondary)
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }
}

#Preview("Tafsir browser — AR RTL") {
    NavigationStack { TafsirBrowserView() }
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Word meanings — EN LTR") {
    NavigationStack { TafsirBrowserView(edition: .gharib) }
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.layoutDirection, .leftToRight)
}
