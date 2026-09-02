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

    /// Delivers one fix (or null) on the main thread, at most once.
    fun fetch(context: Context, onResult: (Location?) -> Unit) {
        val manager = context.getSystemService(LocationManager::class.java)
        if (manager == null || !hasPermission(context)) {
            onResult(null)
            return
        }
        var delivered = false
        val handler = Handler(Looper.getMainLooper())
        fun deliver(location: Location?) {
            if (delivered) return
            delivered = true
            onResult(location ?: lastKnown(manager))
        }
        // Don't hang forever if the provider never answers (e.g. indoors
        // with location services degraded) — fall back to the last fix.
        handler.postDelayed({ deliver(null) }, 20_000)

        val provider = when {
            manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) ->
                LocationManager.NETWORK_PROVIDER
            manager.isProviderEnabled(LocationManager.GPS_PROVIDER) ->
                LocationManager.GPS_PROVIDER
            else -> LocationManager.PASSIVE_PROVIDER
        }
        try {
            if (Build.VERSION.SDK_INT >= 30) {
                manager.getCurrentLocation(provider, null, context.mainExecutor) {
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

    private fun lastKnown(manager: LocationManager): Location? = try {
        listOf(
            LocationManager.NETWORK_PROVIDER,
            LocationManager.GPS_PROVIDER,
            LocationManager.PASSIVE_PROVIDER,
        ).firstNotNullOfOrNull { manager.getLastKnownLocation(it) }
    } catch (_: SecurityException) {
        null
    }
}
