import XCTest
@testable import QuranAudio

final class ReciterTests: XCTestCase {
    func testAyahFileNaming() {
        XCTAssertEqual(Reciter.fileName(surah: 1, ayah: 1), "001001.mp3")
        XCTAssertEqual(Reciter.fileName(surah: 2, ayah: 255), "002255.mp3")
        XCTAssertEqual(Reciter.fileName(surah: 114, ayah: 6), "114006.mp3")
    }

    func testRemoteURLsWithFallback() {
        let urls = Reciter.alafasy.urls(surah: 1, ayah: 7)
        XCTAssertEqual(urls.count, 2)
        XCTAssertEqual(urls[0].absoluteString,
                       "https://everyayah.com/data/Alafasy_128kbps/001007.mp3")
        XCTAssertEqual(urls[1].absoluteString,
                       "https://mirrors.quranicaudio.com/everyayah/Alafasy_128kbps/001007.mp3")
        // Every reciter has a fallback.
        for reciter in Reciter.allCases {
            XCTAssertEqual(reciter.urls(surah: 2, ayah: 255).count, 2)
        }
    }
}
