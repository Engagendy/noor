import Foundation
import Observation

/// Fetches every Madani page font the reader does not yet have, on its own,
/// until all 604 are on disk — so a page is never "unavailable" merely
/// because nobody opened it yet.
///
/// Wiring:
/// - A background `URLSession` (identifier `Self.sessionIdentifier`) carries
///   the requests, so the transfers continue after the user leaves the app
///   and the app is relaunched to hear about them (see
///   `application(_:handleEventsForBackgroundURLSession:completionHandler:)`
///   in the app delegate, which hands `backgroundCompletionHandler` here).
/// - Only a small window of pages is queued at a time (`windowSize`): the
///   job stays sequential and low priority, and the reader's own on-demand
///   fetch (`PageFontStore.ensure(page:)`, a foreground session) is never
///   behind hundreds of queued transfers. Each completion tops the window up
///   — also when the completion arrives as a background wake.
/// - Order: the reader's last page first, then alternately outward (next,
///   previous, next-but-one, …) — the pages the user is most likely to open.
/// - Idempotent: pages already on disk are skipped; safe to re-run on every
///   launch until `cachedCount() == 604`.
/// - Wi-Fi only by default: enforced on each request
///   (`allowsCellularAccess` etc.), so the system itself waits for Wi-Fi.
/// - Follows the chosen typeface (`mushaf.font`); a change re-targets the job.
///
/// Nothing but the font requests to the documented host leaves the device.
@Observable
@MainActor
public final class MushafBackgroundDownloader {
    public static let shared = MushafBackgroundDownloader()

    /// Posted on the main queue for every page the job lands; `userInfo["page"]`.
    nonisolated public static let pageDownloaded = Notification.Name("noor.mushaf.pageDownloaded")

    nonisolated public static let sessionIdentifier = "com.engagendy.Noor.mushaf-fonts"
    nonisolated public static let totalPages = 604

    /// Settings keys (shared with the Settings row).
    nonisolated public static let autoKey = "mushaf.autoDownload"
    nonisolated public static let wifiOnlyKey = "mushaf.wifiOnly"

    /// Pages queued in the background session at once while the app is in
    /// front. Small on purpose: the job stays sequential, re-targeting is
    /// cheap, and the reader's own fetch never shares the link with more
    /// than this many transfers.
    nonisolated static let windowSize = 3
    /// The window once the app has left the screen. The system wakes a
    /// suspended app for its session's events only about once a minute
    /// (measured: 3 pages per wake with the small window, i.e. hours for a
    /// mushaf), so a large batch is handed to the transfer daemon to carry
    /// on unattended (~60 MB at print quality). Connections per host stay
    /// capped at two, so it is still a trickle on the link.
    nonisolated static let backgroundWindowSize = 100

    /// Pages on disk for the current typeface (live; drives Settings).
    public private(set) var cachedCount = 0
    /// True while pages are queued in the session.
    public private(set) var isRunning = false
    /// Pages that failed this run (retried with backoff, then left to the
    /// next launch).
    public private(set) var failedThisRun: Set<Int> = []

    /// Handed over by the app delegate on a background relaunch; called once
    /// the session has delivered all its events.
    public var backgroundCompletionHandler: (() -> Void)?

    /// Whether the app has left the screen (scene phase, or a background
    /// wake) — decides the window size. Set from the scene phase handler.
    public var isInBackground = false {
        didSet { if isInBackground != oldValue, isRunning { fill() } }
    }

    private var session: URLSession?
    private let delegate = SessionDelegate()
    private var queue: [Int] = []
    private var inFlight: Set<Int> = []
    private var stoppedByUser = false
    private var retryTask: Task<Void, Never>?
    private var retryCount = 0
    private var targetVariant = PageFontStore.variant
    private var settingsObserver: (any NSObjectProtocol)?

    private init() {
        cachedCount = PageFontStore.cachedCount()
    }

    // MARK: Settings

    nonisolated public static func isAutomatic(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: autoKey) as? Bool ?? true
    }

    nonisolated public static func isWiFiOnly(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: wifiOnlyKey) as? Bool ?? true
    }

    private struct Settings: Equatable {
        var variant: String
        var automatic: Bool
        var wifiOnly: Bool
        static var current: Settings {
            Settings(variant: PageFontStore.variant,
                     automatic: isAutomatic(),
                     wifiOnly: isWiFiOnly())
        }
    }
    private var lastSettings = Settings.current

    /// The request for one page, carrying the Wi-Fi gate: with `wifiOnly`
    /// the transfer is refused cellular, expensive (hotspot) and constrained
    /// (Low Data Mode) paths, and a background session simply waits for an
    /// allowed one.
    nonisolated public static func request(page: Int, variant: String, wifiOnly: Bool) -> URLRequest {
        var request = URLRequest(url: PageFontStore.remoteURL(page: page, variant: variant))
        request.allowsCellularAccess = !wifiOnly
        request.allowsExpensiveNetworkAccess = !wifiOnly
        request.allowsConstrainedNetworkAccess = !wifiOnly
        request.networkServiceType = .background
        return request
    }

    /// Every page from `start` outward — start, next, previous, next-but-one,
    /// … — minus `cached`. Covers all `total` pages exactly once.
    nonisolated public static func order(from start: Int, skipping cached: Set<Int> = [], total: Int = totalPages) -> [Int] {
        let anchor = min(max(start, 1), total)
        var pages: [Int] = []
        pages.reserveCapacity(total)
        if !cached.contains(anchor) { pages.append(anchor) }
        for distance in 1...max(total, 2) {
            let forward = anchor + distance
            let backward = anchor - distance
            if forward > total && backward < 1 { break }
            if forward <= total && !cached.contains(forward) { pages.append(forward) }
            if backward >= 1 && !cached.contains(backward) { pages.append(backward) }
        }
        return pages
    }

    // MARK: Control

    /// Called once the main app is on screen (never during onboarding), and
    /// on every launch: starts the automatic job when the setting allows.
    public func startIfEnabled() {
        observeSettings()
        guard Self.isAutomatic() else { return }
        start(manual: false)
    }

    /// The Settings button: drives the very same queue.
    public func startManually() {
        stoppedByUser = false
        start(manual: true)
    }

    /// Stops the job until the next launch (or the next manual start).
    public func stop() {
        stoppedByUser = true
        retryTask?.cancel()
        retryTask = nil
        queue = []
        cancelInFlight()
        isRunning = false
    }

    /// Cancels the session's transfers. Cancellation is asynchronous: the
    /// task reports `NSURLErrorCancelled` a moment later, which `finished`
    /// treats as "put it back" (unless the user stopped the job), so a page
    /// that was mid-transfer is neither lost nor stuck in `inFlight`.
    private func cancelInFlight() {
        session?.getAllTasks { tasks in
            for task in tasks { task.cancel() }
        }
        inFlight = []
    }

    /// The app was relaunched (or woken) for the background session: make
    /// sure the session exists so its delegate receives the events.
    public func reconnect() {
        observeSettings()
        isInBackground = true
        _ = makeSession()
    }

    private func start(manual: Bool) {
        if !manual, stoppedByUser { return }
        targetVariant = PageFontStore.variant
        cachedCount = PageFontStore.cachedCount(variant: targetVariant)
        guard cachedCount < Self.totalPages else {
            isRunning = false
            return
        }
        let session = makeSession()
        retryTask?.cancel()
        retryTask = nil
        retryCount = 0
        failedThisRun = []
        // Resume what the session still carries from a previous launch
        // rather than queueing those pages twice.
        session.getAllTasks { [weak self] tasks in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let carried = tasks
                    .filter { $0.state == .running || $0.state == .suspended }
                    .filter { Self.variant(of: $0) == self.targetVariant }
                    .compactMap { Self.page(of: $0) }
                self.rebuildQueue(carried: Set(carried))
            }
        }
    }

    private func rebuildQueue(carried: Set<Int>) {
        let cached = PageFontStore.cachedPages(variant: targetVariant)
        cachedCount = cached.count
        inFlight = carried
        let last = max(1, UserDefaults.standard.integer(forKey: "reader.lastPage"))
        queue = Self.order(from: last, skipping: cached.union(carried).union(failedThisRun))
        isRunning = !(queue.isEmpty && inFlight.isEmpty)
        fill()
    }

    /// Tops the session up to the window for the app's state.
    private func fill() {
        guard let session else { return }
        let window = isInBackground ? Self.backgroundWindowSize : Self.windowSize
        while inFlight.count < window, let page = queue.first {
            queue.removeFirst()
            if PageFontStore.isCached(page: page, variant: targetVariant) {
                continue
            }
            let task = session.downloadTask(with: Self.request(
                page: page, variant: targetVariant, wifiOnly: Self.isWiFiOnly()))
            task.taskDescription = Self.description(page: page, variant: targetVariant)
            task.priority = URLSessionTask.lowPriority
            inFlight.insert(page)
            task.resume()
        }
        if inFlight.isEmpty {
            finishRun()
        }
    }

    private func finishRun() {
        cachedCount = PageFontStore.cachedCount(variant: targetVariant)
        if cachedCount >= Self.totalPages || failedThisRun.isEmpty || stoppedByUser {
            isRunning = false
            return
        }
        // Transient failures: try the leftovers again with backoff
        // (30 s, 60 s, 120 s, 240 s), then leave them to the next launch.
        guard retryCount < 4 else {
            isRunning = false
            return
        }
        let delay = 30.0 * pow(2.0, Double(retryCount))
        retryCount += 1
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            let retry = self.failedThisRun
            self.failedThisRun = []
            self.queue = Self.order(from: max(1, UserDefaults.standard.integer(forKey: "reader.lastPage")),
                                    skipping: Set(1...Self.totalPages).subtracting(retry))
            self.fill()
        }
    }

    // MARK: Session

    private func makeSession() -> URLSession {
        if let session { return session }
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        configuration.sessionSendsLaunchEvents = true
        // Not discretionary: the job must make progress while the user is
        // in the app, not only when the device is charging overnight. The
        // Wi-Fi gate is on the requests themselves.
        configuration.isDiscretionary = false
        configuration.httpMaximumConnectionsPerHost = 2
        delegate.owner = self
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        self.session = session
        return session
    }

    private func observeSettings() {
        guard settingsObserver == nil else { return }
        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.settingsChanged() }
        }
    }

    /// Typeface, automatic or Wi-Fi setting changed: re-target the queue.
    /// Any other defaults write (the reader stores its page on every turn)
    /// is ignored.
    private func settingsChanged() {
        let now = Settings.current
        guard now != lastSettings else { return }
        let variantChanged = now.variant != lastSettings.variant
        let wifiChanged = now.wifiOnly != lastSettings.wifiOnly
        let automaticTurnedOn = now.automatic && !lastSettings.automatic
        lastSettings = now
        if variantChanged || wifiChanged {
            // Old-variant transfers are pointless; old requests carry the
            // old cellular flags. Both are re-queued from disk state.
            cancelInFlight()
            queue = []
            isRunning = false
            cachedCount = PageFontStore.cachedCount()
        }
        if automaticTurnedOn { stoppedByUser = false }
        if now.automatic {
            if !isRunning { start(manual: false) }
        } else {
            // Automatic off: nothing new is queued; what is in flight
            // (at most `windowSize` pages) finishes.
            queue = []
        }
    }

    // MARK: Task bookkeeping

    private static func description(page: Int, variant: String) -> String {
        "\(variant)|\(page)"
    }

    nonisolated private static func page(of task: URLSessionTask) -> Int? {
        guard let description = task.taskDescription,
              let separator = description.firstIndex(of: "|")
        else { return nil }
        return Int(description[description.index(after: separator)...])
    }

    nonisolated private static func variant(of task: URLSessionTask) -> String? {
        guard let description = task.taskDescription,
              let separator = description.firstIndex(of: "|")
        else { return nil }
        return String(description[..<separator])
    }

    fileprivate enum Outcome { case done, failed, cancelled }

    fileprivate func finished(page: Int, variant: String, outcome: Outcome) {
        guard variant == targetVariant else { return }
        inFlight.remove(page)
        switch outcome {
        case .done:
            cachedCount = PageFontStore.cachedCount(variant: targetVariant)
            NotificationCenter.default.post(name: Self.pageDownloaded, object: nil, userInfo: ["page": page])
        case .failed:
            failedThisRun.insert(page)
        case .cancelled:
            if !stoppedByUser, !queue.contains(page),
               !PageFontStore.isCached(page: page, variant: targetVariant) {
                queue.insert(page, at: 0)
            }
        }
        if stoppedByUser {
            if inFlight.isEmpty { isRunning = false }
            return
        }
        fill()
    }

    fileprivate func sessionDidFinishEvents() {
        let handler = backgroundCompletionHandler
        backgroundCompletionHandler = nil
        handler?()
    }

    /// Receives the background session's callbacks on its own queue and
    /// moves each finished file into the cache synchronously (the temp file
    /// is gone once the callback returns), then reports to the main actor.
    private final class SessionDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
        weak var owner: MushafBackgroundDownloader?

        func urlSession(_ session: URLSession,
                        downloadTask: URLSessionDownloadTask,
                        didFinishDownloadingTo location: URL) {
            guard let page = MushafBackgroundDownloader.page(of: downloadTask),
                  let variant = MushafBackgroundDownloader.variant(of: downloadTask)
            else { return }
            let status = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0
            let destination = PageFontStore.localURL(page: page, variant: variant)
            var success = false
            if status == 200 {
                let fileManager = FileManager.default
                try? fileManager.createDirectory(
                    at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                if fileManager.fileExists(atPath: destination.path) {
                    // The reader fetched it meanwhile; keep that copy.
                    success = true
                } else if (try? fileManager.moveItem(at: location, to: destination)) != nil {
                    success = true
                } else {
                    success = fileManager.fileExists(atPath: destination.path)
                }
            }
            report(page: page, variant: variant, outcome: success ? .done : .failed)
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
            // A finished transfer (whatever its status) was reported from
            // didFinishDownloadingTo; only transport failures are left.
            // Cancellation is ours (stop / re-target), not a failure.
            guard let error,
                  let page = MushafBackgroundDownloader.page(of: task),
                  let variant = MushafBackgroundDownloader.variant(of: task)
            else { return }
            let cancelled = (error as NSError).code == NSURLErrorCancelled
            report(page: page, variant: variant, outcome: cancelled ? .cancelled : .failed)
        }

        func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
            Task { @MainActor [weak self] in
                self?.owner?.sessionDidFinishEvents()
            }
        }

        private func report(page: Int, variant: String, outcome: Outcome) {
            Task { @MainActor [weak self] in
                self?.owner?.finished(page: page, variant: variant, outcome: outcome)
            }
        }
    }
}
