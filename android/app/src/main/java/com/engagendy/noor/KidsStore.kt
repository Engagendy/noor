package com.engagendy.noor

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import java.util.concurrent.Executors
import org.json.JSONObject

/// Persistence + live state for kids mode. Keys are shared VERBATIM with
/// iOS so a child's band and stars mean the same thing on both platforms:
///
///   "kids.enabled"  Boolean, default false
///   "kids.age"      Int, default 7 (valid 4…12)
///   "kids.stars"    JSON object of surahId → star count (0…3)
///   "kids.listenMode" Boolean, default false (false = memorise, with the
///                     age band's repeats; true = listen straight through)
///   "kids.reciterApplied" Boolean, default false — the Muallim teaching
///                     recitation is selected the FIRST time kids mode is
///                     ever enabled and never again, so a parent who later
///                     picks another reciter keeps it across disabling and
///                     re-enabling. Never reset on disable.
///
/// They live in the app's existing "noor" SharedPreferences (the same store
/// Settings uses, `KhatmahPlan.prefs`) — kids mode is a setting, not a
/// separate app.
///
/// Compose state is the source of truth for the UI; prefs are written only
/// from click handlers / player callbacks, always on a background thread.
object KidsStore {
    private const val KEY_ENABLED = "kids.enabled"
    private const val KEY_AGE = "kids.age"
    private const val KEY_STARS = "kids.stars"
    private const val KEY_LISTEN = "kids.listenMode"
    private const val KEY_RECITER_APPLIED = "kids.reciterApplied"

    /// True while the kids shell owns the screen.
    var enabled by mutableStateOf(false)
        private set

    /// The child's age; drives every band decision through `KidsMode`.
    var age by mutableIntStateOf(KidsMode.DEFAULT_AGE)
        private set

    /// False (the default) = memorise: the age band's repeats lead. True =
    /// listen straight through. The child changes this from the shell's
    /// sound sheet — no grown-up gate, it is not an escape hatch.
    var listenMode by mutableStateOf(false)
        private set

    private val stars = mutableStateMapOf<Int, Int>()

    private val io = Executors.newSingleThreadExecutor()

    /// Reads the stored flag + age (cheap, needed before the first frame)
    /// and loads the star map off-main. Call once from MainActivity.
    fun load(context: Context) {
        val prefs = KhatmahPlan.prefs(context)
        enabled = prefs.getBoolean(KEY_ENABLED, false)
        age = prefs.getInt(KEY_AGE, KidsMode.DEFAULT_AGE)
            .coerceIn(KidsMode.MIN_AGE, KidsMode.MAX_AGE)
        listenMode = prefs.getBoolean(KEY_LISTEN, false)
        val app = context.applicationContext
        io.execute {
            val parsed = readStars(app)
            // Compose state must change on the main thread.
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                stars.clear()
                stars.putAll(parsed)
            }
        }
    }

    private fun readStars(context: Context): Map<Int, Int> {
        val raw = KhatmahPlan.prefs(context).getString(KEY_STARS, null) ?: return emptyMap()
        return runCatching {
            val json = JSONObject(raw)
            buildMap {
                json.keys().forEach { key ->
                    val id = key.toIntOrNull() ?: return@forEach
                    put(id, json.optInt(key, 0).coerceIn(0, KidsMode.MAX_STARS))
                }
            }
        }.getOrDefault(emptyMap())
    }

    /// User action (age sheet confirmed): stores the band and enters the
    /// shell. On the FIRST enable in the app's lifetime only (guarded by
    /// `kids.reciterApplied`), the Muallim teaching recitation is selected —
    /// afterwards the choice is the parent's or the child's to keep.
    fun enable(context: Context, chosenAge: Int) {
        val value = chosenAge.coerceIn(KidsMode.MIN_AGE, KidsMode.MAX_AGE)
        age = value
        enabled = true
        val prefs = KhatmahPlan.prefs(context)
        val firstEnable = !prefs.getBoolean(KEY_RECITER_APPLIED, false)
        if (firstEnable) NoorPlayer.selectReciter(Reciters.byId(KidsMode.TEACHING_RECITER_ID))
        val app = context.applicationContext
        io.execute {
            KhatmahPlan.prefs(app).edit()
                .putBoolean(KEY_ENABLED, true)
                .putInt(KEY_AGE, value)
                .putBoolean(KEY_RECITER_APPLIED, true)
                .apply()
        }
    }

    /// User action, behind the parental gate.
    fun disable(context: Context) {
        enabled = false
        val app = context.applicationContext
        io.execute {
            KhatmahPlan.prefs(app).edit().putBoolean(KEY_ENABLED, false).apply()
        }
    }

    /// Child action from the sound sheet.
    fun setListenMode(context: Context, value: Boolean) {
        listenMode = value
        val app = context.applicationContext
        io.execute {
            KhatmahPlan.prefs(app).edit().putBoolean(KEY_LISTEN, value).apply()
        }
    }

    fun stars(surahId: Int): Int = stars[surahId] ?: 0

    val totalStars: Int get() = stars.values.sum()

    /// One completed play of [surahId] earns one star (max three). Called
    /// from the player's completion callback; the write is off-main.
    fun recordCompletion(context: Context, surahId: Int) {
        val next = KidsMode.awardStar(stars(surahId))
        if (next == stars(surahId)) return
        stars[surahId] = next
        val snapshot = stars.toMap()
        val app = context.applicationContext
        io.execute {
            val json = JSONObject()
            snapshot.forEach { (id, count) -> json.put(id.toString(), count) }
            KhatmahPlan.prefs(app).edit().putString(KEY_STARS, json.toString()).apply()
        }
    }
}
