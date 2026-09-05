package com.engagendy.noor

import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import kotlin.math.abs

/// Device check for the "Share as video" composer: a real MP3 (the bundled
/// adhan — non-Quranic, so no Quran text is typed here either) → MP4 with
/// one H.264 1080×1920 track and one AAC track, duration = audio + 0.5 s.
@RunWith(AndroidJUnit4::class)
class AyahVideoComposerTest {

    @Test
    fun composesPortraitMp4WithBothTracks() {
        runBlocking { checkComposer() }
    }

    private suspend fun checkComposer() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val mp3 = File(context.cacheDir.apply { mkdirs() }, "test-audio.mp3")
        context.resources.openRawResource(R.raw.adhan_azeez).use { input ->
            mp3.outputStream().use { input.copyTo(it) }
        }
        val audioMs = MediaMetadataRetriever().run {
            setDataSource(mp3.path)
            val d = extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)!!.toLong()
            release(); d
        }
        // Clearly non-Quranic placeholder Arabic for the card.
        val card = ShareCard.render(context, "نصّ تجريبي للبطاقة", "اختبار · 1:1", useQuranFont = true)

        val out = AyahVideoComposer.compose(context, card, mp3)

        assertTrue(out.exists() && out.length() > 10_000)
        assertTrue(out.name.endsWith(".mp4") && out.parentFile!!.name == "shared")
        val retriever = MediaMetadataRetriever().apply { setDataSource(out.path) }
        val width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)!!.toInt()
        val height = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)!!.toInt()
        val duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)!!.toLong()
        assertEquals("yes", retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO))
        assertEquals("yes", retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO))
        retriever.release()
        assertEquals(1080, width)
        assertEquals(1920, height)
        assertTrue("duration $duration vs audio $audioMs", abs(duration - (audioMs + 500)) < 400)

        val extractor = MediaExtractor().apply { setDataSource(out.path) }
        val mimes = (0 until extractor.trackCount)
            .map { extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)!! }.sorted()
        assertEquals(listOf("audio/mp4a-latm", "video/avc"), mimes)
        // 24 fps: one sample per frame on the video track.
        val videoTrack = (0 until extractor.trackCount).first {
            extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME) == "video/avc"
        }
        extractor.selectTrack(videoTrack)
        var frames = 0
        while (extractor.sampleTrackIndex >= 0) { frames++; extractor.advance() }
        extractor.release()
        val expectedFrames = Math.ceil((audioMs + 500) * AyahVideoComposer.FPS / 1000.0).toInt()
        assertEquals(24, AyahVideoComposer.FPS)
        assertTrue("frames $frames vs expected $expectedFrames", abs(frames - expectedFrames) <= 2)

        // The equaliser moves: a mid-video frame differs from the first one.
        val frameReader = MediaMetadataRetriever().apply { setDataSource(out.path) }
        val first = frameReader.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST)!!
        val middle = frameReader.getFrameAtTime(duration * 500, MediaMetadataRetriever.OPTION_CLOSEST)!!
        frameReader.release()
        assertEquals(1080, first.width)
        assertTrue("bars did not move between frame 0 and mid-video", !first.sameAs(middle))
        // Left behind for eyeballing (adb run-as … cat cache/test-mid-frame.png).
        File(context.cacheDir, "test-mid-frame.png").outputStream().use {
            middle.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it)
        }
        out.delete()
    }
}
