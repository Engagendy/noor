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

    private fun localFile(context: Context, page: Int) =
        File(context.filesDir, "pagefonts/v2_page_%03d.ttf".format(page))

    private fun remoteUrl(page: Int) =
        "https://raw.githubusercontent.com/mustafa0x/qpc-fonts/master/mushaf-v2/QCF2%03d.ttf"
            .format(page)

    /// Ensures the font for `page` is on disk and loaded. Blocking network
    /// and file I/O — call on Dispatchers.IO only. Returns null offline.
    fun ensure(context: Context, page: Int): FontFamily? {
        if (page < 1 || page > PageLayoutDb.PAGE_COUNT) return null
        cache[page]?.let { return it }

        val local = localFile(context, page)
        if (!local.exists() && !download(page, local)) return null
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

    private fun download(page: Int, local: File): Boolean {
        local.parentFile?.mkdirs()
        val temp = File(local.path + ".part")
        return try {
            val connection = URL(remoteUrl(page)).openConnection() as HttpURLConnection
            connection.connectTimeout = 15_000
            connection.readTimeout = 30_000
            connection.inputStream.use { input ->
                temp.outputStream().use { input.copyTo(it) }
            }
            connection.disconnect()
            temp.renameTo(local)
        } catch (e: Exception) {
            temp.delete()
            false
        }
    }
}
