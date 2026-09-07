package com.engagendy.noor

import android.app.Application
import android.content.Context
import android.content.res.Configuration

/// Pins the process to the app's OWN language before anything else runs.
///
/// Two jobs, both for code that lives OUTSIDE the activity — widgets,
/// notification builders, alarm receivers — which can run in a freshly
/// started process where no activity ever existed:
///  1. the base context resolves resources in the chosen language, so
///     `getString` from a receiver matches the app;
///  2. `Locale.getDefault()` matches it too (NoorLocale.load), which is what
///     `isArabicLocale()`, `displayName()` and the date/number formatters
///     read. URLs, filenames and cache keys keep using Locale.ROOT.
class NoorApplication : Application() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(NoorLocale.wrapBase(base))
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        // "system" follows the device even for background surfaces.
        NoorLocale.refreshFromSystem()
    }
}
