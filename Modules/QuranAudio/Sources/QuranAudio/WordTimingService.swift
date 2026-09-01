import Foundation

/// Word-level timings for a gapless surah recitation (Quran Foundation /
/// qurancdn "qdc" API, Alafasy murattal = reciter 7). Cached to disk so
/// follow-along works offline after the first play.
public struct SurahTimings: Codable, Sendable {
    public struct VerseTiming: Codable, Sendable {
        public let ayah: Int
        public let fromMs: Int
        public let toMs: Int
        /// (1-based word number, startMs, endMs)
        public let segments: [[Int]]
    }

    public let audioURL: String
    public let verses: [VerseTiming]

    /// (ayah, wordNumber) at a playback position, or nil between verses.
    public func position(atMs ms: Int) -> (ayah: Int, word: Int)? {
        guard let verse = verses.first(where: { ms >= $0.fromMs && ms < $0.toMs }) else { return nil }
        for segment in verse.segments where segment.count >= 3 {
            if ms >= segment[1] && ms < segment[2] {
                return (verse.ayah, segment[0])
            }
        }
        return (verse.ayah, verse.segments.first?.first ?? 1)
    }
}

public enum WordTimingService {
    /// qurancdn reciter id for gapless Alafasy murattal.
    public static let alafasyReciterId = 7

    private static func cacheURL(reciter: Int, surah: Int) -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("timings/qf\(reciter)_\(surah).json")
    }

    private static func audioCacheURL(reciter: Int, surah: Int) -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("timings/qf\(reciter)_\(surah).mp3")
    }

    /// Timings from cache or network.
    public static func timings(reciter: Int = alafasyReciterId, surah: Int) async -> SurahTimings? {
        let cache = cacheURL(reciter: reciter, surah: surah)
        if let data = try? Data(contentsOf: cache),
           let cached = try? JSONDecoder().decode(SurahTimings.self, from: data) {
            return cached
        }
        guard let url = URL(string:
            "https://api.qurancdn.com/api/qdc/audio/reciters/\(reciter)/audio_files?chapter=\(surah)&segments=true"),
            let (data, response) = try? await URLSession.shared.data(from: url),
            (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }

        struct APIFile: Decodable {
            let audio_url: String
            let verse_timings: [APITiming]
        }
        struct APITiming: Decodable {
            let verse_key: String
            let timestamp_from: Int
            let timestamp_to: Int
            let segments: [[Int]]
        }
        struct APIResponse: Decodable { let audio_files: [APIFile] }

        guard let file = (try? JSONDecoder().decode(APIResponse.self, from: data))?.audio_files.first
        else { return nil }
        let verses = file.verse_timings.compactMap { timing -> SurahTimings.VerseTiming? in
            guard let ayah = Int(timing.verse_key.split(separator: ":").last ?? "") else { return nil }
            return SurahTimings.VerseTiming(
                ayah: ayah, fromMs: timing.timestamp_from, toMs: timing.timestamp_to,
                segments: timing.segments)
        }
        let timings = SurahTimings(audioURL: file.audio_url, verses: verses)
        try? FileManager.default.createDirectory(
            at: cache.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(timings).write(to: cache)
        return timings
    }

    /// Already-cached audio, if any (long surahs stream first instead).
    public static func cachedAudio(reciter: Int, surah: Int) -> URL? {
        let local = audioCacheURL(reciter: reciter, surah: surah)
        return FileManager.default.fileExists(atPath: local.path) ? local : nil
    }

    /// Background prefetch so the NEXT playback of this surah is offline.
    public static func prefetchAudio(reciter: Int, surah: Int, remote: String) {
        Task.detached(priority: .utility) {
            _ = await localAudio(reciter: reciter, surah: surah, remote: remote)
        }
    }

    /// Local gapless surah audio, downloading once.
    public static func localAudio(reciter: Int = alafasyReciterId, surah: Int, remote: String) async -> URL? {
        let local = audioCacheURL(reciter: reciter, surah: surah)
        if FileManager.default.fileExists(atPath: local.path) { return local }
        guard let url = URL(string: remote),
              let (temp, response) = try? await URLSession.shared.download(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        try? FileManager.default.createDirectory(
            at: local.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: local)
        guard (try? FileManager.default.moveItem(at: temp, to: local)) != nil else { return nil }
        return local
    }
}
