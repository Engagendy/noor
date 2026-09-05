package com.engagendy.noor

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/// First-run welcome — mirrors the iOS App/OnboardingView.swift flow:
/// language note → searchable city pick → adhan notifications. Thirty
/// seconds, skippable, never shown again (prefs flag set by the caller).
@Composable
fun OnboardingScreen(onDone: () -> Unit) {
    val context = LocalContext.current
    var step by androidx.compose.runtime.saveable.rememberSaveable { mutableIntStateOf(0) }
    // System back returns to the previous step; on step 0 the default
    // behavior (exit) applies — there is nothing before the first step.
    androidx.activity.compose.BackHandler(enabled = step > 0) { step-- }
    // Explicit user actions only — writes happen in click handlers.
    val prayerPrefs = remember { PrayerPrefs(context) }
    var cityVersion by remember { mutableIntStateOf(0) }

    // Onboarding always records an EXPLICIT adhan-notification choice, like
    // iOS (OnboardingView sets notificationsEnabled = granted). Without it
    // "Later" would leave the pref at its default and the next reschedule()
    // would sound the adhan five times a day for a user who declined.
    val finish: (Boolean) -> Unit = { enabled ->
        KhatmahPlan.prefs(context).edit()
            .putBoolean("notifications.enabled", enabled).apply()
        onDone()
    }

    val notificationLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()) { granted -> finish(granted) }

    Column(Modifier.fillMaxSize().background(NoorColor.bgPrimary)) {
        // Header — mihrab mark, welcome, promise line.
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.fillMaxWidth().padding(top = 56.dp, start = 28.dp, end = 28.dp)
        ) {
            Icon(
                painterResource(R.drawable.ic_launcher_fg),
                contentDescription = null,
                tint = Color.Unspecified,
                modifier = Modifier.size(72.dp))
            Text(
                stringResource(R.string.g1_welcome),
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
                color = NoorColor.inkPrimary,
                modifier = Modifier.padding(top = 10.dp))
            Text(
                stringResource(R.string.g1_welcome_promise),
                fontSize = 14.sp,
                color = NoorColor.inkSecondary,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 6.dp))
        }

        Box(Modifier.weight(1f)) {
            when (step) {
                0 -> LanguageStep(onContinue = { step = 1 })
                1 -> CityStep(
                    version = cityVersion,
                    onPick = { city ->
                        prayerPrefs.saveCity(city)
                        cityVersion++
                        AdhanScheduler.reschedule(context)
                        NoorWidgets.refresh(context)
                    },
                    onLocated = {
                        cityVersion++
                        AdhanScheduler.reschedule(context)
                        NoorWidgets.refresh(context)
                    },
                    onContinue = { step = 2 })
                else -> NotificationsStep(
                    onEnable = {
                        if (Build.VERSION.SDK_INT >= 33) {
                            notificationLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                        } else {
                            finish(true)
                        }
                    },
                    onLater = { finish(false) })
            }
        }

        // Progress dots.
        Row(
            horizontalArrangement = Arrangement.spacedBy(7.dp),
            modifier = Modifier.align(Alignment.CenterHorizontally).padding(bottom = 22.dp)
        ) {
            repeat(3) { index ->
                Box(
                    Modifier
                        .size(if (index == step) 8.dp else 6.dp)
                        .background(
                            if (index == step) NoorColor.accentPrimary
                            else NoorColor.inkSecondary.copy(alpha = 0.25f),
                            CircleShape))
            }
        }
    }
}

/// Step 1 — language picker; the choice applies IMMEDIATELY (per-app
/// locale recreates the activity in the new language; the saved step
/// keeps onboarding on this screen so the user sees the switch happen).
@Composable
private fun LanguageStep(onContinue: () -> Unit) {
    val context = LocalContext.current
    val current = remember {
        KhatmahPlan.prefs(context).getString("app.language", "system") ?: "system"
    }
    Column(Modifier.fillMaxSize().padding(24.dp)) {
        Spacer(Modifier.weight(1f))
        StepTitle(stringResource(R.string.g1_app_language))
        Column(
            Modifier
                .padding(top = 14.dp)
                .fillMaxWidth()
                .background(NoorColor.bgElevated, RoundedCornerShape(14.dp))
                .padding(8.dp)
        ) {
            listOf(
                "system" to stringResource(R.string.g1_lang_system),
                "ar" to "العربية",
                "en" to "English",
            ).forEach { (id, label) ->
                val selected = current == id
                Text(
                    label,
                    fontSize = 17.sp,
                    fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                    color = if (selected) NoorColor.accentPrimary else NoorColor.inkPrimary,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 2.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .background(
                            if (selected) NoorColor.stateReciting else Color.Transparent,
                            RoundedCornerShape(10.dp))
                        .clickable {
                            KhatmahPlan.prefs(context)
                                .edit().putString("app.language", id).apply()
                            androidx.appcompat.app.AppCompatDelegate.setApplicationLocales(
                                if (id == "system")
                                    androidx.core.os.LocaleListCompat.getEmptyLocaleList()
                                else androidx.core.os.LocaleListCompat.forLanguageTags(id))
                        }
                        .padding(horizontal = 14.dp, vertical = 12.dp))
            }
        }
        Text(
            stringResource(R.string.g1_arabic_first_note),
            fontSize = 13.sp,
            color = NoorColor.inkSecondary,
            modifier = Modifier.padding(top = 10.dp))
        Spacer(Modifier.weight(1f))
        PrimaryButton(stringResource(R.string.g1_continue), onContinue)
    }
}

/// Step 2 — offline city picker for prayer times (writes PrayerPrefs via
/// the callbacks; the picker itself never touches prefs).
@Composable
private fun CityStep(
    version: Int,
    onPick: (City) -> Unit,
    onLocated: () -> Unit,
    onContinue: () -> Unit,
) {
    val context = LocalContext.current
    val prefs = remember { PrayerPrefs(context) }
    val selectedId = remember(version) { prefs.cityId }
    val located = remember(version) { prefs.useCustomLocation }
    val current = remember(version) { prefs.location }
    val scope = rememberCoroutineScope()
    // Auto-locate, like the prayer settings row: one coarse fix, labelled
    // with the nearest city from the offline table, exact coords stored —
    // never leaves the device.
    var fetching by remember { mutableStateOf(false) }
    fun applyFix(latitude: Double, longitude: Double) {
        scope.launch {
            val near = withContext(Dispatchers.IO) {
                runCatching { CityDb.get(context).nearest(latitude, longitude, 1).firstOrNull() }
                    .getOrNull()
            }
            val preset = near?.asPreset() ?: Cities.nearest(latitude, longitude)
            prefs.saveCustomLocation(latitude, longitude, preset.name, preset.nameArabic)
            fetching = false
            onLocated()
            onContinue()
        }
    }
    fun startFetch() {
        fetching = true
        LocationFetcher.fetch(context) { fix ->
            if (fix != null) applyFix(fix.latitude, fix.longitude) else fetching = false
        }
    }
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted -> if (granted) startFetch() else fetching = false }
    Column(Modifier.fillMaxSize().padding(top = 24.dp, bottom = 24.dp)) {
        Column(Modifier.padding(horizontal = 24.dp)) {
            StepTitle(stringResource(R.string.g1_your_city))
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .padding(top = 12.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(NoorColor.stateReciting, RoundedCornerShape(12.dp))
                    .clickable(enabled = !fetching) {
                        if (LocationFetcher.hasPermission(context)) startFetch()
                        else permissionLauncher.launch(
                            android.Manifest.permission.ACCESS_COARSE_LOCATION)
                    }
                    .padding(horizontal = 16.dp, vertical = 13.dp)
            ) {
                Column(Modifier.weight(1f)) {
                    Text(
                        if (located) stringResource(R.string.g1_using_current_location)
                        else stringResource(R.string.g1_use_my_location),
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = NoorColor.accentPrimary)
                    if (located) {
                        Text(stringResource(R.string.g1_near_city, current.displayName()),
                             fontSize = 12.sp, color = NoorColor.inkSecondary)
                    }
                }
                if (fetching) {
                    androidx.compose.material3.CircularProgressIndicator(
                        color = NoorColor.accentPrimary,
                        strokeWidth = 2.dp,
                        modifier = Modifier.size(18.dp))
                } else if (located) {
                    Icon(painterResource(R.drawable.ic_check), contentDescription = null,
                         tint = NoorColor.accentPrimary, modifier = Modifier.size(16.dp))
                }
            }
        }
        // Inline picker (no auto-focus here — the keyboard would cover the
        // Continue button before the reader has seen the step).
        CityPickerContent(
            selectedCityId = if (located) 0 else selectedId,
            onPick = onPick,
            modifier = Modifier.weight(1f).padding(top = 4.dp))
        Column(Modifier.padding(horizontal = 24.dp)) {
            PrimaryButton(stringResource(R.string.g1_continue), onContinue)
        }
    }
}

/// Step 3 — adhan notification permission, or "later".
@Composable
private fun NotificationsStep(onEnable: () -> Unit, onLater: () -> Unit) {
    Column(Modifier.fillMaxSize().padding(24.dp)) {
        Spacer(Modifier.weight(1f))
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
            StepTitle(stringResource(R.string.g1_adhan_notifications))
            Text(
                stringResource(R.string.g1_onboarding_adhan_body),
                fontSize = 14.sp,
                color = NoorColor.inkSecondary,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 10.dp, start = 12.dp, end = 12.dp))
        }
        Spacer(Modifier.weight(1f))
        PrimaryButton(stringResource(R.string.g1_enable_adhan), onEnable)
        Text(
            stringResource(R.string.g1_later),
            fontSize = 15.sp,
            color = NoorColor.inkSecondary,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onLater)
                .padding(vertical = 12.dp))
    }
}

@Composable
private fun StepTitle(title: String) {
    Text(title, fontSize = 18.sp, fontWeight = FontWeight.SemiBold, color = NoorColor.inkPrimary)
}

@Composable
private fun PrimaryButton(title: String, action: () -> Unit) {
    Text(
        title,
        fontSize = 16.sp,
        fontWeight = FontWeight.SemiBold,
        color = NoorColor.bgPrimary,
        textAlign = TextAlign.Center,
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(NoorColor.accentPrimary, RoundedCornerShape(14.dp))
            .clickable(onClick = action)
            .padding(vertical = 15.dp))
}
