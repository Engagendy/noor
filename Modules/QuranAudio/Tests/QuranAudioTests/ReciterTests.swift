import XCTest
@testable import QuranAudio

final class ReciterTests: XCTestCase {
    func testAyahFileNaming() {
        XCTAssertEqual(Reciter.fileName(surah: 1, ayah: 1), "001001.mp3")
        XCTAssertEqual(Reciter.fileName(surah: 2, ayah: 255), "002255.mp3")
        XCTAssertEqual(Reciter.fileName(surah: 114, ayah: 6), "114006.mp3")
    }

    func testRemoteURLs() {
        XCTAssertEqual(
            Reciter.alafasy.url(surah: 1, ayah: 7).absoluteString,
            "https://everyayah.com/data/Alafasy_128kbps/001007.mp3")
    }
}
