import DesignSystem
import SwiftUI

/// THE offline-pack control (design 6.5): download state for one tafsir
/// edition, with its progress. Extracted from the ayah sheet so the sheet,
/// the browser and the Learn search all show the same row and go through the
/// same `TafsirService.downloadPack` — there is exactly one download path.
///
/// The service is passed in rather than owned: a download started from a row
/// that then disappears (the user clears the search field) must keep its
/// progress, so the owner of the screen owns the service.
public struct TafsirPackRow: View {
    let edition: TafsirEdition
    let service: TafsirService
    /// Search context: the idle prompt then says what the download buys —
    /// searching the whole edition, not only the surahs already downloaded.
    var forSearch = false

    public init(edition: TafsirEdition, service: TafsirService, forSearch: Bool = false) {
        self.edition = edition
        self.service = service
        self.forSearch = forSearch
    }

    public var body: some View {
        switch service.packState {
        case .downloading(let surah):
            VStack(alignment: .leading, spacing: 5) {
                Text("Downloading tafsir \(surah)/114…")
                    .font(NoorFont.caption)
                    .foregroundStyle(NoorColor.inkSecondary)
                ProgressView(value: Double(surah), total: 114)
                    .tint(NoorColor.accentPrimary)
            }
            // `.leading` only — it is already direction-aware.
            .frame(maxWidth: .infinity, alignment: .leading)
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
                    Label(forSearch ? "Download all 114 surahs to search them"
                                    : "Download for offline",
                          systemImage: "arrow.down.circle")
                        .font(NoorFont.caption)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderless)
                .tint(NoorColor.accentPrimary)
            }
        }
    }
}
