import ContentDB
import DesignSystem
import SwiftUI

/// One fragment of a continuous Quran flow: a word, an ayah-end marker, or
/// a hizb-quarter sign. Words come from splitting the checksummed Tanzil
/// text on spaces — layout only, the text itself is never altered.
public struct QuranFlowItem: Identifiable, Hashable {
    public enum Kind { case word, marker, quarter }
    public let id: Int
    public let surahId: Int
    public let ayah: Int
    public let text: String
    public let kind: Kind
    /// Where this fragment starts inside its ayah's stored text, counted in
    /// Unicode scalars — the coordinate system the bundled tajweed spans use.
    /// Measured against the FULL stored text even when a leading basmala was
    /// stripped for display, so the two always line up. `0` for `.marker` and
    /// `.quarter`, which are not part of the stored text.
    public let scalarStart: Int

    public init(id: Int, surahId: Int, ayah: Int, text: String, kind: Kind,
                scalarStart: Int = 0) {
        self.id = id
        self.surahId = surahId
        self.ayah = ayah
        self.text = text
        self.kind = kind
        self.scalarStart = scalarStart
    }

    /// Reciting/selection key used across the readers.
    public var key: Int { surahId * 1000 + ayah }
}

public enum QuranFlow {
    /// Builds the flow fragments for a run of verses.
    ///
    /// - Parameters:
    ///   - verses: verses in ayah order (already scoped to a page/surah).
    ///   - basmalaToStrip: when the caller draws its own basmala line, the
    ///     verified DB basmala so the copy stored inside ayah 1's text is
    ///     not rendered twice (see `BasmalaPrefix`). The DB is untouched.
    ///   - isQuarterStart: `surahId * 1000 + ayah` → is a hizb quarter start.
    public static func items(verses: [Verse],
                             basmalaToStrip: String? = nil,
                             isQuarterStart: (Int) -> Bool = { _ in false }) -> [QuranFlowItem] {
        var items: [QuranFlowItem] = []
        var index = 0
        func add(_ surahId: Int, _ ayah: Int, _ text: String,
                 _ kind: QuranFlowItem.Kind, _ scalarStart: Int = 0) {
            items.append(QuranFlowItem(id: index, surahId: surahId, ayah: ayah,
                                       text: text, kind: kind,
                                       scalarStart: scalarStart))
            index += 1
        }
        for verse in verses {
            if isQuarterStart(verse.surahId * 1000 + verse.ayah) {
                add(verse.surahId, verse.ayah, "۞", .quarter)
            }
            let body: String
            if verse.ayah == 1, let basmalaToStrip {
                body = BasmalaPrefix.strippingLeadingBasmala(from: verse.text,
                                                            basmala: basmalaToStrip)
            } else {
                body = verse.text
            }
            // The basmala (when stripped) is a prefix of the stored text, so
            // every offset inside `body` sits this many scalars further into
            // the stored ayah that the tajweed spans are indexed against.
            let scalarShift = verse.text.unicodeScalars.count - body.unicodeScalars.count
            let bodyScalars = body.unicodeScalars
            for word in body.split(separator: " ") {
                let offset = bodyScalars.distance(from: bodyScalars.startIndex,
                                                  to: word.startIndex)
                add(verse.surahId, verse.ayah, String(word), .word,
                    offset + scalarShift)
            }
            // No synthetic sajdah sign: the Tanzil text of every sajdah ayah
            // already ends with ۩ (U+06E9), so appending one would double it.
            add(verse.surahId, verse.ayah,
                "\u{2067}﴿\(verse.ayah.arabicIndic)﴾\u{2069}", .marker)
        }
        return items
    }
}

/// Read-only continuous Quran flow, laid out word by word right-to-left.
///
/// This is the known-good rendering path: every fragment is its own
/// `Text(verbatim:)` placed by `RTLFlowLayout`, so no bidi run ever spans
/// two fragments and no localisation lookup is ever done on Quranic text.
/// Concatenating runs into one giant `Text` (`Text + Text`) instead is what
/// produced mangled Arabic in the kids reader — never reintroduce it.
public struct QuranFlowText: View {
    public let items: [QuranFlowItem]
    public let fontSize: CGFloat
    /// `surahId * 1000 + ayah` of the ayah being recited, if any.
    public var highlightKey: Int?
    /// Tajweed spans per `surahId * 1000 + ayah`. Empty = colouring off.
    public var tajweed: [Int: [TajweedSpan]]

    public init(items: [QuranFlowItem], fontSize: CGFloat, highlightKey: Int? = nil,
                tajweed: [Int: [TajweedSpan]] = [:]) {
        self.items = items
        self.fontSize = fontSize
        self.highlightKey = highlightKey
        self.tajweed = tajweed
    }

    public var body: some View {
        RTLFlowLayout(horizontalSpacing: fontSize * 0.3,
                      verticalSpacing: fontSize * NoorMetrics.quranLineSpacingFactor) {
            ForEach(items) { item in
                QuranFlowWord(item: item,
                              font: NoorFont.quran(size: item.kind == .word
                                                   ? fontSize : fontSize * 0.62),
                              isReciting: highlightKey == item.key,
                              spans: tajweed[item.key] ?? [])
            }
        }
        // Positions are computed right-to-left by the layout itself.
        .environment(\.layoutDirection, .leftToRight)
        .frame(maxWidth: .infinity)
    }
}

/// One fragment of the flow, tinted.
///
/// Both flow renderers (`QuranFlowText` and the reader's tappable copy) go
/// through this so the two can never drift apart on colouring. When there is
/// nothing to tint it renders exactly the previous `Text(verbatim:)`; only
/// when tajweed spans actually cover the word does it build an
/// `AttributedString`, which keeps the whole word in ONE `Text` so shaping and
/// the bidi run stay intact.
struct QuranFlowWord: View {
    let item: QuranFlowItem
    /// Resolved by the call site: the two flow renderers size the hizb-quarter
    /// sign differently and that predates this view, so neither is changed.
    let font: Font
    let isReciting: Bool
    let spans: [TajweedSpan]

    /// The recitation highlight deliberately wins over tajweed: knowing which
    /// ayah is being played matters more than the rules while audio runs.
    private var plainColor: Color {
        guard item.kind == .word else { return NoorColor.accentGold }
        return isReciting ? NoorColor.accentPrimary : NoorColor.inkPrimary
    }

    private var covering: [TajweedSpan] {
        guard item.kind == .word, !isReciting, !spans.isEmpty else { return [] }
        return TajweedColoring.spans(spans,
                                     overlapping: item.scalarStart,
                                     length: item.text.unicodeScalars.count)
    }

    var body: some View {
        let covering = covering
        if covering.isEmpty {
            Text(verbatim: item.text)
                .font(font)
                .foregroundStyle(plainColor)
        } else {
            Text(TajweedColoring.attributed(word: item.text,
                                            scalarStart: item.scalarStart,
                                            spans: covering,
                                            base: plainColor))
                .font(font)
        }
    }
}

/// Wrapping layout that fills rows from the RIGHT edge (mushaf order).
public struct RTLFlowLayout: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 10

    public init(horizontalSpacing: CGFloat = 8, verticalSpacing: CGFloat = 10) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews,
                             cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                y += rowHeight + verticalSpacing
                x = 0
                rowHeight = 0
            }
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                              subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.width, x > 0 {
                y += rowHeight + verticalSpacing
                x = 0
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: bounds.maxX - x - size.width, y: bounds.minY + y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size))
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
