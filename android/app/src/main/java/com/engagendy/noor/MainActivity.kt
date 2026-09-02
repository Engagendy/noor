package com.engagendy.noor

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.LayoutDirection
import androidx.core.view.WindowCompat

enum class Tab(val titleRes: Int, val icon: Int) {
    TODAY(R.string.g1_tab_today, R.drawable.ic_sun),
    QURAN(R.string.g1_tab_quran, R.drawable.ic_book),
    PRAYER(R.string.g1_tab_prayer, R.drawable.ic_clock),
    HADITH(R.string.g1_tab_hadith, R.drawable.ic_hadith),
    ATHKAR(R.string.g1_tab_athkar, R.drawable.ic_sparkle),
}

/// AppCompatActivity (not ComponentActivity) so the per-app locale picked
/// in Settings (AppCompatDelegate.setApplicationLocales) applies and the
/// activity recreates in the new language. Compose setup is unchanged.
class MainActivity : AppCompatActivity() {
    private val notificationPermission =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            if (granted) AdhanScheduler.reschedule(this)
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        NoorPlayer.init(this)
        // Resolve the stored theme before the first frame so there is no
        // light-mode flash for users who chose dark.
        val systemDark = (resources.configuration.uiMode and
            Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        NoorColor.apply(
            KhatmahPlan.prefs(this).getString("app.theme", "system") ?: "system",
            systemDark)
        val onboarded = KhatmahPlan.prefs(this).getBoolean("onboarding.done", false)
        if (onboarded) {
            requestNotificationPermission()
            // Roll the exact-alarm window forward on every app open.
            AdhanScheduler.reschedule(this)
        }
        NoorWidgets.refresh(this)
        setContent {
            // Re-resolve the palette whenever the system appearance flips
            // (only matters while app.theme == "system"). Prefs are read
            // inside the effect, never observed from composition.
            val isSystemDark = isSystemInDarkTheme()
            LaunchedEffect(isSystemDark) {
                NoorColor.apply(
                    KhatmahPlan.prefs(this@MainActivity)
                        .getString("app.theme", "system") ?: "system",
                    isSystemDark)
            }
            // Status/navigation bar icon contrast follows the active palette.
            val view = LocalView.current
            val dark = NoorColor.isDark
            SideEffect {
                val window = (view.context as Activity).window
                WindowCompat.getInsetsController(window, view).apply {
                    isAppearanceLightStatusBars = !dark
                    isAppearanceLightNavigationBars = !dark
                }
            }
            NoorTheme {
                // Direction follows the CURRENT UI language: ar → RTL, en → LTR.
                CompositionLocalProvider(LocalLayoutDirection provides noorLayoutDirection()) {
                    var showOnboarding by rememberSaveable { mutableStateOf(!onboarded) }
                    if (showOnboarding) {
                        // First run only; the flag write is a user action (finishing).
                        OnboardingScreen(onDone = {
                            KhatmahPlan.prefs(this)
                                .edit().putBoolean("onboarding.done", true).apply()
                            AdhanScheduler.reschedule(this)
                            NoorWidgets.refresh(this)
                            showOnboarding = false
                        })
                    } else {
                        NoorApp()
                    }
                }
            }
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT < 33) return
        val granted = checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        if (!granted) {
            notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }
}

@Composable
fun NoorApp() {
    val context = androidx.compose.ui.platform.LocalContext.current
    var tab by rememberSaveable { mutableStateOf(Tab.TODAY) }
    // Standard bottom-nav convention: system back on a non-Today tab returns
    // to Today; on Today (nothing open) the default behavior exits the app.
    // Screen-level BackHandlers compose later (LIFO) and win while open.
    androidx.activity.compose.BackHandler(enabled = tab != Tab.TODAY) { tab = Tab.TODAY }
    // Madani page requested from Today (khatmah frontier); 0 = none.
    var mushafPage by rememberSaveable { mutableStateOf(0) }
    // Surah requested from Today (continue reading); 0 = none.
    var quranSurah by rememberSaveable { mutableStateOf(0) }

    // Continue reading: reopen the reader exactly where it was left —
    // last Madani page or last surah, whichever was read most recently.
    fun openResume() {
        val prefs = KhatmahPlan.prefs(context)
        when (prefs.getString("reader.lastMode", null)) {
            "surah" -> quranSurah = prefs.getInt("reader.lastSurah", 1).coerceAtLeast(1)
            "page" -> mushafPage = prefs.getInt("reader.lastPage", 1).coerceAtLeast(1)
        }
        tab = Tab.QURAN
    }
    Scaffold(
        containerColor = NoorColor.bgPrimary,
        bottomBar = {
          androidx.compose.foundation.layout.Column {
            AudioPillView()
            NavigationBar(containerColor = NoorColor.bgElevated) {
                Tab.entries.forEach { item ->
                    val title = stringResource(item.titleRes)
                    NavigationBarItem(
                        selected = tab == item,
                        onClick = { tab = item },
                        icon = {
                            Icon(painterResource(item.icon), contentDescription = title)
                        },
                        label = { Text(title) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = NoorColor.accentPrimary,
                            selectedTextColor = NoorColor.accentPrimary,
                            indicatorColor = NoorColor.stateReciting,
                        )
                    )
                }
            }
          }
        }
    ) { padding ->
        val modifier = Modifier.padding(padding)
        when (tab) {
            Tab.TODAY -> TodayScreen(
                modifier,
                openResume = ::openResume,
                openPage = { page -> mushafPage = page; tab = Tab.QURAN },
                openSurah = { id -> quranSurah = id; tab = Tab.QURAN },
                openAthkar = { tab = Tab.ATHKAR })
            Tab.QURAN -> QuranScreen(modifier, mushafPage = mushafPage,
                                     resumeSurahId = quranSurah,
                                     onMushafClosed = { mushafPage = 0 },
                                     onSurahClosed = { quranSurah = 0 })
            Tab.PRAYER -> PrayerScreen(modifier)
            Tab.HADITH -> HadithScreen(modifier)
            Tab.ATHKAR -> AthkarScreen(modifier)
        }
    }
}
