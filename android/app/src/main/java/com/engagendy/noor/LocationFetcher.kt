package com.engagendy.noor

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.Looper

/// One-shot when-in-use location fetch — port of the iOS
/// `OneShotLocationFetcher`. A coarse fix is plenty (city-level prayer
/// times); the coordinate is stored locally and reused offline. Uses plain
/// `android.location` (no Play Services), no continuous tracking, no
/// geocoding — nothing leaves the device (CLAUDE.md rule 3).
object LocationFetcher {

    fun hasPermission(context: Context): Boolean =
        context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    private fun hasFinePermission(context: Context): Boolean =
        context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    /// A stored fix this recent is good enough for city-level prayer times,
    /// so it is delivered straight away rather than making the reader watch a
    /// spinner while the provider warms up.
    private const val FRESH_ENOUGH_MS = 30 * 60 * 1000L

    /// Waiting longer than this buys almost nothing: by then the provider is
    /// not going to answer, and the stored fix is the better outcome.
    private const val TIMEOUT_MS = 10_000L

    /// Delivers one fix (or null) on the main thread, at most once.
    fun fetch(context: Context, onResult: (Location?) -> Unit) {
        val manager = context.getSystemService(LocationManager::class.java)
        if (manager == null || !hasPermission(context)) {
            onResult(null)
            return
        }
        // Fast path: a recent fix answers instantly. Prayer times only need
        // the city, and the provider would just hand back the same place.
        val cached = lastKnown(manager)
        if (cached != null &&
            System.currentTimeMillis() - cached.time in 0 until FRESH_ENOUGH_MS
        ) {
            onResult(cached)
            return
        }
        var delivered = false
        val handler = Handler(Looper.getMainLooper())
        val cancel = android.os.CancellationSignal()
        fun deliver(location: Location?) {
            if (delivered) return
            delivered = true
            handler.removeCallbacksAndMessages(null)
            // Stop the provider once we have answered; otherwise it keeps
            // working after the screen that asked for it has moved on.
            if (location == null) runCatching { cancel.cancel() }
            onResult(location ?: cached ?: lastKnown(manager))
        }
        // Don't hang if the provider never answers (indoors, or location
        // services degraded) — fall back to the stored fix, however old.
        handler.postDelayed({ deliver(null) }, TIMEOUT_MS)

        // GPS and PASSIVE require FINE; with COARSE only (what we ask for,
        // like iOS kCLLocationAccuracyKilometer) they throw SecurityException.
        // FUSED (API 31+) works with COARSE and is the best default; devices
        // without a network provider (AOSP/microG) would otherwise dead-end.
        val fine = hasFinePermission(context)
        val provider = when {
            Build.VERSION.SDK_INT >= 31 -> LocationManager.FUSED_PROVIDER
            manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) ->
                LocationManager.NETWORK_PROVIDER
            fine && manager.isProviderEnabled(LocationManager.GPS_PROVIDER) ->
                LocationManager.GPS_PROVIDER
            fine -> LocationManager.PASSIVE_PROVIDER
            else -> LocationManager.NETWORK_PROVIDER
        }
        try {
            if (Build.VERSION.SDK_INT >= 30) {
                manager.getCurrentLocation(provider, cancel, context.mainExecutor) {
                    deliver(it)
                }
            } else {
                @Suppress("DEPRECATION")
                manager.requestSingleUpdate(provider, { deliver(it) }, Looper.getMainLooper())
            }
        } catch (_: SecurityException) {
            // GPS provider needs FINE; we only ask for COARSE like iOS
            // (kCLLocationAccuracyKilometer).
            deliver(null)
        } catch (_: IllegalArgumentException) {
            deliver(null)
        }
    }

    private fun lastKnown(manager: LocationManager): Location? =
        buildList {
            if (Build.VERSION.SDK_INT >= 31) add(LocationManager.FUSED_PROVIDER)
            add(LocationManager.NETWORK_PROVIDER)
            add(LocationManager.GPS_PROVIDER)
            add(LocationManager.PASSIVE_PROVIDER)
        }.firstNotNullOfOrNull { provider ->
            // Per-provider guard: a provider we lack permission for (GPS and
            // PASSIVE need FINE) must not skip the remaining ones.
            try {
                manager.getLastKnownLocation(provider)
            } catch (_: SecurityException) {
                null
            } catch (_: IllegalArgumentException) {
                null
            }
        }
}
