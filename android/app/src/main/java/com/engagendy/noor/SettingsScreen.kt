package com.engagendy.noor

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.content.Context
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.Job
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/// The five Tanzil translation editions — 1:1 with the iOS
/// Core/Translations TranslationStore.allEditions ("translation.id").
data class TranslationEdition(val id: String, val displayName: String)

val TanzilEditions = listOf(
    TranslationEdition("en.sahih", "English — Saheeh International"),
    TranslationEdition("ur.jalandhry", "اردو — جالندہری"),
    TranslationEdition("fr.hamidullah", "Français — Hamidullah"),
    TranslationEdition("id.indonesian", "Indonesia — Kemenag"),
    TranslationEdition("tr.diyanet", "Türkçe — Diyanet"),
)

/// App settings — 1:1 port of the iOS App/SettingsView.swift: general
/// (language/appearance), prayer, tools, Quran, and about. Prefs live in
/// the shared "noor" store and are written only inside click handlers.
@Composable
fun SettingsScreen(onBack: () -> Unit, modifier: Modifier = Modifier) {
    var sub by rememberSaveable { mutableStateOf("main") }
    // System back pops sub-screens to main settings; from main, the caller's
    // handler (TodayScreen) closes settings back to Today.
    androidx.activity.compose.BackHandler(enabled = sub != "main") { sub = "main" }
    when (sub) {
        "storage" -> StorageScreen(onBack = { sub = "main" }, modifier = modifier)
        "tajweed" -> TajweedGuideScreen(onBack = { sub = "main" }, modifier = modifier)
        "zakat" -> ZakatScreen(onBack = { sub = "main" }, modifier = modifier)
        else -> SettingsMain(
            onBack = onBack,
            openStorage = { sub = "storage" },
            openTajweed = { sub = "tajweed" },
            openZakat = { sub = "zakat" },
            modifier = modifier)
    }
}

@Composable
private fun SettingsMain(
    onBack: () -> Unit,
    openStorage: () -> Unit,
    openTajweed: () -> Unit,
    openZakat: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val prefs = remember { KhatmahPlan.prefs(context) }
    // Bumped after every prefs write (click handlers only) so rows re-read
    // stored values; prefs themselves are never observed from composition.
    var version by remember { mutableIntStateOf(0) }
    val language = remember(version) { prefs.getString("app.language", "system") ?: "system" }
    val theme = remember(version) { prefs.getString("app.theme", "system") ?: "system" }
    // Captured in composition for use inside the theme click handler.
    val systemDark = androidx.compose.foundation.isSystemInDarkTheme()
    val notificationsEnabled = remember(version) { prefs.getBoolean("notifications.enabled", true) }
    val fastingReminders = remember(version) { prefs.getBoolean("fasting.reminders", false) }
    val sound = remember(version) { PrayerPrefs(context).sound }
    val translationId = remember(version) { prefs.getString("translation.id", "en.sahih") ?: "en.sahih" }

    var showReciterPicker by remember { mutableStateOf(false) }
    var showAdhanSounds by remember { mutableStateOf(false) }
    if (showReciterPicker) {
        ReciterPickerSheet(onDismiss = { showReciterPicker = false })
    }
    if (showAdhanSounds) {
        AdhanSoundSheet(
            selected = sound,
            onSelect = { choice ->
                PrayerPrefs(context).sound = choice
                version++
                showAdhanSounds = false
            },
            onDismiss = { showAdhanSounds = false })
    }

    Column(
        modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp)
    ) {
        Row(
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().padding(vertical = 16.dp)
        ) {
            Text(stringResource(R.string.g1_settings), fontSize = 22.sp, fontWeight = FontWeight.Bold,
                 color = NoorColor.inkPrimary)
            Text(stringResource(R.string.g1_done), fontSize = 16.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.accentPrimary,
                 modifier = Modifier
                     .clickable(onClick = onBack)
                     .padding(horizontal = 10.dp, vertical = 6.dp))
        }

        // General — language & appearance, like the top iOS section.
        SettingsCard {
            ChoiceRow(
                title = stringResource(R.string.g1_language),
                options = listOf(
                    "system" to stringResource(R.string.g1_lang_system),
                    "ar" to "العربية", "en" to "English"),
                selectedId = language,
                onSelect = { choice ->
                    prefs.edit().putString("app.language", choice).apply()
                    version++
                    // Applies immediately: AppCompat recreates the activity in
                    // the chosen per-app locale. "system" clears the override.
                    AppCompatDelegate.setApplicationLocales(
                        if (choice == "system") LocaleListCompat.getEmptyLocaleList()
                        else LocaleListCompat.forLanguageTags(choice))
                })
            HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
            ChoiceRow(
                title = stringResource(R.string.g1_appearance),
                options = listOf(
                    "system" to stringResource(R.string.g1_lang_system),
                    "light" to stringResource(R.string.g1_theme_light),
                    "dark" to stringResource(R.string.g1_theme_dark)),
                selectedId = theme,
                onSelect = {
                    prefs.edit().putString("app.theme", it).apply()
                    // Instant switch — every NoorColor reader recomposes.
                    NoorColor.apply(it, systemDark)
                    version++
                })
        }
        Footer(stringResource(R.string.g1_general_footer))

        SectionTitle(stringResource(R.string.g1_section_prayer))
        SettingsCard {
            ToggleRow(stringResource(R.string.g1_adhan_notifications), notificationsEnabled) { on ->
                prefs.edit().putBoolean("notifications.enabled", on).apply()
                version++
                AdhanScheduler.reschedule(context)
            }
            HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
            ToggleRow(stringResource(R.string.g1_fasting_reminders), fastingReminders) { on ->
                prefs.edit().putBoolean("fasting.reminders", on).apply()
                version++
                AdhanScheduler.reschedule(context)
            }
            HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
            NavRow(title = stringResource(R.string.g1_notification_sound),
                   value = stringResource(sound.nameRes),
                   onClick = { showAdhanSounds = true })
        }
        Footer(stringResource(R.string.g1_prayer_footer))

        SectionTitle(stringResource(R.string.g1_section_tools))
        SettingsCard {
            NavRow(title = stringResource(R.string.g1_storage), onClick = openStorage)
            HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
            NavRow(title = stringResource(R.string.g1_zakat_calculator), onClick = openZakat)
        }

        SectionTitle(stringResource(R.string.g1_section_quran))
        SettingsCard {
            FontSizeRow(prefs = prefs)
            HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
            NavRow(title = stringResource(R.string.g1_reciter), value = NoorPlayer.reciter.localizedName,
                   onClick = { showReciterPicker = true })
            HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
            NavRow(title = stringResource(R.string.g1_tajweed_guide), onClick = openTajweed)
            HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
            MushafDownloadRow()
        }

        SectionTitle(stringResource(R.string.g1_section_translation))
        SettingsCard {
            TanzilEditions.forEachIndexed { index, edition ->
                if (index > 0) {
                    HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
                }
                val selected = edition.id == translationId
                Row(
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable {
                            prefs.edit().putString("translation.id", edition.id).apply()
                            version++
                        }
                        .padding(horizontal = 16.dp, vertical = 13.dp)
                ) {
                    Text(edition.displayName, fontSize = 15.sp,
                         fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                         color = if (selected) NoorColor.accentPrimary else NoorColor.inkPrimary)
                    if (selected) {
                        Icon(painterResource(R.drawable.ic_check), contentDescription = null,
                             tint = NoorColor.accentPrimary, modifier = Modifier.size(16.dp))
                    }
                }
            }
        }

        SectionTitle(stringResource(R.string.g1_section_about))
        SettingsCard {
            Column(Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
                   verticalArrangement = Arrangement.spacedBy(6.dp)) {
                val versionName = remember {
                    try {
                        context.packageManager
                            .getPackageInfo(context.packageName, 0).versionName ?: ""
                    } catch (e: Exception) { "" }
                }
                Text(stringResource(R.string.g1_noor_version, versionName), fontSize = 14.sp,
                     fontWeight = FontWeight.SemiBold, color = NoorColor.inkPrimary)
                // Attribution lines — same sources recorded in LICENSES.md.
                listOf(
                    R.string.g1_attr_quran,
                    R.string.g1_attr_fonts,
                    R.string.g1_attr_page_fonts,
                    R.string.g1_attr_translation,
                    R.string.g1_attr_tafsir,
                    R.string.g1_attr_recitations,
                    R.string.g1_attr_hadith,
                    R.string.g1_attr_prayer,
                    R.string.g1_attr_adhan_sounds,
                ).forEach { line ->
                    Text(stringResource(line), fontSize = 12.5.sp, color = NoorColor.inkSecondary)
                }
            }
        }
        Footer(stringResource(R.string.g1_free_forever))
        Spacer(Modifier.padding(bottom = 24.dp))
    }
}

// MARK: building blocks

@Composable
private fun SectionTitle(title: String) {
    Text(title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
         color = NoorColor.inkSecondary,
         modifier = Modifier.padding(top = 18.dp, bottom = 8.dp))
}

@Composable
private fun Footer(text: String) {
    Text(text, fontSize = 12.sp, color = NoorColor.inkSecondary,
         lineHeight = 18.sp,
         modifier = Modifier.padding(top = 8.dp, start = 4.dp, end = 4.dp))
}

@Composable
private fun SettingsCard(content: @Composable () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(NoorColor.bgElevated, RoundedCornerShape(14.dp))
    ) { content() }
}

@Composable
private fun ToggleRow(title: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp)
    ) {
        Text(title, fontSize = 15.sp, color = NoorColor.inkPrimary)
        Switch(
            checked = checked,
            onCheckedChange = onChange,
            colors = SwitchDefaults.colors(
                checkedTrackColor = NoorColor.accentPrimary,
                checkedThumbColor = NoorColor.bgElevated))
    }
}

@Composable
private fun NavRow(title: String, value: String? = null, onClick: () -> Unit) {
    Row(
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 13.dp)
    ) {
        Text(title, fontSize = 15.sp, color = NoorColor.inkPrimary)
        Row(verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            if (value != null) {
                Text(value, fontSize = 14.sp, color = NoorColor.inkSecondary)
            }
            // Disclosure points forward: LEFT in RTL, RIGHT in LTR.
            Icon(painterResource(NoorIcons.chevronForward()), contentDescription = null,
                 tint = NoorColor.accentPrimary, modifier = Modifier.size(16.dp))
        }
    }
}

/// One-line multiple choice — chips on the trailing side, like a segmented
/// picker (keeps the screen compact where iOS uses menu pickers).
@Composable
private fun ChoiceRow(
    title: String,
    options: List<Pair<String, String>>,
    selectedId: String,
    onSelect: (String) -> Unit,
) {
    Row(
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp)
    ) {
        Text(title, fontSize = 15.sp, color = NoorColor.inkPrimary)
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            options.forEach { (id, label) ->
                val selected = id == selectedId
                Text(
                    label,
                    fontSize = 13.sp,
                    fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                    color = if (selected) NoorColor.accentPrimary else NoorColor.inkSecondary,
                    modifier = Modifier
                        .clip(RoundedCornerShape(10.dp))
                        .background(
                            if (selected) NoorColor.stateReciting else NoorColor.bgPrimary,
                            RoundedCornerShape(10.dp))
                        .clickable { onSelect(id) }
                        .padding(horizontal = 10.dp, vertical = 6.dp))
            }
        }
    }
}

/// Quran text size for the flow reader — "reader.fontSize" (20–44 pt,
/// same range as iOS NoorMetrics.quranSizeRange). Written on release only.
@Composable
private fun FontSizeRow(prefs: android.content.SharedPreferences) {
    var size by remember { mutableFloatStateOf(prefs.getFloat("reader.fontSize", 26f)) }
    Column(Modifier.padding(horizontal = 16.dp, vertical = 10.dp)) {
        Row(
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(stringResource(R.string.g1_quran_font_size), fontSize = 15.sp, color = NoorColor.inkPrimary)
            Text(size.toInt().localizedDigits(), fontSize = 13.sp, color = NoorColor.inkSecondary)
        }
        Slider(
            value = size,
            onValueChange = { size = it },
            // Writing on release keeps drags cheap; the drag itself is a
            // user action, never a composition-time write.
            onValueChangeFinished = {
                prefs.edit().putFloat("reader.fontSize", size).apply()
            },
            valueRange = 20f..44f,
            steps = 23,
            colors = SliderDefaults.colors(
                thumbColor = NoorColor.accentPrimary,
                activeTrackColor = NoorColor.accentPrimary,
                inactiveTrackColor = NoorColor.inkSecondary.copy(alpha = 0.2f),
                activeTickColor = NoorColor.accentPrimary,
                inactiveTickColor = NoorColor.inkSecondary.copy(alpha = 0.2f)))
    }
}

/// Process-scoped owner of the full-mushaf download so it survives the
/// Settings row leaving composition (back/Done, tab switch, activity
/// recreation on language/theme change). The row only observes this state.
object MushafDownloader {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var job: Job? = null

    /// Pages cached on disk; -1 until first counted.
    var cached by mutableIntStateOf(-1)
        private set
    var running by mutableStateOf(false)
        private set

    fun refresh(context: Context) {
        val app = context.applicationContext
        scope.launch { cached = PageFontStore.cachedCount(app) }
    }

    fun start(context: Context) {
        if (running) return
        val app = context.applicationContext
        val total = PageLayoutDb.PAGE_COUNT
        running = true
        job = scope.launch {
            try {
                for (page in 1..total) {
                    if (!isActive) break
                    PageFontStore.ensure(app, page)
                    if (page % 5 == 0 || page == total) {
                        cached = PageFontStore.cachedCount(app)
                    }
                }
            } finally {
                cached = PageFontStore.cachedCount(app)
                running = false
            }
        }
    }

    fun stop() {
        job?.cancel()
        job = null
    }
}

/// Download the full printed mushaf — all 604 QCF v2 page fonts (~350 MB),
/// like the iOS MushafDownloadRow. Cancellable; progress is page count.
/// The job lives in MushafDownloader, not this composable's scope.
@Composable
private fun MushafDownloadRow() {
    val context = LocalContext.current
    val cached = MushafDownloader.cached
    val running = MushafDownloader.running
    LaunchedEffect(Unit) { MushafDownloader.refresh(context) }
    val total = PageLayoutDb.PAGE_COUNT
    val complete = cached >= total
    Row(
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 13.dp)
    ) {
        Column {
            Text(stringResource(R.string.g1_download_full_mushaf), fontSize = 15.sp, color = NoorColor.inkPrimary)
            Text(
                when {
                    cached < 0 -> "…"
                    complete -> stringResource(R.string.g1_all_pages_offline,
                                               total.localizedDigits())
                    else -> stringResource(R.string.g1_mushaf_progress,
                                           cached.localizedDigits(), total.localizedDigits())
                },
                fontSize = 12.sp, color = NoorColor.inkSecondary)
        }
        when {
            complete -> Icon(painterResource(R.drawable.ic_check), contentDescription = null,
                             tint = NoorColor.accentPrimary, modifier = Modifier.size(17.dp))
            running -> Text(stringResource(R.string.g1_stop), fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                            color = NoorColor.accentGold,
                            modifier = Modifier
                                .clickable { MushafDownloader.stop() }
                                .padding(6.dp))
            else -> Text(stringResource(R.string.g1_download), fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                         color = NoorColor.accentPrimary,
                         modifier = Modifier
                             .clickable { MushafDownloader.start(context) }
                             .padding(6.dp))
        }
    }
}

/// Adhan notification sound — same five options as the iOS AdhanSound picker.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AdhanSoundSheet(
    selected: AdhanSound,
    onSelect: (AdhanSound) -> Unit,
    onDismiss: () -> Unit,
) {
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = NoorColor.bgPrimary) {
        Column(Modifier.padding(horizontal = 16.dp)) {
            Text(stringResource(R.string.g1_notification_sound), fontSize = 17.sp, fontWeight = FontWeight.Bold,
                 color = NoorColor.inkPrimary,
                 modifier = Modifier.padding(bottom = 10.dp))
            LazyColumn(Modifier.heightIn(max = 420.dp)) {
                items(AdhanSound.entries) { choice ->
                    val isSelected = choice == selected
                    Row(
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 2.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(
                                if (isSelected) NoorColor.stateReciting else NoorColor.bgElevated,
                                RoundedCornerShape(12.dp))
                            .clickable { onSelect(choice) }
                            .padding(horizontal = 16.dp, vertical = 13.dp)
                    ) {
                        Text(stringResource(choice.nameRes), fontSize = 15.sp,
                             fontWeight = if (isSelected) FontWeight.SemiBold
                                          else FontWeight.Normal,
                             color = if (isSelected) NoorColor.accentPrimary
                                     else NoorColor.inkPrimary)
                        if (isSelected) {
                            Icon(painterResource(R.drawable.ic_check),
                                 contentDescription = null,
                                 tint = NoorColor.accentPrimary,
                                 modifier = Modifier.size(16.dp))
                        }
                    }
                }
                item { Spacer(Modifier.padding(bottom = 20.dp)) }
            }
        }
    }
}
