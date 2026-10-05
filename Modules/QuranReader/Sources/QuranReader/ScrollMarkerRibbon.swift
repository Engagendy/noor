import DesignSystem
import SwiftUI

/// Where one Quran word sits on screen in the scrolling reading modes
/// (flowing mushaf, ayah by ayah), reported up through `MarkerTargetsKey`
/// in the reader's `ScrollMarkerRibbon.space`. The ribbon groups these into
/// the lines actually on screen.
struct MarkerTarget: Equatable {
    /// surah * 1000 + ayah.
    let key: Int
    /// 1-based word number within the ayah (`QuranFlowItem.wordIndex`).
    let word: Int
    let frame: CGRect
}

struct MarkerTargetsKey: PreferenceKey {
    static let defaultValue: [MarkerTarget] = []
    static func reduce(value: inout [MarkerTarget], nextValue: () -> [MarkerTarget]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    /// Reports this word's place for the reading marker. Off costs no
    /// GeometryReader.
    func markerTarget(_ key: Int, word: Int, enabled: Bool = true) -> some View {
        background {
            if enabled {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: MarkerTargetsKey.self,
                        value: [MarkerTarget(key: key, word: word,
                                             frame: geometry.frame(in: .named(ScrollMarkerRibbon.space)))])
                }
            }
        }
    }
}

/// The reading marker for the scrolling modes — the counterpart of the
/// Madani page's per-line ribbon (see `MadaniPageView.markerRibbon`).
///
/// It floats on the screen's leading edge (the right, in the RTL reader)
/// over whatever is scrolled into view. The words report where they are;
/// grouped by row they give the lines on screen, so a drag snaps LINE by
/// line with a live wash, and dropping marks that line by its first word —
/// the same (ayah, word) the Madani page stores, so every mode agrees.
/// When the marked line is on screen the ribbon sits on it; otherwise it
/// parks, faded, at the top, and a tap goes back to the marker.
///
/// Lives in `overlayPreferenceValue`, so scrolling only re-renders this
/// overlay — never the reader's body.
struct ScrollMarkerRibbon: View {
    static let space = "readerContent"

    /// Every reported word, including the pager's off-screen neighbours —
    /// filtered to the visible ones here.
    let targets: [MarkerTarget]
    let markerKey: Int?
    let markerWord: Int
    let onPlace: (_ key: Int, _ word: Int) -> Void
    let onJump: () -> Void

    @State private var dragLine: Int?

    /// One row of words on screen. `first` is the word read first: the
    /// rightmost, in Arabic.
    private struct Line {
        var band: CGRect
        var first: MarkerTarget
        var words: [MarkerTarget]
    }

    var body: some View {
        GeometryReader { geometry in
            let lines = Self.lines(of: targets, in: CGRect(origin: .zero, size: geometry.size))
            let markerLine = markerKey.flatMap { Self.lineIndex(of: $0, word: markerWord, in: lines) }
            let shownIndex = dragLine ?? markerLine
            let shown = shownIndex.flatMap { lines.indices.contains($0) ? lines[$0] : nil }
            let active = shown != nil
            let y = shown?.band.midY ?? 28

            ZStack(alignment: .topLeading) {
                if let shown {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(NoorColor.accentGold.opacity(0.16))
                        .frame(width: geometry.size.width - 16, height: shown.band.height + 6)
                        .offset(x: 8, y: shown.band.minY - 3)
                        .allowsHitTesting(false)
                }
                RibbonShape()
                    .fill(NoorColor.accentGold)
                    .frame(width: 15, height: 30)
                    .shadow(color: .black.opacity(active ? 0.18 : 0), radius: 1.5, y: 1)
                    .opacity(active ? 1 : 0.4)
                    .frame(width: 44, height: 44, alignment: .trailing)
                    .contentShape(Rectangle())
                    .offset(x: geometry.size.width - 44, y: y - 22)
                    .animation(.easeOut(duration: 0.12), value: y)
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                            .onChanged { value in
                                guard abs(value.translation.height) > 4 || dragLine != nil else { return }
                                dragLine = Self.nearest(to: value.location.y, in: lines)
                            }
                            .onEnded { value in
                                defer { dragLine = nil }
                                guard dragLine != nil else {
                                    if !active, markerKey != nil { onJump() }
                                    return
                                }
                                if let index = Self.nearest(to: value.location.y, in: lines) {
                                    onPlace(lines[index].first.key, lines[index].first.word)
                                }
                            })
                    .sensoryFeedback(.selection, trigger: dragLine) { _, new in new != nil }
                    .accessibilityElement()
                    .accessibilityLabel("Reading marker")
                    .accessibilityValue(shown.map { String(localized: "Ayah \($0.first.key % 1000)") } ?? "")
                    .accessibilityHint("Drag to the line you stopped at")
                    .accessibilityAdjustableAction { direction in
                        let next = direction == .increment
                            ? (markerLine.map { $0 + 1 } ?? 0) : (markerLine.map { $0 - 1 } ?? 0)
                        if lines.indices.contains(next) {
                            onPlace(lines[next].first.key, lines[next].first.word)
                        }
                    }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            // Laid out left-to-right explicitly: the offsets are absolute
            // (geometry frames are), and the reader is RTL.
            .environment(\.layoutDirection, .leftToRight)
        }
    }

    /// The visible words grouped into rows, top to bottom. Words whose
    /// vertical centres sit within half a word's height share a row.
    private static func lines(of targets: [MarkerTarget], in bounds: CGRect) -> [Line] {
        let visible = targets
            .filter { bounds.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY)) }
            .sorted { $0.frame.midY < $1.frame.midY }
        var lines: [Line] = []
        for target in visible {
            if var last = lines.last,
               abs(target.frame.midY - last.band.midY) < max(target.frame.height, last.band.height) * 0.5 {
                last.band = last.band.union(target.frame)
                if target.frame.maxX > last.first.frame.maxX { last.first = target }
                last.words.append(target)
                lines[lines.count - 1] = last
            } else {
                lines.append(Line(band: target.frame, first: target, words: [target]))
            }
        }
        return lines
    }

    /// The row holding the marker's word — or, if that exact word is not
    /// on screen, the row holding the closest earlier word of its ayah.
    private static func lineIndex(of key: Int, word: Int, in lines: [Line]) -> Int? {
        var best: (index: Int, word: Int)?
        for (index, line) in lines.enumerated() {
            for target in line.words where target.key == key {
                if target.word == word { return index }
                let isEarlier = target.word < word
                if isEarlier, target.word > (best?.word ?? 0) { best = (index, target.word) }
            }
        }
        return best?.index
    }

    /// The row whose centre is closest to `y` — the one under the finger.
    private static func nearest(to y: CGFloat, in lines: [Line]) -> Int? {
        lines.indices.min { abs(lines[$0].band.midY - y) < abs(lines[$1].band.midY - y) }
    }
}
