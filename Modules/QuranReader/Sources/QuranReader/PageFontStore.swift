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
    private var inFlight: Set<Int> = []

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
            ? String(format: "AQF_P%03d_HA", page)
            : String(format: "QCF2%03d", page)
    }

    private static func localURL(page: Int) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("pagefonts/\(variant)_page_\(page).ttf")
    }

    private static func remoteURL(page: Int) -> URL {
        variant == "v1"
            ? URL(string: "https://raw.githubusercontent.com/mustafa0x/qpc-fonts/master/mushaf-v1.5/page_\(page).ttf")!
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
        return files.filter { $0.hasPrefix("\(variant)_page_") }.count
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

    /// Ensures the font for `page` is downloaded and registered.
    public func ensure(page: Int) async {
        refreshVariantIfNeeded()
        guard page >= 1, page <= 604,
              !readyPages.contains(page), !inFlight.contains(page) else { return }
        inFlight.insert(page)
        defer { inFlight.remove(page) }

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
        // Registration failure for an already-registered font is fine.
        CTFontManagerRegisterFontsForURL(local as CFURL, .process, nil)
        failedPages.remove(page)
        readyPages.insert(page)
    }
}
