package com.engagendy.noor

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import java.io.File
import java.nio.ByteBuffer
import java.util.ArrayDeque
import java.util.Locale
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.exp
import kotlin.math.floor
import kotlin.math.log10
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sqrt

/// Why a video could not be produced — surfaced as one short toast.
class AyahVideoException(val kind: Kind, message: String, cause: Throwable? = null) :
    Exception(message, cause) {
    enum class Kind { AUDIO_UNREADABLE, CODEC_UNAVAILABLE, ENCODE_FAILED, MUX_FAILED }
}

/// "Share as video": the ayah share card on paper with a gold equaliser
/// under it that moves with the reciter's voice, muxed into a 1080×1920
/// H.264 + AAC MP4 — 1:1 with the iOS AyahVideoComposer (numbers mirrored
/// from Modules/QuranAudio/Sources/QuranAudio/AyahVideoComposer.swift).
/// Platform codecs only (MediaCodec / MediaExtractor / MediaMuxer) — no
/// ffmpeg, no third-party code. Runs entirely off-main.
///
/// Assembly: the MP3 is decoded to PCM, re-encoded to AAC (buffered, a few
/// hundred KB) and reduced to a per-frame loudness envelope on the way. The
/// paper + card base is drawn once and converted once to YUV420; per frame
/// only the bar-row strip is redrawn (small ARGB bitmap) and its rows
/// re-converted in place before the frame is queued at 24 fps for (audio
/// duration + 0.5 s). The muxer starts when the video encoder reports its
/// output format, with audio samples interleaved by timestamp.
object AyahVideoComposer {

    const val WIDTH = 1080
    const val HEIGHT = 1920
    const val FPS = 24
    private const val VIDEO_BIT_RATE = 4_000_000
    private const val AUDIO_BIT_RATE = 128_000
    private const val I_FRAME_INTERVAL_S = 1
    private const val TAIL_US = 500_000L
    /// Horizontal breathing room on each side of the card (fraction of width).
    private const val MARGIN_FRACTION = 0.06f
    private val paper = Color.parseColor("#FAF6EE")
    /// Equaliser geometry — iOS barCount / barAreaHeightFraction /
    /// barRowWidthFraction / barGapAfterCardFraction, gold = NoorColor.accentGold.
    private const val BAR_COUNT = 25
    private const val BAR_AREA_HEIGHT_FRACTION = 0.075f
    private const val BAR_ROW_WIDTH_FRACTION = 0.62f
    private const val BAR_GAP_AFTER_CARD_FRACTION = 0.03f
    private val gold = Color.parseColor("#B98A2F")
    private const val TIMEOUT_US = 10_000L
    /// Consecutive empty dequeues before we give up on a stalled codec (~10 s).
    private const val MAX_STALLS = 1_000
    private const val STALE_SHARE_MS = 60 * 60 * 1000L

    private class EncodedSample(val data: ByteArray, val presentationUs: Long, val flags: Int)
    private class AudioResult(
        val format: MediaFormat,
        val samples: List<EncodedSample>,
        val durationUs: Long,
        /// Per-video-frame loudness 0…1 (see [loudnessEnvelope]).
        val envelope: FloatArray,
    )

    /// Where the card and the bar row sit: the card scaled to fit the width
    /// (minus margins) and card + gap + bar area centred vertically as one block.
    private class Layout(val card: RectF, val barArea: RectF)

    /// Produces the MP4 in cacheDir/shared (fresh name each time, old
    /// share files pruned like ShareCard). Throws [AyahVideoException].
    suspend fun compose(context: android.content.Context, card: Bitmap, audio: File): File =
        withContext(Dispatchers.Default) {
            val ctx = currentCoroutineContext()
            val check = { ctx.ensureActive() }
            val dir = File(context.cacheDir, "shared").apply { mkdirs() }
            val cutoff = System.currentTimeMillis() - STALE_SHARE_MS
            dir.listFiles()?.forEach { if (it.lastModified() < cutoff) it.delete() }
            val out = File(dir, "noor-share-%d.mp4".format(Locale.ROOT, System.currentTimeMillis()))

            val layout = layout(card.width, card.height)
            val base = renderBase(card, layout)
            val yuv = toYuv420(base)
            base.recycle()
            check()
            val audioResult = transcodeAudio(audio, check)
            check()
            try {
                encodeAndMux(yuv, layout, audioResult, out, check)
            } catch (e: AyahVideoException) {
                out.delete(); throw e
            } catch (e: Throwable) {
                out.delete(); throw e
            }
            out
        }

    // MARK: - frame

    private fun layout(cardW: Int, cardH: Int): Layout {
        val margin = WIDTH * MARGIN_FRACTION
        val barAreaH = HEIGHT * BAR_AREA_HEIGHT_FRACTION
        val gap = HEIGHT * BAR_GAP_AFTER_CARD_FRACTION
        val maxW = WIDTH - 2 * margin
        val maxH = HEIGHT - 2 * margin - barAreaH - gap
        val scale = min(maxW / cardW, maxH / cardH)
        val w = cardW * scale
        val h = cardH * scale
        val blockH = h + gap + barAreaH
        val blockTop = (HEIGHT - blockH) / 2f
        val cardLeft = (WIDTH - w) / 2f
        val rowW = WIDTH * BAR_ROW_WIDTH_FRACTION
        val rowLeft = (WIDTH - rowW) / 2f
        val barTop = blockTop + h + gap
        return Layout(
            card = RectF(cardLeft, blockTop, cardLeft + w, blockTop + h),
            barArea = RectF(rowLeft, barTop, rowLeft + rowW, barTop + barAreaH))
    }

    /// Paper + the card; the bar area below it stays plain paper here.
    private fun renderBase(card: Bitmap, layout: Layout): Bitmap {
        val frame = Bitmap.createBitmap(WIDTH, HEIGHT, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(frame)
        canvas.drawColor(paper)
        canvas.drawBitmap(card, null, layout.card,
            Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG))
        return frame
    }

    /// Bar heights for one frame (iOS barLevels): the loudness at this frame
    /// rippling outwards from the centre (outer bars lag a few frames) under
    /// a bell-shaped cap, never fully flat.
    private fun barLevels(envelope: FloatArray, frameIndex: Int, out: FloatArray) {
        val centre = (BAR_COUNT - 1) / 2.0
        for (i in 0 until BAR_COUNT) {
            val distance = abs(i - centre)
            val lagged = maxOf(0, frameIndex - (distance * 1.5).toInt())
            val level = if (envelope.isEmpty()) 0.0
                else envelope[min(lagged, envelope.size - 1)].toDouble()
            val bell = exp(-((distance / (centre * 0.75)).pow(2)))
            val floor = 0.10
            out[i] = (floor + (1 - floor) * level * (0.35 + 0.65 * bell)).toFloat()
        }
    }

    /// The strip of the frame the bars live in, even-aligned so it maps onto
    /// whole 2×2 chroma blocks. Redrawn per frame on the paper colour.
    private class BarRegion(val x: Int, val y: Int, val w: Int, val h: Int) {
        val bitmap: Bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val pixels = IntArray(w * h)
        val levels = FloatArray(BAR_COUNT)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = gold }
        val rect = RectF()
    }

    private fun barRegion(layout: Layout): BarRegion {
        val a = layout.barArea
        val x0 = (floor(a.left).toInt()).coerceAtLeast(0) and 1.inv()
        val y0 = (floor(a.top).toInt()).coerceAtLeast(0) and 1.inv()
        val x1 = ((ceil(a.right).toInt() + 1) and 1.inv()).coerceAtMost(WIDTH)
        val y1 = ((ceil(a.bottom).toInt() + 1) and 1.inv()).coerceAtMost(HEIGHT)
        return BarRegion(x0, y0, x1 - x0, y1 - y0)
    }

    /// Draws this frame's bars into the region bitmap and re-converts just
    /// those rows into the base YUV planes (in place: the region is plain
    /// paper in the base, so nothing underneath needs restoring).
    private fun drawBars(region: BarRegion, layout: Layout, envelope: FloatArray, frameIndex: Int, yuv: Yuv) {
        val area = layout.barArea
        barLevels(envelope, frameIndex, region.levels)
        region.canvas.drawColor(paper)
        val slot = area.width() / BAR_COUNT
        val barW = slot * 0.55f
        val centre = (BAR_COUNT - 1) / 2f
        for (i in 0 until BAR_COUNT) {
            val h = maxOf(barW, area.height() * region.levels[i])
            val x = area.left + slot * i + (slot - barW) / 2 - region.x
            val y = area.centerY() - h / 2 - region.y
            val edge = 1 - abs(i - centre) / centre
            region.paint.alpha = ((0.35f + 0.65f * edge) * 255).toInt().coerceIn(0, 255)
            region.rect.set(x, y, x + barW, y + h)
            region.canvas.drawRoundRect(region.rect, barW / 2, barW / 2, region.paint)
        }
        region.bitmap.getPixels(region.pixels, 0, region.w, 0, 0, region.w, region.h)
        convertRegion(region.pixels, region.w, region.h, yuv, region.x, region.y)
    }

    private class Yuv(val y: ByteArray, val u: ByteArray, val v: ByteArray)

    /// BT.601 limited-range planar conversion of the whole frame.
    private fun toYuv420(bitmap: Bitmap): Yuv {
        val w = bitmap.width
        val h = bitmap.height
        val argb = IntArray(w * h)
        bitmap.getPixels(argb, 0, w, 0, 0, w, h)
        val yuv = Yuv(ByteArray(w * h), ByteArray(w * h / 4), ByteArray(w * h / 4))
        convertRegion(argb, w, h, yuv, 0, 0)
        return yuv
    }

    /// Converts a w×h ARGB block into the frame-sized planes at (dstX, dstY);
    /// all four must be even. Chroma is averaged over each 2×2 block.
    private fun convertRegion(argb: IntArray, w: Int, h: Int, yuv: Yuv, dstX: Int, dstY: Int) {
        val fw = WIDTH
        val cw = fw / 2
        for (row in 0 until h) {
            val dstRow = (dstY + row) * fw + dstX
            val srcRow = row * w
            for (col in 0 until w) {
                val p = argb[srcRow + col]
                val r = (p shr 16) and 0xFF
                val g = (p shr 8) and 0xFF
                val b = p and 0xFF
                yuv.y[dstRow + col] = ((66 * r + 129 * g + 25 * b + 128) shr 8).plus(16).coerceIn(16, 235).toByte()
            }
        }
        for (row in 0 until h / 2) {
            val dstRow = (dstY / 2 + row) * cw + dstX / 2
            for (col in 0 until w / 2) {
                var rs = 0; var gs = 0; var bs = 0
                for (dy in 0..1) for (dx in 0..1) {
                    val p = argb[(row * 2 + dy) * w + col * 2 + dx]
                    rs += (p shr 16) and 0xFF; gs += (p shr 8) and 0xFF; bs += p and 0xFF
                }
                val r = rs / 4; val g = gs / 4; val b = bs / 4
                yuv.u[dstRow + col] = ((-38 * r - 74 * g + 112 * b + 128) shr 8).plus(128).coerceIn(16, 240).toByte()
                yuv.v[dstRow + col] = ((112 * r - 94 * g - 18 * b + 128) shr 8).plus(128).coerceIn(16, 240).toByte()
            }
        }
    }

    /// Copies the planes into the codec's Image honouring row/pixel strides
    /// (planar or semi-planar — the plane views overlap for NV12/NV21).
    private fun fillImage(image: android.media.Image, yuv: Yuv) {
        val planes = image.planes
        val w = image.width
        val h = image.height
        copyPlane(planes[0].buffer, planes[0].rowStride, planes[0].pixelStride, yuv.y, w, h)
        copyPlane(planes[1].buffer, planes[1].rowStride, planes[1].pixelStride, yuv.u, w / 2, h / 2)
        copyPlane(planes[2].buffer, planes[2].rowStride, planes[2].pixelStride, yuv.v, w / 2, h / 2)
    }

    private fun copyPlane(dst: ByteBuffer, rowStride: Int, pixelStride: Int, src: ByteArray, w: Int, h: Int) {
        if (pixelStride == 1) {
            for (row in 0 until h) {
                dst.position(row * rowStride)
                dst.put(src, row * w, w)
            }
        } else {
            for (row in 0 until h) {
                val base = row * rowStride
                for (col in 0 until w) dst.put(base + col * pixelStride, src[row * w + col])
            }
        }
    }

    /// Fallback when the codec hands out no Image: raw I420 / NV12 buffer.
    private fun fillBuffer(buffer: ByteBuffer, colorFormat: Int, yuv: Yuv, w: Int, h: Int) {
        buffer.clear()
        buffer.put(yuv.y)
        if (colorFormat == MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar) {
            val n = w * h / 4
            for (i in 0 until n) { buffer.put(yuv.u[i]); buffer.put(yuv.v[i]) }
        } else {
            buffer.put(yuv.u); buffer.put(yuv.v)
        }
    }

    // MARK: - audio (MP3 → PCM → AAC, buffered)

    private fun transcodeAudio(file: File, check: () -> Unit): AudioResult {
        val extractor = MediaExtractor()
        var decoder: MediaCodec? = null
        var encoder: MediaCodec? = null
        try {
            try {
                extractor.setDataSource(file.path)
            } catch (e: Exception) {
                throw AyahVideoException(AyahVideoException.Kind.AUDIO_UNREADABLE, "cannot open recitation", e)
            }
            var trackIndex = -1
            var trackFormat: MediaFormat? = null
            for (i in 0 until extractor.trackCount) {
                val f = extractor.getTrackFormat(i)
                if (f.getString(MediaFormat.KEY_MIME).orEmpty().startsWith("audio/")) {
                    trackIndex = i; trackFormat = f; break
                }
            }
            if (trackIndex < 0 || trackFormat == null) {
                throw AyahVideoException(AyahVideoException.Kind.AUDIO_UNREADABLE, "no audio track")
            }
            extractor.selectTrack(trackIndex)
            val mime = trackFormat.getString(MediaFormat.KEY_MIME)!!
            val dec = try {
                MediaCodec.createDecoderByType(mime).apply {
                    configure(trackFormat, null, null, 0); start()
                }
            } catch (e: Exception) {
                throw AyahVideoException(AyahVideoException.Kind.CODEC_UNAVAILABLE, "no decoder for $mime", e)
            }
            decoder = dec

            val info = MediaCodec.BufferInfo()
            val pcm = ArrayDeque<ByteArray>()
            var pcmHeadOffset = 0
            var sampleRate = 0
            var channels = 0
            var decoderInputDone = false
            var decoderOutputDone = false
            var encoderInputDone = false
            var encoderOutputDone = false
            var fedBytes = 0L
            var encodedFormat: MediaFormat? = null
            val samples = ArrayList<EncodedSample>()
            var stalls = 0
            // Loudness accumulators, one bucket per video frame (grown as needed).
            var sums = DoubleArray(256)
            var counts = IntArray(256)
            var sampleIndex = 0L

            fun startEncoder(outputFormat: MediaFormat) {
                if (encoder != null) return
                sampleRate = outputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                channels = outputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                val format = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, channels).apply {
                    setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                    setInteger(MediaFormat.KEY_BIT_RATE, AUDIO_BIT_RATE)
                    setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 64 * 1024)
                }
                encoder = try {
                    MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC).apply {
                        configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE); start()
                    }
                } catch (e: Exception) {
                    throw AyahVideoException(AyahVideoException.Kind.CODEC_UNAVAILABLE, "no AAC encoder", e)
                }
            }

            while (!encoderOutputDone) {
                check()
                var progressed = false
                // 1. compressed audio → decoder
                if (!decoderInputDone) {
                    val idx = dec.dequeueInputBuffer(TIMEOUT_US)
                    if (idx >= 0) {
                        progressed = true
                        val buf = dec.getInputBuffer(idx)!!
                        val size = extractor.readSampleData(buf, 0)
                        if (size < 0) {
                            dec.queueInputBuffer(idx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            decoderInputDone = true
                        } else {
                            dec.queueInputBuffer(idx, 0, size, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }
                // 2. decoder → PCM queue
                if (!decoderOutputDone) {
                    val idx = dec.dequeueOutputBuffer(info, TIMEOUT_US)
                    when {
                        idx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            progressed = true
                            startEncoder(dec.outputFormat)
                        }
                        idx >= 0 -> {
                            progressed = true
                            if (encoder == null) startEncoder(dec.outputFormat)
                            if (info.size > 0) {
                                val buf = dec.getOutputBuffer(idx)!!
                                buf.position(info.offset); buf.limit(info.offset + info.size)
                                val chunk = ByteArray(info.size)
                                buf.get(chunk)
                                pcm.addLast(chunk)
                                // Mono-averaged squared samples into this frame's bucket.
                                val window = maxOf(1, sampleRate / FPS)
                                val frameBytes = 2 * channels
                                var off = 0
                                while (off + frameBytes <= chunk.size) {
                                    var acc = 0
                                    for (c in 0 until channels) {
                                        val lo = chunk[off + 2 * c].toInt() and 0xFF
                                        val hi = chunk[off + 2 * c + 1].toInt()
                                        acc += (hi shl 8) or lo
                                    }
                                    val v = acc.toDouble() / channels / 32768.0
                                    val frame = (sampleIndex / window).toInt()
                                    if (frame >= sums.size) {
                                        sums = sums.copyOf(sums.size * 2); counts = counts.copyOf(counts.size * 2)
                                    }
                                    sums[frame] += v * v; counts[frame]++
                                    sampleIndex++
                                    off += frameBytes
                                }
                            }
                            if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) decoderOutputDone = true
                            dec.releaseOutputBuffer(idx, false)
                        }
                    }
                }
                val enc = encoder
                if (enc != null) {
                    // 3. PCM queue → encoder (drain as far as it accepts)
                    while (!encoderInputDone && (pcm.isNotEmpty() || decoderOutputDone)) {
                        val idx = enc.dequeueInputBuffer(if (pcm.isEmpty()) TIMEOUT_US else 0)
                        if (idx < 0) break
                        progressed = true
                        val buf = enc.getInputBuffer(idx)!!
                        buf.clear()
                        if (pcm.isEmpty()) {
                            enc.queueInputBuffer(idx, 0, 0, presentationUs(fedBytes, sampleRate, channels),
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            encoderInputDone = true
                            break
                        }
                        var n = 0
                        while (pcm.isNotEmpty() && buf.remaining() > 0) {
                            val head = pcm.peekFirst()!!
                            val take = min(head.size - pcmHeadOffset, buf.remaining())
                            buf.put(head, pcmHeadOffset, take)
                            n += take
                            pcmHeadOffset += take
                            if (pcmHeadOffset >= head.size) { pcm.removeFirst(); pcmHeadOffset = 0 }
                        }
                        // Keep whole PCM frames per buffer so timestamps stay exact.
                        val frameBytes = 2 * channels
                        val rem = n % frameBytes
                        if (rem != 0) {
                            // Push the partial frame back to the queue head.
                            val tail = ByteArray(rem)
                            buf.position(n - rem); buf.get(tail)
                            n -= rem
                            if (pcm.isEmpty()) { pcm.addFirst(tail); pcmHeadOffset = 0 }
                            else {
                                val head = pcm.removeFirst()
                                val merged = tail + head.copyOfRange(pcmHeadOffset, head.size)
                                pcm.addFirst(merged); pcmHeadOffset = 0
                            }
                        }
                        enc.queueInputBuffer(idx, 0, n, presentationUs(fedBytes, sampleRate, channels), 0)
                        fedBytes += n
                    }
                    // 4. encoder → AAC samples
                    val idx = enc.dequeueOutputBuffer(info, TIMEOUT_US)
                    when {
                        idx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            progressed = true
                            encodedFormat = enc.outputFormat
                        }
                        idx >= 0 -> {
                            progressed = true
                            val isConfig = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
                            if (info.size > 0 && !isConfig) {
                                val buf = enc.getOutputBuffer(idx)!!
                                buf.position(info.offset); buf.limit(info.offset + info.size)
                                val data = ByteArray(info.size)
                                buf.get(data)
                                samples.add(EncodedSample(data, info.presentationTimeUs, info.flags))
                            }
                            if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) encoderOutputDone = true
                            enc.releaseOutputBuffer(idx, false)
                        }
                    }
                }
                stalls = if (progressed) 0 else stalls + 1
                if (stalls > MAX_STALLS) {
                    throw AyahVideoException(AyahVideoException.Kind.ENCODE_FAILED, "audio codec stalled")
                }
            }
            val format = encodedFormat ?: encoder?.outputFormat
                ?: throw AyahVideoException(AyahVideoException.Kind.ENCODE_FAILED, "no AAC output format")
            if (samples.isEmpty()) {
                throw AyahVideoException(AyahVideoException.Kind.AUDIO_UNREADABLE, "recitation decoded to silence")
            }
            val durationUs = presentationUs(fedBytes, sampleRate, channels)
            val frameCount = frameCount(durationUs)
            return AudioResult(format, samples, durationUs, loudnessEnvelope(sums, counts, frameCount))
        } catch (e: AyahVideoException) {
            throw e
        } catch (e: Exception) {
            throw AyahVideoException(AyahVideoException.Kind.ENCODE_FAILED, "audio transcode failed", e)
        } finally {
            runCatching { decoder?.stop() }; runCatching { decoder?.release() }
            runCatching { encoder?.stop() }; runCatching { encoder?.release() }
            runCatching { extractor.release() }
        }
    }

    /// Frames for (audio + tail) at [FPS], rounded up.
    private fun frameCount(audioUs: Long): Int {
        val frameUs = 1_000_000L / FPS
        return ((audioUs + TAIL_US + frameUs - 1) / frameUs).toInt().coerceAtLeast(1)
    }

    /// iOS loudnessEnvelope: per-frame RMS, log-scaled relative to the
    /// loudest frame (-40 dB floor), then fast attack / slow release. The
    /// tail frames have no samples and read as silence.
    private fun loudnessEnvelope(sums: DoubleArray, counts: IntArray, frameCount: Int): FloatArray {
        val raw = FloatArray(frameCount) { i ->
            if (i < counts.size && counts[i] > 0) sqrt(sums[i] / counts[i]).toFloat() else 0f
        }
        val peak = maxOf(raw.maxOrNull() ?: 0f, 0.0001f)
        for (i in raw.indices) {
            val db = 20 * log10(maxOf(raw[i] / peak, 0.0001f))
            raw[i] = ((db + 40) / 40).coerceIn(0f, 1f)
        }
        val smoothed = FloatArray(frameCount)
        var current = 0f
        for (i in 0 until frameCount) {
            val target = raw[i]
            current += (target - current) * (if (target > current) 0.6f else 0.18f)
            smoothed[i] = current
        }
        return smoothed
    }

    private fun presentationUs(bytes: Long, sampleRate: Int, channels: Int): Long =
        if (sampleRate <= 0 || channels <= 0) 0L
        else bytes * 1_000_000L / (2L * channels * sampleRate)

    // MARK: - video + mux

    private fun encodeAndMux(yuv: Yuv, layout: Layout, audio: AudioResult, out: File, check: () -> Unit) {
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, WIDTH, HEIGHT).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible)
            setInteger(MediaFormat.KEY_BIT_RATE, VIDEO_BIT_RATE)
            setInteger(MediaFormat.KEY_FRAME_RATE, FPS)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL_S)
        }
        val encoder = try {
            MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC).apply {
                configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE); start()
            }
        } catch (e: Exception) {
            throw AyahVideoException(AyahVideoException.Kind.CODEC_UNAVAILABLE, "no H.264 encoder", e)
        }
        val muxer = try {
            MediaMuxer(out.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        } catch (e: Exception) {
            runCatching { encoder.release() }
            throw AyahVideoException(AyahVideoException.Kind.MUX_FAILED, "cannot create MP4", e)
        }
        val inputColor = runCatching { encoder.inputFormat.getInteger(MediaFormat.KEY_COLOR_FORMAT) }
            .getOrDefault(MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar)
        val frameUs = 1_000_000L / FPS
        val frameCount = frameCount(audio.durationUs)
        val region = barRegion(layout)
        val info = MediaCodec.BufferInfo()
        var videoTrack = -1
        var audioTrack = -1
        var started = false
        var audioCursor = 0
        var frame = 0
        var inputDone = false
        var outputDone = false
        var stalls = 0

        fun writeAudioUpTo(untilUs: Long) {
            while (audioCursor < audio.samples.size && audio.samples[audioCursor].presentationUs <= untilUs) {
                val s = audio.samples[audioCursor]
                val bi = MediaCodec.BufferInfo().apply {
                    set(0, s.data.size, s.presentationUs, s.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM.inv())
                }
                muxer.writeSampleData(audioTrack, ByteBuffer.wrap(s.data), bi)
                audioCursor++
            }
        }

        try {
            while (!outputDone) {
                check()
                var progressed = false
                if (!inputDone) {
                    val idx = encoder.dequeueInputBuffer(TIMEOUT_US)
                    if (idx >= 0) {
                        progressed = true
                        val pts = frame * frameUs
                        if (frame >= frameCount) {
                            encoder.queueInputBuffer(idx, 0, 0, pts, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            drawBars(region, layout, audio.envelope, frame, yuv)
                            val image = encoder.getInputImage(idx)
                            if (image != null) {
                                fillImage(image, yuv)
                                image.close()
                            } else {
                                fillBuffer(encoder.getInputBuffer(idx)!!, inputColor, yuv, WIDTH, HEIGHT)
                            }
                            encoder.queueInputBuffer(idx, 0, WIDTH * HEIGHT * 3 / 2, pts, 0)
                            frame++
                        }
                    }
                }
                val idx = encoder.dequeueOutputBuffer(info, TIMEOUT_US)
                when {
                    idx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        progressed = true
                        if (started) throw AyahVideoException(AyahVideoException.Kind.ENCODE_FAILED, "format changed twice")
                        // Both output formats known (the video one carries
                        // csd-0/csd-1) — only now may the muxer start.
                        videoTrack = muxer.addTrack(encoder.outputFormat)
                        audioTrack = muxer.addTrack(audio.format)
                        muxer.start()
                        started = true
                    }
                    idx >= 0 -> {
                        progressed = true
                        val isConfig = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
                        if (info.size > 0 && !isConfig) {
                            if (!started) throw AyahVideoException(AyahVideoException.Kind.ENCODE_FAILED, "video sample before format")
                            val buf = encoder.getOutputBuffer(idx)!!
                            buf.position(info.offset); buf.limit(info.offset + info.size)
                            val flags = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM.inv()
                            val bi = MediaCodec.BufferInfo().apply { set(info.offset, info.size, info.presentationTimeUs, flags) }
                            muxer.writeSampleData(videoTrack, buf, bi)
                            writeAudioUpTo(info.presentationTimeUs)
                        }
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
                        encoder.releaseOutputBuffer(idx, false)
                    }
                }
                stalls = if (progressed) 0 else stalls + 1
                if (stalls > MAX_STALLS) {
                    throw AyahVideoException(AyahVideoException.Kind.ENCODE_FAILED, "video encoder stalled")
                }
            }
            if (!started) throw AyahVideoException(AyahVideoException.Kind.ENCODE_FAILED, "no video output")
            writeAudioUpTo(Long.MAX_VALUE)
            try {
                muxer.stop()
            } catch (e: Exception) {
                throw AyahVideoException(AyahVideoException.Kind.MUX_FAILED, "finalising MP4 failed", e)
            }
        } catch (e: AyahVideoException) {
            throw e
        } catch (e: Exception) {
            throw AyahVideoException(AyahVideoException.Kind.ENCODE_FAILED, "video encode failed", e)
        } finally {
            region.bitmap.recycle()
            runCatching { encoder.stop() }; runCatching { encoder.release() }
            runCatching { muxer.release() }
        }
    }
}
