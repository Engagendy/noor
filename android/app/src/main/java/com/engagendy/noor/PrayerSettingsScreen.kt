package com.engagendy.noor

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver

/// Prayer settings — city, calculation method, Asr madhab, and manual
/// per-prayer minute adjustments (-30..30), matching the iOS settings sheet.
/// Prefs are written only inside click handlers, never from state observers.
@Composable
fun PrayerSettingsScreen(modifier: Modifier = Modifier, onDone: () -> Unit) {
    val context = LocalContext.current
    val prefs = remember { PrayerPrefs(context) }
    // Bumped after every prefs write (inside click handlers only) so the UI
    // re-reads the stored values; prefs themselves are never observed.
    var version by remember { mutableIntStateOf(0) }
    fun changed() {
        version++
        AdhanScheduler.reschedule(context)
    }
    val method = remember(version) { prefs.method }
    val madhab = remember(version) { prefs.madhab }
    val cityName = remember(version) { prefs.cityName }
    val useCustomLocation = remember(version) { prefs.useCustomLocation }
    val preAlert = remember(version) { prefs.preAlertMinutes }
    // Android 12/12L: "Alarms & reminders" may be off, in which case adhans
    // drift by minutes. Re-check when returning from the system screen.
    val canExactAlarms = remember(version) { AdhanScheduler.canScheduleExact(context) }
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) changed()
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    // Auto location — mirrors the iOS "Use my current location" button:
    // fetch one coarse fix, store the exact coordinate, label it with the
    // nearest preset. Nothing leaves the device.
    var fetchingLocation by remember { mutableStateOf(false) }
    var locationFailed by remember { mutableStateOf(false) }
    fun applyFix(latitude: Double, longitude: Double) {
        val nearest = Cities.nearest(latitude, longitude)
        prefs.saveCustomLocation(latitude, longitude, nearest.name)
        prefs.cityName = nearest.name
        changed()
    }
    fun startLocationFetch() {
        fetchingLocation = true
        locationFailed = false
        LocationFetcher.fetch(context) { fix ->
            fetchingLocation = false
            if (fix != null) applyFix(fix.latitude, fix.longitude)
            else locationFailed = true
        }
    }
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) startLocationFetch() else locationFailed = true
    }
    val adjustments = remember(version) {
        listOf("fajr", "dhuhr", "asr", "maghrib", "isha")
            .associateWith(prefs::adjustment)
    }

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 20.dp)) {
        item {
            Row(
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth().padding(vertical = 16.dp)
            ) {
                Text(stringResource(R.string.g1_prayer_settings), fontSize = 22.sp, fontWeight = FontWeight.Bold,
                     color = NoorColor.inkPrimary)
                Text(stringResource(R.string.g1_done), fontSize = 16.sp, fontWeight = FontWeight.SemiBold,
                     color = NoorColor.accentPrimary,
                     modifier = Modifier
                         .clickable(onClick = onDone)
                         .padding(horizontal = 10.dp, vertical = 6.dp))
            }
        }

        if (!canExactAlarms) {
            item {
                Row(
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 4.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(NoorColor.stateReciting, RoundedCornerShape(12.dp))
                        .clickable {
                            runCatching {
                                context.startActivity(
                                    AdhanScheduler.exactAlarmSettingsIntent(context))
                            }
                        }
                        .padding(horizontal = 16.dp, vertical = 13.dp)
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(stringResource(R.string.prayer_exact_alarm_title),
                             fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                             color = NoorColor.accentPrimary)
                        Text(stringResource(R.string.prayer_exact_alarm_text),
                             fontSize = 12.sp, color = NoorColor.inkSecondary)
                    }
                    Text(stringResource(R.string.prayer_exact_alarm_action),
                         fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                         color = NoorColor.accentPrimary,
                         modifier = Modifier.padding(start = 12.dp))
                }
            }
        }

        item { SectionHeader(stringResource(R.string.g1_section_location)) }
        item {
            // "تحديد موقعي تلقائيًا" — like the iOS settings-sheet button.
            Row(
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(
                        if (useCustomLocation) NoorColor.stateReciting else NoorColor.bgElevated,
                        RoundedCornerShape(12.dp))
                    .clickable(enabled = !fetchingLocation) {
                        if (LocationFetcher.hasPermission(context)) startLocationFetch()
                        else permissionLauncher.launch(Manifest.permission.ACCESS_COARSE_LOCATION)
                    }
                    .padding(horizontal = 16.dp, vertical = 13.dp)
            ) {
                Column {
                    Text(
                        if (useCustomLocation) stringResource(R.string.g1_using_current_location)
                        else stringResource(R.string.g1_use_my_location),
                        fontSize = 15.sp,
                        fontWeight = if (useCustomLocation) FontWeight.SemiBold
                                     else FontWeight.Normal,
                        color = if (useCustomLocation) NoorColor.accentPrimary
                                else NoorColor.inkPrimary)
                    if (useCustomLocation) {
                        Text(stringResource(R.string.g1_near_city,
                                            Cities.named(cityName).displayName()),
                             fontSize = 12.sp, color = NoorColor.inkSecondary)
                    }
                }
                if (fetchingLocation) {
                    CircularProgressIndicator(
                        color = NoorColor.accentPrimary,
                        strokeWidth = 2.dp,
                        modifier = Modifier.size(18.dp))
                } else if (useCustomLocation) {
                    Icon(painterResource(R.drawable.ic_check), contentDescription = null,
                         tint = NoorColor.accentPrimary, modifier = Modifier.size(16.dp))
                }
            }
            if (locationFailed) {
                Text(
                    stringResource(R.string.g1_location_failed),
                    fontSize = 12.sp, color = NoorColor.inkSecondary,
                    modifier = Modifier.padding(top = 6.dp))
            }
        }

        item { SectionHeader(stringResource(R.string.g1_calc_method)) }
        items(CalculationMethodChoice.entries) { choice ->
            val selected = method == choice
            SettingRow(
                title = choice.displayName(),
                selected = selected,
                onClick = {
                    prefs.method = choice
                    changed()
                })
        }

        item { SectionHeader(stringResource(R.string.g1_asr_madhab)) }
        items(MadhabChoice.entries) { choice ->
            val selected = madhab == choice
            SettingRow(
                title = choice.displayName(),
                selected = selected,
                onClick = {
                    prefs.madhab = choice
                    changed()
                })
        }

        item { SectionHeader(stringResource(R.string.g1_prealert_minutes)) }
        item {
            // Wired into AdhanScheduler via changed(): a gentle reminder
            // before each adhan — time for wudu and the walk to the masjid.
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                listOf(0, 5, 10, 15, 30).forEach { minutes ->
                    val selected = preAlert == minutes
                    Text(
                        if (minutes == 0) stringResource(R.string.g1_off)
                        else minutes.localizedDigits(),
                        fontSize = 14.sp,
                        fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                        textAlign = TextAlign.Center,
                        color = if (selected) NoorColor.bgPrimary else NoorColor.inkPrimary,
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(12.dp))
                            .background(
                                if (selected) NoorColor.accentPrimary else NoorColor.bgElevated,
                                RoundedCornerShape(12.dp))
                            .clickable {
                                prefs.preAlertMinutes = minutes
                                changed()
                            }
                            .padding(vertical = 10.dp))
                }
            }
        }

        item { SectionHeader(stringResource(R.string.g1_manual_adjust)) }
        item {
            Column(
                Modifier
                    .fillMaxWidth()
                    .background(NoorColor.bgElevated, RoundedCornerShape(14.dp))
                    .padding(horizontal = 16.dp, vertical = 6.dp)
            ) {
                val prayers = listOf(
                    "fajr" to R.string.g1_fajr, "dhuhr" to R.string.g1_dhuhr,
                    "asr" to R.string.g1_asr, "maghrib" to R.string.g1_maghrib,
                    "isha" to R.string.g1_isha)
                prayers.forEach { (prayerKey, nameRes) ->
                    val value = adjustments[prayerKey] ?: 0
                    AdjustmentRow(
                        title = stringResource(nameRes),
                        value = value,
                        onChange = { minutes ->
                            prefs.setAdjustment(prayerKey, minutes)
                            changed()
                        })
                }
            }
        }

        item { SectionHeader(stringResource(R.string.g1_city)) }
        items(Cities.all) { city ->
            val selected = !useCustomLocation && cityName == city.name
            SettingRow(
                title = city.displayName(),
                subtitle = if (isArabicUi()) city.name else city.nameArabic,
                selected = selected,
                onClick = {
                    // A manual pick turns off the device-location override.
                    prefs.useCustomLocation = false
                    prefs.cityName = city.name
                    changed()
                })
        }
        item { androidx.compose.foundation.layout.Spacer(Modifier.padding(bottom = 24.dp)) }
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
         color = NoorColor.inkSecondary,
         modifier = Modifier.padding(top = 18.dp, bottom = 8.dp))
}

@Composable
private fun SettingRow(
    title: String,
    subtitle: String? = null,
    selected: Boolean,
    onClick: () -> Unit,
) {
    Row(
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 2.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(
                if (selected) NoorColor.stateReciting else NoorColor.bgElevated,
                RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 13.dp)
    ) {
        Column {
            Text(title, fontSize = 15.sp,
                 fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                 color = if (selected) NoorColor.accentPrimary else NoorColor.inkPrimary)
            if (subtitle != null) {
                Text(subtitle, fontSize = 12.sp, color = NoorColor.inkSecondary)
            }
        }
        if (selected) {
            Icon(painterResource(R.drawable.ic_check), contentDescription = null,
                 tint = NoorColor.accentPrimary, modifier = Modifier.size(16.dp))
        }
    }
}

@Composable
private fun AdjustmentRow(title: String, value: Int, onChange: (Int) -> Unit) {
    Row(
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp)
    ) {
        Text(title, fontSize = 15.sp, color = NoorColor.inkPrimary)
        Row(verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            StepperButton("−", enabled = value > -30) { onChange(value - 1) }
            Text(
                if (value > 0) "+$value" else "$value",
                fontSize = 15.sp,
                textAlign = TextAlign.Center,
                color = if (value == 0) NoorColor.inkSecondary else NoorColor.accentPrimary,
                modifier = Modifier.size(width = 44.dp, height = 20.dp))
            StepperButton("+", enabled = value < 30) { onChange(value + 1) }
        }
    }
}

@Composable
private fun StepperButton(label: String, enabled: Boolean, onClick: () -> Unit) {
    Text(
        label,
        fontSize = 18.sp,
        textAlign = TextAlign.Center,
        color = if (enabled) NoorColor.accentPrimary else NoorColor.inkSecondary.copy(alpha = 0.4f),
        modifier = Modifier
            .size(32.dp)
            .clip(CircleShape)
            .background(NoorColor.bgPrimary, CircleShape)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(top = 3.dp))
}
