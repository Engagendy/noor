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

    // MARK: - Warsh

    func testWarshReciters() {
        XCTAssertEqual(Reciter.all(riwayah: .warsh), [.dosaryWarsh, .jazaeryWarsh])
        XCTAssertEqual(Reciter.all(riwayah: .hafs).count + 2, Reciter.allCases.count)
        XCTAssertTrue(Reciter.all(riwayah: .hafs).allSatisfy { $0.riwayah == .hafs })
        XCTAssertEqual(Reciter.alafasy.riwayah, .hafs)
        XCTAssertNil(Reciter.dosaryWarsh.qfTimingId)
        XCTAssertNil(Reciter.jazaeryWarsh.qfTimingId)
        XCTAssertEqual(Reciter.dosaryWarsh.flag, "🇸🇦")
        XCTAssertEqual(Reciter.jazaeryWarsh.flag, "🇩🇿")
        XCTAssertEqual(Reciter.dosaryWarsh.arabicName, "إبراهيم الدوسري (ورش)")
        XCTAssertEqual(Reciter.jazaeryWarsh.englishName, "Yassin Al-Jazaery (Warsh)")
    }

    func testWarshNestedFolderURLs() {
        let urls = Reciter.dosaryWarsh.urls(surah: 1, ayah: 1)
        XCTAssertEqual(urls[0].absoluteString,
                       "https://everyayah.com/data/warsh/warsh_ibrahim_aldosary_128kbps/001001.mp3")
        XCTAssertEqual(urls[1].absoluteString,
                       "https://mirrors.quranicaudio.com/everyayah/warsh/warsh_ibrahim_aldosary_128kbps/001001.mp3")
        XCTAssertEqual(Reciter.jazaeryWarsh.url(surah: 114, ayah: 6).absoluteString,
                       "https://everyayah.com/data/warsh/warsh_yassin_al_jazaery_64kbps/114006.mp3")
    }

    func testCachePathsNeverNestFolders() {
        for reciter in Reciter.allCases {
            XCTAssertFalse(reciter.cacheFolder.contains("/"), reciter.rawValue)
            let url = AudioCache.downloadedURL(reciter: reciter, surah: 2, ayah: 286)
            XCTAssertEqual(url.lastPathComponent, "002286.mp3")
            XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, reciter.cacheFolder)
            XCTAssertEqual(url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent,
                           "recitations")
        }
        XCTAssertEqual(AudioCache.downloadedURL(reciter: .dosaryWarsh, surah: 1, ayah: 1)
                        .deletingLastPathComponent().lastPathComponent, "dosaryWarsh")
    }

    // MARK: - Translated readings

    func testTranslationVoiceOrderAndDefault() {
        XCTAssertEqual(TranslationVoice.allCases.first, TranslationVoice.none)
        XCTAssertEqual(TranslationVoice.allCases,
                       [.none, .english, .urdu, .persian, .bosnian, .azerbaijani])
        XCTAssertEqual(TranslationVoice.defaultsKey, "audio.translation")
        XCTAssertEqual(TranslationVoice(rawValue: "") ?? .none, TranslationVoice.none)
        XCTAssertEqual(TranslationVoice.english.displayName(arabicUI: true), "الإنجليزية · إبراهيم ووك")
        XCTAssertEqual(TranslationVoice.english.displayName(arabicUI: false), "English · Ibrahim Walk")
    }

    func testTranslationVoiceURLs() {
        XCTAssertTrue(TranslationVoice.none.urls(surah: 1, ayah: 1).isEmpty)
        XCTAssertNil(TranslationVoice.none.url(surah: 1, ayah: 1))
        let expected: [TranslationVoice: String] = [
            .english: "English/Sahih_Intnl_Ibrahim_Walk_192kbps",
            .urdu: "translations/urdu_shamshad_ali_khan_46kbps",
            .persian: "translations/Fooladvand_Hedayatfar_40Kbps",
            .bosnian: "translations/besim_korkut_ajet_po_ajet",
            .azerbaijani: "translations/azerbaijani/balayev",
        ]
        for (voice, folder) in expected {
            let urls = voice.urls(surah: 2, ayah: 286)
            XCTAssertEqual(urls.count, 2, voice.rawValue)
            XCTAssertEqual(urls[0].absoluteString, "https://everyayah.com/data/\(folder)/002286.mp3")
            XCTAssertEqual(urls[1].absoluteString,
                           "https://mirrors.quranicaudio.com/everyayah/\(folder)/002286.mp3")
        }
    }

    func testTranslationCacheFolderIsSanitised() {
        XCTAssertNil(TranslationVoice.none.cacheFolder)
        XCTAssertEqual(TranslationVoice.azerbaijani.cacheFolder, "translations_azerbaijani_balayev")
        XCTAssertEqual(TranslationVoice.english.cacheFolder, "English_Sahih_Intnl_Ibrahim_Walk_192kbps")
        for voice in TranslationVoice.allCases where voice != .none {
            XCTAssertFalse(voice.cacheFolder!.contains("/"))
            let url = AudioCache.downloadedURL(voice: voice, surah: 114, ayah: 6)!
            XCTAssertEqual(url.lastPathComponent, "114006.mp3")
            XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, voice.cacheFolder)
            XCTAssertEqual(url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent,
                           "recitations")
            // Never collides with a reciter's folder.
            XCTAssertFalse(Reciter.allCases.map(\.cacheFolder).contains(voice.cacheFolder!))
        }
        XCTAssertNil(AudioCache.downloadedURL(voice: .none, surah: 1, ayah: 1))
    }

    func testSurahDownloadIncludesTranslation() {
        let arabicOnly = SurahDownloader.tracks(reciter: .alafasy, translation: .none, surah: 1, ayahCount: 7)
        XCTAssertEqual(arabicOnly.count, 7)
        let pairs = SurahDownloader.tracks(reciter: .alafasy, translation: .urdu, surah: 1, ayahCount: 7)
        XCTAssertEqual(pairs.count, 14)
        XCTAssertEqual(pairs[0].track.cacheFolder, "alafasy")
        XCTAssertEqual(pairs[1].track.cacheFolder, "translations_urdu_shamshad_ali_khan_46kbps")
        XCTAssertEqual(pairs[1].ayah, 1)
        XCTAssertEqual(pairs.last?.ayah, 7)
    }
}
