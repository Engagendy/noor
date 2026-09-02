package com.engagendy.noor

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.LayoutDirection

enum class Tab(val titleArabic: String, val icon: Int) {
    TODAY("اليوم", R.drawable.ic_sun),
    QURAN("القرآن", R.drawable.ic_book),
    PRAYER("الصلاة", R.drawable.ic_clock),
    HADITH("الحديث", R.drawable.ic_hadith),
    ATHKAR("الأذكار", R.drawable.ic_sparkle),
}

class MainActivity : ComponentActivity() {
    private val notificationPermission =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            if (granted) AdhanScheduler.reschedule(this)
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        NoorPlayer.init(this)
        val onboarded = KhatmahPlan.prefs(this).getBoolean("onboarding.done", false)
        if (onboarded) {
            requestNotificationPermission()
            // Roll the exact-alarm window forward on every app open.
            AdhanScheduler.reschedule(this)
        }
        NoorWidgets.refresh(this)
        setContent {
            NoorTheme {
                // Arabic-first: the whole app lays out right-to-left.
                CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
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
                    NavigationBarItem(
                        selected = tab == item,
                        onClick = { tab = item },
                        icon = {
                            Icon(painterResource(item.icon), contentDescription = item.titleArabic)
                        },
                        label = { Text(item.titleArabic) },
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
                openPage = { page -> mushafPage = page; tab = Tab.QURAN })
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
