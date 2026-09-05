import AVFoundation
import CoreGraphics
import DesignSystem
import Foundation

/// Failure modes of "Share as video"; `errorDescription` is user-facing.
public enum AyahVideoError: LocalizedError, Equatable {
    /// The ayah recitation is not cached and could not be downloaded.
    case audioUnavailable
    /// The audio file could not be read (corrupt or empty).
    case audioUnreadable
    /// Frame rendering / H.264 writing failed.
    case videoWriteFailed
    /// Muxing video + audio into the final MP4 failed.
    case exportFailed
    /// The user left the sheet before composing finished.
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .audioUnavailable:
            String(localized: "Connect once to download this ayah's recitation")
        case .audioUnreadable, .videoWriteFailed, .exportFailed:
            String(localized: "Couldn't create the video. Please try again.")
        case .cancelled:
            String(localized: "Cancelled")
        }
    }
}

/// Assembles a 9:16 MP4 from a share card plus an ayah recitation, with a
/// gold equaliser under the card that moves with the reciter's voice.
///
/// Pipeline (AVFoundation only, fully offline once the MP3 is cached):
/// 1. The recitation is decoded to PCM and reduced to a loudness envelope,
///    one value per video frame, smoothed so bars glide rather than jitter.
/// 2. `AVAssetWriter` writes a video-only H.264 MP4 (1080×1920, 24 fps): the
///    card centred on paper (#FAF6EE) with side margins, and under it a row of
///    bars whose heights follow the envelope, rippling out from the centre.
///    Runs for the audio duration + 0.5 s.
/// 2. `AVMutableComposition` pairs that video track with the MP3's audio track.
/// 3. `AVAssetExportSession` (highest quality) muxes to `.mp4` with AAC audio in
///    Caches/shared-video/<baseName>-<timestamp>.mp4.
public enum AyahVideoComposer {
    public static let defaultSize = CGSize(width: 1080, height: 1920)
    public static let framesPerSecond: Int32 = 24
    /// Silence appended after the recitation ends so the last word isn't clipped.
    public static let trailingPadding: Double = 0.5
    /// Horizontal breathing room on each side of the card, as a fraction of width.
    public static let horizontalMarginFraction: CGFloat = 0.06
    /// App paper colour (NoorColor.bgPrimary, light) as sRGB components.
    public static let paperColor: (r: CGFloat, g: CGFloat, b: CGFloat) = (0xFA / 255, 0xF6 / 255, 0xEE / 255)
    /// Bar colour: the app's gold (NoorColor.accentGold).
    public static let goldColor: (r: CGFloat, g: CGFloat, b: CGFloat) = (0xB9 / 255, 0x8A / 255, 0x2F / 255)
    /// Equaliser geometry, as fractions of the frame height/width.
    static let barCount = 25
    static let barAreaHeightFraction: CGFloat = 0.075
    static let barRowWidthFraction: CGFloat = 0.62
    static let barGapAfterCardFraction: CGFloat = 0.03

    /// Folder for finished videos. Cleared of previous outputs on each run.
    public static var outputDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("shared-video", isDirectory: true)
    }

    /// Builds the MP4 and returns its URL. Throws `AyahVideoError`.
    public static func makeVideo(
        card: CGImage,
        audioURL: URL,
        size: CGSize = defaultSize,
        baseName: String = "noor-ayah"
    ) async throws -> URL {
        let audioAsset = AVURLAsset(url: audioURL)
        guard let duration = try? await audioAsset.load(.duration),
              duration.seconds.isFinite, duration.seconds > 0,
              let audioTrack = try? await audioAsset.loadTracks(withMediaType: .audio).first
        else { throw AyahVideoError.audioUnreadable }
        let totalSeconds = duration.seconds + trailingPadding

        try Task.checkCancellation()
        let folder = try prepareOutputDirectory()
        let stamp = Int(Date().timeIntervalSince1970)
        let stillURL = folder.appendingPathComponent("\(baseName)-\(stamp)-still.mp4")
        let finalURL = folder.appendingPathComponent("\(baseName)-\(stamp).mp4")
        defer { try? FileManager.default.removeItem(at: stillURL) }

        // 1. Loudness envelope, then the animated video.
        let envelope = try await loudnessEnvelope(
            asset: audioAsset, track: audioTrack, seconds: totalSeconds, fps: framesPerSecond)
        try Task.checkCancellation()
        let lay = layout(card: card, size: size)
        guard let base = renderBase(card: card, size: size, layout: lay) else { throw AyahVideoError.videoWriteFailed }
        try await writeVideo(size: size, seconds: totalSeconds, to: stillURL) { index in
            renderFrame(base: base, size: size, layout: lay, envelope: envelope, frameIndex: index)
        }
        try Task.checkCancellation()

        // 2. Composition: video track + audio track.
        let composition = AVMutableComposition()
        let stillAsset = AVURLAsset(url: stillURL)
        guard let stillTrack = try? await stillAsset.loadTracks(withMediaType: .video).first,
              let stillDuration = try? await stillAsset.load(.duration),
              let videoTrack = composition.addMutableTrack(
                  withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let compAudio = composition.addMutableTrack(
                  withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw AyahVideoError.exportFailed }
        do {
            try videoTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: stillDuration), of: stillTrack, at: .zero)
            try compAudio.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration), of: audioTrack, at: .zero)
        } catch {
            throw AyahVideoError.exportFailed
        }

        // 3. Export as MP4 / AAC.
        guard let session = AVAssetExportSession(
            asset: composition, presetName: AVAssetExportPresetHighestQuality)
        else { throw AyahVideoError.exportFailed }
        session.shouldOptimizeForNetworkUse = true
        try await withTaskCancellationHandler {
            if #available(iOS 18, macOS 15, *) {
                do {
                    try await session.export(to: finalURL, as: .mp4)
                } catch is CancellationError {
                    throw AyahVideoError.cancelled
                } catch {
                    throw AyahVideoError.exportFailed
                }
            } else {
                session.outputURL = finalURL
                session.outputFileType = .mp4
                await session.export()
                switch session.status {
                case .completed: break
                case .cancelled: throw AyahVideoError.cancelled
                default: throw AyahVideoError.exportFailed
                }
            }
        } onCancel: {
            session.cancelExport()
        }
        guard FileManager.default.fileExists(atPath: finalURL.path) else { throw AyahVideoError.exportFailed }
        return finalURL
    }

    // MARK: - Steps

    private static func prepareOutputDirectory() throws -> URL {
        let folder = outputDirectory
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            throw AyahVideoError.videoWriteFailed
        }
        // Old exports are worthless once shared; don't let them pile up.
        (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil))?
            .forEach { try? fm.removeItem(at: $0) }
        return folder
    }

    /// Where the card and the bar row sit: the card is scaled to fit the width
    /// (minus margins) and the pair is centred vertically as one block.
    struct Layout {
        let cardRect: CGRect
        let barArea: CGRect
    }

    static func layout(card: CGImage, size: CGSize) -> Layout {
        let margin = size.width * horizontalMarginFraction
        let barAreaHeight = size.height * barAreaHeightFraction
        let gap = size.height * barGapAfterCardFraction
        let maxWidth = size.width - margin * 2
        let maxHeight = size.height - margin * 2 - barAreaHeight - gap
        let cardSize = CGSize(width: card.width, height: card.height)
        let scale = min(maxWidth / cardSize.width, maxHeight / cardSize.height)
        let drawSize = CGSize(width: cardSize.width * scale, height: cardSize.height * scale)
        let blockHeight = drawSize.height + gap + barAreaHeight
        // CGContext origin is bottom-left: the bars sit BELOW the card visually,
        // so they take the lower y range.
        let blockBottom = (size.height - blockHeight) / 2
        let barArea = CGRect(x: (size.width - size.width * barRowWidthFraction) / 2,
                             y: blockBottom,
                             width: size.width * barRowWidthFraction, height: barAreaHeight)
        let cardRect = CGRect(x: (size.width - drawSize.width) / 2,
                              y: blockBottom + barAreaHeight + gap,
                              width: drawSize.width, height: drawSize.height)
        return Layout(cardRect: cardRect, barArea: barArea)
    }

    /// The unchanging part of every frame: paper background plus the card.
    static func renderBase(card: CGImage, size: CGSize, layout lay: Layout) -> CGImage? {
        guard let context = CGContext(
            data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }
        context.setFillColor(red: paperColor.r, green: paperColor.g, blue: paperColor.b, alpha: 1)
        context.fill(CGRect(origin: .zero, size: size))
        context.interpolationQuality = .high
        context.draw(card, in: lay.cardRect)
        return context.makeImage()
    }

    /// Bar heights for one frame: the loudness at this frame rippling outwards
    /// from the centre (outer bars lag a few frames) under a bell-shaped cap,
    /// so the row breathes with the voice and stays calm in the pauses.
    static func barLevels(envelope: [Float], frameIndex: Int) -> [CGFloat] {
        let centre = Double(barCount - 1) / 2
        return (0..<barCount).map { i in
            let distance = abs(Double(i) - centre)
            let lagged = max(0, frameIndex - Int(distance * 1.5))
            let level = envelope.isEmpty ? 0 : Double(envelope[min(lagged, envelope.count - 1)])
            let bell = exp(-pow(distance / (centre * 0.75), 2))
            let floor = 0.10                       // never fully flat
            return CGFloat(floor + (1 - floor) * level * (0.35 + 0.65 * bell))
        }
    }

    /// One BGRA pixel buffer: the base plus this frame's bars.
    static func renderFrame(base: CGImage, size: CGSize, layout lay: Layout, envelope: [Float], frameIndex: Int) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        guard CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height),
                                  kCVPixelFormatType_32BGRA, attrs as CFDictionary, &buffer) == kCVReturnSuccess,
              let pixelBuffer = buffer
        else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        else { return nil }
        context.draw(base, in: CGRect(origin: .zero, size: size))

        // Bars: rounded, gold, fading towards the edges of the row.
        let area = lay.barArea
        let levels = barLevels(envelope: envelope, frameIndex: frameIndex)
        let slot = area.width / CGFloat(barCount)
        let barWidth = slot * 0.55
        let centre = CGFloat(barCount - 1) / 2
        for (i, level) in levels.enumerated() {
            let height = max(barWidth, lay.barArea.height * level)
            let x = area.minX + slot * CGFloat(i) + (slot - barWidth) / 2
            let y = lay.barArea.midY - height / 2
            let edge = 1 - abs(CGFloat(i) - centre) / centre
            context.setFillColor(red: goldColor.r, green: goldColor.g, blue: goldColor.b,
                                 alpha: 0.35 + 0.65 * edge)
            let path = CGPath(roundedRect: CGRect(x: x, y: y, width: barWidth, height: height),
                              cornerWidth: barWidth / 2, cornerHeight: barWidth / 2, transform: nil)
            context.addPath(path)
            context.fillPath()
        }
        return pixelBuffer
    }

    /// Per-frame loudness, 0…1, from the decoded recitation. RMS over each
    /// frame's window, log-scaled so quiet passages still move, then smoothed
    /// with a fast attack and slow release. Padded with zeros for the tail.
    static func loudnessEnvelope(asset: AVAsset, track: AVAssetTrack, seconds: Double, fps: Int32) async throws -> [Float] {
        let frameCount = Int((seconds * Double(fps)).rounded(.up))
        let sampleRate = 22_050.0
        guard let reader = try? AVAssetReader(asset: asset) else { throw AyahVideoError.audioUnreadable }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw AyahVideoError.audioUnreadable }
        reader.add(output)
        guard reader.startReading() else { throw AyahVideoError.audioUnreadable }

        let window = Int(sampleRate / Double(fps))
        var sums = [Double](repeating: 0, count: frameCount)
        var counts = [Int](repeating: 0, count: frameCount)
        var sampleIndex = 0
        while let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            guard let block = CMSampleBufferGetDataBuffer(sample) else { continue }
            var length = 0; var pointer: UnsafeMutablePointer<Int8>?
            guard CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil,
                                              totalLengthOut: &length, dataPointerOut: &pointer) == noErr,
                  let base = pointer else { continue }
            let floats = UnsafeRawPointer(base).assumingMemoryBound(to: Float.self)
            for i in 0..<(length / 4) {
                let frame = sampleIndex / window
                if frame < frameCount {
                    let v = Double(floats[i]); sums[frame] += v * v; counts[frame] += 1
                }
                sampleIndex += 1
            }
        }
        if reader.status == .failed { throw AyahVideoError.audioUnreadable }

        var raw = (0..<frameCount).map { i -> Float in
            counts[i] == 0 ? 0 : Float(sqrt(sums[i] / Double(counts[i])))
        }
        // Log scale relative to the loudest frame, so soft recitation still shows.
        let peak = max(raw.max() ?? 0, 0.0001)
        raw = raw.map { r in
            let db = 20 * log10(max(r / peak, 0.0001))   // 0 dB … -80 dB
            return Float(max(0, min(1, (db + 40) / 40)))  // -40 dB floor
        }
        // Fast attack, slow release.
        var smoothed = [Float](repeating: 0, count: frameCount)
        var current: Float = 0
        for i in 0..<frameCount {
            let target = raw[i]
            current = target > current ? current + (target - current) * 0.6
                                       : current + (target - current) * 0.18
            smoothed[i] = current
        }
        return smoothed
    }

    /// H.264 video at `framesPerSecond` for `seconds`, one pixel buffer per
    /// frame from `frameAt` (called on the writer's queue, in order).
    static func writeVideo(size: CGSize, seconds: Double, to url: URL,
                           frameAt: @escaping (Int) -> CVPixelBuffer?) async throws {
        try? FileManager.default.removeItem(at: url)
        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        } catch {
            throw AyahVideoError.videoWriteFailed
        }
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2_500_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: framesPerSecond * 2
            ]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        guard writer.canAdd(input) else { throw AyahVideoError.videoWriteFailed }
        writer.add(input)
        guard writer.startWriting() else { throw AyahVideoError.videoWriteFailed }
        writer.startSession(atSourceTime: .zero)

        let frameCount = Int((seconds * Double(framesPerSecond)).rounded(.up))
        var index = 0
        let queue = DispatchQueue(label: "com.engagendy.noor.ayah-video")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var finished = false
            input.requestMediaDataWhenReady(on: queue) {
                guard !finished else { return }
                while input.isReadyForMoreMediaData, index < frameCount {
                    if Task.isCancelled {
                        finished = true
                        input.markAsFinished()
                        writer.cancelWriting()
                        continuation.resume(throwing: AyahVideoError.cancelled)
                        return
                    }
                    let time = CMTime(value: CMTimeValue(index), timescale: framesPerSecond)
                    guard let frame = frameAt(index), adaptor.append(frame, withPresentationTime: time) else {
                        finished = true
                        input.markAsFinished()
                        writer.cancelWriting()
                        continuation.resume(throwing: AyahVideoError.videoWriteFailed)
                        return
                    }
                    index += 1
                }
                if index >= frameCount {
                    finished = true
                    input.markAsFinished()
                    writer.finishWriting {
                        if writer.status == .completed {
                            continuation.resume()
                        } else {
                            continuation.resume(throwing: AyahVideoError.videoWriteFailed)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Share-sheet integration

public extension AyahVideoComposer {
    /// Ready-made "Share as video" option for `NoorShareSheet`: resolves the
    /// current reciter, fetches the ayah MP3 (cache → download) and composes.
    @MainActor
    static func shareOption(surah: Int, ayah: Int, arabicUI: Bool) -> NoorShareVideoOption {
        let reciter = Reciter(rawValue: UserDefaults.standard.string(forKey: "audio.reciter") ?? "") ?? .alafasy
        let name = reciter.displayName(arabicUI: arabicUI)
        let caption = String(localized: "with \(name)'s recitation")
        return NoorShareVideoOption(caption: caption) { card in
            guard let audio = await AudioCache.ensureLocal(reciter: reciter, surah: surah, ayah: ayah)
            else { throw AyahVideoError.audioUnavailable }
            try Task.checkCancellation()
            return try await makeVideo(
                card: card, audioURL: audio,
                baseName: "noor-ayah-\(surah)-\(ayah)-\(reciter.rawValue)")
        }
    }
}
