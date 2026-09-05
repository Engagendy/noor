import Foundation

/// Athkar recordings (Hamad Al-Duraihim, hisnmuslim.com — see LICENSES.md).
/// Files are fetched once and kept in Application Support so replays are
/// fully offline; the folder is excluded from iCloud backup and surfaced in
/// Settings › Storage for measurement and deletion.
public enum AthkarAudioStore {
    /// Sources in order: primary host, then the GitHub mirror.
    static let hosts = [
        "https://www.hisnmuslim.com/audio/ar/",
        "https://raw.githubusercontent.com/rn0x/Adhkar-json/main/audio/",
    ]

    /// Smallest body we accept as a real recording — anything under this is
    /// an error page or a truncated transfer.
    private static let minimumBytes: Int64 = 8 * 1024

    public static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("athkar-audio", isDirectory: true)
    }

    static func localURL(file: String) -> URL {
        directory.appendingPathComponent(file)
    }

    /// True when the file is already on disk (no network needed).
    public static func isCached(file: String) -> Bool {
        FileManager.default.fileExists(atPath: localURL(file: file).path)
    }

    /// A playable local file: the cached copy if present, else downloaded
    /// from the first reachable host and stored atomically. Offline with
    /// nothing cached → nil.
    public static func ensureLocal(file: String) async -> URL? {
        let destination = localURL(file: file)
        if FileManager.default.fileExists(atPath: destination.path) { return destination }
        guard let encoded = file.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        else { return nil }
        for host in hosts {
            guard let remote = URL(string: host + encoded) else { continue }
            var request = URLRequest(url: remote)
            request.timeoutInterval = 30
            guard let (temp, response) = try? await URLSession.shared.download(for: request),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  plausibleSize(temp)
            else { continue }
            guard prepareDirectory() else { return nil }
            try? FileManager.default.removeItem(at: destination)
            // Atomic: the file only ever appears at `destination` complete.
            guard (try? FileManager.default.moveItem(at: temp, to: destination)) != nil
            else { continue }
            return destination
        }
        return nil
    }

    private static func plausibleSize(_ url: URL) -> Bool {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        return size >= minimumBytes
    }

    /// Creates the folder (excluded from backup — it is re-downloadable content).
    private static func prepareDirectory() -> Bool {
        var dir = directory
        guard (try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)) != nil
        else { return false }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? dir.setResourceValues(values)
        return true
    }
}
