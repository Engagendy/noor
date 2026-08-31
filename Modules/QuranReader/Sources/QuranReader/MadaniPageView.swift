import ContentDB
import DesignSystem
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
    /// Long-pressing a line reports exactly the ayat on that line.
    var onLongPressLine: (([PageLine.Ref]) -> Void)?

    @State private var lines: [PageLine] = []
    @State private var fontReady = false
    @State private var fontFailed = false

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
                            case .surahHeader(let surahId):
                                headerLine(surahId: surahId, rowHeight: rowHeight, withBasmala: false)
                            case .surahHeaderWithBasmala(let surahId):
                                headerLine(surahId: surahId, rowHeight: rowHeight, withBasmala: true)
                            case .basmala:
                                Text(basmala ?? "")
                                    .font(NoorFont.quran(size: rowHeight * 0.45))
                                    .foregroundStyle(NoorColor.inkPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: rowHeight)
                            case .words:
                                // RLI…PDI: hard right-to-left, immune to
                                // bidi mis-segmentation of ligature codes.
                                Text(verbatim: "\u{2067}" + (line.glyphsV2.isEmpty ? line.glyphs : line.glyphsV2) + "\u{2069}")
                                    .font(.custom(PageFontStore.fontName(page: page), size: fontSize))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: rowHeight)
                                    .contentShape(Rectangle())
                                    .onLongPressGesture { onLongPressLine?(line.ayahRefs) }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 4)
                } else if fontFailed {
                    ContentUnavailableView {
                        Label("Page font unavailable", systemImage: "wifi.slash")
                    } description: {
                        Text("Connect to the internet once to download this page.")
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
        .task(id: page) {
            lines = (try? layout?.lines(page: page)) ?? []
            await fontStore.ensure(page: page)
            fontReady = fontStore.isReady(page: page)
            fontFailed = fontStore.failedPages.contains(page)
            // Prefetch neighbors for smooth swiping.
            await fontStore.ensure(page: page + 1)
            await fontStore.ensure(page: page - 1)
        }
        .accessibilityLabel("Page \(page)")
    }

    /// Compact header: gold rules flanking the framed surah name; when the
    /// print shares the line, the basmala sits beside the name.
    private func headerLine(surahId: Int, rowHeight: CGFloat, withBasmala: Bool) -> some View {
        HStack(spacing: 10) {
            if !withBasmala {
                Rectangle().fill(NoorColor.accentGold.opacity(0.45)).frame(height: 1)
            }
            Text(surahName(surahId))
                .font(NoorFont.quran(size: rowHeight * 0.4))
                .foregroundStyle(NoorColor.inkPrimary)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(NoorColor.accentGold, lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(NoorColor.accentGold.opacity(0.45), lineWidth: 0.8)
                        .padding(2.5)
                )
            if withBasmala {
                Text(basmala ?? "")
                    .font(NoorFont.quran(size: rowHeight * 0.38))
                    .foregroundStyle(NoorColor.inkPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            } else {
                Rectangle().fill(NoorColor.accentGold.opacity(0.45)).frame(height: 1)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: rowHeight)
    }
}
