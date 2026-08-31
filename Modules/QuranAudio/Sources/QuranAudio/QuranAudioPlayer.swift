import AVFoundation
import Foundation
import MediaPlayer
import Observation

/// Ayah-by-ayah recitation player. Streams from EveryAyah, caches every
/// finished download so replays are offline, advances automatically, and
/// drives lock-screen / Control Center controls.
@Observable
@MainActor
public final class QuranAudioPlayer {
    public struct Reference: Equatable, Sendable {
        public let surah: Int
        public let ayah: Int
        public init(surah: Int, ayah: Int) {
            self.surah = surah
            self.ayah = ayah
        }
    }

    /// How playback advances after each ayah finishes.
    public enum PlaybackMode: String, CaseIterable {
        case continuous   // through the whole surah
        case repeatAyah   // repeat the current ayah (memorization)
        case pageOnly     // stop at the end of the current page
    }

    public private(set) var current: Reference?
    public private(set) var isPlaying = false
    public var mode: PlaybackMode = .continuous
    /// Last ayah to play when mode is .pageOnly (set by the reader).
    public var pageEndAyah: Int?
    public var reciter: Reciter {
        get { Reciter(rawValue: reciterRaw) ?? .alafasy }
        set {
            reciterRaw = newValue.rawValue
            // Switching sheikh mid-recitation restarts the current ayah in
            // the new voice immediately.
            if let current, isPlaying {
                playAyah(current)
            }
        }
    }
    private var reciterRaw: String {
        get { UserDefaults.standard.string(forKey: "audio.reciter") ?? Reciter.alafasy.rawValue }
        set { UserDefaults.standard.set(newValue, forKey: "audio.reciter") }
    }

    /// Set by the reader so the player knows the surah bounds and titles.
    public var surahTitle = ""
    private var ayahCount = 0

    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var commandsConfigured = false

    public init() {}

    public func play(surah: Int, ayahCount: Int, from ayah: Int, title: String, pageEndAyah: Int? = nil) {
        surahTitle = title
        self.ayahCount = ayahCount
        self.pageEndAyah = pageEndAyah
        configureSessionAndCommands()
        playAyah(Reference(surah: surah, ayah: ayah))
    }

    /// Called when an ayah finishes naturally — honors the playback mode.
    private func advanceAfterFinish() {
        guard let current else { return }
        switch mode {
        case .repeatAyah:
            playAyah(current)
        case .pageOnly:
            if let end = pageEndAyah, current.ayah >= end {
                stop()
            } else {
                next()
            }
        case .continuous:
            next()
        }
    }

    public func togglePlayPause() {
        guard let player else { return }
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
        updateNowPlaying()
    }

    public func stop() {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        player?.pause()
        player = nil
        current = nil
        isPlaying = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    public func next() {
        guard let current, current.ayah < ayahCount else {
            stop()
            return
        }
        playAyah(Reference(surah: current.surah, ayah: current.ayah + 1))
    }

    public func previous() {
        guard let current, current.ayah > 1 else { return }
        playAyah(Reference(surah: current.surah, ayah: current.ayah - 1))
    }

    // MARK: - Internals

    private func playAyah(_ reference: Reference) {
        current = reference
        let url = AudioCache.localOrRemoteURL(reciter: reciter, surah: reference.surah, ayah: reference.ayah)
        let item = AVPlayerItem(url: url)
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.advanceAfterFinish() }
        }
        if let player {
            player.replaceCurrentItem(with: item)
        } else {
            player = AVPlayer(playerItem: item)
        }
        player?.play()
        isPlaying = true
        updateNowPlaying()
        AudioCache.cacheInBackground(reciter: reciter, surah: reference.surah, ayah: reference.ayah)
        // Prefetch the next ayah so auto-advance is gapless-ish offline.
        if reference.ayah < ayahCount {
            AudioCache.cacheInBackground(reciter: reciter, surah: reference.surah, ayah: reference.ayah + 1)
        }
    }

    private func configureSessionAndCommands() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        guard !commandsConfigured else { return }
        commandsConfigured = true
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                if self?.isPlaying == false { self?.togglePlayPause() }
            }
            return .success
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                if self?.isPlaying == true { self?.togglePlayPause() }
            }
            return .success
        }
        commands.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        }
        commands.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        }
    }

    private func updateNowPlaying() {
        guard let current else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "\(surahTitle) · \(current.ayah)",
            MPMediaItemPropertyArtist: reciter.displayName,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
    }
}

/// Simple ayah-file cache in Caches/ — replays work offline.
enum AudioCache {
    static var directory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("recitations", isDirectory: true)
    }

    static func localURL(reciter: Reciter, surah: Int, ayah: Int) -> URL {
        directory
            .appendingPathComponent(reciter.rawValue, isDirectory: true)
            .appendingPathComponent(Reciter.fileName(surah: surah, ayah: ayah))
    }

    static func localOrRemoteURL(reciter: Reciter, surah: Int, ayah: Int) -> URL {
        let local = localURL(reciter: reciter, surah: surah, ayah: ayah)
        return FileManager.default.fileExists(atPath: local.path) ? local
            : reciter.url(surah: surah, ayah: ayah)
    }

    static func cacheInBackground(reciter: Reciter, surah: Int, ayah: Int) {
        let local = localURL(reciter: reciter, surah: surah, ayah: ayah)
        guard !FileManager.default.fileExists(atPath: local.path) else { return }
        let remote = reciter.url(surah: surah, ayah: ayah)
        Task.detached(priority: .utility) {
            guard let (temp, response) = try? await URLSession.shared.download(from: remote),
                  (response as? HTTPURLResponse)?.statusCode == 200
            else { return }
            try? FileManager.default.createDirectory(
                at: local.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.moveItem(at: temp, to: local)
        }
    }
}
