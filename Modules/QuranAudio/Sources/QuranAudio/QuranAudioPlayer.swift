import AVFoundation
import Foundation
import MediaPlayer
import Observation
#if os(iOS)
import UIKit
#endif

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
    /// Stored (→ observable, so the pill label updates) and mirrored to
    /// UserDefaults for the Settings picker and next launch.
    private var reciterRaw: String
        = UserDefaults.standard.string(forKey: "audio.reciter") ?? Reciter.alafasy.rawValue {
        didSet { UserDefaults.standard.set(reciterRaw, forKey: "audio.reciter") }
    }

    /// Supplies the next surah's metadata so continuous playback flows
    /// across surah boundaries (set by the reader, which owns the DB).
    public var surahAdvance: ((Int) -> (ayahCount: Int, title: String, arabicTitle: String)?)?

    /// Set by the reader so the player knows the surah bounds and titles.
    public var surahTitle = ""
    /// Arabic surah name — what the lock screen / Control Center shows.
    public var surahTitleArabic = ""
    private var ayahCount = 0

    private var player: AVQueuePlayer?
    /// Next ayah pre-enqueued in the queue player — the hand-off happens
    /// inside AVFoundation, so there is no fetch-then-swap pause.
    private var queuedNext: (item: AVPlayerItem, ref: Reference)?
    private var endObserver: NSObjectProtocol?
    private var commandsConfigured = false

    public init() {}

    public func play(surah: Int, ayahCount: Int, from ayah: Int, title: String,
                     arabicTitle: String? = nil, pageEndAyah: Int? = nil) {
        // Settings may have changed the reciter while we were idle.
        if let stored = UserDefaults.standard.string(forKey: "audio.reciter"), stored != reciterRaw {
            reciterRaw = stored
        }
        surahTitle = title
        surahTitleArabic = arabicTitle ?? title
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
        player?.pause()
        player?.removeAllItems()
        queuedNext = nil
        player = nil
        current = nil
        isPlaying = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    public func next() {
        guard let current else {
            stop()
            return
        }
        if current.ayah < ayahCount {
            playAyah(Reference(surah: current.surah, ayah: current.ayah + 1))
            return
        }
        // End of surah: in continuous mode, flow into the next surah.
        if mode == .continuous, current.surah < 114,
           let next = surahAdvance?(current.surah + 1) {
            surahTitle = next.title
            surahTitleArabic = next.arabicTitle
            ayahCount = next.ayahCount
            playAyah(Reference(surah: current.surah + 1, ayah: 1))
        } else {
            stop()
        }
    }

    public func previous() {
        guard let current, current.ayah > 1 else { return }
        playAyah(Reference(surah: current.surah, ayah: current.ayah - 1))
    }

    // MARK: - Internals

    private func playAyah(_ reference: Reference) {
        current = reference
        isPlaying = true
        UserDefaults.standard.set(reference.surah, forKey: "audio.lastSurah")
        UserDefaults.standard.set(reference.ayah, forKey: "audio.lastAyah")
        let reciter = self.reciter
        let ayahCount = self.ayahCount
        // Fetch-then-play: tries EveryAyah then the mirror, caches the file
        // (~50–200 KB), plays locally. Replays are offline automatically.
        Task { [weak self] in
            let local = await AudioCache.ensureLocal(
                reciter: reciter, surah: reference.surah, ayah: reference.ayah)
            guard let self, self.current == reference else { return }
            guard let local else {
                self.stop()  // all sources unreachable and not cached
                return
            }
            self.startPlayer(with: local)
        }
        _ = ayahCount
    }

    private func startPlayer(with url: URL) {
        let item = AVPlayerItem(url: url)
        queuedNext = nil
        if let player {
            player.removeAllItems()
            player.insert(item, after: nil)
        } else {
            player = AVQueuePlayer(items: [item])
        }
        installEndObserver()
        player?.play()
        isPlaying = true
        updateNowPlaying()
        enqueueNextIfNeeded()
    }

    /// One persistent end-of-item observer for whatever we play.
    private func installEndObserver() {
        guard endObserver == nil else { return }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.itemDidEnd() }
        }
    }

    private func itemDidEnd() {
        guard let cur = current else { return }
        if mode == .repeatAyah {
            playAyah(cur)  // rebuilds the queue (drops any pre-enqueued next)
            return
        }
        if mode == .pageOnly, let end = pageEndAyah, cur.ayah >= end {
            stop()
            return
        }
        if let next = queuedNext {
            // The queue player already rolled into the next item gaplessly —
            // just catch our state up and stage the one after.
            queuedNext = nil
            current = next.ref
            updateNowPlaying()
            enqueueNextIfNeeded()
        } else {
            advanceAfterFinish()
        }
    }

    /// Downloads (or reads from cache) the next ayah and appends it to the
    /// queue while the current one is still playing.
    private func enqueueNextIfNeeded() {
        guard queuedNext == nil, mode != .repeatAyah,
              let cur = current, cur.ayah < ayahCount else { return }
        if mode == .pageOnly, let end = pageEndAyah, cur.ayah >= end { return }
        let nextRef = Reference(surah: cur.surah, ayah: cur.ayah + 1)
        let reciter = self.reciter
        Task { [weak self] in
            guard let local = await AudioCache.ensureLocal(
                reciter: reciter, surah: nextRef.surah, ayah: nextRef.ayah) else { return }
            guard let self, self.current == cur, self.queuedNext == nil,
                  self.reciter == reciter, self.player != nil else { return }
            let item = AVPlayerItem(url: local)
            self.player?.insert(item, after: nil)
            self.queuedNext = (item, nextRef)
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

    /// App-icon artwork for the lock screen, rendered once.
    private static let lockScreenArtwork: MPMediaItemArtwork? = {
        #if os(iOS)
        guard let icon = UIImage(named: "AppIcon") ?? Bundle.main.iconImage else { return nil }
        return MPMediaItemArtwork(boundsSize: icon.size) { _ in icon }
        #else
        return nil
        #endif
    }()

    private func updateNowPlaying() {
        guard let current else { return }
        let title = surahTitleArabic.isEmpty ? surahTitle : surahTitleArabic
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: "\(title) · \(current.ayah.arabicIndicDigits)",
            MPMediaItemPropertyArtist: reciter.arabicName,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if let artwork = Self.lockScreenArtwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
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

    /// Returns a playable local file: the cache if present, else downloads
    /// from the first reachable source (EveryAyah → mirror) and caches it.
    static func ensureLocal(reciter: Reciter, surah: Int, ayah: Int) async -> URL? {
        let local = localURL(reciter: reciter, surah: surah, ayah: ayah)
        if FileManager.default.fileExists(atPath: local.path) { return local }
        for remote in reciter.urls(surah: surah, ayah: ayah) {
            guard let (temp, response) = try? await URLSession.shared.download(from: remote),
                  (response as? HTTPURLResponse)?.statusCode == 200
            else { continue }
            try? FileManager.default.createDirectory(
                at: local.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: local)
            guard (try? FileManager.default.moveItem(at: temp, to: local)) != nil else { continue }
            return local
        }
        return nil
    }
}


extension Int {
    /// ٠١٢٣… for lock-screen ayah numbers.
    var arabicIndicDigits: String {
        String(self).map { c -> String in
            guard let d = c.wholeNumberValue else { return String(c) }
            return String(UnicodeScalar(0x0660 + d)!)
        }.joined()
    }
}

#if os(iOS)
extension Bundle {
    /// Largest icon listed in Info.plist (works when the asset catalog
    /// doesn't expose "AppIcon" as a named image).
    var iconImage: UIImage? {
        guard let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let name = files.last else { return nil }
        return UIImage(named: name)
    }
}
#endif
