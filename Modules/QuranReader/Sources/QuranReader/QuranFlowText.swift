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

    public init(id: Int, surahId: Int, ayah: Int, text: String, kind: Kind) {
        self.id = id
        self.surahId = surahId
        self.ayah = ayah
        self.text = text
        self.kind = kind
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
        func add(_ surahId: Int, _ ayah: Int, _ text: String, _ kind: QuranFlowItem.Kind) {
            items.append(QuranFlowItem(id: index, surahId: surahId, ayah: ayah,
                                       text: text, kind: kind))
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
            for word in body.split(separator: " ") {
                add(verse.surahId, verse.ayah, String(word), .word)
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

    public init(items: [QuranFlowItem], fontSize: CGFloat, highlightKey: Int? = nil) {
        self.items = items
        self.fontSize = fontSize
        self.highlightKey = highlightKey
    }

    public var body: some View {
        RTLFlowLayout(horizontalSpacing: fontSize * 0.3,
                      verticalSpacing: fontSize * NoorMetrics.quranLineSpacingFactor) {
            ForEach(items) { item in
                Text(verbatim: item.text)
                    .font(NoorFont.quran(size: item.kind == .word
                                         ? fontSize : fontSize * 0.62))
                    .foregroundStyle(
                        item.kind == .word
                            ? (highlightKey == item.key
                               ? NoorColor.accentPrimary : NoorColor.inkPrimary)
                            : NoorColor.accentGold)
            }
        }
        // Positions are computed right-to-left by the layout itself.
        .environment(\.layoutDirection, .leftToRight)
        .frame(maxWidth: .infinity)
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
