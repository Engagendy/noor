import AVFoundation
import XCTest
@testable import QuranAudio

final class AyahVideoComposerTests: XCTestCase {
    /// Composes a 1080×1920 MP4 from a synthetic card + 2 s tone and checks
    /// the result is a readable asset with one video and one audio track.
    func testMakeVideoProducesPlayableMP4() async throws {
        let tone = try makeToneFile(seconds: 2)
        defer { try? FileManager.default.removeItem(at: tone) }
        let card = try XCTUnwrap(makeCard(width: 620, height: 400))

        let url = try await AyahVideoComposer.makeVideo(card: card, audioURL: tone, baseName: "test")
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(url.pathExtension, "mp4")
        XCTAssertTrue(url.path.contains("shared-video"))
        let asset = AVURLAsset(url: url)
        let video = try await asset.loadTracks(withMediaType: .video)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        XCTAssertEqual(video.count, 1)
        XCTAssertEqual(audio.count, 1)
        let size = try await video[0].load(.naturalSize)
        XCTAssertEqual(size, CGSize(width: 1080, height: 1920))
        let fps = try await video[0].load(.nominalFrameRate)
        XCTAssertEqual(fps, Float(AyahVideoComposer.framesPerSecond), accuracy: 0.5)
        let duration = try await asset.load(.duration).seconds
        XCTAssertEqual(duration, 2.5, accuracy: 0.15)
        let playable = try await asset.load(.isPlayable)
        XCTAssertTrue(playable)
        let format = try await audio[0].load(.formatDescriptions).first
        XCTAssertEqual(format.map { CMFormatDescriptionGetMediaSubType($0) }, kAudioFormatMPEG4AAC)
    }

    func testFrameUsesPaperBackground() throws {
        let card = try XCTUnwrap(makeCard(width: 100, height: 50))
        let size = CGSize(width: 108, height: 192)
        let lay = AyahVideoComposer.layout(card: card, size: size)
        let base = try XCTUnwrap(AyahVideoComposer.renderBase(card: card, size: size, layout: lay))
        let frame = try XCTUnwrap(AyahVideoComposer.renderFrame(
            base: base, size: size, layout: lay, envelope: [0.5], frameIndex: 0))
        CVPixelBufferLockBaseAddress(frame, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(frame, .readOnly) }
        let px = try XCTUnwrap(CVPixelBufferGetBaseAddress(frame)).assumingMemoryBound(to: UInt8.self)
        // Top-left pixel is background: BGRA of #FAF6EE.
        XCTAssertEqual(px[0], 0xEE); XCTAssertEqual(px[1], 0xF6); XCTAssertEqual(px[2], 0xFA)
    }

    func testMissingAudioThrowsTypedError() async {
        let card = makeCard(width: 10, height: 10)!
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("nope.mp3")
        do {
            _ = try await AyahVideoComposer.makeVideo(card: card, audioURL: missing)
            XCTFail("expected throw")
        } catch let error as AyahVideoError {
            XCTAssertEqual(error, .audioUnreadable)
        } catch {
            XCTFail("untyped error \(error)")
        }
    }

    // MARK: - Fixtures (non-Quranic placeholder graphics/audio only)

    private func makeCard(width: Int, height: Int) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }

    private func makeToneFile(seconds: Double) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tone-\(UUID().uuidString).wav")
        let rate = 44_100.0
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let frames = AVAudioFrameCount(rate * seconds)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        for i in 0..<Int(frames) {
            buffer.floatChannelData![0][i] = Float(sin(2 * .pi * 440 * Double(i) / rate)) * 0.3
        }
        try file.write(from: buffer)
        return url
    }

    func testEnvelopeFollowsLoudness() async throws {
        // Reuse the synthetic tone the composer test writes.
        let url = try makeToneFile(seconds: 1.0)
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        let track = try XCTUnwrap(tracks.first)
        let env = try await AyahVideoComposer.loudnessEnvelope(asset: asset, track: track, seconds: 1.5, fps: 24)
        XCTAssertEqual(env.count, 36)
        XCTAssertTrue(env.allSatisfy { $0 >= 0 && $0 <= 1 })
        XCTAssertGreaterThan(env[12], 0.5, "tone should register as loud")
        XCTAssertLessThan(env.last!, 0.2, "padding after the tone should decay")
    }
}
