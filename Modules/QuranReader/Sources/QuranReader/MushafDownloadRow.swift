import DesignSystem
import SwiftUI

/// Settings row: download the full printed mushaf (all 604 page fonts,
/// ~350 MB) for complete offline reading.
public struct MushafDownloadRow: View {
    @State private var fontStore = PageFontStore()
    @State private var cached = PageFontStore.cachedCount()
    @State private var task: Task<Void, Never>?

    public init() {}

    private var isComplete: Bool { cached >= 604 }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Download full mushaf")
                        .foregroundStyle(NoorColor.inkPrimary)
                    Text(isComplete
                         ? "All 604 pages are offline"
                         : "\(cached) of 604 pages · ~350 MB total")
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.inkSecondary)
                }
                Spacer()
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(NoorColor.accentPrimary)
                } else if fontStore.bulkRunning {
                    Button {
                        task?.cancel()
                        task = nil
                    } label: {
                        Image(systemName: "stop.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(NoorColor.accentPrimary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Stop download")
                } else {
                    Button {
                        task = Task {
                            await fontStore.downloadAll()
                            cached = PageFontStore.cachedCount()
                        }
                    } label: {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(NoorColor.accentPrimary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Download")
                }
            }
            if fontStore.bulkRunning {
                ProgressView(value: Double(fontStore.bulkProgress), total: 604)
                    .tint(NoorColor.accentPrimary)
                    .onChange(of: fontStore.bulkProgress) { _, new in cached = new }
            }
        }
    }
}
