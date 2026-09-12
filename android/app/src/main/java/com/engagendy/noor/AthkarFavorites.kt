package com.engagendy.noor

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import java.util.concurrent.Executors

/// Favourite athkar. Key shared VERBATIM with iOS:
///
///   "athkar.favorites"  string set of the dhikr's `audio` filename
///
/// A dhikr in athkar.json has no id — only text, count and audio — and the
/// audio filename is the one field that is unique across all 267 items
/// (texts repeat in four places; an index breaks the moment a chapter is
/// reordered), so it is the stable identity. Items without a recording
/// cannot be favourited; there are none today.
///
/// Lives in the app's existing "noor" SharedPreferences (`KhatmahPlan.prefs`).
/// Compose state is the source of truth for the UI and is read by every
/// screen at once; prefs are written only from click handlers, off-main.
object AthkarFavorites {
    private const val KEY = "athkar.favorites"

    var keys by mutableStateOf<Set<String>>(emptySet())
        private set

    private val io = Executors.newSingleThreadExecutor()

    /// Cheap read (one string set), called once from MainActivity.
    fun load(context: Context) {
        keys = KhatmahPlan.prefs(context).getStringSet(KEY, null)?.toSet() ?: emptySet()
    }

    fun key(dhikr: Dhikr): String? = dhikr.audio

    fun isFavorite(dhikr: Dhikr): Boolean = dhikr.audio?.let { it in keys } == true

    /// User action from a dhikr row: flips the flag and persists it.
    fun toggle(context: Context, dhikr: Dhikr) {
        val id = dhikr.audio ?: return
        val next = if (id in keys) keys - id else keys + id
        keys = next
        val app = context.applicationContext
        io.execute {
            // A fresh set: SharedPreferences must never be handed the
            // instance it returned from getStringSet.
            KhatmahPlan.prefs(app).edit().putStringSet(KEY, HashSet(next)).apply()
        }
    }
}
