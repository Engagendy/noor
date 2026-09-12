package com.engagendy.noor

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.ui.text.PlatformTextStyle
import androidx.compose.ui.unit.sp
import androidx.compose.material3.LocalTextStyle
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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
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
/// A screen requested by a notification tap. The serial makes every tap a
/// NEW request, so tapping the same notification twice re-opens the screen.
data class OpenRequest(val route: String, val serial: Int)

class MainActivity : AppCompatActivity() {
    /// The activity is built in the app's OWN language, read from the
    /// `app.language` pref — not from whatever the system decided to do with
    /// the per-app locale. This covers non-Compose surfaces the activity
    /// creates (dialogs, toasts, AppCompat chrome); Compose gets the same
    /// locale from `NoorLocaleProvider` below, which also re-applies it
    /// WITHOUT a recreation when the user switches language.
    override fun attachBaseContext(newBase: Context) {
        super.attachBaseContext(NoorLocale.wrapBase(newBase))
    }

    /// "system" must genuinely follow the device — including a language
    /// changed while the app was backgrounded.
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        NoorLocale.refreshFromSystem()
    }

    /// Set from onCreate/onNewIntent (never from composition); NoorApp
    /// consumes it in a LaunchedEffect.
    private var openRequest by mutableStateOf<OpenRequest?>(null)
    private var openSerial = 0

    private fun consumeOpenIntent(intent: Intent?) {
        val route = intent?.getStringExtra(AdhanScheduler.EXTRA_OPEN) ?: return
        intent.removeExtra(AdhanScheduler.EXTRA_OPEN)
        openRequest = OpenRequest(route, ++openSerial)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        consumeOpenIntent(intent)
    }

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
        // Same for the interface font ("ui.font") — resolved before the first
        // frame so nothing renders in the wrong family.
        NoorFont.apply(KhatmahPlan.prefs(this).getString("ui.font", null))
        // Kids mode: the stored flag decides which shell the app opens in,
        // resolved before the first frame (never read from composition).
        KidsStore.load(this)
        AthkarFavorites.load(this)
        val onboarded = KhatmahPlan.prefs(this).getBoolean("onboarding.done", false)
        if (onboarded) {
            requestNotificationPermission()
            // Roll the exact-alarm window forward on every app open.
            AdhanScheduler.reschedule(this)
        }
        NoorWidgets.refresh(this)
        // Cold start only: on process-death restore the OS re-delivers the same
        // Intent, which would re-open the category the user already left.
        if (savedInstanceState == null) consumeOpenIntent(intent)
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
            // The app language, applied to the whole tree from OUR pref.
            // Everything below resolves strings/drawables through it, so a
            // language tap repaints on the next frame on every OEM.
            NoorLocaleProvider {
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
                    } else if (KidsStore.enabled) {
                        // Kids mode replaces the whole tab bar: no Settings,
                        // no search, no share. The grown-up gate leaves it.
                        KidsShell(onExit = {})
                    } else {
                        NoorApp(openRequest = openRequest)
                    }
                }
            }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // Catches a device-language change made while we were backgrounded
        // on skins that do not recreate the activity for it.
        NoorLocale.refreshFromSystem()
        // The user may have just granted "Alarms & reminders" (or changed
        // notification settings) in the system UI — re-arm as exact alarms.
        if (KhatmahPlan.prefs(this).getBoolean("onboarding.done", false)) {
            AdhanScheduler.reschedule(this)
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
fun NoorApp(openRequest: OpenRequest? = null) {
    val context = androidx.compose.ui.platform.LocalContext.current
    var tab by rememberSaveable { mutableStateOf(Tab.TODAY) }
    // Athkar category requested by a notification tap; the serial changes
    // per tap so the same category re-opens on a second tap.
    var athkarCategory by rememberSaveable { mutableStateOf<String?>(null) }
    var athkarSerial by rememberSaveable { mutableStateOf(0) }
    LaunchedEffect(openRequest) {
        when (openRequest?.route) {
            AdhanScheduler.OPEN_ATHKAR_AFTER_SALAH -> {
                athkarCategory = AdhanScheduler.ATHKAR_AFTER_SALAH_TITLE
                athkarSerial = openRequest.serial
                tab = Tab.ATHKAR
            }
        }
    }
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
    // Immersive reading (iOS: the reader's tab bar follows its chrome): the
    // reader owns the whole page, and the bar comes and goes with the top
    // strip. Gated on the tab too, so the bar can never be stranded
    // off-screen after a tab is tapped from inside the reader.
    // Only a reader whose chrome hides needs the floating bar: the flow /
    // ayah-by-ayah reader's top bar is permanently visible, so its tab bar is
    // permanently visible too and stays INLINE, insetting its scrolling text
    // rather than sitting on top of it.
    val readerImmersive =
        ReaderChrome.readerOpen && ReaderChrome.chromeHides && tab == Tab.QURAN
    val barVisible = !readerImmersive || ReaderChrome.chromeVisible
    // The tab bar drawn as ONE composable, used inline (normal tabs) or as a
    // floating overlay (reader) — same items, same colors, no duplication.
    val tabBar: @Composable () -> Unit = {
        NavigationBar(containerColor = NoorColor.bgElevated) {
            Tab.entries.forEach { item ->
                val title = stringResource(item.titleRes)
                NavigationBarItem(
                    selected = tab == item,
                    onClick = { tab = item },
                    icon = {
                        Icon(painterResource(item.icon), contentDescription = title)
                    },
                    // Cairo (and other tall-metric Arabic faces) report a
                    // large ascent/descent. With the default font padding
                    // the label box grows until it rides up over the icon,
                    // so pin the line box rather than letting the face
                    // decide it.
                    label = {
                        Text(
                            title,
                            maxLines = 1,
                            fontSize = 11.sp,
                            lineHeight = 13.sp,
                            style = LocalTextStyle.current.copy(
                                platformStyle = PlatformTextStyle(
                                    includeFontPadding = false)))
                    },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = NoorColor.accentPrimary,
                        selectedTextColor = NoorColor.accentPrimary,
                        indicatorColor = NoorColor.stateReciting,
                    )
                )
            }
        }
    }
    Box(Modifier.fillMaxSize()) {
    Scaffold(
        containerColor = NoorColor.bgPrimary,
        bottomBar = {
          androidx.compose.foundation.layout.Column(
            // NavigationBar consumes the system gesture-bar inset; while the
            // reader is open it is not in this Column, so the pill (and a
            // page with no pill) would otherwise sit under the system bar.
            modifier = if (readerImmersive)
                Modifier.navigationBarsPadding()
            else Modifier
          ) {
            // Inset, not overlay (iOS `safeAreaInset`): a Madani page has no
            // scroll and must shrink above the pill rather than be covered.
            // The floating tab bar lands right on top of it, so slide the
            // pill clear — as an OFFSET, never padding, so this costs the
            // page below not one pixel of height.
            val pillLift by androidx.compose.animation.core.animateFloatAsState(
                if (readerImmersive && barVisible) 1f else 0f,
                animationSpec = ReaderChrome.fadeSpec,
                label = "pillLift")
            androidx.compose.foundation.layout.Box(
                Modifier.offset { IntOffset(0, -(pillLift * TAB_BAR_CLEARANCE.toPx()).toInt()) }
            ) {
                AudioPillView()
            }
            // In the reader the bar is an overlay (below), NEVER here: the
            // Scaffold's bottomBar insets its content by design, and a bar
            // that takes height re-flows every one of the Madani page's
            // fifteen rows on every tap.
            if (!readerImmersive) tabBar()
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
                openAthkar = { tab = Tab.ATHKAR },
                openPrayer = { tab = Tab.PRAYER })
            Tab.QURAN -> QuranScreen(modifier, mushafPage = mushafPage,
                                     resumeSurahId = quranSurah,
                                     onMushafClosed = { mushafPage = 0 },
                                     onSurahClosed = { quranSurah = 0 })
            Tab.PRAYER -> PrayerScreen(modifier)
            Tab.HADITH -> HadithScreen(modifier)
            Tab.ATHKAR -> AthkarScreen(modifier, openCategoryTitle = athkarCategory,
                                       openSerial = athkarSerial,
                                       onOpenConsumed = { athkarCategory = null; athkarSerial = 0 })
        }
    }
    // The reader's tab bar: it FLOATS over the page, outside the Scaffold, so
    // the reader keeps the full height whether the bar is up or down and the
    // fifteen rows of a Madani page never move. It fades with the reader's
    // top strip on the one shared spring, so a tap reads as a single gesture.
    // Not composed while hidden, so taps at the bottom of the page reach the
    // page (they toggle the chrome) instead of a tab.
    androidx.compose.animation.AnimatedVisibility(
        visible = readerImmersive && ReaderChrome.chromeVisible,
        enter = androidx.compose.animation.fadeIn(ReaderChrome.fadeSpec),
        exit = androidx.compose.animation.fadeOut(ReaderChrome.fadeSpec),
        modifier = Modifier.align(androidx.compose.ui.Alignment.BottomCenter)
    ) {
        // NavigationBar applies the system gesture-bar inset itself, so the
        // floating copy clears it exactly as the inline one does.
        tabBar()
    }
    }
}

/// Height the floating tab bar covers, used to lift the audio pill clear of
/// it (iOS `SurahReaderView.tabBarClearance`).
private val TAB_BAR_CLEARANCE = 62.dp
