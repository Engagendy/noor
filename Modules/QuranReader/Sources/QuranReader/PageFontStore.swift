import CoreText
import Foundation
import Observation

/// Downloads and registers the per-page QCF v2 fonts (KFGQPC — the exact
/// printed Madani mushaf typeface, ~600 KB each) on demand, cached in
/// Application Support — each page is offline after its first view.
/// Source: mustafa0x/qpc-fonts mirror (see LICENSES.md).
@Observable
@MainActor
public final class PageFontStore {
    public private(set) var readyPages: Set<Int> = []
    public private(set) var failedPages: Set<Int> = []
    /// In-progress downloads, keyed by page. A second caller for the same
    /// page (e.g. the page's own view arriving while a neighbour's prefetch
    /// is running) awaits the existing task instead of returning early.
    private var inFlight: [Int: Task<Void, Never>] = [:]

    // Full-mushaf background download state.
    public private(set) var bulkProgress: Int = 0     // pages on disk
    public private(set) var bulkRunning = false

    public init() {}

    /// Mushaf typeface quality: "v1" = compact (~45 MB total, QCF v1.5),
    /// "v2" = high (~350 MB, QCF v2 print). Both official KFGQPC.
    public static var variant: String {
        UserDefaults.standard.string(forKey: "mushaf.font") ?? "v2"
    }

    public static func fontName(page: Int) -> String {
        variant == "v1"
            ? String(format: "QCF_P%03d", page)
            : String(format: "QCF2%03d", page)
    }

    /// The page's font built straight from the file on disk.
    ///
    /// `CTFontCreateWithName` silently substitutes a system font when the name
    /// does not resolve, and a substitute measures a fraction of the real
    /// width — which then reads as "this line already fits" and the page
    /// renders unjustified and overflowing. Going through the file makes a
    /// wrong font impossible: the caller gets the right font or nothing.
    public static func measurementFont(page: Int, size: CGFloat) -> CTFont? {
        let descriptor: CTFontDescriptor
        if let cached = descriptorCache[page] {
            descriptor = cached
        } else {
            guard let found = CTFontManagerCreateFontDescriptorsFromURL(
                    localURL(page: page) as CFURL) as? [CTFontDescriptor],
                  let first = found.first
            else { return nil }
            descriptorCache[page] = first
            descriptor = first
        }
        return CTFontCreateWithFontDescriptor(descriptor, size, nil)
    }

    /// Parsing the file on every measurement would be far too slow.
    nonisolated(unsafe) private static var descriptorCache: [Int: CTFontDescriptor] = [:]

    private static func localURL(page: Int) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        // v1b: cache key bumped after the v1.5 mispairing (resequenced
        // glyph codes rendered shifted text — files must not be reused).
        let prefix = variant == "v1" ? "v1b" : variant
        return base.appendingPathComponent("pagefonts/\(prefix)_page_\(page).ttf")
    }

    /// One-time cleanup of caches from the v1.5 experiment.
    public static func purgeStaleCaches() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pagefonts")
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return }
        for file in files where file.hasPrefix("v1_page_") || (file.hasPrefix("page_") && file.hasSuffix(".ttf")) {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(file))
        }
    }

    private static func remoteURL(page: Int) -> URL {
        variant == "v1"
            ? URL(string: String(format:
                "https://raw.githubusercontent.com/mustafa0x/qpc-fonts/master/mushaf/QCF_P%03d.TTF", page))!
            : URL(string: String(format:
                "https://raw.githubusercontent.com/mustafa0x/qpc-fonts/master/mushaf-v2/QCF2%03d.ttf", page))!
    }

    private var loadedVariant = PageFontStore.variant

    public func isReady(page: Int) -> Bool {
        refreshVariantIfNeeded()
        return readyPages.contains(page)
    }

    /// Quality switched in Settings → forget registrations for the old set.
    private func refreshVariantIfNeeded() {
        let current = Self.variant
        if current != loadedVariant {
            loadedVariant = current
            readyPages = []
            failedPages = []
        }
    }

    /// How many page fonts are already on disk (cheap directory scan).
    public static func cachedCount() -> Int {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pagefonts")
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        let prefix = variant == "v1" ? "v1b" : variant
        return files.filter { $0.hasPrefix("\(prefix)_page_") }.count
    }

    /// Downloads every remaining page font (~600 KB each, ≤604 total) so
    /// the whole printed mushaf is available offline. Resumable: already
    /// cached pages are skipped instantly.
    public func downloadAll() async {
        guard !bulkRunning else { return }
        bulkRunning = true
        defer { bulkRunning = false }
        bulkProgress = Self.cachedCount()
        for page in 1...604 {
            if Task.isCancelled { return }
            let local = Self.localURL(page: page)
            if FileManager.default.fileExists(atPath: local.path) { continue }
            await ensure(page: page)
            bulkProgress = Self.cachedCount()
        }
    }

    /// Ensures the font for `page` is downloaded and registered. Returns
    /// only once the page is ready or has failed — even when the work was
    /// started by another caller.
    public func ensure(page: Int) async {
        refreshVariantIfNeeded()
        guard page >= 1, page <= 604, !readyPages.contains(page) else { return }
        if let existing = inFlight[page] {
            await existing.value
            return
        }
        // A retry after a failure shows the spinner, not the stale placeholder.
        failedPages.remove(page)
        // Unstructured so a cancelled awaiter (view swiped away) does not
        // abort a download other pages may be waiting on.
        let task = Task { await self.fetchAndRegister(page: page) }
        inFlight[page] = task
        await task.value
        if inFlight[page] == task { inFlight[page] = nil }
    }

    private func fetchAndRegister(page: Int) async {
        let local = Self.localURL(page: page)
        if !FileManager.default.fileExists(atPath: local.path) {
            let remote = Self.remoteURL(page: page)
            guard let (temp, response) = try? await URLSession.shared.download(from: remote),
                  (response as? HTTPURLResponse)?.statusCode == 200
            else {
                failedPages.insert(page)
                return
            }
            try? FileManager.default.createDirectory(
                at: local.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: local)
            guard (try? FileManager.default.moveItem(at: temp, to: local)) != nil else {
                failedPages.insert(page)
                return
            }
        }
        guard Self.register(url: local) else {
            // The cached file is unusable (truncated move, non-font body).
            // Drop it so the next ensure() re-downloads instead of rendering
            // tofu forever.
            try? FileManager.default.removeItem(at: local)
            failedPages.insert(page)
            return
        }
        failedPages.remove(page)
        readyPages.insert(page)
    }

    /// Registers a font file with the process font manager. Returns false
    /// only for a genuinely bad file — an already-registered font counts as
    /// success.
    private static func register(url: URL) -> Bool {
        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) { return true }
        guard let cfError = error?.takeRetainedValue() else { return false }
        let code = CFErrorGetCode(cfError)
        return code == CTFontManagerError.alreadyRegistered.rawValue
    }
}
