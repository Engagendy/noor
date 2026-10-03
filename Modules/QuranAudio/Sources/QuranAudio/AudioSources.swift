import Foundation

/// Where ayah-by-ayah audio comes from, and how to fetch it quickly.
///
/// Four independent hosts serve the same per-ayah files (see LICENSES.md):
/// EveryAyah, its quranicaudio mirror, the Quran Foundation verse CDN and
/// the Islamic Network CDN. The first two cover every reciter; the last two
/// cover the popular ones. On 2026-10-03 both EveryAyah hosts refused
/// connections from Egypt for hours while the other two answered in
/// ~100 ms, which is why playback never depends on a single host.
public enum AudioSources {
    public static let everyAyah = "https://everyayah.com/data"
    public static let everyAyahMirror = "https://mirrors.quranicaudio.com/everyayah"
    /// Per-ayah files of the Quran Foundation (quran.com) recitations.
    public static let quranFoundation = "https://verses.quran.foundation"
    /// Islamic Network (alquran.cloud) CDN — files are numbered by the
    /// global ayah index 1…6236 instead of surah/ayah.
    public static let islamicNetwork = "https://cdn.islamic.network/quran/audio"

    /// Ayah count of every surah, in mushaf order (metadata only, not text).
    public static let ayahCounts: [Int] = [
        7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128, 111, 110, 98, 135,
        112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73, 54, 45, 83, 182, 88, 75, 85,
        54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13,
        14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42,
        29, 19, 36, 25, 22, 17, 19, 26, 30, 20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11,
        11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6,
    ]

    /// 1-based position of the ayah in the whole mushaf (1:1 → 1, 114:6 → 6236).
    public static func globalAyahNumber(surah: Int, ayah: Int) -> Int {
        ayahCounts.prefix(max(0, surah - 1)).reduce(0, +) + ayah
    }

    static func quranFoundationURL(path: String, surah: Int, ayah: Int) -> URL {
        URL(string: "\(quranFoundation)/\(path)/mp3/\(Reciter.fileName(surah: surah, ayah: ayah))")!
    }

    static func islamicNetworkURL(bitrate: Int, edition: String, surah: Int, ayah: Int) -> URL {
        URL(string: "\(islamicNetwork)/\(bitrate)/\(edition)/\(globalAyahNumber(surah: surah, ayah: ayah)).mp3")!
    }
}

/// Remembers which hosts recently failed so the next ayah does not wait on
/// them again: a host that errored or timed out is tried last for a while.
/// In-memory only — a reachability blip must not outlive the session.
final class HostHealth: @unchecked Sendable {
    static let shared = HostHealth()
    static let cooldown: TimeInterval = 90

    private let lock = NSLock()
    private var downUntil: [String: Date] = [:]

    func markDown(_ url: URL, now: Date = .now) {
        guard let host = url.host else { return }
        lock.lock(); defer { lock.unlock() }
        downUntil[host] = now.addingTimeInterval(Self.cooldown)
    }

    func markUp(_ url: URL) {
        guard let host = url.host else { return }
        lock.lock(); defer { lock.unlock() }
        downUntil[host] = nil
    }

    func isDown(_ url: URL, now: Date = .now) -> Bool {
        guard let host = url.host else { return false }
        lock.lock(); defer { lock.unlock() }
        guard let until = downUntil[host] else { return false }
        if until <= now { downUntil[host] = nil; return false }
        return true
    }

    /// Same candidates, healthy hosts first (relative order preserved).
    func ordered(_ urls: [URL], now: Date = .now) -> [URL] {
        let healthy = urls.filter { !isDown($0, now: now) }
        return healthy + urls.filter { isDown($0, now: now) }
    }

    /// Test hook.
    func reset() {
        lock.lock(); defer { lock.unlock() }
        downUntil.removeAll()
    }
}

/// Downloads one ayah file from the first source that delivers it.
///
/// Sources are started in order, each `stagger` after the previous one is
/// still unanswered — a hedged request: a healthy host is never slowed down
/// by a dead or sluggish one in front of it, yet a fast first host means a
/// single request. The first complete audio body wins; the rest are
/// cancelled.
enum AyahFetcher {
    /// Short per-request timeout: the default 60 s is what made a stalled
    /// host feel like "the ayah is not available".
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 120
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()
    static let stagger: TimeInterval = 4
    /// Anything smaller is an error page, not a recitation.
    static let minimumBytes = 1024

    /// Temporary file holding the audio, or nil when every source failed.
    static func download(_ candidates: [URL]) async -> URL? {
        let ordered = HostHealth.shared.ordered(candidates)
        guard !ordered.isEmpty else { return nil }
        return await withTaskGroup(of: URL?.self) { group in
            for (index, url) in ordered.enumerated() {
                group.addTask {
                    if index > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(stagger * Double(index) * 1_000_000_000))
                    }
                    guard !Task.isCancelled else { return nil }
                    return await fetchOne(url)
                }
            }
            var winner: URL?
            for await file in group {
                if let file {
                    winner = file
                    group.cancelAll()
                    break
                }
            }
            return winner
        }
    }

    /// One source → temp file, after checking it really is a complete audio body.
    static func fetchOne(_ url: URL) async -> URL? {
        guard let (temp, response) = try? await session.download(from: url) else {
            if !Task.isCancelled { HostHealth.shared.markDown(url) }
            return nil
        }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              isAudio(http),
              let size = try? FileManager.default.attributesOfItem(atPath: temp.path)[.size] as? Int,
              size >= minimumBytes
        else {
            try? FileManager.default.removeItem(at: temp)
            // A 404 means this host lacks the file, not that it is down —
            // only connection-level trouble (status ≥ 500 / no HTTP) demotes it.
            if let http = response as? HTTPURLResponse, http.statusCode >= 500 {
                HostHealth.shared.markDown(url)
            }
            return nil
        }
        HostHealth.shared.markUp(url)
        return temp
    }

    /// A captive portal or error page answers 200 with HTML; never cache that.
    static func isAudio(_ response: HTTPURLResponse) -> Bool {
        let type = (response.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
        return type.isEmpty || type.hasPrefix("audio/") || type.hasPrefix("application/octet-stream")
            || type.hasPrefix("binary/")
    }
}
