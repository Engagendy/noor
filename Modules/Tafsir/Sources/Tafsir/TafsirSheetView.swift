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
            Label {
                Text("Downloading tafsir \(surah)/114…")
            } icon: {
                ProgressView().controlSize(.small)
            }
            .font(NoorFont.caption)
            .foregroundStyle(NoorColor.inkSecondary)
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

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(ayahText)
                        .font(NoorFont.quran(size: 20))
                        .foregroundStyle(NoorColor.inkPrimary)
                        .lineSpacing(14)
                        .environment(\.layoutDirection, .rightToLeft)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(14)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(NoorColor.accentGold.opacity(0.6), lineWidth: 1))

                    packRow
                    HStack(spacing: 8) {
                        ForEach(TafsirEdition.all) { candidate in
                            let isOn = candidate.slug == editionSlug
                            Text(candidate.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 13)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(isOn ? NoorColor.accentPrimary : NoorColor.accentPrimary.opacity(0.1)))
                                .foregroundStyle(isOn ? NoorColor.bgPrimary : NoorColor.accentPrimary)
                                .onTapGesture { editionSlug = candidate.slug }
                                .accessibilityAddTraits(isOn ? .isSelected : [])
                        }
                    }

                    switch service.state {
                    case .idle, .loading:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    case .ready(let text):
                        Text(text)
                            .font(edition.isArabic ? .system(size: 18) : NoorFont.tafsir)
                            .foregroundStyle(NoorColor.inkPrimary)
                            .lineSpacing(edition.isArabic ? 10 : 6)
                            .environment(\.layoutDirection, edition.isArabic ? .rightToLeft : .leftToRight)
                            .frame(maxWidth: .infinity, alignment: edition.isArabic ? .trailing : .leading)
                            .textSelection(.enabled)
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
