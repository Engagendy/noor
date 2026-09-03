import ContentDB
import DesignSystem
import CoreText
import SwiftUI

/// Pixel-faithful Madani page: the page's QCF v1 font renders each line's
/// glyphs exactly as printed in the mushaf.
struct MadaniPageView: View {
    let page: Int
    let layout: PageLayoutDatabase?
    let fontStore: PageFontStore
    /// Arabic surah name for injected header lines.
    var surahName: (Int) -> String = { _ in "" }
    /// Basmala text (from the verified DB) for injected basmala lines.
    var basmala: String?
    /// surah*1000+ayah to softly highlight (arrival from search/bookmarks).
    var highlightKey: Int?
    /// Plain tap on the page (chrome toggle / close panels).
    var onTap: (() -> Void)?
    /// Long-pressing a line reports exactly the ayat on that line.
    var onLongPressLine: (([PageLine.Ref]) -> Void)?

    /// VoiceOver: which ayat this printed line carries (the QCF glyph
    /// codes themselves are not readable text).
    private func lineLabel(_ line: PageLine) -> String {
        guard let first = line.ayahRefs.first else { return "" }
        let last = line.ayahRefs.last ?? first
        return first.ayah == last.ayah
            ? String(localized: "Ayah \(first.ayah)")
            : String(localized: "Ayahs \(first.ayah) to \(last.ayah)")
    }

    /// One printed line, justified edge to edge like the Madani print.
    ///
    /// Drawing the line as a single run renders it at the font's natural
    /// advance, so a line that happens to be narrower than the column floats
    /// short and centered (visible from page 354 onward). Instead each word is
    /// placed by us and the slack is shared between the gaps — the same
    /// algorithm the Android reader uses, so both platforms match the print.
    /// Short closing lines stay centered rather than being stretched apart.
    @ViewBuilder
    private func justifiedLine(_ line: PageLine, fontSize: CGFloat, width: CGFloat) -> some View {
        let fontName = PageFontStore.fontName(page: page)
        let words = lineWords(line)
        let total = GlyphMetrics.total(words, page: page, size: fontSize)
        if total <= 0 {
            // Could not measure: fall back to the single run, which SwiftUI
            // shrinks to fit. Unjustified but never overflowing.
            Text(verbatim: "\u{2067}" + lineGlyphs(line) + "\u{2069}")
                .font(.custom(fontName, size: fontSize))
                .foregroundStyle(NoorColor.inkPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        } else {
            let target = width * 0.97
            // Overflow shrinks the line; it must never clip.
            let scale = total > target ? target / total : 1
            let justify = total * scale >= width * 0.55
            let slack = max(target - total * scale, 0)
            let gap = justify && words.count > 1 ? slack / CGFloat(words.count - 1) : 0
            HStack(spacing: 0) {
                ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                    if index > 0 && gap > 0 {
                        Spacer().frame(width: gap)
                    }
                    Text(verbatim: word)
                        .font(.custom(fontName, size: fontSize * scale))
                        .foregroundStyle(NoorColor.inkPrimary)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            // Words arrive in reading order, so the first must sit at the
            // right edge whatever the interface language.
            .environment(\.layoutDirection, .rightToLeft)
        }
    }

    /// v1 fonts consume the v1 codes; v2 fonts the v2 codes — always from
    /// the SAME observed variant the font name uses, never mixed.
    private func lineGlyphs(_ line: PageLine) -> String {
        if fontVariant == "v1" { return line.glyphs }
        return line.glyphsV2.isEmpty ? line.glyphs : line.glyphsV2
    }

    /// The per-word split of `lineGlyphs`, under the very same variant rule.
    /// Falls back to the whole line as one word so a page can never blank out.
    private func lineWords(_ line: PageLine) -> [String] {
        if fontVariant == "v1" {
            return line.words.isEmpty ? [line.glyphs] : line.words
        }
        if line.glyphsV2.isEmpty {
            return line.words.isEmpty ? [line.glyphs] : line.words
        }
        return line.wordsV2.isEmpty ? [line.glyphsV2] : line.wordsV2
    }

    private func isHighlighted(_ line: PageLine) -> Bool {
        guard let highlightKey else { return false }
        return line.ayahRefs.contains {
            $0.surahId * 1000 + $0.ayah == highlightKey
        }
    }

    @State private var lines: [PageLine] = []
    /// Read from the observable store (not @State copies) so the page
    /// re-renders the moment a download finished by a neighbour's prefetch
    /// lands, instead of sticking on the spinner.
    private var fontReady: Bool { fontStore.readyPages.contains(page) }
    private var fontFailed: Bool { fontStore.failedPages.contains(page) }
    /// Bumped to re-run `ensure` after a failed font download (tap or auto
    /// retry) — `.task(id:)` alone only fires on page/variant change.
    @State private var attempt = 0
    /// Quiet automatic re-download attempts before the page settles on the
    /// Retry button.
    private static let autoRetries = 3
    /// Re-registers and re-renders when the mushaf typeface changes.
    @AppStorage("mushaf.font") private var fontVariant = "v2"

    var body: some View {
        GeometryReader { geometry in
            // Every printed line must fit: bound the size by height (15 rows)
            // AND width, so no line is ever clipped or dropped.
            let rowHeight = geometry.size.height / CGFloat(max(lines.count, 15))
            let fontSize = min(geometry.size.width / 9.8, rowHeight * 0.72)
            Group {
                if fontReady && !lines.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(lines) { line in
                            switch line.kind {
                            case .surahHeader:
                                // Name already shown in the top bar — a calm
                                // gold rule marks the surah boundary.
                                Rectangle()
                                    .fill(NoorColor.accentGold.opacity(0.35))
                                    .frame(height: 0.7)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: rowHeight)
                            case .surahHeaderWithBasmala:
                                Text(basmala ?? "")
                                    .font(NoorFont.quran(size: rowHeight * 0.45))
                                    .foregroundStyle(NoorColor.inkPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: rowHeight)
                            case .basmala:
                                Text(basmala ?? "")
                                    .font(NoorFont.quran(size: rowHeight * 0.45))
                                    .foregroundStyle(NoorColor.inkPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: rowHeight)
                            case .words:
                                justifiedLine(line,
                                              fontSize: fontSize,
                                              width: geometry.size.width)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: rowHeight)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isHighlighted(line) ? NoorColor.stateReciting : Color.clear)
                                    )
                                    .contentShape(Rectangle())
                                    .onLongPressGesture { onLongPressLine?(line.ayahRefs) }
                                    .accessibilityLabel(lineLabel(line))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 4)
                    .contentShape(Rectangle())
                    .onTapGesture { onTap?() }
                } else if fontFailed {
                    ContentUnavailableView {
                        Label("Page font unavailable", systemImage: "wifi.slash")
                    } description: {
                        Text("Connect to the internet once to download this page.")
                    } actions: {
                        Button("Retry") { attempt += 1 }
                            .buttonStyle(.borderedProminent)
                    }
                    // A transient network hiccup must not strand the page on
                    // the offline placeholder: retry quietly a few times with
                    // backoff (4s, 8s, 16s), then leave it to the Retry button
                    // so a genuinely offline device stops re-downloading.
                    .task(id: attempt) {
                        guard attempt < Self.autoRetries else { return }
                        try? await Task.sleep(for: .seconds(4 << attempt))
                        guard !Task.isCancelled else { return }
                        attempt += 1
                    }
                } else {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("Preparing page \(page)…")
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.inkSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .foregroundStyle(NoorColor.inkPrimary)
        .task(id: "\(page)-\(fontVariant)-\(attempt)") {
            lines = (try? layout?.lines(page: page)) ?? []
            await fontStore.ensure(page: page)
            // Prefetch neighbors for smooth swiping.
            await fontStore.ensure(page: page + 1)
            await fontStore.ensure(page: page - 1)
        }
        .accessibilityLabel("Page \(page)")
    }

}

/// Word advances, measured once per line/size and kept.
///
/// The reader re-renders on every animation frame (page turns, the recitation
/// highlight), and measuring every word with CoreText each frame would show.
@MainActor
private enum GlyphMetrics {
    private static var cache: [String: CGFloat] = [:]

    /// Total advance of a line's words, or 0 when the page font is not
    /// available yet — never a system-font substitute's width, which would be
    /// a fraction of the truth and defeat the whole point of measuring.
    static func total(_ words: [String], page: Int, size: CGFloat) -> CGFloat {
        let key = "\(page)|\(Int(size * 10))|\(words.count)|\(words.first ?? "")"
        if let hit = cache[key] { return hit }
        guard let font = PageFontStore.measurementFont(page: page, size: size) else { return 0 }
        let attributes = [kCTFontAttributeName as NSAttributedString.Key: font]
        let measured = words.reduce(CGFloat.zero) { running, word in
            let line = CTLineCreateWithAttributedString(
                NSAttributedString(string: word, attributes: attributes))
            return running + CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        }
        // Only a real measurement is worth keeping.
        if measured > 0 { cache[key] = measured }
        return measured
    }
}
