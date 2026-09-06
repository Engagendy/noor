import ContentDB
import DesignSystem
import SwiftUI

/// Word-by-word display of one ayah: each word in the Quran font with its
/// English gloss beneath, wrapping right-to-left like the mushaf.
struct WordByWordView: View {
    let words: [PageWord]
    let fontSize: CGFloat
    /// 1-based word number to highlight (follow-along recitation).
    var highlightPosition: Int?
    var onTapWord: ((PageWord) -> Void)?

    var body: some View {
        RTLFlowLayout(horizontalSpacing: 10, verticalSpacing: 14) {
            ForEach(words, id: \.position) { word in
                let isCurrent = word.position == highlightPosition
                VStack(spacing: 3) {
                    Text(verbatim: word.text)
                        .font(NoorFont.quran(size: fontSize * 0.92))
                        .foregroundStyle(isCurrent ? NoorColor.accentPrimary : NoorColor.inkPrimary)
                    Text(verbatim: word.translation)
                        .font(.system(size: 11, design: .serif))
                        .foregroundStyle(NoorColor.inkSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 90)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6)
                    .fill(isCurrent ? NoorColor.stateReciting : NoorColor.bgElevated.opacity(0.6)))
                .animation(.easeInOut(duration: 0.15), value: highlightPosition)
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
