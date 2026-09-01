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
        requestNotificationPermission()
        // Roll the exact-alarm window forward on every app open.
        AdhanScheduler.reschedule(this)
        setContent {
            NoorTheme {
                // Arabic-first: the whole app lays out right-to-left.
                CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                    NoorApp()
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
    var tab by rememberSaveable { mutableStateOf(Tab.TODAY) }
    // Madani page requested from Today (khatmah frontier); 0 = none.
    var mushafPage by rememberSaveable { mutableStateOf(0) }
    Scaffold(
        containerColor = NoorColor.bgPrimary,
        bottomBar = {
          androidx.compose.foundation.layout.Column {
            PlayerBar()
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
                openQuran = { tab = Tab.QURAN },
                openPage = { page -> mushafPage = page; tab = Tab.QURAN })
            Tab.QURAN -> QuranScreen(modifier, mushafPage = mushafPage,
                                     onMushafClosed = { mushafPage = 0 })
            Tab.PRAYER -> PrayerScreen(modifier)
            Tab.ATHKAR -> AthkarScreen(modifier)
        }
    }
}
