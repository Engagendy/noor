package com.engagendy.noor

import android.content.Context
import android.content.SharedPreferences
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

/// A khatmah goal: finish the mushaf (604 pages) in a chosen number of
/// days. Pure math over SharedPreferences state — 1:1 port of the iOS
/// App/KhatmahPlan.swift, same keys.
data class KhatmahPlan(
    val goalDays: Int,
    val startDay: LocalDate,
    val startPage: Int,
) {
    companion object {
        const val TOTAL_PAGES = 604

        fun prefs(context: Context): SharedPreferences =
            context.getSharedPreferences("noor", Context.MODE_PRIVATE)

        /// Loads the active plan, if one was started.
        fun load(context: Context): KhatmahPlan? {
            val p = prefs(context)
            val days = p.getInt("khatmah.goalDays", 0)
            if (days <= 0) return null
            return KhatmahPlan(
                goalDays = days,
                startDay = LocalDate.ofEpochDay(p.getLong("khatmah.goalStart", 0)),
                startPage = p.getInt("khatmah.goalStartPage", 0))
        }

        /// A khatmah always covers the whole mushaf: start at page 1.
        fun start(context: Context, days: Int) {
            prefs(context).edit()
                .putInt("khatmah.goalDays", days)
                .putLong("khatmah.goalStart", LocalDate.now().toEpochDay())
                .putInt("khatmah.goalStartPage", 0)
                .putInt("khatmah.page", 1)  // frontier: first unread page
                .apply()
        }

        /// Next unread page of the plan (the frontier).
        fun frontier(context: Context): Int {
            val stored = prefs(context).getInt("khatmah.page", 0)
            return if (stored > 0) min(stored, TOTAL_PAGES) else 1
        }

        /// Last page actually read within the plan.
        fun lastRead(context: Context): Int = max(0, frontier(context) - 1)

        fun clear(context: Context) {
            prefs(context).edit().putInt("khatmah.goalDays", 0).apply()
        }

        /// Completed khatmahs (count persists across plans).
        fun completions(context: Context): Int =
            prefs(context).getInt("khatmah.completions", 0)

        /// Completion timestamps (epoch seconds, oldest first) — kept for
        /// the future history UI, mirroring iOS "khatmah.completionDates".
        /// Stored comma-joined so the order survives (a StringSet wouldn't).
        fun completionDates(context: Context): List<Long> =
            prefs(context).getString("khatmah.completionDates", "")
                .orEmpty()
                .split(",")
                .mapNotNull { it.trim().toLongOrNull() }

        /// Records the completion once, then a new plan can begin.
        fun recordCompletion(context: Context) {
            val p = prefs(context)
            if (p.getInt("khatmah.goalDays", 0) <= 0) return
            val dates = completionDates(context) + System.currentTimeMillis() / 1000
            p.edit()
                .putInt("khatmah.completions", completions(context) + 1)
                .putString("khatmah.completionDates", dates.joinToString(","))
                .apply()
            clear(context)
        }
    }

    /// 1-based day number within the plan (day 1 = start day).
    fun dayNumber(now: LocalDate = LocalDate.now()): Int =
        ChronoUnit.DAYS.between(startDay, now).toInt() + 1

    val pagesPerDay: Double
        get() = (TOTAL_PAGES - startPage).toDouble() / goalDays

    /// Page the reader should reach by the END of the given day to stay
    /// on schedule.
    fun targetPage(now: LocalDate = LocalDate.now()): Int {
        val day = min(dayNumber(now), goalDays)
        return min(TOTAL_PAGES, startPage + ceil(day * pagesPerDay).toInt())
    }

    /// Pages still to read today (0 = on/ahead of schedule for today).
    fun pagesLeftToday(now: LocalDate, currentPage: Int): Int =
        max(0, targetPage(now) - max(currentPage, startPage))

    /// Positive = behind schedule by that many pages (vs yesterday's target).
    fun pagesBehind(now: LocalDate, currentPage: Int): Int {
        val day = dayNumber(now)
        if (day <= 1) return 0
        val expectedYesterday = min(TOTAL_PAGES,
            startPage + ceil(min(day - 1, goalDays) * pagesPerDay).toInt())
        return max(0, expectedYesterday - max(currentPage, startPage))
    }

    fun isFinished(currentPage: Int): Boolean = currentPage >= TOTAL_PAGES
}

/// Direct prefs writes when a Madani page settles — never observed as
/// Compose state, so swiping can't trigger recomposition loops (same
/// approach as the iOS reader's persistPosition).
object ReadingProgress {
    fun pageViewed(context: Context, page: Int) {
        if (page < 1) return
        val p = KhatmahPlan.prefs(context)
        val edit = p.edit()
        if (page > p.getInt("khatmah.maxPage", 0)) edit.putInt("khatmah.maxPage", page)
        edit.putInt("reader.lastPage", page)
        edit.putString("reader.lastMode", "page")
        // Khatmah frontier: only SEQUENTIAL reading advances the plan —
        // viewing the next-unread page marks it read. Jumping around
        // (search, bookmarks, browsing) never inflates progress.
        val frontier = p.getInt("khatmah.page", 0)
        if (frontier > 0 && page == frontier) edit.putInt("khatmah.page", page + 1)
        // Reading streak: any reader session counts the day.
        val today = LocalDate.now().toEpochDay()
        val last = p.getLong("streak.lastDay", 0)
        if (last != today) {
            val count = if (last == today - 1) p.getInt("streak.count", 0) + 1 else 1
            edit.putInt("streak.count", count)
            edit.putLong("streak.lastDay", today)
            if (count > p.getInt("streak.best", 0)) edit.putInt("streak.best", count)
        }
        edit.apply()
    }

    /// Flow-reader position: the last opened surah becomes the resume
    /// target for the Today "continue reading" card.
    fun surahViewed(context: Context, surahId: Int) {
        if (surahId < 1) return
        KhatmahPlan.prefs(context).edit()
            .putInt("reader.lastSurah", surahId)
            .putString("reader.lastMode", "surah")
            .apply()
    }

    /// Current reading streak in days (0 if the chain broke before today).
    fun streakDays(context: Context): Int {
        val p = KhatmahPlan.prefs(context)
        val last = p.getLong("streak.lastDay", 0)
        val today = LocalDate.now().toEpochDay()
        if (last != today && last != today - 1) return 0
        return p.getInt("streak.count", 0)
    }
}
