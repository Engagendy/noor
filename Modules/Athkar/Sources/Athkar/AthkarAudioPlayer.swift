import AVFoundation
import Foundation
import Observation

/// Plays one athkar recording at a time (a single dhikr or a whole chapter).
/// Shared app-wide so a card in one screen and the chapter pill agree on
/// what is playing. Mirrors the Quran player's session handling: playback
/// category only while playing, pause on interruption / route loss.
@Observable
@MainActor
public final class AthkarAudioPlayer {
    public static let shared = AthkarAudioPlayer()

    /// Identifier of the recording being loaded or played (dhikr id or a
    /// chapter key); nil when idle.
    public private(set) var nowPlaying: String?
    /// True from tap until the file is on disk and the player has started.
    public private(set) var isLoading = false
    public private(set) var isPlaying = false
    /// 0…1 through the current recording.
    public private(set) var progress: Double = 0
    /// Identifier whose recording could not be fetched (offline, not cached);
    /// cleared on the next play request.
    public private(set) var failed: String?

    /// Set by the app: called just before playback starts so any other
    /// voice (the Quran reciter) is paused — features cannot import each
    /// other, so the app wires this hook.
    public var pauseOthers: (() -> Void)?

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var observersInstalled = false
    /// Bumped on every request so a stale download cannot start playback.
    private var requestSerial = 0

    private init() {}

    /// Starts `file` for `id`; tapping the already-playing id pauses/resumes.
    public func play(file: String, id: String) {
        if nowPlaying == id, player != nil, !isLoading {
            toggle()
            return
        }
        stopPlayer()
        failed = nil
        nowPlaying = id
        isLoading = true
        requestSerial += 1
        let serial = requestSerial
        Task { [weak self] in
            let local = await AthkarAudioStore.ensureLocal(file: file)
            guard let self, self.requestSerial == serial else { return }
            self.isLoading = false
            guard let local else {
                self.nowPlaying = nil
                self.failed = id
                return
            }
            self.start(url: local)
        }
    }

    public func toggle() {
        guard let player, nowPlaying != nil else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            deactivateSession()
        } else {
            pauseOthers?()
            activateSession()
            player.play()
            isPlaying = true
        }
    }

    public func stop() {
        requestSerial += 1
        stopPlayer()
        nowPlaying = nil
        isLoading = false
        deactivateSession()
    }

    // MARK: - Internals

    private func start(url: URL) {
        pauseOthers?()
        activateSession()
        installSessionObservers()
        let avPlayer = AVPlayer(url: url)
        player = avPlayer
        progress = 0
        timeObserver = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 4), queue: .main
        ) { [weak self] time in
            let duration = avPlayer.currentItem?.duration.seconds ?? 0
            let fraction = duration.isFinite && duration > 0 ? time.seconds / duration : 0
            Task { @MainActor in self?.progress = min(max(fraction, 0), 1) }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: avPlayer.currentItem, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        }
        avPlayer.play()
        isPlaying = true
    }

    private func stopPlayer() {
        if let timeObserver, let player { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        timeObserver = nil
        endObserver = nil
        player?.pause()
        player = nil
        isPlaying = false
        progress = 0
    }

    private func activateSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }

    /// Releases the session only when nothing else in the app is playing.
    private func deactivateSession() {
        #if os(iOS)
        guard AVAudioSession.sharedInstance().isOtherAudioPlaying == false else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func installSessionObservers() {
        guard !observersInstalled else { return }
        observersInstalled = true
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: session, queue: .main
        ) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
            Task { @MainActor in self?.pauseFromSystem() }
        }
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: session, queue: .main
        ) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
            Task { @MainActor in self?.pauseFromSystem() }
        }
        #endif
    }

    /// Mirrors a pause the system already performed (call, Siri, unplugged
    /// headphones) into our state so the button shows "Play" again.
    private func pauseFromSystem() {
        guard isPlaying else { return }
        player?.pause()
        isPlaying = false
    }
}
