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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
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
    // Explicit user actions only — writes happen in click handlers.
    val prayerPrefs = remember { PrayerPrefs(context) }
    var cityName by remember { mutableStateOf(prayerPrefs.cityName) }
    var citySearch by remember { mutableStateOf("") }

    val notificationLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()) { onDone() }

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
                    cityName = cityName,
                    citySearch = citySearch,
                    onSearch = { citySearch = it },
                    onPick = { city ->
                        cityName = city.name
                        prayerPrefs.cityName = city.name
                        AdhanScheduler.reschedule(context)
                        NoorWidgets.refresh(context)
                    },
                    onContinue = { step = 2 })
                else -> NotificationsStep(
                    onEnable = {
                        if (Build.VERSION.SDK_INT >= 33) {
                            notificationLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                        } else {
                            onDone()
                        }
                    },
                    onLater = onDone)
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

/// Step 2 — searchable city list for prayer times (writes PrayerPrefs).
@Composable
private fun CityStep(
    cityName: String,
    citySearch: String,
    onSearch: (String) -> Unit,
    onPick: (CityPreset) -> Unit,
    onContinue: () -> Unit,
) {
    val filtered = remember(citySearch) {
        val query = citySearch.trim()
        if (query.isEmpty()) Cities.all
        else Cities.all.filter {
            it.name.contains(query, ignoreCase = true) || it.nameArabic.contains(query)
        }
    }
    Column(Modifier.fillMaxSize().padding(24.dp)) {
        StepTitle(stringResource(R.string.g1_your_city))
        TextField(
            value = citySearch,
            onValueChange = onSearch,
            placeholder = {
                Text(stringResource(R.string.g1_search_city), color = NoorColor.inkSecondary.copy(alpha = 0.7f))
            },
            singleLine = true,
            shape = RoundedCornerShape(10.dp),
            colors = TextFieldDefaults.colors(
                focusedContainerColor = NoorColor.bgElevated,
                unfocusedContainerColor = NoorColor.bgElevated,
                focusedIndicatorColor = Color.Transparent,
                unfocusedIndicatorColor = Color.Transparent),
            modifier = Modifier.fillMaxWidth().padding(top = 12.dp))
        LazyColumn(Modifier.weight(1f).padding(top = 8.dp)) {
            items(filtered, key = { it.name }) { city ->
                val selected = city.name == cityName
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onPick(city) }
                        .padding(horizontal = 12.dp, vertical = 11.dp)
                ) {
                    Text(
                        city.displayName(),
                        fontSize = 15.sp,
                        fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                        color = NoorColor.inkPrimary)
                    Spacer(Modifier.weight(1f))
                    if (selected) {
                        Icon(painterResource(R.drawable.ic_check), contentDescription = null,
                             tint = NoorColor.accentPrimary, modifier = Modifier.size(16.dp))
                    }
                }
            }
        }
        PrimaryButton(stringResource(R.string.g1_continue), onContinue)
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
