import DesignSystem
import SwiftUI

/// Where one ayah sits on screen in the scrolling reading modes (flowing
/// mushaf, ayah by ayah), reported up through `MarkerTargetsKey` in the
/// reader's `ScrollMarkerRibbon.space`.
struct MarkerTarget: Equatable {
    /// surah * 1000 + ayah.
    let key: Int
    /// Height the ribbon points at: the ayah's first line.
    let anchorY: CGFloat
    /// What the marker's gold wash covers: the ayah block (ayah by ayah),
    /// or — with `lineBand` — the reported word, widened by the ribbon to
    /// the full line the ayah begins on (flow).
    let band: CGRect
    var lineBand = false
}

struct MarkerTargetsKey: PreferenceKey {
    static let defaultValue: [MarkerTarget] = []
    static func reduce(value: inout [MarkerTarget], nextValue: () -> [MarkerTarget]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    /// Reports this view as the place of ayah `key` for the reading marker.
    /// `lineBand`: the view is the ayah's first word in a flowing line, and
    /// the wash spans that whole line. Off (`enabled == false`) costs no
    /// GeometryReader, so only ayah-start words carry one.
    func markerTarget(_ key: Int, enabled: Bool = true, lineBand: Bool = false,
                      anchorY: @escaping (CGRect) -> CGFloat = { $0.midY }) -> some View {
        background {
            if enabled {
                GeometryReader { geometry in
                    let frame = geometry.frame(in: .named(ScrollMarkerRibbon.space))
                    Color.clear.preference(
                        key: MarkerTargetsKey.self,
                        value: [MarkerTarget(key: key, anchorY: anchorY(frame),
                                             band: frame, lineBand: lineBand)])
                }
            }
        }
    }
}

/// The reading marker for the scrolling modes — the counterpart of the
/// Madani page's per-line ribbon (see `MadaniPageView.markerRibbon`).
///
/// It floats on the screen's leading edge (the right, in the RTL reader)
/// over whatever is scrolled into view. Drag it vertically and it snaps
/// ayah by ayah with a live wash; dropping it marks that ayah. When the
/// marked ayah is on screen the ribbon sits on it; otherwise it parks,
/// faded, at the top, and a tap goes back to the marker.
///
/// Lives in `overlayPreferenceValue`, so scrolling only re-renders this
/// overlay — never the reader's body.
struct ScrollMarkerRibbon: View {
    static let space = "readerContent"

    /// Every reported ayah, including the pager's off-screen neighbours —
    /// filtered to the visible ones here.
    let targets: [MarkerTarget]
    let markerKey: Int?
    let onPlace: (Int) -> Void
    let onJump: () -> Void

    @State private var dragKey: Int?

    var body: some View {
        GeometryReader { geometry in
            let bounds = CGRect(origin: .zero, size: geometry.size)
            let visible = targets
                .filter { bounds.contains(CGPoint(x: $0.band.midX, y: $0.anchorY)) }
                .sorted { $0.anchorY < $1.anchorY }
            let shownKey = dragKey ?? markerKey
            let shown = visible.first { $0.key == shownKey }
            let active = shown != nil
            let wash = shown.map { target in
                target.lineBand
                    ? CGRect(x: 8, y: target.band.minY - 3,
                             width: geometry.size.width - 16, height: target.band.height + 6)
                    : target.band
            }
            let y = shown?.anchorY ?? 28

            ZStack(alignment: .topLeading) {
                if let wash {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(NoorColor.accentGold.opacity(0.16))
                        .frame(width: wash.width, height: wash.height)
                        .offset(x: wash.minX, y: wash.minY)
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
                                guard abs(value.translation.height) > 4 || dragKey != nil else { return }
                                dragKey = nearest(to: value.location.y, in: visible)?.key
                            }
                            .onEnded { value in
                                defer { dragKey = nil }
                                guard dragKey != nil else {
                                    if !active, markerKey != nil { onJump() }
                                    return
                                }
                                if let target = nearest(to: value.location.y, in: visible) {
                                    onPlace(target.key)
                                }
                            })
                    .sensoryFeedback(.selection, trigger: dragKey) { _, new in new != nil }
                    .accessibilityElement()
                    .accessibilityLabel("Reading marker")
                    .accessibilityValue(shown.map { String(localized: "Ayah \($0.key % 1000)") } ?? "")
                    .accessibilityHint("Drag to the line you stopped at")
                    .accessibilityAdjustableAction { direction in
                        let index = visible.firstIndex { $0.key == markerKey }
                        let next = direction == .increment
                            ? (index.map { $0 + 1 } ?? 0) : (index.map { $0 - 1 } ?? 0)
                        if visible.indices.contains(next) { onPlace(visible[next].key) }
                    }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            // Laid out left-to-right explicitly: the offsets are absolute
            // (geometry frames are), and the reader is RTL.
            .environment(\.layoutDirection, .leftToRight)
        }
    }

    /// The ayah under the finger: the one whose block holds `y` (ayah by
    /// ayah), else the one whose first line is closest (flow).
    private func nearest(to y: CGFloat, in visible: [MarkerTarget]) -> MarkerTarget? {
        visible.first { $0.band.height > 60 && $0.band.minY <= y && y <= $0.band.maxY }
            ?? visible.min { abs($0.anchorY - y) < abs($1.anchorY - y) }
    }
}
