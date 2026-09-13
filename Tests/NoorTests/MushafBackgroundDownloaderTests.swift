import XCTest
import QuranReader
@testable import Noor

/// The automatic Madani page-font download: its order, its skip-if-present
/// rule and its Wi-Fi gate. The transfers themselves run in a background
/// URLSession and are not exercised here.
final class MushafBackgroundDownloaderTests: XCTestCase {
    private let total = MushafBackgroundDownloader.totalPages

    // MARK: Order — the reader's last page first, then outward

    func testOrderStartsAtLastPageAndAlternatesOutward() {
        let order = MushafBackgroundDownloader.order(from: 300)
        XCTAssertEqual(Array(order.prefix(7)), [300, 301, 299, 302, 298, 303, 297])
    }

    func testOrderCoversEveryPageExactlyOnce() {
        for start in [1, 2, 77, 300, 603, 604] {
            let order = MushafBackgroundDownloader.order(from: start)
            XCTAssertEqual(order.count, total, "start \(start)")
            XCTAssertEqual(Set(order), Set(1...total), "start \(start)")
        }
    }

    func testOrderFromFirstPageRunsForward() {
        XCTAssertEqual(Array(MushafBackgroundDownloader.order(from: 1).prefix(4)), [1, 2, 3, 4])
    }

    func testOrderFromLastPageRunsBackward() {
        XCTAssertEqual(Array(MushafBackgroundDownloader.order(from: 604).prefix(4)), [604, 603, 602, 601])
    }

    /// A stored page of 0 (never read) or out of range must not break the
    /// queue: it clamps to the mushaf.
    func testOrderClampsAnOutOfRangeStart() {
        XCTAssertEqual(MushafBackgroundDownloader.order(from: 0).first, 1)
        XCTAssertEqual(MushafBackgroundDownloader.order(from: 9_999).first, 604)
        XCTAssertEqual(MushafBackgroundDownloader.order(from: 0).count, total)
    }

    // MARK: Skip if present — never re-download a page that is on disk

    func testOrderSkipsCachedPages() {
        let cached: Set<Int> = [300, 301, 298, 1, 604]
        let order = MushafBackgroundDownloader.order(from: 300, skipping: cached)
        XCTAssertTrue(Set(order).isDisjoint(with: cached))
        XCTAssertEqual(order.count, total - cached.count)
        XCTAssertEqual(Array(order.prefix(3)), [299, 302, 303])
    }

    func testOrderIsEmptyWhenEverythingIsCached() {
        XCTAssertTrue(MushafBackgroundDownloader.order(from: 50, skipping: Set(1...total)).isEmpty)
    }

    func testCachedPagesReadsOnlyTheVariantsOwnFiles() throws {
        let directory = PageFontStore.cacheDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let variant = "test-\(UUID().uuidString)"
        let names = [PageFontStore.fileName(page: 12, variant: variant),
                     PageFontStore.fileName(page: 340, variant: variant)]
        for name in names {
            try Data("not a font".utf8).write(to: directory.appendingPathComponent(name))
        }
        defer {
            for name in names { try? FileManager.default.removeItem(at: directory.appendingPathComponent(name)) }
        }
        XCTAssertEqual(PageFontStore.cachedPages(variant: variant), [12, 340])
        XCTAssertEqual(PageFontStore.cachedCount(variant: variant), 2)
        XCTAssertTrue(PageFontStore.isCached(page: 12, variant: variant))
        XCTAssertFalse(PageFontStore.isCached(page: 13, variant: variant))
        XCTAssertFalse(PageFontStore.cachedPages(variant: "other-\(variant)").contains(12))
    }

    // MARK: Wi-Fi gate

    func testWiFiOnlyRequestRefusesCellularExpensiveAndConstrainedPaths() {
        let request = MushafBackgroundDownloader.request(page: 76, variant: "v2", wifiOnly: true)
        XCTAssertFalse(request.allowsCellularAccess)
        XCTAssertFalse(request.allowsExpensiveNetworkAccess)
        XCTAssertFalse(request.allowsConstrainedNetworkAccess)
        XCTAssertEqual(request.networkServiceType, .background)
    }

    func testCellularOptInAllowsEveryPath() {
        let request = MushafBackgroundDownloader.request(page: 76, variant: "v2", wifiOnly: false)
        XCTAssertTrue(request.allowsCellularAccess)
        XCTAssertTrue(request.allowsExpensiveNetworkAccess)
        XCTAssertTrue(request.allowsConstrainedNetworkAccess)
    }

    func testRequestTargetsTheDocumentedHostForEachVariant() throws {
        let v2 = try XCTUnwrap(MushafBackgroundDownloader.request(page: 76, variant: "v2", wifiOnly: true).url)
        let v1 = try XCTUnwrap(MushafBackgroundDownloader.request(page: 76, variant: "v1", wifiOnly: true).url)
        XCTAssertEqual(v2.host, "raw.githubusercontent.com")
        XCTAssertEqual(v2.lastPathComponent, "QCF2076.ttf")
        XCTAssertEqual(v1.lastPathComponent, "QCF_P076.TTF")
    }

    func testAutomaticAndWiFiOnlyAreOnByDefault() {
        let defaults = UserDefaults(suiteName: "MushafBackgroundDownloaderTests")!
        defaults.removePersistentDomain(forName: "MushafBackgroundDownloaderTests")
        XCTAssertTrue(MushafBackgroundDownloader.isAutomatic(defaults))
        XCTAssertTrue(MushafBackgroundDownloader.isWiFiOnly(defaults))
        defaults.set(false, forKey: MushafBackgroundDownloader.wifiOnlyKey)
        defaults.set(false, forKey: MushafBackgroundDownloader.autoKey)
        XCTAssertFalse(MushafBackgroundDownloader.isAutomatic(defaults))
        XCTAssertFalse(MushafBackgroundDownloader.isWiFiOnly(defaults))
    }
}
