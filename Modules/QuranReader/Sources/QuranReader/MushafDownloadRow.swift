import DesignSystem
import SwiftUI

/// Settings rows: the mushaf typeface, the automatic background download
/// (on by default, Wi-Fi only by default) and its live `n / 604` progress,
/// plus the manual button that drives the very same queue.
public struct MushafDownloadRow: View {
    @State private var downloader = MushafBackgroundDownloader.shared
    @AppStorage("mushaf.font") private var fontVariant = "v2"
    @AppStorage(MushafBackgroundDownloader.autoKey) private var automatic = true
    @AppStorage(MushafBackgroundDownloader.wifiOnlyKey) private var wifiOnly = true

    public init() {}

    private var sizeLabel: String { fontVariant == "v1" ? "~100 MB" : "~350 MB" }

    private var cached: Int { downloader.cachedCount }
    private var isComplete: Bool { cached >= MushafBackgroundDownloader.totalPages }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(selection: $fontVariant) {
                Text("Compact (~100 MB)").tag("v1")
                Text("Print quality (~350 MB)").tag("v2")
            } label: {
                Text("Mushaf typeface")
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Download full mushaf")
                        .foregroundStyle(NoorColor.inkPrimary)
                    Text(verbatim: isComplete
                         ? String(localized: "All 604 pages are offline")
                         : "\(cached) / \(MushafBackgroundDownloader.totalPages) · \(sizeLabel)")
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.inkSecondary)
                }
                Spacer()
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(NoorColor.accentPrimary)
                } else if downloader.isRunning {
                    Button {
                        downloader.stop()
                    } label: {
                        Image(systemName: "stop.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(NoorColor.accentPrimary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Stop download")
                } else {
                    Button {
                        downloader.startManually()
                    } label: {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(NoorColor.accentPrimary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Download")
                }
            }
            if downloader.isRunning {
                ProgressView(value: Double(cached), total: Double(MushafBackgroundDownloader.totalPages))
                    .tint(NoorColor.accentPrimary)
            }
        }
        // The downloader re-targets itself on these (it watches the
        // defaults); the toggles only need to persist.
        Toggle(isOn: $automatic) {
            Text("Download the mushaf automatically")
                .foregroundStyle(NoorColor.inkPrimary)
        }
        Toggle(isOn: $wifiOnly) {
            Text("Only on Wi-Fi")
                .foregroundStyle(NoorColor.inkPrimary)
        }
        .disabled(!automatic && !downloader.isRunning)
    }
}
