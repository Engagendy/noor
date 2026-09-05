import Foundation
import Observation

/// Downloads a whole surah's ayah files for one reciter into purge-proof
/// storage the player reads from — after download, playback is fully offline.
@Observable
@MainActor
public final class SurahDownloader {
    public enum State: Equatable {
        case idle
        case downloading(completed: Int, total: Int)
        case done
        case failed(String)
    }

    public private(set) var state: State = .idle

    public init() {}

    /// True when every Arabic file — and, with a translation voice on, every
    /// translated reading — is in permanent storage.
    public static func isDownloaded(reciter: Reciter, surah: Int, ayahCount: Int,
                                    translation: TranslationVoice = .none) -> Bool {
        tracks(reciter: reciter, translation: translation, surah: surah, ayahCount: ayahCount)
            .allSatisfy {
                FileManager.default.fileExists(
                    atPath: AudioCache.downloadedURL(track: $0.track, surah: surah, ayah: $0.ayah).path)
            }
    }

    /// Downloads the surah's Arabic files plus the translated readings when
    /// a voice is selected, so offline playback stays gapless.
    public func download(reciter: Reciter, surah: Int, ayahCount: Int,
                         translation: TranslationVoice = .none) async {
        if case .downloading = state { return }
        let jobs = Self.tracks(reciter: reciter, translation: translation,
                               surah: surah, ayahCount: ayahCount)
        state = .downloading(completed: 0, total: jobs.count)
        var completed = 0
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                var pending = jobs.makeIterator()
                var inFlight = 0
                func addNext(_ group: inout ThrowingTaskGroup<Void, Error>) {
                    guard let job = pending.next() else { return }
                    inFlight += 1
                    group.addTask {
                        try await Self.fetch(track: job.track, surah: surah, ayah: job.ayah)
                    }
                }
                // Modest concurrency — EveryAyah is a charity service.
                for _ in 0..<3 { addNext(&group) }
                while inFlight > 0 {
                    try await group.next()
                    inFlight -= 1
                    completed += 1
                    state = .downloading(completed: completed, total: jobs.count)
                    addNext(&group)
                }
            }
            state = .done
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Every file the surah needs, in playback order (Arabic then its translation).
    nonisolated static func tracks(reciter: Reciter, translation: TranslationVoice,
                       surah: Int, ayahCount: Int) -> [(track: AudioCache.Track, ayah: Int)] {
        (1...max(1, ayahCount)).flatMap { ayah -> [(track: AudioCache.Track, ayah: Int)] in
            var list = [(AudioCache.Track(reciter: reciter, surah: surah, ayah: ayah), ayah)]
            if let voiceTrack = AudioCache.Track(voice: translation, surah: surah, ayah: ayah) {
                list.append((voiceTrack, ayah))
            }
            return list
        }
    }

    private static func fetch(track: AudioCache.Track, surah: Int, ayah: Int) async throws {
        guard await AudioCache.ensureLocal(
            track: track, surah: surah, ayah: ayah, persistent: true) != nil else {
            throw URLError(.badServerResponse)
        }
    }
}
