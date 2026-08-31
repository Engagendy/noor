import ContentDB
import DesignSystem
import SwiftUI

/// Pixel-faithful Madani page: the page's QCF v1 font renders each line's
/// glyphs exactly as printed in the mushaf.
struct MadaniPageView: View {
    let page: Int
    let layout: PageLayoutDatabase?
    let fontStore: PageFontStore
    /// Long-pressing a line reports exactly the ayat on that line.
    var onLongPressLine: (([PageLine.Ref]) -> Void)?

    @State private var lines: [PageLine] = []
    @State private var fontReady = false
    @State private var fontFailed = false

    var body: some View {
        GeometryReader { geometry in
            let fontSize = geometry.size.width / 9.8
            Group {
                if fontReady && !lines.isEmpty {
                    VStack(spacing: fontSize * 0.42) {
                        ForEach(lines) { line in
                            Text(verbatim: line.glyphsV2.isEmpty ? line.glyphs : line.glyphsV2)
                                .font(.custom(PageFontStore.fontName(page: page), size: fontSize))
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                                .onLongPressGesture { onLongPressLine?(line.ayahRefs) }
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
}
