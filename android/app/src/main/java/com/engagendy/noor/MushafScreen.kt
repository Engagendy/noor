package com.engagendy.noor

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.min

/// Pixel-faithful Madani mushaf: HorizontalPager over all 604 printed
/// pages. The app is RTL app-wide, so swiping follows mushaf order.
@Composable
fun MushafScreen(startPage: Int, onBack: () -> Unit, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val pager = rememberPagerState(
        initialPage = (startPage - 1).coerceIn(0, PageLayoutDb.PAGE_COUNT - 1)
    ) { PageLayoutDb.PAGE_COUNT }

    // Direct prefs writes off the composition (khatmah frontier, streak);
    // nothing observes these as Compose state.
    LaunchedEffect(pager) {
        snapshotFlow { pager.settledPage }.collect { index ->
            withContext(Dispatchers.IO) { ReadingProgress.pageViewed(context, index + 1) }
        }
    }

    Column(modifier.fillMaxSize()) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)
        ) {
            Text(
                "صفحة ${(pager.currentPage + 1).arabicIndic()}",
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = NoorColor.inkSecondary
            )
            Text(
                "رجوع",
                color = NoorColor.accentPrimary,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.clickable(onClick = onBack).padding(8.dp)
            )
        }
        HorizontalPager(state = pager, modifier = Modifier.weight(1f), beyondViewportPageCount = 1) { index ->
            MadaniPage(page = index + 1)
        }
    }
}

private class PageContent(
    val lines: List<PageLine>,
    val fontFamily: FontFamily?,
    val basmala: String?,
)

@Composable
private fun MadaniPage(page: Int) {
    val context = LocalContext.current
    // Layout rows + the ~600 KB page font parse off the main thread.
    val content by produceState<PageContent?>(initialValue = null, page) {
        value = withContext(Dispatchers.IO) {
            PageContent(
                lines = PageLayoutDb.get(context).lines(page),
                fontFamily = PageFontStore.ensure(context, page),
                basmala = QuranDb.get(context).basmala())
        }
        // Prefetch neighbors for smooth swiping.
        launch(Dispatchers.IO) {
            PageFontStore.ensure(context, page + 1)
            PageFontStore.ensure(context, page - 1)
        }
    }

    val loaded = content
    when {
        loaded == null -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(color = NoorColor.accentPrimary)
        }
        loaded.fontFamily == null -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text(
                "خط الصفحة غير متاح.\nاتصل بالإنترنت مرة واحدة لتنزيل هذه الصفحة.",
                fontSize = 15.sp,
                textAlign = TextAlign.Center,
                color = NoorColor.inkSecondary,
                modifier = Modifier.padding(30.dp)
            )
        }
        else -> MadaniPageBody(loaded)
    }
}

@Composable
private fun MadaniPageBody(content: PageContent) {
    BoxWithConstraints(Modifier.fillMaxSize().padding(horizontal = 4.dp)) {
        // Every printed line must fit: 15 fixed rows bound the size by
        // height AND width, so no line is ever clipped or dropped.
        val density = LocalDensity.current
        val rowHeight = maxHeight / maxOf(content.lines.size, 15)
        val fontSize = with(density) {
            min(maxWidth.toPx() / 9.8f, rowHeight.toPx() * 0.72f).toSp()
        }
        val basmalaSize = with(density) { (rowHeight.toPx() * 0.45f).toSp() }
        Column(Modifier.fillMaxSize()) {
            content.lines.forEach { line ->
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier.fillMaxWidth().weight(1f)
                ) {
                    when (line.kind) {
                        is LineKind.SurahHeader ->
                            // A calm gold rule marks the surah boundary.
                            Box(
                                Modifier
                                    .fillMaxWidth()
                                    .height(0.7.dp)
                                    .background(NoorColor.accentGold.copy(alpha = 0.35f))
                            )
                        is LineKind.SurahHeaderWithBasmala, LineKind.Basmala ->
                            Text(
                                content.basmala ?: "",
                                fontFamily = QuranFont,
                                fontSize = basmalaSize,
                                maxLines = 1,
                                color = NoorColor.inkPrimary
                            )
                        LineKind.Words ->
                            // RLI…PDI: hard right-to-left, immune to bidi
                            // mis-segmentation of the QCF ligature codes.
                            Text(
                                "\u2067" + line.glyphsV2 + "\u2069",
                                fontFamily = content.fontFamily,
                                fontSize = fontSize,
                                maxLines = 1,
                                softWrap = false,
                                color = NoorColor.inkPrimary
                            )
                    }
                }
            }
        }
    }
}
