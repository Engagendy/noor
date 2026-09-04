package com.engagendy.noor

import android.content.Context
import android.graphics.Typeface
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ConcurrentHashMap

/// Downloads the per-page QCF v2 fonts (KFGQPC — the exact printed Madani
/// mushaf typeface, ~600 KB each) on demand, cached in filesDir — each
/// page is offline after its first view. Same source as iOS: the
/// mustafa0x/qpc-fonts mirror (see LICENSES.md).
object PageFontStore {
    private val cache = ConcurrentHashMap<Int, FontFamily>()
    // One lock per page: the pager's off-screen composition, the neighbour
    // prefetch and Settings' download-all can all call ensure() for the same
    // page at once — without this they'd write into one shared file.
    private val locks = ConcurrentHashMap<Int, Any>()
    private fun lockFor(page: Int): Any = locks.getOrPut(page) { Any() }

    /// Where the downloaded page fonts live — measured by the Storage screen.
    fun dir(context: Context) = File(context.filesDir, "pagefonts")

    private const val PREFIX = "v2c_page_"
    // Pre-cmap-patch name used by earlier builds; same bytes minus the patch.
    private const val LEGACY_PREFIX = "v2_page_"

    /// How many of the 604 page fonts are already offline. Only files of the
    /// current (patched) generation count — legacy `v2_` files still need
    /// patching before a page can render. Disk IO — call on Dispatchers.IO.
    fun cachedCount(context: Context): Int {
        // Settings can ask before any page was opened; kick the migration so
        // an old install's legacy files are promoted rather than re-fetched.
        sweepStaleOnce(context)
        return dir(context).listFiles { f -> f.name.startsWith(PREFIX) && f.name.endsWith(".ttf") }?.size ?: 0
    }

    // v2c: cmap-patched files (presentation-form codepoints shifted to PUA
    // so Android's shaper can't treat the shadda-ligature glyphs as
    // combining marks and stack them — the page-76 word-overlap bug).
    private fun localFile(context: Context, page: Int) =
        File(dir(context), "%s%03d.ttf".format(java.util.Locale.ROOT, PREFIX, page))

    private fun legacyFile(context: Context, page: Int) =
        File(dir(context), "%s%03d.ttf".format(java.util.Locale.ROOT, LEGACY_PREFIX, page))

    /// Re-uses a legacy unpatched download instead of fetching ~600 KB
    /// again: patch it in place and promote it to the current name. Caller
    /// holds lockFor(page). Returns true if `local` now exists.
    private fun migrateLegacy(context: Context, page: Int, local: File): Boolean {
        val legacy = legacyFile(context, page)
        if (!legacy.exists()) return false
        if (local.exists()) { legacy.delete(); return true }
        return try {
            patchCmap(legacy)
            legacy.renameTo(local)
        } catch (e: Exception) {
            false
        }.also { if (!it) legacy.delete() }
    }

    @Volatile private var sweepStarted = false

    /// One-off, off the caller's thread: promotes every leftover legacy
    /// file and removes stray `.part` temps, so old installs neither keep
    /// ~360 MB of orphans nor re-download pages they already have.
    private fun sweepStaleOnce(context: Context) {
        if (sweepStarted) return
        synchronized(this) {
            if (sweepStarted) return
            sweepStarted = true
        }
        val appContext = context.applicationContext
        Thread({
            val files = dir(appContext).listFiles() ?: return@Thread
            // A .part younger than this may be a download in flight.
            val staleBefore = System.currentTimeMillis() - 10 * 60_000L
            for (f in files) {
                val name = f.name
                when {
                    name.endsWith(".part") -> if (f.lastModified() < staleBefore) f.delete()
                    name.startsWith(LEGACY_PREFIX) && name.endsWith(".ttf") -> {
                        val page = name.removePrefix(LEGACY_PREFIX).removeSuffix(".ttf").toIntOrNull()
                        if (page == null || page < 1 || page > PageLayoutDb.PAGE_COUNT) {
                            f.delete()
                        } else if (!cache.containsKey(page)) {
                            // Never rewrite a file a live FontFamily is
                            // already reading: Compose resolves it lazily.
                            synchronized(lockFor(page)) {
                                migrateLegacy(appContext, page, localFile(appContext, page))
                            }
                        }
                    }
                }
            }
        }, "pagefont-sweep").apply { isDaemon = true; priority = Thread.MIN_PRIORITY }.start()
    }

    /// Maps a DB glyph string to the patched font's codepoints.
    fun mapGlyphs(text: String): String = buildString(text.length) {
        for (ch in text) {
            append(if (ch.code in 0xFB50..0xFD79) (ch.code - 0x1000).toChar() else ch)
        }
    }

    /// Shifts every cmap character code in FB50..FD79 down by 0x1000 into
    /// the PUA (EB50..ED79). Segment structure is untouched, so this is a
    /// safe in-place byte edit; glyphs and metrics are unchanged.
    private fun patchCmap(file: File) {
        val bytes = file.readBytes()
        fun u16(o: Int) = ((bytes[o].toInt() and 255) shl 8) or (bytes[o + 1].toInt() and 255)
        fun u32(o: Int) = (u16(o).toLong() shl 16) or u16(o + 2).toLong()
        fun put16(o: Int, v: Int) { bytes[o] = (v shr 8).toByte(); bytes[o + 1] = v.toByte() }
        fun put32(o: Int, v: Long) { put16(o, (v shr 16).toInt()); put16(o + 2, (v and 0xFFFF).toInt()) }
        val numTables = u16(4)
        var cmapOffset = -1
        for (i in 0 until numTables) {
            val rec = 12 + i * 16
            val tag = String(bytes, rec, 4, Charsets.US_ASCII)
            if (tag == "cmap") { cmapOffset = u32(rec + 8).toInt(); break }
        }
        if (cmapOffset < 0) return
        val subCount = u16(cmapOffset + 2)
        for (i in 0 until subCount) {
            val subOffset = cmapOffset + u32(cmapOffset + 4 + i * 8 + 4).toInt()
            when (u16(subOffset)) {
                4 -> {
                    val segCount = u16(subOffset + 6) / 2
                    val endBase = subOffset + 14
                    val startBase = endBase + segCount * 2 + 2
                    val deltaBase = startBase + segCount * 2
                    val rangeBase = deltaBase + segCount * 2
                    for (seg in 0 until segCount) {
                        val sv = u16(startBase + seg * 2)
                        if (sv !in 0xFB50..0xFD79) continue
                        put16(startBase + seg * 2, sv - 0x1000)
                        put16(endBase + seg * 2, u16(endBase + seg * 2) - 0x1000)
                        // glyph = charCode + idDelta (mod 2^16) when
                        // idRangeOffset == 0 — compensate the shift.
                        if (u16(rangeBase + seg * 2) == 0) {
                            put16(deltaBase + seg * 2,
                                  (u16(deltaBase + seg * 2) + 0x1000) and 0xFFFF)
                        }
                    }
                }
                12 -> {
                    val groups = u32(subOffset + 12).toInt()
                    for (g in 0 until groups) {
                        val go = subOffset + 16 + g * 12
                        for (field in 0..1) {
                            val v = u32(go + field * 4)
                            if (v in 0xFB50L..0xFD79L) put32(go + field * 4, v - 0x1000)
                        }
                    }
                }
            }
        }
        file.writeBytes(bytes)
    }

    private fun remoteUrl(page: Int) =
        "https://raw.githubusercontent.com/mustafa0x/qpc-fonts/master/mushaf-v2/QCF2%03d.ttf"
            .format(java.util.Locale.ROOT, page)

    /// Ensures the font for `page` is on disk and loaded. Blocking network
    /// and file I/O — call on Dispatchers.IO only. Returns null offline.
    /// Drops a page's cached family and its file, so the next `ensure`
    /// refetches. Called when the font turns out to be unusable at render
    /// time — Compose rejects some files Typeface accepts.
    fun invalidate(context: Context, page: Int) {
        cache.remove(page)
        runCatching { localFile(context, page).delete() }
    }

    fun ensure(context: Context, page: Int): FontFamily? {
        if (page < 1 || page > PageLayoutDb.PAGE_COUNT) return null
        // A cached family is only good while its file is still there: the
        // file backs the FontFamily lazily, and handing out one whose file
        // has gone makes Compose throw "Could not load font" mid-layout,
        // which takes the whole app down.
        cache[page]?.let {
            if (localFile(context, page).exists()) return it
            cache.remove(page)
        }
        sweepStaleOnce(context)

        synchronized(lockFor(page)) {
            // Re-check: another caller may have finished while we waited.
            cache[page]?.let { return it }
            val local = localFile(context, page)
            if (!local.exists() && !migrateLegacy(context, page, local) &&
                !download(page, local)) return null
            try {
                // Validates the file — throws on a corrupt/partial download.
                Typeface.createFromFile(local)
            } catch (e: RuntimeException) {
                local.delete()  // refetch next time
                return null
            }
            val family = FontFamily(Font(local))
            cache[page] = family
            return family
        }
    }

    private fun download(page: Int, local: File): Boolean {
        val dir = local.parentFile ?: return false
        dir.mkdirs()
        // Uniquely named temp so no two writers can ever share a file, then
        // an atomic rename once the bytes are complete and patched.
        val temp = try {
            File.createTempFile(local.name + ".", ".part", dir)
        } catch (e: java.io.IOException) {
            return false
        }
        return try {
            val connection = URL(remoteUrl(page)).openConnection() as HttpURLConnection
            connection.connectTimeout = 15_000
            connection.readTimeout = 30_000
            connection.inputStream.use { input ->
                temp.outputStream().use { input.copyTo(it) }
            }
            connection.disconnect()
            patchCmap(temp)
            temp.renameTo(local).also { if (!it) temp.delete() }
        } catch (e: Exception) {
            temp.delete()
            false
        }
    }
}
