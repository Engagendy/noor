import ContentDB
import DesignSystem
import SwiftUI

/// Tap target for mushaf/page modes: lists the tapped page's ayat with
/// direct actions — play, tafsir, share, bookmark.
struct AyahActionsSheet: View {
    let verses: [Verse]
    let bookmarkedAyat: Set<Int>
    let onPlay: ((Verse) -> Void)?
    let onTafsir: (Verse) -> Void
    let onShare: (Verse) -> Void
    let onToggleBookmark: ((Int) -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(verses) { verse in
                HStack(spacing: 10) {
                    AyahEndMarker(verse.ayah, size: 28)
                    Text(verse.text)
                        .font(NoorFont.quran(size: 17))
                        .foregroundStyle(NoorColor.inkPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .environment(\.layoutDirection, .rightToLeft)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    if let onPlay {
                        Button {
                            dismiss()
                            onPlay(verse)
                        } label: {
                            Image(systemName: "play.fill")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Play from here")
                    }
                    Button {
                        dismiss()
                        onTafsir(verse)
                    } label: {
                        Image(systemName: "book")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Tafsir")
                    Button {
                        dismiss()
                        onShare(verse)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Share")
                    if let onToggleBookmark {
                        Button {
                            onToggleBookmark(verse.ayah)
                        } label: {
                            Image(systemName: bookmarkedAyat.contains(verse.ayah) ? "bookmark.fill" : "bookmark")
                                .foregroundStyle(NoorColor.accentGold)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Bookmark")
                    }
                }
                .foregroundStyle(NoorColor.accentPrimary)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(NoorColor.bgPrimary)
            .navigationTitle(Text("Ayah actions"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
