package com.engagendy.noor

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.setValue
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkInfo
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/// Owns the full-mushaf download (all 604 QCF v2 page fonts, ~350 MB).
///
/// The work itself is a WorkManager job (`MushafDownloadWorker`), so it
/// keeps going after the app is swiped away or the process is killed, and
/// resumes on the next eligible network. It is enqueued as UNIQUE work with
/// `KEEP`, so every launch may call `syncOnLaunch` and never stacks a
/// second job. Idempotent: pages already on disk are skipped, so
/// re-running (after a kill, a JobScheduler timeout, a backoff retry) costs
/// nothing but the one page that was mid-flight.
///
/// Settings (both persisted in the "noor" prefs, written from click
/// handlers only):
///  - `mushaf.autoDownload` (default ON)  — fetch in the background at all.
///  - `mushaf.wifiOnly`     (default ON)  — UNMETERED vs CONNECTED
///    constraint. 350 MB over cellular without asking would be hostile.
object MushafDownloader {
    const val WORK_NAME = "mushaf-page-fonts"
    const val KEY_AUTO = "mushaf.autoDownload"
    const val KEY_WIFI_ONLY = "mushaf.wifiOnly"
    const val PROGRESS_CACHED = "cached"

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /// Pages cached on disk; -1 until first counted. Updated live by the
    /// worker (same process) and by `refresh`.
    var cached by mutableIntStateOf(-1)
        internal set

    fun autoEnabled(prefs: SharedPreferences) = prefs.getBoolean(KEY_AUTO, true)
    fun wifiOnly(prefs: SharedPreferences) = prefs.getBoolean(KEY_WIFI_ONLY, true)

    fun refresh(context: Context) {
        val app = context.applicationContext
        scope.launch { cached = PageFontStore.cachedCount(app) }
    }

    /// Called once the main shell is up (never during onboarding). With the
    /// automatic download on and pages still missing, makes sure a job is
    /// queued — KEEP, so a job already waiting/running is left alone.
    fun syncOnLaunch(context: Context) {
        val app = context.applicationContext
        scope.launch {
            val count = PageFontStore.cachedCount(app)
            cached = count
            if (count >= PageLayoutDb.PAGE_COUNT) return@launch
            if (!autoEnabled(KhatmahPlan.prefs(app))) return@launch
            enqueue(app, ExistingWorkPolicy.KEEP)
        }
    }

    /// Settings "Download" — same worker, REPLACE so a job sitting in a
    /// backoff window starts now instead of at the end of its wait.
    fun start(context: Context) = enqueue(context.applicationContext, ExistingWorkPolicy.REPLACE)

    /// Settings "Stop". With the automatic download on, the next launch
    /// queues it again; turning the toggle off is the lasting way.
    fun stop(context: Context) {
        WorkManager.getInstance(context.applicationContext).cancelUniqueWork(WORK_NAME)
    }

    /// After either toggle changes: re-target the constraints (REPLACE) or
    /// cancel outright.
    fun onSettingsChanged(context: Context) {
        val app = context.applicationContext
        if (!autoEnabled(KhatmahPlan.prefs(app))) {
            stop(app)
        } else {
            scope.launch {
                if (PageFontStore.cachedCount(app) < PageLayoutDb.PAGE_COUNT) {
                    enqueue(app, ExistingWorkPolicy.REPLACE)
                }
            }
        }
    }

    fun workInfos(context: Context): Flow<List<WorkInfo>> =
        WorkManager.getInstance(context.applicationContext)
            .getWorkInfosForUniqueWorkFlow(WORK_NAME)

    private fun enqueue(app: Context, policy: ExistingWorkPolicy) {
        val network = if (wifiOnly(KhatmahPlan.prefs(app))) NetworkType.UNMETERED
                      else NetworkType.CONNECTED
        val request = OneTimeWorkRequestBuilder<MushafDownloadWorker>()
            .setConstraints(
                Constraints.Builder()
                    .setRequiredNetworkType(network)
                    .setRequiresStorageNotLow(true)
                    .build())
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
            .build()
        WorkManager.getInstance(app).enqueueUniqueWork(WORK_NAME, policy, request)
    }

    /// Download order: the page the reader last had open, then outward on
    /// both sides (p, p+1, p-1, p+2, p-2, …) so the pages most likely to be
    /// opened next arrive first, and the rest follow. Covers all 604.
    fun order(context: Context): List<Int> {
        val total = PageLayoutDb.PAGE_COUNT
        val center = KhatmahPlan.prefs(context).getInt("reader.lastPage", 1).coerceIn(1, total)
        val out = ArrayList<Int>(total)
        out.add(center)
        var step = 1
        while (out.size < total) {
            val ahead = center + step
            val behind = center - step
            if (ahead <= total) out.add(ahead)
            if (behind >= 1) out.add(behind)
            step++
        }
        return out
    }
}

/// One page at a time, at background thread priority, standing aside
/// whenever the reader is fetching (PageFontStore.readerBusy). Returns
/// `retry` (exponential backoff) when the network gives out — three
/// consecutive failures — or when pages are still missing at the end, so
/// the job keeps coming back until the mushaf is complete.
class MushafDownloadWorker(context: Context, params: WorkerParameters) :
    CoroutineWorker(context, params) {

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val app = applicationContext
        val thread = Thread.currentThread()
        val savedPriority = thread.priority
        thread.priority = Thread.MIN_PRIORITY
        try {
            var consecutiveFailures = 0
            var count = PageFontStore.cachedCount(app)
            MushafDownloader.cached = count
            for (page in MushafDownloader.order(app)) {
                ensureActive()
                if (PageFontStore.isCached(app, page)) continue
                // The reader comes first: its ensure() and neighbour prefetch
                // own the connection while they run.
                while (PageFontStore.readerBusy) delay(250)
                ensureActive()
                if (PageFontStore.fetch(app, page)) {
                    consecutiveFailures = 0
                    count++
                    MushafDownloader.cached = count
                    setProgress(workDataOf(MushafDownloader.PROGRESS_CACHED to count))
                } else if (++consecutiveFailures >= 3) {
                    // Network is gone or the host is refusing: back off
                    // rather than burn through the remaining pages.
                    MushafDownloader.cached = PageFontStore.cachedCount(app)
                    return@withContext Result.retry()
                }
            }
            val finalCount = PageFontStore.cachedCount(app)
            MushafDownloader.cached = finalCount
            if (finalCount >= PageLayoutDb.PAGE_COUNT) Result.success() else Result.retry()
        } finally {
            thread.priority = savedPriority
        }
    }
}
