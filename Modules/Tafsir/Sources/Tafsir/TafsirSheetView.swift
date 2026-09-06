import DesignSystem
import SwiftUI

/// Tafsir sheet (design 6.5): the ayah in a gold frame, edition chips,
/// serif body at a comfortable measure.
public struct TafsirSheetView: View {
    let surahId: Int
    let ayah: Int
    let ayahText: String

    @AppStorage("tafsir.edition") private var editionSlug = TafsirEdition.all[0].slug
    @State private var service = TafsirService()

    public init(surahId: Int, ayah: Int, ayahText: String) {
        self.surahId = surahId
        self.ayah = ayah
        self.ayahText = ayahText
    }

    private var edition: TafsirEdition { TafsirEdition.named(editionSlug) }

    /// Offline pack state row (design 6.5: download state per tafsir pack).
    @ViewBuilder
    private var packRow: some View {
        switch service.packState {
        case .downloading(let surah):
            VStack(alignment: .leading, spacing: 5) {
                Text("Downloading tafsir \(surah)/114…")
                    .font(NoorFont.caption)
                    .foregroundStyle(NoorColor.inkSecondary)
                ProgressView(value: Double(surah), total: 114)
                    .tint(NoorColor.accentPrimary)
            }
        case .done:
            Label("Available offline", systemImage: "checkmark.circle")
                .font(NoorFont.caption)
                .foregroundStyle(NoorColor.accentPrimary)
        case .failed(let message):
            Text(verbatim: message)
                .font(NoorFont.caption)
                .foregroundStyle(.red)
        case .idle:
            if TafsirService.isPackDownloaded(edition: edition) {
                Label("Available offline", systemImage: "checkmark.circle")
                    .font(NoorFont.caption)
                    .foregroundStyle(NoorColor.accentPrimary)
            } else {
                Button {
                    Task { await service.downloadPack(edition: edition) }
                } label: {
                    Label("Download for offline", systemImage: "arrow.down.circle")
                        .font(NoorFont.caption)
                }
                .buttonStyle(.borderless)
                .tint(NoorColor.accentPrimary)
            }
        }
    }

    /// Arabic tafsir is an Arabic block (RTL, right edge) even in the English
    /// UI; English editions read left-to-right.
    @ViewBuilder
    private func tafsirParagraph(_ paragraph: String) -> some View {
        if edition.isArabic {
            Text(paragraph)
                .font(.noorScaled(18))
                .foregroundStyle(NoorColor.inkPrimary)
                .lineSpacing(10)
                .textSelection(.enabled)
                .arabicBlock()
        } else {
            Text(paragraph)
                .font(NoorFont.tafsir)
                .foregroundStyle(NoorColor.inkPrimary)
                .lineSpacing(6)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    /// Splits the tafsir into renderable paragraphs (never empty).
    private func paragraphs(of text: String) -> [String] {
        let parts = text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? [text] : parts
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(ayahText)
                        .font(NoorFont.quran(size: 20))
                        .foregroundStyle(NoorColor.inkPrimary)
                        .lineSpacing(14)
                        .arabicBlock()
                        .padding(14)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(NoorColor.accentGold.opacity(0.6), lineWidth: 1))

                    packRow
                    // One-line chips in a horizontal scroll — names never wrap.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(TafsirEdition.all) { candidate in
                                let isOn = candidate.slug == editionSlug
                                Text(candidate.displayName)
                                    .font(.noorScaled(13, weight: .semibold))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(isOn ? NoorColor.accentPrimary : NoorColor.accentPrimary.opacity(0.1)))
                                    .foregroundStyle(isOn ? NoorColor.bgPrimary : NoorColor.accentPrimary)
                                    .onTapGesture { editionSlug = candidate.slug }
                                    .accessibilityAddTraits(isOn ? .isSelected : [])
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    switch service.state {
                    case .idle, .loading:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    case .ready(let text):
                        // One paragraph per Text: monolithic multi-thousand-
                        // character Arabic strings hit a SwiftUI layout path
                        // that drops shaping/bidi (seen with Ibn Kathir 3:7).
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(Array(paragraphs(of: text).enumerated()), id: \.offset) { _, paragraph in
                                tafsirParagraph(paragraph)
                            }
                        }
                    case .failed(let message):
                        ContentUnavailableView {
                            Label("Tafsir unavailable", systemImage: "wifi.slash")
                        } description: {
                            Text("Check your connection and try again. (\(message))")
                        }
                    }
                }
                .padding(20)
            }
            .background(NoorColor.bgPrimary)
            .navigationTitle(Text("Tafsir — \(surahId):\(ayah)"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .task(id: editionSlug) {
            await service.load(edition: edition, surah: surahId, ayah: ayah)
        }
    }
}

#Preview("Tafsir EN-LTR (Arabic ayah stays RTL)") {
    // Non-Quranic placeholder Arabic only — real ayat come from the DB.
    TafsirSheetView(surahId: 1, ayah: 1, ayahText: "نص عربي تجريبي للمعاينة فقط")
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.layoutDirection, .leftToRight)
}
