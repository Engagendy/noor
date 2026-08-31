import Foundation
import Observation

/// Downloads a whole surah's ayah files for one reciter into the same cache
/// the player reads from — after download, playback is fully offline.
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

    public static func isDownloaded(reciter: Reciter, surah: Int, ayahCount: Int) -> Bool {
        (1...ayahCount).allSatisfy {
            FileManager.default.fileExists(
                atPath: AudioCache.localURL(reciter: reciter, surah: surah, ayah: $0).path)
        }
    }

    public func download(reciter: Reciter, surah: Int, ayahCount: Int) async {
        if case .downloading = state { return }
        state = .downloading(completed: 0, total: ayahCount)
        var completed = 0
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                var pending = Array(1...ayahCount).makeIterator()
                var inFlight = 0
                func addNext(_ group: inout ThrowingTaskGroup<Void, Error>) {
                    guard let ayah = pending.next() else { return }
                    inFlight += 1
                    group.addTask {
                        try await Self.fetch(reciter: reciter, surah: surah, ayah: ayah)
                    }
                }
                // Modest concurrency — EveryAyah is a charity service.
                for _ in 0..<3 { addNext(&group) }
                while inFlight > 0 {
                    try await group.next()
                    inFlight -= 1
                    completed += 1
                    state = .downloading(completed: completed, total: ayahCount)
                    addNext(&group)
                }
            }
            state = .done
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private static func fetch(reciter: Reciter, surah: Int, ayah: Int) async throws {
        guard await AudioCache.ensureLocal(reciter: reciter, surah: surah, ayah: ayah) != nil else {
            throw URLError(.badServerResponse)
        }
    }
}
