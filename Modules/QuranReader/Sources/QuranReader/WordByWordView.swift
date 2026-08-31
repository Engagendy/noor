import ContentDB
import DesignSystem
import SwiftUI

/// Word-by-word display of one ayah: each word in the Quran font with its
/// English gloss beneath, wrapping right-to-left like the mushaf.
struct WordByWordView: View {
    let words: [PageWord]
    let fontSize: CGFloat
    var onTapWord: ((PageWord) -> Void)?

    var body: some View {
        RTLFlowLayout(horizontalSpacing: 10, verticalSpacing: 14) {
            ForEach(words, id: \.position) { word in
                VStack(spacing: 3) {
                    Text(word.text)
                        .font(NoorFont.quran(size: fontSize * 0.92))
                        .foregroundStyle(NoorColor.inkPrimary)
                    Text(word.translation)
                        .font(.system(size: 11, design: .serif))
                        .foregroundStyle(NoorColor.inkSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 90)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(NoorColor.bgElevated.opacity(0.6)))
                .contentShape(Rectangle())
                .onTapGesture { onTapWord?(word) }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(word.text)
                .accessibilityValue(word.translation)
            }
        }
        // Positions are computed right-to-left by the layout itself.
        .environment(\.layoutDirection, .leftToRight)
    }
}

/// Wrapping layout that fills rows from the RIGHT edge (mushaf order).
struct RTLFlowLayout: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
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

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
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
