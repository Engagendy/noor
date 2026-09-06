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
    ///
    /// `pageScale` is the ONE scale the whole page prints at (see
    /// `GlyphMetrics.pageScale`). Sizing each line on its own made a surah's
    /// short closing line — which never needs shrinking — tower over the
    /// full-width lines that did (pages 595, 602). In the printed mushaf every
    /// glyph on a page shares one size; only the gaps between words change.
    @ViewBuilder
    private func justifiedLine(_ line: PageLine,
                               fontSize: CGFloat,
                               width: CGFloat,
                               pageScale: CGFloat,
                               pageInk: (top: CGFloat, bottom: CGFloat)) -> some View {
        let fontName = PageFontStore.fontName(page: page)
        let words = lineWords(line)
        let total = GlyphMetrics.total(words, page: page, size: fontSize)
        if total <= 0 {
            // Could not measure: fall back to the single run, which SwiftUI
            // shrinks to fit. Unjustified but never overflowing.
            Text(verbatim: "\u{2067}" + lineGlyphs(line) + "\u{2069}")
                // fixedSize, NOT size: `Font.custom(_:size:)` scales with the
                // user's Dynamic Type setting, so the text drawn is larger
                // than the size measured against and the line overflows. A
                // mushaf page is a fixed 15-row grid already sized to the
                // screen, so it must not scale a second time.
                .font(.custom(fontName, fixedSize: fontSize * pageScale))
                .foregroundStyle(NoorColor.inkPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        } else {
            let target = width * 0.995
            // The page's shared scale already fits every line; the second
            // branch is a float-rounding safety net so a line can never clip.
            let scale = total * pageScale > target ? target / total : pageScale
            let justify = total * scale >= width * 0.55
            let slack = max(target - total * scale, 0)
            let gap = justify && words.count > 1 ? slack / CGFloat(words.count - 1) : 0
            // Drawn as glyph outlines, not Text views: a QCF glyph can reach
            // past its own advance (the final letter of الرحمن on page 1), and
            // both Text and its Compose counterpart clip that overhang.
            // Outlines fill wherever the ink is, and Dynamic Type never
            // enters into it.
            let outlines = GlyphMetrics.outlines(words, page: page, size: fontSize)
            Canvas { context, canvasSize in
                let blockWidth = total * scale + gap * CGFloat(max(words.count - 1, 0))
                var x = (canvasSize.width + blockWidth) / 2           // right edge, RTL
                // Baseline from the page's INK extent, not the font's nominal
                // ascent/descent: QCF marks that ride high (the maddah over
                // ٱلٓمٓ, the superscript marks on the basmala line) reach above
                // the ascent, and a Canvas clips to its own bounds, so they
                // came out sliced flat. Measured page-wide, so every row keeps
                // the same baseline instead of jittering per line.
                let baseline = (canvasSize.height - (pageInk.top + pageInk.bottom) * scale) / 2
                    + pageInk.top * scale
                for word in outlines {
                    x -= word.advance * scale
                    // Font units are y-up; the canvas is y-down.
                    let transform = CGAffineTransform(a: scale, b: 0, c: 0, d: -scale, tx: x, ty: baseline)
                    context.fill(Path(word.path).applying(transform), with: .color(NoorColor.inkPrimary))
                    x -= gap
                }
            }
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

    /// Side margin of the printed page.
    private static let pageMargin: CGFloat = 16

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
            // Breathing room down both sides, like the printed page. Every
            // measurement below works from the remaining width, never the
            // full screen, so justified lines stop at the margin.
            let contentWidth = geometry.size.width - Self.pageMargin * 2
            let rowHeight = geometry.size.height / CGFloat(max(lines.count, 15))
            let fontSize = min(contentWidth / 9.8, rowHeight * 0.72)
            // One glyph size for the whole page, measured once per
            // (page, variant, size, column width) — never per redraw.
            let pageScale = GlyphMetrics.pageScale(lines,
                                                   page: page,
                                                   size: fontSize,
                                                   target: contentWidth * 0.995,
                                                   words: lineWords)
            // How far the page's ink really reaches above and below the
            // baseline — cached alongside the scale, same measurement pass.
            let pageInk = GlyphMetrics.pageInk(lines,
                                               page: page,
                                               size: fontSize,
                                               words: lineWords)
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
                                Text(verbatim: basmala ?? "")
                                    .font(NoorFont.quran(size: rowHeight * 0.45))
                                    .foregroundStyle(NoorColor.inkPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: rowHeight)
                            case .basmala:
                                Text(verbatim: basmala ?? "")
                                    .font(NoorFont.quran(size: rowHeight * 0.45))
                                    .foregroundStyle(NoorColor.inkPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: rowHeight)
                            case .words:
                                justifiedLine(line,
                                              fontSize: fontSize,
                                              width: contentWidth,
                                              pageScale: pageScale,
                                              pageInk: pageInk)
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
                    .padding(.horizontal, Self.pageMargin)
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

/// Word glyph outlines and advances, built once per word/size and kept.
///
/// The reader re-renders on every animation frame (page turns, the recitation
/// highlight); building outlines with CoreText each frame would show.
@MainActor
private enum GlyphMetrics {
    struct Outline {
        let path: CGPath
        let advance: CGFloat
        /// Where the ink actually reaches, relative to the baseline (y-up).
        /// QCF marks can sit well above the font's nominal ascent.
        let bounds: CGRect
    }
    private static var cache: [String: Outline] = [:]
    private static var scaleCache: [String: CGFloat] = [:]
    private static var inkCache: [String: (top: CGFloat, bottom: CGFloat)] = [:]

    /// The single scale the whole page prints at: the tightest any one of its
    /// lines needs to fit the column, applied to every line.
    ///
    /// A mushaf page is set in ONE glyph size — justification comes from the
    /// spaces between words, never from resizing a line. Scaling each line on
    /// its own left a surah's short closing line (which never overflows, so it
    /// kept scale 1) visibly larger than the full-width lines that had been
    /// shrunk to fit.
    ///
    /// Measured once per (page, variant, size, column width) and kept: the
    /// reader re-renders on every animation frame, and the cache is consulted
    /// before the per-line word split is even built.
    static func pageScale(_ lines: [PageLine],
                          page: Int,
                          size: CGFloat,
                          target: CGFloat,
                          words: (PageLine) -> [String]) -> CGFloat {
        // No font yet: measuring would yield nothing, and caching that "1"
        // would stick once the download lands.
        guard target > 0, PageFontStore.measurementFont(page: page, size: size) != nil else { return 1 }
        let key = "\(page)|\(Int(size * 10))|\(Int(target * 10))|\(PageFontStore.variant)"
        if let hit = scaleCache[key] { return hit }
        var scale: CGFloat = 1
        var measured = false
        for line in lines where line.kind == .words {
            let total = total(words(line), page: page, size: size)
            guard total > 0 else { continue }
            measured = true
            if total > target { scale = min(scale, target / total) }
        }
        // The first body pass runs before `.task` has loaded the page's
        // lines. Caching that empty pass would pin the page at scale 1 —
        // exactly the per-line sizing this exists to remove.
        guard measured else { return 1 }
        scaleCache[key] = scale
        return scale
    }

    /// The page's true ink extent above and below the baseline, at `size`.
    ///
    /// A row is a fixed slice of the 15-row grid and a Canvas clips to its own
    /// bounds, so a baseline placed from the font's nominal ascent sliced the
    /// tops off high marks. Taking the union of the glyph outlines' bounding
    /// boxes gives the box that actually has to fit; centring that box in the
    /// row buys the headroom out of the row's own slack instead of growing it.
    ///
    /// Page-wide (not per line) so every row shares one baseline, and cached
    /// per (page, variant, size) like `pageScale`.
    static func pageInk(_ lines: [PageLine],
                        page: Int,
                        size: CGFloat,
                        words: (PageLine) -> [String]) -> (top: CGFloat, bottom: CGFloat) {
        let nominal = vertical(page: page, size: size)
        let fallback = (top: nominal.ascent, bottom: nominal.descent)
        guard PageFontStore.measurementFont(page: page, size: size) != nil else { return fallback }
        let key = "\(page)|\(Int(size * 10))|\(PageFontStore.variant)"
        if let hit = inkCache[key] { return hit }
        var top: CGFloat = 0
        var bottom: CGFloat = 0
        for line in lines where line.kind == .words {
            for outline in outlines(words(line), page: page, size: size) {
                let box = outline.bounds
                guard !box.isNull, !box.isEmpty else { continue }
                top = max(top, box.maxY)
                bottom = max(bottom, -box.minY)
            }
        }
        guard top > 0 || bottom > 0 else { return fallback }
        // A hair of breathing room so antialiasing never grazes the edge.
        let pad = size * 0.03
        let result = (top: top + pad, bottom: bottom + pad)
        inkCache[key] = result
        return result
    }

    /// Total advance of a line's words, or 0 when the page font is not
    /// available yet — never a system-font substitute's width, which would be
    /// a fraction of the truth and defeat the whole point of measuring.
    static func total(_ words: [String], page: Int, size: CGFloat) -> CGFloat {
        outlines(words, page: page, size: size).reduce(0) { $0 + $1.advance }
    }

    /// One outline per word, in reading order; empty if the font is missing.
    static func outlines(_ words: [String], page: Int, size: CGFloat) -> [Outline] {
        guard let font = PageFontStore.measurementFont(page: page, size: size) else { return [] }
        let fontKey = "\(page)|\(Int(size * 10))|\(PageFontStore.variant)"
        return words.map { word in
            let key = fontKey + "|" + word
            if let hit = cache[key] { return hit }
            let built = build(word, font: font)
            cache[key] = built
            return built
        }
    }

    /// Ascent and descent of the page font at `size`, for baseline placement.
    static func vertical(page: Int, size: CGFloat) -> (ascent: CGFloat, descent: CGFloat) {
        guard let font = PageFontStore.measurementFont(page: page, size: size) else { return (size * 0.8, size * 0.2) }
        return (CTFontGetAscent(font), CTFontGetDescent(font))
    }

    private static func build(_ word: String, font: CTFont) -> Outline {
        let attributed = NSAttributedString(string: word, attributes: [kCTFontAttributeName as NSAttributedString.Key: font])
        let line = CTLineCreateWithAttributedString(attributed)
        let advance = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        let path = CGMutablePath()
        for run in (CTLineGetGlyphRuns(line) as? [CTRun]) ?? [] {
            let count = CTRunGetGlyphCount(run)
            guard count > 0 else { continue }
            let attrs = CTRunGetAttributes(run) as NSDictionary
            let runFont = (attrs[kCTFontAttributeName as String] as! CTFont)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
            for i in 0..<count {
                var t = CGAffineTransform(translationX: positions[i].x, y: positions[i].y)
                if let glyphPath = CTFontCreatePathForGlyph(runFont, glyphs[i], &t) {
                    path.addPath(glyphPath)
                }
            }
        }
        return Outline(path: path,
                       advance: advance,
                       bounds: path.isEmpty ? .zero : path.boundingBoxOfPath)
    }
}
