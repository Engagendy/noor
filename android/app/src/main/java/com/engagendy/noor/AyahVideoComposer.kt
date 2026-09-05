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
import kotlin.math.min

/// Why a video could not be produced — surfaced as one short toast.
class AyahVideoException(val kind: Kind, message: String, cause: Throwable? = null) :
    Exception(message, cause) {
    enum class Kind { AUDIO_UNREADABLE, CODEC_UNAVAILABLE, ENCODE_FAILED, MUX_FAILED }
}

/// "Share as video": the ayah share card held still on paper for the
/// length of its recitation, muxed into a 1080×1920 H.264 + AAC MP4.
/// Platform codecs only (MediaCodec / MediaExtractor / MediaMuxer) — no
/// ffmpeg, no third-party code. Runs entirely off-main.
///
/// Assembly: the card is drawn once onto a portrait paper frame, converted
/// once to the encoder's flexible YUV420 layout, and that same frame is
/// queued at 15 fps with rising timestamps for (audio duration + 0.5 s).
/// The MP3 is decoded to PCM and re-encoded to AAC first (buffered, a few
/// hundred KB), so the muxer can start as soon as the video encoder
/// reports its output format, with audio samples interleaved by timestamp.
object AyahVideoComposer {

    const val WIDTH = 1080
    const val HEIGHT = 1920
    const val FPS = 15
    private const val VIDEO_BIT_RATE = 4_000_000
    private const val AUDIO_BIT_RATE = 128_000
    private const val I_FRAME_INTERVAL_S = 1
    private const val TAIL_US = 500_000L
    private const val MARGIN = 72f
    private val paper = Color.parseColor("#FAF6EE")
    private const val TIMEOUT_US = 10_000L
    /// Consecutive empty dequeues before we give up on a stalled codec (~10 s).
    private const val MAX_STALLS = 1_000
    private const val STALE_SHARE_MS = 60 * 60 * 1000L

    private class EncodedSample(val data: ByteArray, val presentationUs: Long, val flags: Int)
    private class AudioResult(val format: MediaFormat, val samples: List<EncodedSample>, val durationUs: Long)

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

            val frame = renderFrame(card)
            val yuv = toYuv420(frame)
            frame.recycle()
            check()
            val audioResult = transcodeAudio(audio, check)
            check()
            try {
                encodeAndMux(yuv, audioResult, out, check)
            } catch (e: AyahVideoException) {
                out.delete(); throw e
            } catch (e: Throwable) {
                out.delete(); throw e
            }
            out
        }

    // MARK: - frame

    /// Card scaled to the frame width (minus margins), centred on paper.
    private fun renderFrame(card: Bitmap): Bitmap {
        val frame = Bitmap.createBitmap(WIDTH, HEIGHT, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(frame)
        canvas.drawColor(paper)
        val maxW = WIDTH - 2 * MARGIN
        val maxH = HEIGHT - 2 * MARGIN
        val scale = min(maxW / card.width, maxH / card.height)
        val w = card.width * scale
        val h = card.height * scale
        val left = (WIDTH - w) / 2f
        val top = (HEIGHT - h) / 2f
        canvas.drawBitmap(card, null, RectF(left, top, left + w, top + h),
            Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG))
        return frame
    }

    private class Yuv(val y: ByteArray, val u: ByteArray, val v: ByteArray)

    /// BT.601 limited-range planar conversion, chroma averaged over 2×2.
    private fun toYuv420(bitmap: Bitmap): Yuv {
        val w = bitmap.width
        val h = bitmap.height
        val argb = IntArray(w * h)
        bitmap.getPixels(argb, 0, w, 0, 0, w, h)
        val y = ByteArray(w * h)
        val u = ByteArray(w * h / 4)
        val v = ByteArray(w * h / 4)
        for (row in 0 until h) {
            for (col in 0 until w) {
                val p = argb[row * w + col]
                val r = (p shr 16) and 0xFF
                val g = (p shr 8) and 0xFF
                val b = p and 0xFF
                y[row * w + col] = ((66 * r + 129 * g + 25 * b + 128) shr 8).plus(16).coerceIn(16, 235).toByte()
            }
        }
        val cw = w / 2
        for (row in 0 until h / 2) {
            for (col in 0 until cw) {
                var rs = 0; var gs = 0; var bs = 0
                for (dy in 0..1) for (dx in 0..1) {
                    val p = argb[(row * 2 + dy) * w + col * 2 + dx]
                    rs += (p shr 16) and 0xFF; gs += (p shr 8) and 0xFF; bs += p and 0xFF
                }
                val r = rs / 4; val g = gs / 4; val b = bs / 4
                u[row * cw + col] = ((-38 * r - 74 * g + 112 * b + 128) shr 8).plus(128).coerceIn(16, 240).toByte()
                v[row * cw + col] = ((112 * r - 94 * g - 18 * b + 128) shr 8).plus(128).coerceIn(16, 240).toByte()
            }
        }
        return Yuv(y, u, v)
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
            return AudioResult(format, samples, durationUs)
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

    private fun presentationUs(bytes: Long, sampleRate: Int, channels: Int): Long =
        if (sampleRate <= 0 || channels <= 0) 0L
        else bytes * 1_000_000L / (2L * channels * sampleRate)

    // MARK: - video + mux

    private fun encodeAndMux(yuv: Yuv, audio: AudioResult, out: File, check: () -> Unit) {
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
        val totalUs = audio.durationUs + TAIL_US
        val frameCount = ((totalUs + frameUs - 1) / frameUs).toInt().coerceAtLeast(1)
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
            runCatching { encoder.stop() }; runCatching { encoder.release() }
            runCatching { muxer.release() }
        }
    }
}
