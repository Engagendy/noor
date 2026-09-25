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
        case memorize     // loop a range, repeating each ayah N times
    }

    // Memorize-mode settings (set from the range sheet).
    public var memorizeStart = 1
    public var memorizeEnd = 5
    public var memorizePerAyah = 3
    private var memorizeRepeatsDone = 0
    /// 1-based repetition of `current` playing in `.memorize` mode — what
    /// the kids reader shows as "2 of 3". Observable: the private stored
    /// counter behind it is instrumented by @Observable like any other.
    public var memorizeRepeat: Int {
        min(memorizeRepeatsDone + 1, max(memorizePerAyah, 1))
    }

    /// Bumped when the user asks the reader to jump back to what is being
    /// recited (tapping the pill's reference). The reader observes it; the
    /// player itself does nothing with it. Mirrors Android's `resyncRequest`.
    public private(set) var resyncRequest = 0

    /// "Take me back to the ayah being recited."
    public func requestResync() {
        guard current != nil else { return }
        resyncRequest &+= 1
    }

    public private(set) var current: Reference?
    public private(set) var isPlaying = false
    /// True while an ayah's audio is being fetched and there is nothing to
    /// start yet. The pill shows a spinner instead of a transport icon (as
    /// Android's already did): a mujawwad ayah is megabytes, not the ~100 KB
    /// this was written around, so the wait is long enough that a play/pause
    /// icon which cannot act yet reads as a dead button.
    public private(set) var isBuffering = false
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

    /// Translated reading played after each Arabic ayah (`.none` = off).
    public var translationVoice: TranslationVoice {
        get { TranslationVoice(rawValue: translationRaw) ?? .none }
        set {
            guard newValue.rawValue != translationRaw else { return }
            translationRaw = newValue.rawValue
            translationDidChange()
        }
    }
    private var translationRaw: String
        = UserDefaults.standard.string(forKey: TranslationVoice.defaultsKey) ?? TranslationVoice.none.rawValue {
        didSet { UserDefaults.standard.set(translationRaw, forKey: TranslationVoice.defaultsKey) }
    }
    /// True while the translated reading of `current` is what's audible.
    /// The ayah highlight stays put; the pill shows the voice's name.
    public private(set) var isPlayingTranslation = false
    /// Translation item staged in the queue (or playing) for `current`.
    private var translationItem: AVPlayerItem?
    /// Arabic finished before the translation file arrived — play it as
    /// soon as it lands instead of advancing.
    private var awaitingTranslation = false

    /// Supplies the next surah's metadata so continuous playback flows
    /// across surah boundaries (set by the reader, which owns the DB).
    public var surahAdvance: ((Int) -> (ayahCount: Int, title: String, arabicTitle: String)?)?

    /// Verified DB text of an ayah, for the lock screen / Control Center
    /// title (set by the reader, which owns the DB). Passed through
    /// VERBATIM — the Now Playing title is never a reshaped Quran string.
    public var ayahText: ((Int, Int) -> String?)?

    /// Set by the reader so the player knows the surah bounds and titles.
    public var surahTitle = ""
    /// Arabic surah name — what the lock screen / Control Center shows.
    public var surahTitleArabic = ""
    private var ayahCount = 0

    private var player: AVQueuePlayer?
    // Follow-along (word highlight): separate gapless-surah player.
    private var followPlayer: AVPlayer?
    private var followObserver: Any?
    private var followTimings: SurahTimings?
    private var followReciterId = WordTimingService.alafasyReciterId
    /// surah*1_000_000 + ayah*1_000 + wordNumber while following, else nil.
    public private(set) var recitingWordKey: Int?
    public private(set) var isFollowAlong = false
    /// Surah the live follow-along observer belongs to (stale ticks from a
    /// replaced player are ignored).
    private var followSurah = 0
    /// True between "surah finished" and the next surah actually starting,
    /// so the 100 ms observer can't spawn duplicate advances.
    private var isAdvancingSurah = false

    // Sleep timer + playback rate.
    public private(set) var sleepDeadline: Date?
    public var stopAfterSurah = false
    public var rate: Float = 1.0 {
        didSet {
            player?.rate = isPlaying ? rate : 0
            followPlayer?.rate = isPlaying ? rate : 0
            // NO defaults write here: @Observable routes init assignments
            // through the setter, and a defaults write invalidates every
            // @AppStorage — with the discarded per-body player inits that
            // made an infinite render loop. Persisted in persistRate().
        }
    }

    /// Called by the speed UI after a deliberate change.
    public func persistRate() {
        UserDefaults.standard.set(rate, forKey: "audio.rate")
    }
    private var sleepTimer: Timer?

    /// Arms (or clears, with nil) the sleep timer.
    public func setSleepTimer(minutes: Int?) {
        sleepTimer?.invalidate()
        sleepTimer = nil
        guard let minutes else {
            sleepDeadline = nil
            return
        }
        let deadline = Date().addingTimeInterval(TimeInterval(minutes * 60))
        sleepDeadline = deadline
        sleepTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60),
                                          repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.sleepDeadline = nil
                self?.stop()
            }
        }
    }
    /// Next ayah pre-enqueued in the queue player — the hand-off happens
    /// inside AVFoundation, so there is no fetch-then-swap pause.
    private var queuedNext: (item: AVPlayerItem, ref: Reference)?
    private var endObserver: NSObjectProtocol?
    /// 1 Hz ticker that keeps the lock-screen scrubber honest, and the
    /// player it belongs to (a time observer MUST be removed from the exact
    /// player it was added to).
    private var progressObserver: Any?
    private var progressPlayer: AVPlayer?
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var resumeAfterInterruption = false
    private var commandsConfigured = false
    /// Bumped by every start and every `stop()`. A fetch that was in flight
    /// when the user pressed stop carries a stale token and must not start
    /// audio they already cancelled.
    private var playbackToken = 0

    public init() {
        let stored = UserDefaults.standard.float(forKey: "audio.rate")
        if stored > 0 { rate = stored }
    }

    public func play(surah: Int, ayahCount: Int, from ayah: Int, title: String,
                     arabicTitle: String? = nil, pageEndAyah: Int? = nil) {
        // Settings may have changed the reciter/translation while we were idle.
        if let stored = UserDefaults.standard.string(forKey: "audio.reciter"), stored != reciterRaw {
            reciterRaw = stored
        }
        if let stored = UserDefaults.standard.string(forKey: TranslationVoice.defaultsKey),
           stored != translationRaw {
            translationRaw = stored
        }
        surahTitle = title
        surahTitleArabic = arabicTitle ?? title
        self.ayahCount = ayahCount
        self.pageEndAyah = pageEndAyah
        resetAyahLengthEstimate()
        configureSessionAndCommands()
        playAyah(Reference(surah: surah, ayah: ayah))
    }

    /// Called when an ayah finishes naturally — honors the playback mode.
    private func advanceAfterFinish() {
        guard let current else { return }
        switch mode {
        case .memorize:
            advanceMemorize(from: current)
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

    /// Memorize loop: each ayah ×N, then the next; wrap to the start of
    /// the range after the last ayah.
    private func advanceMemorize(from current: Reference) {
        memorizeRepeatsDone += 1
        if memorizeRepeatsDone < memorizePerAyah {
            playAyah(current)
            return
        }
        memorizeRepeatsDone = 0
        let nextAyah = current.ayah < min(memorizeEnd, ayahCount) ? current.ayah + 1 : memorizeStart
        playAyah(Reference(surah: current.surah, ayah: nextAyah))
    }

    /// Starts the memorize loop over an ayah range.
    public func startMemorize(start: Int, end: Int, perAyah: Int) {
        memorizeStart = max(1, min(start, ayahCount))
        memorizeEnd = max(memorizeStart, min(end, ayahCount))
        memorizePerAyah = max(1, perAyah)
        memorizeRepeatsDone = 0
        mode = .memorize
        guard let current else { return }
        playAyah(Reference(surah: current.surah, ayah: memorizeStart))
    }

    /// Exposed so range pickers can bound their steppers.
    public var currentAyahCount: Int { ayahCount }

    public func togglePlayPause() {
        if isFollowAlong, let followPlayer {
            if isPlaying { followPlayer.pause() } else { followPlayer.playImmediately(atRate: rate) }
            isPlaying.toggle()
            updateNowPlaying()
            return
        }
        // NO `guard let player`: the ayah's file may still be downloading, so
        // there is either no AVPlayer yet or one still holding the PREVIOUS
        // ayah. Flipping the flag is still the honest answer — `startPlayer`
        // reads it before it starts anything, so a pause during the fetch is
        // respected instead of being overridden when the file lands.
        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            #if os(iOS)
            // Cheap insurance: a session that lost activation while paused
            // would also make play() a silent no-op.
            try? AVAudioSession.sharedInstance().setActive(true)
            #endif
            // One call, not `play()` then `rate =`: the API for "start now,
            // at this rate".
            player?.playImmediately(atRate: rate)
            isPlaying = true
        }
        updateNowPlaying()
    }

    public func stop() {
        playbackToken &+= 1
        setSleepTimer(minutes: nil)
        stopAfterSurah = false
        stopFollowAlong()
        removeProgressObserver()
        player?.pause()
        player?.removeAllItems()
        queuedNext = nil
        clearTranslationState()
        ownedItems.removeAll()
        resetAyahLengthEstimate()
        player = nil
        current = nil
        isPlaying = false
        isBuffering = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func clearTranslationState() {
        translationItem = nil
        isPlayingTranslation = false
        awaitingTranslation = false
    }

    /// Voice switched from the picker: mid-translation (or when the Arabic
    /// has already ended) restart the pair; while the Arabic is still
    /// playing just swap what's staged behind it.
    private func translationDidChange() {
        guard let current, isPlaying || player != nil, !isFollowAlong else { return }
        if isPlayingTranslation || awaitingTranslation {
            playAyah(current)
            return
        }
        if let translationItem { player?.remove(translationItem) }
        if let next = queuedNext { player?.remove(next.item) }
        queuedNext = nil
        clearTranslationState()
        stageAfterArabic()
    }

    public func next() {
        if isFollowAlong { seekFollow(by: 1); return }
        guard let current else {
            stop()
            return
        }
        if current.ayah < ayahCount {
            playAyah(Reference(surah: current.surah, ayah: current.ayah + 1))
            return
        }
        if stopAfterSurah {
            stop()
            return
        }
        // End of surah: in continuous mode, flow into the next surah.
        if mode == .continuous, current.surah < 114,
           let next = surahAdvance?(current.surah + 1) {
            surahTitle = next.title
            surahTitleArabic = next.arabicTitle
            ayahCount = next.ayahCount
            resetAyahLengthEstimate()
            playAyah(Reference(surah: current.surah + 1, ayah: 1))
        } else {
            stop()
        }
    }

    public func previous() {
        if isFollowAlong { seekFollow(by: -1); return }
        guard let current, current.ayah > 1 else { return }
        playAyah(Reference(surah: current.surah, ayah: current.ayah - 1))
    }

    // MARK: - Follow-along (word-level highlight, Alafasy gapless)

    /// Plays the gapless surah with word tracking.
    ///
    /// `false` means "I could not do this — fall back to ayah playback".
    /// Being cancelled mid-fetch returns `true`: nothing is playing, and that
    /// is exactly what the user asked for, so the caller must NOT fall back.
    public func playFollowAlong(surah: Int, ayahCount: Int, from ayah: Int,
                                title: String, arabicTitle: String,
                                qfReciterId: Int = WordTimingService.alafasyReciterId) async -> Bool {
        playbackToken &+= 1
        let token = playbackToken
        surahTitle = title
        surahTitleArabic = arabicTitle
        self.ayahCount = ayahCount
        configureSessionAndCommands()
        // Timings come off the network on a cold surah; stopping during that
        // wait used to be overridden by the audio starting when it landed.
        guard let timings = await WordTimingService.timings(reciter: qfReciterId, surah: surah)
        else { return playbackToken != token }
        guard playbackToken == token else { return true }
        followReciterId = qfReciterId
        // Play immediately: cached file if present, else STREAM the remote
        // (long surahs run to ~100 MB — downloading first meant silence).
        let playURL: URL
        if let cached = WordTimingService.cachedAudio(reciter: qfReciterId, surah: surah) {
            playURL = cached
        } else if let remote = URL(string: timings.audioURL) {
            playURL = remote
            WordTimingService.prefetchAudio(reciter: qfReciterId, surah: surah,
                                            remote: timings.audioURL)
        } else {
            return false
        }
        player?.pause()
        player?.removeAllItems()
        queuedNext = nil
        stopFollowAlong()
        followTimings = timings
        isFollowAlong = true
        followSurah = surah
        isAdvancingSurah = false
        let avPlayer = AVPlayer(url: playURL)
        followPlayer = avPlayer
        current = Reference(surah: surah, ayah: ayah)
        if let verse = timings.verses.first(where: { $0.ayah == ayah }) {
            avPlayer.seek(to: CMTime(value: CMTimeValue(verse.fromMs), timescale: 1000),
                          toleranceBefore: .zero, toleranceAfter: .zero) { _ in }
        }
        followObserver = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 10), queue: .main
        ) { [weak self] time in
            Task { @MainActor in self?.followTick(ms: Int(time.seconds * 1000), surah: surah) }
        }
        installProgressObserver(on: avPlayer)
        isBuffering = false
        avPlayer.play()
        avPlayer.rate = rate
        isPlaying = true
        updateNowPlaying()
        return true
    }

    private func followTick(ms: Int, surah: Int) {
        guard surah == followSurah, let timings = followTimings else { return }
        if let position = timings.position(atMs: ms) {
            let key = surah * 1_000_000 + position.ayah * 1_000 + position.word
            if recitingWordKey != key { recitingWordKey = key }
            if current?.ayah != position.ayah {
                current = Reference(surah: surah, ayah: position.ayah)
                UserDefaults.standard.set(position.ayah, forKey: "audio.lastAyah")
                updateNowPlaying()
            }
        }
        // Finished the surah: flow into the next one (continuous mode),
        // exactly like ayah playback does.
        if let last = timings.verses.last, ms >= last.toMs, !isAdvancingSurah {
            guard mode == .continuous, surah < 114,
                  let next = surahAdvance?(surah + 1) else {
                stop()
                return
            }
            let reciterId = followReciterId
            isAdvancingSurah = true
            Task { [weak self] in
                guard let self else { return }
                let ok = await self.playFollowAlong(
                    surah: surah + 1, ayahCount: next.ayahCount, from: 1,
                    title: next.title, arabicTitle: next.arabicTitle,
                    qfReciterId: reciterId)
                self.isAdvancingSurah = false
                if !ok { self.stop() }
            }
        }
    }

    private func seekFollow(by delta: Int) {
        guard let timings = followTimings, let current,
              let verse = timings.verses.first(where: { $0.ayah == current.ayah + delta })
        else { return }
        followPlayer?.seek(to: CMTime(value: CMTimeValue(verse.fromMs), timescale: 1000),
                           toleranceBefore: .zero, toleranceAfter: .zero) { _ in }
        self.current = Reference(surah: current.surah, ayah: verse.ayah)
    }

    private func stopFollowAlong() {
        if let followObserver, let followPlayer {
            followPlayer.removeTimeObserver(followObserver)
        }
        if progressPlayer === followPlayer { removeProgressObserver() }
        followObserver = nil
        followPlayer?.pause()
        followPlayer = nil
        followTimings = nil
        recitingWordKey = nil
        isFollowAlong = false
        followSurah = 0
        isAdvancingSurah = false
    }

    // MARK: - Internals

    private func playAyah(_ reference: Reference) {
        playbackToken &+= 1
        let token = playbackToken
        isBuffering = true
        // Never two voices at once. Switching sheikh mid-recitation (the
        // `reciter` setter) lands here while a gapless follow-along surah is
        // still running — without this the two played over each other, and
        // the pill's play/pause then only controlled one of them.
        if isFollowAlong { stopFollowAlong() }
        current = reference
        isPlaying = true
        UserDefaults.standard.set(reference.surah, forKey: "audio.lastSurah")
        UserDefaults.standard.set(reference.ayah, forKey: "audio.lastAyah")
        // Silence whatever is still queued (a translation segment, the
        // pre-enqueued next ayah) so its end can't advance us twice.
        player?.pause()
        player?.removeAllItems()
        queuedNext = nil
        clearTranslationState()
        ownedItems.removeAll()
        let reciter = self.reciter
        let voice = self.translationVoice
        // Fetch-then-play: tries EveryAyah then the mirror, caches the file
        // (~50–200 KB), plays locally. Replays are offline automatically.
        Task { [weak self] in
            // Warm the translation alongside so the hand-off is gapless.
            if voice != .none {
                Task { _ = await AudioCache.ensureLocal(
                    voice: voice, surah: reference.surah, ayah: reference.ayah) }
            }
            let local = await AudioCache.ensureLocal(
                reciter: reciter, surah: reference.surah, ayah: reference.ayah)
            // The token also covers a stop-then-replay of the SAME ayah,
            // which `current == reference` alone would wave through.
            guard let self, self.playbackToken == token, self.current == reference else { return }
            guard let local else {
                self.stop()  // all sources unreachable and not cached
                return
            }
            self.startPlayer(with: local)
        }
    }

    private func startPlayer(with url: URL) {
        isBuffering = false
        let item = makeItem(url: url)
        queuedNext = nil
        clearTranslationState()
        if let player {
            player.removeAllItems()
            player.insert(item, after: nil)
        } else {
            let queue = AVQueuePlayer(items: [item])
            // Every item here is a fully downloaded local file: there is
            // nothing to buffer, so stall-avoidance has no job. Off, play()
            // starts immediately instead of passing through "waiting while
            // evaluating buffering rate" first.
            queue.automaticallyWaitsToMinimizeStalling = false
            player = queue
        }
        if let player, progressPlayer !== player { installProgressObserver(on: player) }
        installEndObserver()
        // Honour a pause the user made WHILE this file was downloading — do
        // not resurrect playback they already stopped. `playAyah` set
        // `isPlaying` when the fetch began; only a tap since then clears it.
        if isPlaying {
            player?.playImmediately(atRate: rate)
        }
        updateNowPlaying()
        stageAfterArabic()
    }

    /// What follows the Arabic ayah in the queue: its translated reading
    /// when a voice is on (then the next pair is only prefetched to disk),
    /// otherwise the next ayah itself for a gapless roll-over.
    private func stageAfterArabic() {
        guard translationVoice != .none else {
            enqueueNextIfNeeded()
            return
        }
        stageTranslation()
        prefetchNextPair()
    }

    private func stageTranslation() {
        guard let cur = current, translationItem == nil else { return }
        let voice = translationVoice
        Task { [weak self] in
            let local = await AudioCache.ensureLocal(voice: voice, surah: cur.surah, ayah: cur.ayah)
            guard let self, self.current == cur, !self.isPlayingTranslation,
                  self.translationItem == nil, self.translationVoice == voice,
                  let player = self.player else { return }
            guard let local else {
                // Unreachable and not cached: the pair is just the Arabic.
                if self.awaitingTranslation {
                    self.awaitingTranslation = false
                    self.pairDidFinish()
                }
                return
            }
            let item = makeItem(url: local)
            player.insert(item, after: nil)
            self.translationItem = item
            if self.awaitingTranslation {
                // Arabic already ended while we were fetching — go now.
                self.awaitingTranslation = false
                self.isPlayingTranslation = true
                player.playImmediately(atRate: self.rate)
                self.updateNowPlaying()
            }
        }
    }

    /// Warms the next ayah's Arabic + translation files on disk.
    private func prefetchNextPair() {
        guard mode != .repeatAyah, mode != .memorize,
              let cur = current, cur.ayah < ayahCount else { return }
        if mode == .pageOnly, let end = pageEndAyah, cur.ayah >= end { return }
        let reciter = self.reciter
        let voice = self.translationVoice
        let next = Reference(surah: cur.surah, ayah: cur.ayah + 1)
        Task {
            _ = await AudioCache.ensureLocal(reciter: reciter, surah: next.surah, ayah: next.ayah)
            _ = await AudioCache.ensureLocal(voice: voice, surah: next.surah, ayah: next.ayah)
        }
    }

    /// Identities of the AVPlayerItems WE made. `.AVPlayerItemDidPlayToEndTime`
    /// is observed with `object: nil` (the item that ends is often already
    /// gone from the queue by the time it posts, so there is nothing stable to
    /// scope it to), which means an athkar recording or an adhan preview
    /// finishing also lands in `itemDidEnd` — and used to silently advance the
    /// recitation by one ayah. Entries are dropped as they end, so this holds
    /// three at most.
    private var ownedItems: Set<ObjectIdentifier> = []

    private func makeItem(url: URL) -> AVPlayerItem {
        let item = AVPlayerItem(url: url)
        ownedItems.insert(ObjectIdentifier(item))
        return item
    }

    /// One persistent end-of-item observer for whatever we play.
    private func installEndObserver() {
        guard endObserver == nil else { return }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main
        ) { [weak self] note in
            let item = note.object as? AVPlayerItem
            Task { @MainActor in self?.itemDidEnd(item) }
        }
    }

    private func itemDidEnd(_ item: AVPlayerItem?) {
        guard current != nil, !isFollowAlong else { return }
        // Somebody else's audio (an athkar recording, an adhan preview) —
        // not ours to advance on. See `ownedItems`.
        guard let item, ownedItems.remove(ObjectIdentifier(item)) != nil else { return }
        if isPlayingTranslation {
            // Translated reading finished: the pair is complete.
            clearTranslationState()
            pairDidFinish()
            return
        }
        if let translationItem, item !== translationItem {
            // Arabic ended with the translation staged behind it — the
            // queue player is already rolling into it.
            isPlayingTranslation = true
            updateNowPlaying()
            return
        }
        if translationVoice != .none, translationItem == nil, !awaitingTranslation {
            // Slow network: the translation isn't in yet; wait for it.
            awaitingTranslation = true
            stageTranslation()
            return
        }
        pairDidFinish()
    }

    /// The ayah (Arabic, plus its translation when on) has finished.
    private func pairDidFinish() {
        guard let cur = current else { return }
        if mode == .repeatAyah || mode == .memorize {
            advanceAfterFinish()
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
        guard queuedNext == nil, translationVoice == .none, mode != .repeatAyah, mode != .memorize,
              let cur = current, cur.ayah < ayahCount else { return }
        if mode == .pageOnly, let end = pageEndAyah, cur.ayah >= end { return }
        let nextRef = Reference(surah: cur.surah, ayah: cur.ayah + 1)
        let reciter = self.reciter
        Task { [weak self] in
            guard let local = await AudioCache.ensureLocal(
                reciter: reciter, surah: nextRef.surah, ayah: nextRef.ayah) else { return }
            guard let self, self.current == cur, self.queuedNext == nil,
                  self.reciter == reciter, self.translationVoice == .none,
                  self.player != nil else { return }
            let item = makeItem(url: local)
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
        installSessionObservers()
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
        // Dragging the lock-screen scrubber.
        commands.changePlaybackPositionCommand.isEnabled = true
        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent
            else { return .commandFailed }
            Task { @MainActor in self?.seek(toSeconds: event.positionTime) }
            return .success
        }
    }

    /// Keeps `isPlaying` honest when iOS pauses us behind our back (phone
    /// call, Siri, alarm) or the output route disappears (headphones
    /// unplugged). Without this the pill shows "pause" while nothing plays
    /// and the first tap after a call is swallowed.
    private func installSessionObservers() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: session, queue: .main
        ) { [weak self] note in
            guard let info = note.userInfo,
                  let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            let options = (info[AVAudioSessionInterruptionOptionKey] as? UInt)
                .map(AVAudioSession.InterruptionOptions.init(rawValue:)) ?? []
            Task { @MainActor in self?.handleInterruption(type, options: options) }
        }
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: session, queue: .main
        ) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: raw),
                  reason == .oldDeviceUnavailable else { return }
            Task { @MainActor in self?.pauseFromSystem() }
        }
        #endif
    }

    #if os(iOS)
    private func handleInterruption(_ type: AVAudioSession.InterruptionType,
                                    options: AVAudioSession.InterruptionOptions) {
        switch type {
        case .began:
            resumeAfterInterruption = isPlaying
            pauseFromSystem()
        case .ended:
            let shouldResume = resumeAfterInterruption && options.contains(.shouldResume)
            resumeAfterInterruption = false
            guard shouldResume, !isPlaying else { return }
            try? AVAudioSession.sharedInstance().setActive(true)
            togglePlayPause()
        @unknown default:
            break
        }
    }
    #endif

    /// Mirrors a pause the system already performed into our state.
    private func pauseFromSystem() {
        guard isPlaying else { return }
        if isFollowAlong { followPlayer?.pause() } else { player?.pause() }
        isPlaying = false
        updateNowPlaying()
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

    // MARK: Surah-wide progress

    /// Rolling mean length of an ayah in the surah being recited. Ayah-by-ayah
    /// playback has no single file to measure, so the surah's total length is
    /// estimated as `mean × ayahCount` and refined as ayat play. Seeded by the
    /// first ayah, so the bar is sensible from the very first second.
    private var measuredSeconds: Double = 0
    private var measuredAyat: Set<Int> = []
    private var meanAyahSeconds: Double? {
        measuredAyat.isEmpty ? nil : measuredSeconds / Double(measuredAyat.count)
    }

    /// Starts the estimate over — a different surah has different ayat.
    private func resetAyahLengthEstimate() {
        measuredSeconds = 0
        measuredAyat.removeAll()
    }

    /// Folds the audible ayah's real length into the mean, once per ayah.
    /// Translated readings are deliberately excluded: they are a second file
    /// over the same ayah, not a unit of the surah.
    private func measureCurrentAyah() {
        guard !isFollowAlong, !isPlayingTranslation,
              let current, !measuredAyat.contains(current.ayah),
              let seconds = player?.currentItem?.duration.seconds,
              seconds.isFinite, seconds > 0 else { return }
        measuredAyat.insert(current.ayah)
        measuredSeconds += seconds
    }

    /// Where the scrubber sits and how long the "track" runs — the WHOLE
    /// surah in both modes. Following along that is literal (one gapless
    /// file); ayah by ayah it is the estimate above, because a bar that
    /// measured one ayah refilled every few seconds and told the user nothing
    /// about where in the surah they were.
    private var nowPlayingTimes: (elapsed: Double, duration: Double)? {
        if isFollowAlong {
            guard let followPlayer, let item = followPlayer.currentItem else { return nil }
            let duration = item.duration.seconds
            let elapsed = followPlayer.currentTime().seconds
            guard duration.isFinite, duration > 0, elapsed.isFinite else { return nil }
            return (max(0, min(elapsed, duration)), duration)
        }
        guard let player, let current else { return nil }
        let intoAyah = player.currentTime().seconds
        guard intoAyah.isFinite else { return nil }
        guard ayahCount > 0, let mean = meanAyahSeconds else { return nil }
        let duration = mean * Double(ayahCount)
        // Cap the within-ayah part at one mean so a long ayah can never push
        // the bar into the next ayah's share and then jump backwards.
        let elapsed = mean * Double(current.ayah - 1) + max(0, min(intoAyah, mean))
        return (min(elapsed, duration), duration)
    }

    private func updateNowPlaying() {
        guard let current else { return }
        measureCurrentAyah()
        let surahName = surahTitleArabic.isEmpty ? surahTitle : surahTitleArabic
        let reference = "\(surahName) · \(current.ayah.arabicIndicDigits)"
        // The recited ayah itself is the title, so the lock screen scrolls
        // the words being read; DB text, passed through untouched.
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: ayahText?(current.surah, current.ayah) ?? reference,
            MPMediaItemPropertyAlbumTitle: reference,
            MPMediaItemPropertyArtist: isPlayingTranslation ? translationVoice.arabicName : reciter.arabicName,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(rate) : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]
        if ayahCount > 0 {
            info[MPNowPlayingInfoPropertyPlaybackQueueCount] = ayahCount
            info[MPNowPlayingInfoPropertyPlaybackQueueIndex] = max(0, current.ayah - 1)
        }
        // Without BOTH of these the lock screen draws no progress bar at all.
        // iOS interpolates between updates using the playback rate above, so
        // 1 Hz is plenty.
        if let times = nowPlayingTimes {
            info[MPMediaItemPropertyPlaybackDuration] = times.duration
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = times.elapsed
        }
        if let artwork = Self.lockScreenArtwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Keeps the scrubber alive: an item's duration only becomes known once
    /// it is ready to play, and gapless roll-overs swap the item without any
    /// call of ours, so neither is covered by the explicit update points.
    private func installProgressObserver(on player: AVPlayer) {
        removeProgressObserver()
        progressPlayer = player
        progressObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 1), queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updateNowPlaying() }
        }
    }

    private func removeProgressObserver() {
        if let progressObserver, let progressPlayer {
            progressPlayer.removeTimeObserver(progressObserver)
        }
        progressObserver = nil
        progressPlayer = nil
    }

    /// Lock-screen / Control Center scrub. The position is on the SURAH
    /// timeline the bar shows, so ayah by ayah it has to be converted back
    /// into an ayah — seeking the few-second file to minute 12 would just end
    /// it. Dragging the bar therefore moves through the surah, which is what
    /// the bar promises.
    public func seek(toSeconds seconds: Double) {
        let position = max(0, seconds)
        if isFollowAlong {
            followPlayer?.seek(to: CMTime(seconds: position, preferredTimescale: 1000),
                               toleranceBefore: .zero, toleranceAfter: .zero) { _ in }
            updateNowPlaying()
            return
        }
        guard let current, ayahCount > 0, let mean = meanAyahSeconds, mean > 0 else { return }
        let target = min(max(Int(position / mean) + 1, 1), ayahCount)
        guard target != current.ayah else { return }
        playAyah(Reference(surah: current.surah, ayah: target))
    }
}

/// Ayah-file storage. Explicit "download surah" files live in Application
/// Support so iOS never purges them (offline-first guarantee); opportunistic
/// playback caching stays in Caches. Reads check both locations.
enum AudioCache {
    /// Opportunistic playback cache — the system may evict this under storage pressure.
    static var directory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("recitations", isDirectory: true)
    }

    /// User-requested downloads — kept until the user deletes them.
    static var downloadsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("recitations", isDirectory: true)
    }

    /// One downloadable ayah file: where it lives on disk and where to get it.
    struct Track: Equatable {
        /// Single path component under the recitations directory.
        let cacheFolder: String
        let urls: [URL]

        init(reciter: Reciter, surah: Int, ayah: Int) {
            cacheFolder = reciter.cacheFolder
            urls = reciter.urls(surah: surah, ayah: ayah)
        }

        /// nil for `.none`.
        init?(voice: TranslationVoice, surah: Int, ayah: Int) {
            guard let folder = voice.cacheFolder else { return nil }
            cacheFolder = folder
            urls = voice.urls(surah: surah, ayah: ayah)
        }
    }

    private static func fileURL(in base: URL, track: Track, surah: Int, ayah: Int) -> URL {
        base
            .appendingPathComponent(track.cacheFolder, isDirectory: true)
            .appendingPathComponent(Reciter.fileName(surah: surah, ayah: ayah))
    }

    /// Permanent location for an explicitly downloaded ayah.
    static func downloadedURL(reciter: Reciter, surah: Int, ayah: Int) -> URL {
        downloadedURL(track: Track(reciter: reciter, surah: surah, ayah: ayah), surah: surah, ayah: ayah)
    }

    /// Permanent location for an explicitly downloaded translated reading.
    static func downloadedURL(voice: TranslationVoice, surah: Int, ayah: Int) -> URL? {
        Track(voice: voice, surah: surah, ayah: ayah).map { downloadedURL(track: $0, surah: surah, ayah: ayah) }
    }

    static func downloadedURL(track: Track, surah: Int, ayah: Int) -> URL {
        fileURL(in: downloadsDirectory, track: track, surah: surah, ayah: ayah)
    }

    /// Opportunistic-cache location (what playback writes to).
    static func cachedURL(track: Track, surah: Int, ayah: Int) -> URL {
        fileURL(in: directory, track: track, surah: surah, ayah: ayah)
    }

    /// An existing local file for this ayah — permanent download first, then cache.
    static func localURL(reciter: Reciter, surah: Int, ayah: Int) -> URL? {
        localURL(track: Track(reciter: reciter, surah: surah, ayah: ayah), surah: surah, ayah: ayah)
    }

    static func localURL(track: Track, surah: Int, ayah: Int) -> URL? {
        [downloadedURL(track: track, surah: surah, ayah: ayah),
         cachedURL(track: track, surah: surah, ayah: ayah)]
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Returns a playable local file: an existing copy if present, else downloads
    /// from the first reachable source (EveryAyah → mirror) and stores it.
    /// `persistent` marks a user-requested download (purge-proof storage).
    static func ensureLocal(
        reciter: Reciter, surah: Int, ayah: Int, persistent: Bool = false
    ) async -> URL? {
        await ensureLocal(track: Track(reciter: reciter, surah: surah, ayah: ayah),
                          surah: surah, ayah: ayah, persistent: persistent)
    }

    /// Translated reading for the ayah; nil for `.none` or when unreachable.
    static func ensureLocal(
        voice: TranslationVoice, surah: Int, ayah: Int, persistent: Bool = false
    ) async -> URL? {
        guard let track = Track(voice: voice, surah: surah, ayah: ayah) else { return nil }
        return await ensureLocal(track: track, surah: surah, ayah: ayah, persistent: persistent)
    }

    static func ensureLocal(
        track: Track, surah: Int, ayah: Int, persistent: Bool = false
    ) async -> URL? {
        let destination = persistent
            ? downloadedURL(track: track, surah: surah, ayah: ayah)
            : cachedURL(track: track, surah: surah, ayah: ayah)
        if let existing = localURL(track: track, surah: surah, ayah: ayah) {
            guard persistent, existing != destination else { return existing }
            // Promote a cache hit into permanent storage instead of re-downloading.
            guard prepare(destination), (try? FileManager.default.moveItem(at: existing, to: destination)) != nil
            else { return existing }
            return destination
        }
        for remote in track.urls {
            guard let (temp, response) = try? await URLSession.shared.download(from: remote),
                  (response as? HTTPURLResponse)?.statusCode == 200
            else { continue }
            guard prepare(destination),
                  (try? FileManager.default.moveItem(at: temp, to: destination)) != nil
            else { continue }
            return destination
        }
        return nil
    }

    /// Creates the parent directory (excluded from backup) and clears any stale file.
    private static func prepare(_ file: URL) -> Bool {
        var parent = file.deletingLastPathComponent()
        guard (try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)) != nil
        else { return false }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? parent.setResourceValues(values)
        try? FileManager.default.removeItem(at: file)
        return true
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
