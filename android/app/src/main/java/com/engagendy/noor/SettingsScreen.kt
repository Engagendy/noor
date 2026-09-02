package com.engagendy.noor

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/// Settings — the essentials of the iOS SettingsView: language note,
/// reciter, tafsir edition, prayer settings, tools (zakat, storage) and
/// the About attributions. Prefs are written only from click handlers.
@Composable
fun SettingsScreen(modifier: Modifier = Modifier, onDone: () -> Unit) {
    val context = LocalContext.current
    var showReciterPicker by remember { mutableStateOf(false) }
    var showTafsirPicker by remember { mutableStateOf(false) }
    var showZakat by remember { mutableStateOf(false) }
    var showStorage by remember { mutableStateOf(false) }
    var showPrayerSettings by remember { mutableStateOf(false) }
    var version by remember { mutableIntStateOf(0) }

    if (showZakat) {
        ZakatScreen(onBack = { showZakat = false }, modifier = modifier)
        return
    }
    if (showStorage) {
        StorageScreen(onBack = { showStorage = false }, modifier = modifier)
        return
    }
    if (showPrayerSettings) {
        PrayerSettingsScreen(modifier = modifier, onDone = { showPrayerSettings = false })
        return
    }

    val tafsirName = remember(version) {
        Tafsir.named(KhatmahPlan.prefs(context).getString("tafsir.edition", null)).displayName
    }

    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
        Row(
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().padding(vertical = 16.dp)
        ) {
            Text("الإعدادات", fontSize = 22.sp, fontWeight = FontWeight.Bold,
                 color = NoorColor.inkPrimary)
            Text("تم", fontSize = 16.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.accentPrimary,
                 modifier = Modifier
                     .clickable(onClick = onDone)
                     .padding(horizontal = 10.dp, vertical = 6.dp))
        }

        SettingsSection("عام") {
            SettingsRow(title = "اللغة", value = "العربية")
            SettingsRow(title = "المظهر", value = "فاتح (المصحف)")
        }

        SettingsSection("القرآن") {
            SettingsRow(title = "القارئ", value = NoorPlayer.reciter.nameArabic,
                        onClick = { showReciterPicker = true })
            HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
            SettingsRow(title = "التفسير", value = tafsirName,
                        onClick = { showTafsirPicker = true })
        }

        SettingsSection("الصلاة") {
            SettingsRow(title = "إعدادات الصلاة", value = "",
                        onClick = { showPrayerSettings = true })
        }

        SettingsSection("الأدوات") {
            SettingsRow(title = "حاسبة الزكاة", value = "", onClick = { showZakat = true })
            HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
            SettingsRow(title = "التخزين", value = "", onClick = { showStorage = true })
        }

        SettingsSection("حول التطبيق") {
            Column(Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
                listOf(
                    "نص القرآن: Tanzil.net (العثماني)",
                    "الخط: أميري قرآن و KFGQPC حفص",
                    "التفسير: الميسر وابن كثير وغيرهما (spa5k/tafsir_api)",
                    "التلاوات: EveryAyah.com",
                    "مواقيت الصلاة: adhan (Batoul Apps)",
                ).forEach { line ->
                    Text(line, fontSize = 12.sp, color = NoorColor.inkSecondary,
                         modifier = Modifier.padding(vertical = 2.dp))
                }
                Text("مجاني دائمًا — في سبيل الله. بلا إعلانات ولا تتبع.",
                     fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                     color = NoorColor.accentPrimary,
                     modifier = Modifier.padding(top = 8.dp))
            }
        }
        Spacer(Modifier.padding(bottom = 24.dp))
    }

    if (showReciterPicker) {
        ReciterPickerSheet(onDismiss = { showReciterPicker = false; version++ })
    }
    if (showTafsirPicker) {
        TafsirEditionSheet(onDismiss = { showTafsirPicker = false; version++ })
    }
}

@Composable
private fun SettingsSection(title: String, content: @Composable () -> Unit) {
    Text(title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
         color = NoorColor.inkSecondary,
         modifier = Modifier.padding(top = 14.dp, bottom = 6.dp))
    Column(
        Modifier
            .fillMaxWidth()
            .background(NoorColor.bgElevated, RoundedCornerShape(14.dp))
    ) { content() }
}

@Composable
private fun SettingsRow(title: String, value: String, onClick: (() -> Unit)? = null) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .let { if (onClick != null) it.clickable(onClick = onClick) else it }
            .padding(horizontal = 16.dp, vertical = 14.dp)
    ) {
        Text(title, fontSize = 15.sp, color = NoorColor.inkPrimary)
        Spacer(Modifier.weight(1f))
        if (value.isNotEmpty()) {
            Text(value, fontSize = 14.sp, color = NoorColor.inkSecondary)
        }
        if (onClick != null) {
            Text("‹", fontSize = 16.sp,
                 color = NoorColor.inkSecondary.copy(alpha = 0.6f),
                 modifier = Modifier.padding(start = 8.dp))
        }
    }
}

/// Pick the default tafsir edition (same list as the reader's chips).
@androidx.compose.runtime.Composable
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
private fun TafsirEditionSheet(onDismiss: () -> Unit) {
    val context = LocalContext.current
    val prefs = remember { KhatmahPlan.prefs(context) }
    val current = prefs.getString("tafsir.edition", Tafsir.editions[0].slug)
    androidx.compose.material3.ModalBottomSheet(
        onDismissRequest = onDismiss, containerColor = NoorColor.bgPrimary
    ) {
        Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 32.dp)) {
            Text("اختر التفسير", fontSize = 17.sp, fontWeight = FontWeight.Bold,
                 color = NoorColor.inkPrimary,
                 modifier = Modifier.padding(bottom = 10.dp))
            Tafsir.editions.forEach { edition ->
                val selected = edition.slug == current
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 2.dp)
                        .background(
                            if (selected) NoorColor.stateReciting else NoorColor.bgElevated,
                            RoundedCornerShape(12.dp))
                        .clickable {
                            prefs.edit().putString("tafsir.edition", edition.slug).apply()
                            onDismiss()
                        }
                        .padding(horizontal = 16.dp, vertical = 13.dp)
                ) {
                    Text(edition.displayName, fontSize = 15.sp,
                         fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                         color = if (selected) NoorColor.accentPrimary else NoorColor.inkPrimary)
                    Spacer(Modifier.weight(1f))
                    if (selected) {
                        Text("✓", fontSize = 15.sp, fontWeight = FontWeight.Bold,
                             color = NoorColor.accentPrimary)
                    }
                }
            }
        }
    }
}

/// Storage overview: bundled content plus removable downloads — the
/// essentials of the iOS StorageView.
@Composable
fun StorageScreen(onBack: () -> Unit, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    var version by remember { mutableIntStateOf(0) }
    val sizes by produceState<Triple<Long, Map<HadithCollection, Long>, Long>?>(
        initialValue = null, version
    ) {
        value = withContext(Dispatchers.IO) {
            val quran = File(context.filesDir, "quran.sqlite").length()
            val hadith = HadithCollection.entries.associateWith { collection ->
                File(File(context.filesDir, "hadith"), "${collection.key}.db")
                    .takeIf { it.exists() }?.length() ?: 0L
            }
            val tafsir = File(context.filesDir, "tafsir")
                .walkTopDown().filter { it.isFile }.sumOf { it.length() }
            Triple(quran, hadith, tafsir)
        }
    }

    fun megabytes(bytes: Long): String = "%.1f م.ب".format(bytes / 1048576.0)

    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
        Row(
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().padding(vertical = 16.dp)
        ) {
            Text("التخزين", fontSize = 22.sp, fontWeight = FontWeight.Bold,
                 color = NoorColor.inkPrimary)
            Text("رجوع", fontSize = 16.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.accentPrimary,
                 modifier = Modifier
                     .clickable(onClick = onBack)
                     .padding(horizontal = 10.dp, vertical = 6.dp))
        }
        val loaded = sizes
        if (loaded == null) {
            Text("جارٍ الحساب…", fontSize = 14.sp, color = NoorColor.inkSecondary)
        } else {
            Column(
                Modifier
                    .fillMaxWidth()
                    .background(NoorColor.bgElevated, RoundedCornerShape(14.dp))
                    .padding(horizontal = 16.dp, vertical = 6.dp)
            ) {
                StorageRow("مصحف نور (مضمّن)", megabytes(loaded.first))
                HadithCollection.entries.forEach { collection ->
                    val size = loaded.second[collection] ?: 0L
                    if (size > 0) {
                        StorageRow(collection.nameArabic, megabytes(size), onDelete = {
                            HadithLibrary.remove(context, collection)
                            version++
                        })
                    }
                }
                if (loaded.third > 0) {
                    StorageRow("التفسير المحفوظ", megabytes(loaded.third), onDelete = {
                        File(context.filesDir, "tafsir").deleteRecursively()
                        version++
                    })
                }
            }
            Text(
                "المحتوى المحمّل يعمل دون اتصال. الحذف يحرر المساحة ويمكن إعادة التحميل في أي وقت.",
                fontSize = 12.sp, color = NoorColor.inkSecondary,
                modifier = Modifier.padding(top = 10.dp))
        }
    }
}

@Composable
private fun StorageRow(title: String, size: String, onDelete: (() -> Unit)? = null) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(vertical = 10.dp)
    ) {
        Text(title, fontSize = 15.sp, color = NoorColor.inkPrimary)
        Spacer(Modifier.weight(1f))
        Text(size, fontSize = 13.sp, color = NoorColor.inkSecondary)
        if (onDelete != null) {
            Text("حذف", fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                 color = androidx.compose.ui.graphics.Color(0xFFB3402A),
                 modifier = Modifier
                     .clickable(onClick = onDelete)
                     .padding(start = 12.dp, top = 4.dp, bottom = 4.dp))
        }
    }
}
