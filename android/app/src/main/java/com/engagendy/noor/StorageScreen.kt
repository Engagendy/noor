package com.engagendy.noor

import android.content.Context
import android.text.format.Formatter
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/// What Noor keeps on disk, per category, with one-tap cleanup — the
/// Android port of iOS App/StorageView.swift, measuring the real cache
/// directories used by PageFontStore, Tafsir and HadithLibrary.
@Composable
fun StorageScreen(onBack: () -> Unit, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var items by remember { mutableStateOf<List<StorageItem>?>(null) }
    LaunchedEffect(Unit) {
        items = withContext(Dispatchers.IO) { scanStorage(context) }
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
            Text(stringResource(R.string.g1_storage), fontSize = 22.sp, fontWeight = FontWeight.Bold,
                 color = NoorColor.inkPrimary)
            Text(stringResource(R.string.g1_back), fontSize = 16.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.accentPrimary,
                 modifier = Modifier
                     .clickable(onClick = onBack)
                     .padding(horizontal = 10.dp, vertical = 6.dp))
        }

        Column(
            Modifier
                .fillMaxWidth()
                .background(NoorColor.bgElevated, RoundedCornerShape(14.dp))
        ) {
            val list = items
            if (list == null) {
                Text(stringResource(R.string.g1_calculating), fontSize = 14.sp, color = NoorColor.inkSecondary,
                     modifier = Modifier.padding(16.dp))
            } else {
                list.forEachIndexed { index, item ->
                    if (index > 0) {
                        HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
                    }
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 12.dp)
                    ) {
                        Column(Modifier.weight(1f)) {
                            Text(stringResource(item.title), fontSize = 15.sp, color = NoorColor.inkPrimary)
                            Text(stringResource(item.subtitle), fontSize = 12.sp, color = NoorColor.inkSecondary)
                        }
                        Text(
                            Formatter.formatFileSize(context, item.bytes),
                            fontSize = 13.sp, color = NoorColor.inkSecondary)
                        if (item.bytes > 0) {
                            Text(stringResource(R.string.g1_delete), fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                                 color = Color(0xFFB3402E),
                                 modifier = Modifier
                                     .clickable {
                                         // Heavy IO off-main: delete then rescan.
                                         scope.launch {
                                             // Dropping the recitation cache must not
                                             // leave the player holding a deleted file.
                                             if (item.stopsPlayback) NoorPlayer.stop()
                                             withContext(Dispatchers.IO) { item.delete() }
                                             items = withContext(Dispatchers.IO) { scanStorage(context) }
                                         }
                                     }
                                     .padding(horizontal = 6.dp, vertical = 8.dp))
                        }
                    }
                }
            }
        }
        Text(
            stringResource(R.string.g1_storage_footer),
            fontSize = 12.sp, lineHeight = 18.sp, color = NoorColor.inkSecondary,
            modifier = Modifier.padding(top = 10.dp, start = 4.dp, end = 4.dp))
        Spacer(Modifier.padding(bottom = 24.dp))
    }
}

data class StorageItem(
    val title: Int,       // string resource
    val subtitle: Int,    // string resource
    val bytes: Long,
    val dirs: List<File>,
    /// Sub-directories owned by another row — never measured or deleted here.
    val excluded: List<File> = emptyList(),
    /// Recitations are deleted out from under the player, so stop it first.
    val stopsPlayback: Boolean = false,
) {
    /// Disk IO — call on Dispatchers.IO only.
    fun delete() {
        dirs.forEach { dir ->
            if (excluded.isEmpty()) {
                dir.deleteRecursively()
            } else {
                dir.listFiles()?.forEach { child ->
                    if (excluded.none { it == child }) child.deleteRecursively()
                }
            }
        }
    }
}

/// Disk IO — call on Dispatchers.IO only.
private fun scanStorage(context: Context): List<StorageItem> {
    fun size(dir: File, excluded: List<File>): Long =
        dir.walkBottomUp()
            .filter { file -> file.isFile && excluded.none { file.startsWith(it) } }
            .sumOf { it.length() }
    // Recitations live inside cacheDir but get their own row (mirrors iOS
    // StorageView), so the temporary-files row must skip them.
    val recitations = File(context.cacheDir, "recitations")
    val candidates = listOf(
        StorageItem(R.string.g1_storage_page_fonts, R.string.g1_storage_page_fonts_sub, 0L,
                    listOf(PageFontStore.dir(context))),
        StorageItem(R.string.misc_storage_recitations, R.string.misc_storage_recitations_sub, 0L,
                    listOf(recitations), stopsPlayback = true),
        StorageItem(R.string.g1_storage_tafsir, R.string.g1_storage_tafsir_sub, 0L,
                    listOf(File(context.filesDir, "tafsir"))),
        StorageItem(R.string.g1_storage_hadith, R.string.g1_storage_hadith_sub, 0L,
                    listOf(File(context.filesDir, "hadith"))),
        StorageItem(R.string.g1_storage_temp, R.string.g1_storage_temp_sub, 0L,
                    listOf(context.cacheDir), excluded = listOf(recitations)),
    )
    return candidates.map { item ->
        item.copy(bytes = item.dirs.sumOf {
            if (it.exists()) size(it, item.excluded) else 0L
        })
    }
}
