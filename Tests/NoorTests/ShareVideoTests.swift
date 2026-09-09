import AVFoundation
import Athkar
import ShareVideo
import XCTest

/// Covers the "Share as video" path that Athkar and the Quran reader both
/// use. The composer itself lives in `Core/ShareVideo`; these run in the app
/// suite so a regression in either feature's wiring is caught by `xcodebuild
/// test` (the package test targets are not in the Noor scheme).
final class ShareVideoTests: XCTestCase {
    // MARK: - The shared composer

    /// Composes a 1080×1920 MP4 from a synthetic card + 2 s tone and checks
    /// the result carries one video and one AAC audio track.
    func testComposerProducesPlayableMP4() async throws {
        let tone = try makeToneFile(seconds: 2)
        defer { try? FileManager.default.removeItem(at: tone) }
        let card = try XCTUnwrap(makeCard(width: 620, height: 400))

        let url = try await ShareVideoComposer.makeVideo(
            card: card, audioURL: tone, baseName: "noor-test")
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(url.pathExtension, "mp4")
        XCTAssertTrue(url.path.contains("shared-video"))
        let asset = AVURLAsset(url: url)
        let video = try await asset.loadTracks(withMediaType: .video)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        XCTAssertEqual(video.count, 1)
        XCTAssertEqual(audio.count, 1)
        let naturalSize = try await video[0].load(.naturalSize)
        let frameRate = try await video[0].load(.nominalFrameRate)
        let duration = try await asset.load(.duration).seconds
        let playable = try await asset.load(.isPlayable)
        XCTAssertEqual(naturalSize, CGSize(width: 1080, height: 1920))
        XCTAssertEqual(frameRate, Float(ShareVideoComposer.framesPerSecond), accuracy: 0.5)
        // Whole recording + the half second of tail padding, nothing trimmed.
        XCTAssertEqual(duration, 2 + ShareVideoComposer.trailingPadding, accuracy: 0.15)
        XCTAssertTrue(playable)
        let format = try await audio[0].load(.formatDescriptions).first
        XCTAssertEqual(format.map { CMFormatDescriptionGetMediaSubType($0) }, kAudioFormatMPEG4AAC)
    }

    func testUnreadableAudioThrowsTypedError() async throws {
        let card = try XCTUnwrap(makeCard(width: 10, height: 10))
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("nope.mp3")
        do {
            _ = try await ShareVideoComposer.makeVideo(card: card, audioURL: missing)
            XCTFail("expected throw")
        } catch let error as ShareVideoError {
            XCTAssertEqual(error, .audioUnreadable)
        }
    }

    // MARK: - The dhikr flavour

    /// The caption must follow the INTERFACE language, not the process
    /// language — `String(localized:)` would get this wrong (see the comment
    /// in `DhikrVideoComposer`).
    func testCaptionNamesReciterInInterfaceLanguage() {
        XCTAssertEqual(DhikrVideoComposer.caption(arabicUI: true),
                       "بصوت \(DhikrVideoComposer.reciterArabic)")
        XCTAssertEqual(DhikrVideoComposer.caption(arabicUI: false),
                       "with \(DhikrVideoComposer.reciterEnglish)'s recitation")
    }

    func testShareOptionOfferedOnlyWhenTheDhikrHasAudio() throws {
        let withAudio = try makeDhikr(audio: "\"12.mp3\"")
        let option = try XCTUnwrap(DhikrVideoComposer.shareOption(for: withAudio, arabicUI: true))
        XCTAssertEqual(option.caption, DhikrVideoComposer.caption(arabicUI: true))

        let silent = try makeDhikr(audio: "null")
        XCTAssertNil(DhikrVideoComposer.shareOption(for: silent, arabicUI: true))
    }

    /// Every bundled dhikr has a recording, so every share sheet gets the
    /// button — the feature is not a subset of the data.
    func testEveryBundledDhikrHasAudio() {
        let categories = AthkarStore.load()
        XCTAssertFalse(categories.isEmpty)
        let items = categories.flatMap(\.items)
        XCTAssertEqual(items.filter { $0.audio == nil }.count, 0)
    }

    func testBaseNameIsPathSafe() {
        XCTAssertEqual(DhikrVideoComposer.baseName(file: "12.mp3"), "12")
        XCTAssertEqual(DhikrVideoComposer.baseName(file: "ar_7esn_AlMoslem_by_Doors_002.mp3"),
                       "ar_7esn_AlMoslem_by_Doors_002")
        XCTAssertEqual(DhikrVideoComposer.baseName(file: "a b/../c.mp3"), "abc")
    }

    // MARK: - Fixtures (non-Quranic placeholder text/graphics/audio only)

    private func makeDhikr(audio: String) throws -> Dhikr {
        let json = """
        {"text": "نص تجريبي للاختبار", "count": 1, "audio": \(audio)}
        """
        return try JSONDecoder().decode(Dhikr.self, from: Data(json.utf8))
    }

    private func makeCard(width: Int, height: Int) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.setFillColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }

    private func makeToneFile(seconds: Double) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tone-\(UUID().uuidString).wav")
        let rate = 44_100.0
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1))
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let frames = AVAudioFrameCount(rate * seconds)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        for i in 0..<Int(frames) {
            buffer.floatChannelData?[0][i] = Float(sin(2 * .pi * 440 * Double(i) / rate)) * 0.3
        }
        try file.write(from: buffer)
        return url
    }
}
