import DesignSystem
import SwiftUI

/// What Noor keeps on disk, per category, with one-tap cleanup. Content
/// re-downloads automatically when needed again.
struct StorageView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var items: [Item] = []

    struct Item: Identifiable {
        let title: LocalizedStringKey
        let subtitle: LocalizedStringKey
        let bytes: Int64
        let urls: [URL]
        var id: String { urls.first?.lastPathComponent ?? "\(bytes)" }
    }

    private static func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            total += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    private static func scan() -> [Item] {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let candidates: [(LocalizedStringKey, LocalizedStringKey, [URL])] = [
            ("Mushaf page fonts", "Madani print typefaces", [support.appendingPathComponent("pagefonts")]),
            // Both locations: streamed ayahs are cached, explicitly downloaded
            // surahs live in Application Support so iOS cannot purge them.
            ("Recitations", "Downloaded ayah audio",
             [caches.appendingPathComponent("recitations"),
              support.appendingPathComponent("recitations")]),
            ("Follow-along audio", "Word-tracking surah files",
             [caches.appendingPathComponent("timings"),
              support.appendingPathComponent("timings")]),
            ("Tafsir packs", "Offline tafsir texts", [support.appendingPathComponent("tafsir")]),
            ("Hadith packs", "Sahih al-Bukhari and Muslim", [support.appendingPathComponent("hadith")]),
            ("Athkar audio", "Hisn al-Muslim recordings", [support.appendingPathComponent("athkar-audio")]),
        ]
        return candidates.map { title, subtitle, urls in
            Item(title: title, subtitle: subtitle,
                 bytes: urls.reduce(0) { $0 + directorySize($1) }, urls: urls)
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .foregroundStyle(NoorColor.inkPrimary)
                            Text(item.subtitle)
                                .font(NoorFont.caption)
                                .foregroundStyle(NoorColor.inkSecondary)
                        }
                        Spacer()
                        Text(verbatim: ByteCountFormatter.string(
                            fromByteCount: item.bytes, countStyle: .file))
                            .font(.system(size: 14).monospacedDigit())
                            .foregroundStyle(NoorColor.inkSecondary)
                        if item.bytes > 0 {
                            Button {
                                for url in item.urls {
                                    try? FileManager.default.removeItem(at: url)
                                }
                                items = Self.scan()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.red.opacity(0.8))
                                    .frame(width: 40, height: 40)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Delete")
                        }
                    }
                }
            } footer: {
                Text("Deleting only removes downloaded copies — everything re-downloads when you use it again. The Quran text itself is part of the app and cannot be removed.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(NoorColor.bgPrimary)
        .navigationTitle(Text("Storage"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { items = Self.scan() }
    }
}
