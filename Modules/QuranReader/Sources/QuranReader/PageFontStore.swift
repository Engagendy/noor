import CoreText
import Foundation
import Observation

/// Downloads and registers the per-page QCF v1 fonts (KFGQPC, ~42 KB each)
/// on demand, cached in Application Support — each page is offline after its
/// first view. Source: mustafa0x/qpc-fonts mirror (see LICENSES.md).
@Observable
@MainActor
public final class PageFontStore {
    public private(set) var readyPages: Set<Int> = []
    public private(set) var failedPages: Set<Int> = []
    private var inFlight: Set<Int> = []

    public init() {}

    public static func fontName(page: Int) -> String {
        String(format: "AQF_P%03d_HA", page)
    }

    private static func localURL(page: Int) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("pagefonts/page_\(page).ttf")
    }

    public func isReady(page: Int) -> Bool {
        readyPages.contains(page)
    }

    /// Ensures the font for `page` is downloaded and registered.
    public func ensure(page: Int) async {
        guard page >= 1, page <= 604,
              !readyPages.contains(page), !inFlight.contains(page) else { return }
        inFlight.insert(page)
        defer { inFlight.remove(page) }

        let local = Self.localURL(page: page)
        if !FileManager.default.fileExists(atPath: local.path) {
            let remote = URL(string:
                "https://raw.githubusercontent.com/mustafa0x/qpc-fonts/master/mushaf-v1.5/page_\(page).ttf")!
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
