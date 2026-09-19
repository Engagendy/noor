import ContentDB
import DesignSystem
import SwiftUI

/// Long-press target for mushaf/page modes. One ayah → big action rows
/// directly; several ayat → pick one first, then the actions.
struct AyahActionsSheet: View {
    let verses: [Verse]
    let bookmarkedRefs: Set<String>
    let onPlay: ((Verse) -> Void)?
    let onTafsir: (Verse) -> Void
    let onShare: (Verse) -> Void
    let onToggleBookmark: ((Int, Int) -> Void)?

    @State private var picked: Verse?
    @Environment(\.dismiss) private var dismiss

    private var current: Verse? {
        picked ?? (verses.count == 1 ? verses.first : nil)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let verse = current {
                    actionList(for: verse)
                } else {
                    versePicker
                }
            }
            .background(NoorColor.bgPrimary)
            .navigationTitle(Text("Ayah actions"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            // ONE group, with back declared FIRST so it takes the leading
            // edge. As two separate items ("Done" in `.cancellationAction`,
            // back in `.navigation`) the system packed them into a single
            // capsule with Done outermost, which left the back chevron inboard
            // pointing INTO the Done button rather than out of the view —
            // plainly wrong in Arabic, where leading is the right-hand side.
            .toolbar {
                ToolbarItemGroup(placement: .cancellationAction) {
                    if picked != nil && verses.count > 1 {
                        Button {
                            picked = nil
                        } label: {
                            Image(systemName: "chevron.backward")
                        }
                        .accessibilityLabel("Back")
                    }
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// Several ayat on the pressed line: choose one.
    private var versePicker: some View {
        List(verses) { verse in
            Button {
                picked = verse
            } label: {
                HStack(spacing: 12) {
                    AyahEndMarker(verse.ayah, size: 30)
                    Text(verbatim: verse.text)
                        .font(NoorFont.quran(size: 18))
                        .foregroundStyle(NoorColor.inkPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NoorColor.inkSecondary)
                }
                .arabicBlock()
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// Big, easily tappable action rows (≥56pt).
    private func actionList(for verse: Verse) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                Text(verbatim: verse.text)
                    .font(NoorFont.quran(size: 19))
                    .foregroundStyle(NoorColor.inkPrimary)
                    .lineSpacing(12)
                    .lineLimit(3)
                    .arabicBlock()
                    .padding(14)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(NoorColor.accentGold.opacity(0.5), lineWidth: 1))
                    .padding(.bottom, 6)

                if let onPlay {
                    actionRow("Play from here", icon: "play.fill", prominent: true) {
                        dismiss()
                        onPlay(verse)
                    }
                }
                actionRow("Tafsir", icon: "book") {
                    dismiss()
                    onTafsir(verse)
                }
                actionRow("Share", icon: "square.and.arrow.up") {
                    dismiss()
                    onShare(verse)
                }
                if let onToggleBookmark {
                    let isBookmarked = bookmarkedRefs.contains(verse.id)
                    actionRow(isBookmarked ? "Bookmarked" : "Bookmark",
                              icon: isBookmarked ? "bookmark.fill" : "bookmark",
                              gold: isBookmarked) {
                        onToggleBookmark(verse.surahId, verse.ayah)
                    }
                }
            }
            .padding(16)
        }
    }

    private func actionRow(_ title: LocalizedStringKey, icon: String,
                           prominent: Bool = false, gold: Bool = false,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 19))
                    .frame(width: 30)
                Text(title)
                    .font(.noorScaled(17, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(prominent ? NoorColor.bgPrimary
                             : gold ? NoorColor.accentGold
                             : NoorColor.accentPrimary)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(prominent ? AnyShapeStyle(NoorColor.accentPrimary)
                                    : AnyShapeStyle(NoorColor.bgElevated))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(NoorColor.inkPrimary.opacity(prominent ? 0 : 0.07), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Ayah actions EN-LTR") {
    if let db = try? QuranDatabase(), let verses = try? db.verses(surahId: 1) {
        AyahActionsSheet(verses: Array(verses.prefix(3)), bookmarkedRefs: [],
                         onPlay: nil, onTafsir: { _ in }, onShare: { _ in },
                         onToggleBookmark: nil)
            .environment(\.locale, Locale(identifier: "en"))
            .environment(\.layoutDirection, .leftToRight)
    }
}
