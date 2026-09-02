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
            Text("التخزين", fontSize = 22.sp, fontWeight = FontWeight.Bold,
                 color = NoorColor.inkPrimary)
            Text("رجوع", fontSize = 16.sp, fontWeight = FontWeight.SemiBold,
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
                Text("جارٍ الحساب…", fontSize = 14.sp, color = NoorColor.inkSecondary,
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
                            Text(item.title, fontSize = 15.sp, color = NoorColor.inkPrimary)
                            Text(item.subtitle, fontSize = 12.sp, color = NoorColor.inkSecondary)
                        }
                        Text(
                            Formatter.formatFileSize(context, item.bytes),
                            fontSize = 13.sp, color = NoorColor.inkSecondary)
                        if (item.bytes > 0) {
                            Text("حذف", fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                                 color = Color(0xFFB3402E),
                                 modifier = Modifier
                                     .clickable {
                                         // Heavy IO off-main: delete then rescan.
                                         scope.launch(Dispatchers.IO) {
                                             item.dirs.forEach { it.deleteRecursively() }
                                             items = scanStorage(context)
                                         }
                                     }
                                     .padding(horizontal = 6.dp, vertical = 8.dp))
                        }
                    }
                }
            }
        }
        Text(
            "الحذف يزيل النسخ المنزّلة فقط — يعود كل شيء للتنزيل عند استخدامه " +
            "مجددًا. نص القرآن نفسه جزء من التطبيق ولا يمكن حذفه.",
            fontSize = 12.sp, lineHeight = 18.sp, color = NoorColor.inkSecondary,
            modifier = Modifier.padding(top = 10.dp, start = 4.dp, end = 4.dp))
        Spacer(Modifier.padding(bottom = 24.dp))
    }
}

data class StorageItem(
    val title: String,
    val subtitle: String,
    val bytes: Long,
    val dirs: List<File>,
)

/// Disk IO — call on Dispatchers.IO only.
private fun scanStorage(context: Context): List<StorageItem> {
    fun size(dir: File): Long =
        dir.walkBottomUp().filter { it.isFile }.sumOf { it.length() }
    val candidates = listOf(
        Triple("خطوط صفحات المصحف", "خط المصحف المطبوع (مجمع الملك فهد)",
               listOf(PageFontStore.dir(context))),
        Triple("التفسير", "نصوص التفسير المحفوظة للقراءة دون اتصال",
               listOf(File(context.filesDir, "tafsir"))),
        Triple("كتب الحديث", "صحيح البخاري وصحيح مسلم",
               listOf(File(context.filesDir, "hadith"))),
        Triple("الملفات المؤقتة", "بقايا التنزيلات والصور المؤقتة",
               listOf(context.cacheDir)),
    )
    return candidates.map { (title, subtitle, dirs) ->
        StorageItem(title, subtitle, dirs.sumOf { if (it.exists()) size(it) else 0L }, dirs)
    }
}
