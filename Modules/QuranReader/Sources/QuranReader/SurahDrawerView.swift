import ContentDB
import DesignSystem
import SwiftUI

/// Reader side drawer: the full surah index, reachable without leaving the
/// reader. Mirrors the Android `SurahDrawer`. It slides in from the START
/// edge of the INTERFACE (right in the Arabic UI, left in English) over a
/// scrim, opens scrolled to the surah being read, and carries the explicit
/// way out of the reader ("الرجوع إلى القرآن") — the reader chrome's back
/// button is now the list button, so this row and the interactive
/// swipe-back are the exits.
///
/// IMPORTANT: the edge is derived from `isArabicUI`, never from the ambient
/// layout direction. `SurahReaderView.body` forces `.rightToLeft` on the
/// reading content, so the ambient direction is RTL in BOTH languages and
/// would put the drawer on the wrong side in English. Placement here is
/// therefore done in an explicitly left-to-right container (physical
/// coordinates), while the drawer's own content runs in the UI direction.
struct SurahDrawerView: View {
    let surahs: [Surah]
    let currentSurahId: Int
    /// Interface language — the ONLY source of the drawer's edge.
    let isArabicUI: Bool
    let onPick: (Surah) -> Void
    let onClose: () -> Void
    let onExitReader: () -> Void

    /// Screenshot/UI-test hook, twin of the index's NOOR_SEARCH: opens the
    /// drawer with the field already filled.
    @State private var query = ProcessInfo.processInfo.environment["NOOR_DRAWER_QUERY"] ?? ""
    @Environment(\.locale) private var locale

    private var uiDirection: LayoutDirection { isArabicUI ? .rightToLeft : .leftToRight }

    /// Same matcher as the Quran tab index: Arabic name, transliteration,
    /// English meaning or number (`SurahSearch`).
    private var filtered: [Surah] {
        SurahSearch.matches(surahs, query: query.trimmingCharacters(in: .whitespaces))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { onClose() }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(Text("Close"))
                    .accessibilityAction { onClose() }
                // Physical placement: leading == left, trailing == right,
                // whatever the reader forced on the content behind us.
                HStack(spacing: 0) {
                    if isArabicUI { Spacer(minLength: 0) }
                    panel(width: min(320, geometry.size.width * 0.86))
                        .transition(.move(edge: isArabicUI ? .trailing : .leading))
                    if !isArabicUI { Spacer(minLength: 0) }
                }
                .environment(\.layoutDirection, .leftToRight)
            }
        }
    }

    private func panel(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            exitRow
            Divider().overlay(NoorColor.inkPrimary.opacity(0.08))
            searchField
            list
        }
        .frame(width: width)
        .background(
            NoorColor.bgPrimary
                .ignoresSafeArea(edges: .vertical)
                .shadow(color: .black.opacity(0.18), radius: 14)
        )
        .environment(\.layoutDirection, uiDirection)
        .environment(\.locale, locale)
    }

    /// The explicit exit. On iOS this is the primary way out: the reader
    /// hides both bars and the chevron is gone, so it must never be subtle.
    private var exitRow: some View {
        Button {
            onExitReader()
        } label: {
            HStack(spacing: 10) {
                // Auto-mirroring symbol: points right in Arabic, left in English.
                Image(systemName: "chevron.backward")
                    .font(.system(size: 14, weight: .semibold))
                Text("Back to Quran")
                    .font(.noorScaled(15, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(NoorColor.accentPrimary)
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Back to Quran"))
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(NoorColor.inkSecondary)
            // Custom placeholder: the system one anchors to the process
            // language and ignores the RTL environment.
            TextField("", text: $query)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) {
                    if query.isEmpty {
                        Text("Search surah")
                            .font(.noorScaled(14))
                            .foregroundStyle(NoorColor.inkSecondary.opacity(0.8))
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityLabel(Text("Search surah"))
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(NoorColor.inkSecondary)
                        .frame(width: 44, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear search"))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(RoundedRectangle(cornerRadius: 12).fill(NoorColor.bgElevated))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(NoorColor.inkPrimary.opacity(0.08), lineWidth: 1))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered) { surah in
                        Button {
                            onPick(surah)
                        } label: {
                            SurahDrawerRow(surah: surah,
                                           isCurrent: surah.id == currentSurahId,
                                           isArabicUI: isArabicUI)
                        }
                        .buttonStyle(.plain)
                        .id(surah.id)
                        Divider().overlay(NoorColor.inkPrimary.opacity(0.05))
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            // Open already scrolled to the surah being read. This runs one
            // tick late on purpose: the LazyVStack has materialised nothing
            // on the first layout pass, so a scroll issued from `onAppear`
            // lands on no row at all and the list stays at surah 1.
            .task {
                try? await Task.sleep(for: .milliseconds(60))
                proxy.scrollTo(query.isEmpty ? currentSurahId : filtered.first?.id ?? 1,
                               anchor: query.isEmpty ? .center : .top)
            }
            // Filtering keeps the old scroll offset, which can leave the
            // best match off screen — every query starts at the top.
            .onChange(of: query) {
                if let first = filtered.first { proxy.scrollTo(first.id, anchor: .top) }
            }
        }
    }
}

/// One drawer row — the Quran index's visual language (diamond number,
/// Arabic name, ayah count · Makki/Madani), with the surah being read
/// highlighted.
private struct SurahDrawerRow: View {
    let surah: Surah
    let isCurrent: Bool
    let isArabicUI: Bool
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 12) {
            SurahNumberBadge(surah.id)
            VStack(alignment: .leading, spacing: 2) {
                if isArabicUI {
                    Text(verbatim: surah.nameArabic)
                        .font(NoorFont.quran(size: 18))
                        .foregroundStyle(isCurrent ? NoorColor.accentPrimary : NoorColor.inkPrimary)
                    Text(verbatim: "\(surah.ayahCount.arabicIndic) آية · \(surah.isMeccan ? "مكية" : "مدنية")")
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.inkSecondary)
                } else {
                    Text(verbatim: surah.nameTransliterated)
                        .font(.noorScaled(15, weight: isCurrent ? .bold : .semibold))
                        .foregroundStyle(isCurrent ? NoorColor.accentPrimary : NoorColor.inkPrimary)
                    Text("\(surah.nameEnglish) · \(surah.ayahCount) ayat · \(surah.isMeccan ? String(localized: "Makki", locale: locale) : String(localized: "Madani", locale: locale))")
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.inkSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if !isArabicUI {
                Text(verbatim: surah.nameArabic)
                    .font(NoorFont.quran(size: 17))
                    .foregroundStyle(isCurrent ? NoorColor.accentPrimary : NoorColor.inkPrimary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 44)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isCurrent ? NoorColor.accentPrimary.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(surah.id), \(surah.nameTransliterated), \(surah.ayahCount) ayat")
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }
}

/// The reader chrome's list button (replaces the old back chevron): opens
/// the surah drawer. A bare glyph on the page background — no filled chip —
/// with a 44pt target.
struct SurahListButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "list.bullet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(NoorColor.accentPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Surah list"))
    }
}

#Preview("Drawer — AR RTL (right edge)") {
    if let db = try? QuranDatabase(), let surahs = try? db.allSurahs() {
        ZStack {
            NoorColor.bgPrimary
            SurahDrawerView(surahs: surahs, currentSurahId: 18, isArabicUI: true,
                            onPick: { _ in }, onClose: {}, onExitReader: {})
        }
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
    }
}

#Preview("Drawer — EN LTR (left edge)") {
    if let db = try? QuranDatabase(), let surahs = try? db.allSurahs() {
        ZStack {
            NoorColor.bgPrimary
            SurahDrawerView(surahs: surahs, currentSurahId: 18, isArabicUI: false,
                            onPick: { _ in }, onClose: {}, onExitReader: {})
        }
        .environment(\.locale, Locale(identifier: "en"))
        // The reader forces RTL on its content; the drawer must ignore it.
        .environment(\.layoutDirection, .rightToLeft)
    }
}
