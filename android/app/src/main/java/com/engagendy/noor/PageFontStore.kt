package com.engagendy.noor

import android.content.Context
import android.graphics.Typeface
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger

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

    // Reader downloads in flight (ensure + its neighbour prefetch). The
    // background worker polls this and waits while it is non-zero, so the
    // page the user is looking at never shares bandwidth with the queue.
    private val readerFetches = AtomicInteger(0)
    val readerBusy: Boolean get() = readerFetches.get() > 0

    /// Bumped whenever a page file lands on disk — from the reader OR the
    /// background worker. A page stuck on the "unavailable" placeholder
    /// watches this so it reloads the moment the worker fetches it.
    var landedGeneration by mutableIntStateOf(0)
        private set

    /// Where the downloaded page fonts live — measured by the Storage screen.
    fun dir(context: Context) = File(context.filesDir, "pagefonts")

    private const val PREFIX = "v2u_page_"
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

    /// The font is shipped untouched, so the DB's glyph codes are already
    /// the font's codes. Kept as the single place callers go through, so a
    /// future remapping has one home.
    fun mapGlyphs(text: String): String = text

    private fun remoteUrl(page: Int) =
        "https://raw.githubusercontent.com/mustafa0x/qpc-fonts/master/mushaf-v2/QCF2%03d.ttf"
            .format(java.util.Locale.ROOT, page)

    /// Drops a page's cached family and its file, so the next `ensure`
    /// refetches. Called when the font turns out to be unusable at render
    /// time — Compose rejects some files Typeface accepts.
    fun invalidate(context: Context, page: Int) {
        cache.remove(page)
        runCatching { localFile(context, page).delete() }
    }

    /// True when the page's font file is already on disk. Cheap (one stat).
    fun isCached(context: Context, page: Int): Boolean = localFile(context, page).exists()

    /// Whether any network with internet access is up right now — lets the
    /// reader show "no connection" instead of retrying into the void.
    fun isOnline(context: Context): Boolean {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return true
        val caps = cm.getNetworkCapabilities(cm.activeNetwork ?: return false) ?: return false
        return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }

    /// Gets the page file onto disk (legacy promotion or download) and
    /// validates it. Caller holds lockFor(page). Blocking; IO thread only.
    private fun materialize(context: Context, page: Int, local: File): Boolean {
        val wasThere = local.exists()
        if (!wasThere && !migrateLegacy(context, page, local) &&
            !download(page, local)) return false
        try {
            // Validates the file — throws on a corrupt/partial download.
            Typeface.createFromFile(local)
        } catch (e: RuntimeException) {
            local.delete()  // refetch next time
            return false
        }
        if (!wasThere) landedGeneration++
        return true
    }

    /// Ensures the font for `page` is on disk and loaded. Blocking network
    /// and file I/O — call on Dispatchers.IO only. Returns null offline.
    /// This is the READER's path: while it is downloading, `readerBusy`
    /// is true and the background worker stands aside.
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

        readerFetches.incrementAndGet()
        try {
            synchronized(lockFor(page)) {
                // Re-check: another caller may have finished while we waited.
                cache[page]?.let { return it }
                val local = localFile(context, page)
                if (!materialize(context, page, local)) return null
                val family = FontFamily(Font(local))
                cache[page] = family
                return family
            }
        } finally {
            readerFetches.decrementAndGet()
        }
    }

    /// The background WORKER's path: disk only, no FontFamily is built (604
    /// families would sit in memory for nothing). Idempotent — returns true
    /// at once when the file is there. Takes the same per-page lock as
    /// `ensure`, so a page the reader is fetching is never fetched twice,
    /// and a reader arriving mid-download waits only for that one file.
    /// Locks are never nested, so the two paths cannot deadlock.
    fun fetch(context: Context, page: Int): Boolean {
        if (page < 1 || page > PageLayoutDb.PAGE_COUNT) return false
        if (isCached(context, page)) return true
        synchronized(lockFor(page)) {
            return materialize(context, page, localFile(context, page))
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
            temp.renameTo(local).also { if (!it) temp.delete() }
        } catch (e: Exception) {
            temp.delete()
            false
        }
    }
}
