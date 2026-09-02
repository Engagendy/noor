package com.engagendy.noor

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.min
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/// Pixel-faithful Madani mushaf: HorizontalPager over all 604 printed
/// pages, with the iOS reader chrome — a fixed-height top strip that
/// cross-fades between full controls (back · surah + juz/page · play) and
/// the minimal reading line; a tap on the page toggles it.
@Composable
fun MushafScreen(startPage: Int, onBack: () -> Unit, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val pager = rememberPagerState(
        initialPage = (startPage - 1).coerceIn(0, PageLayoutDb.PAGE_COUNT - 1)
    ) { PageLayoutDb.PAGE_COUNT }
    var chromeVisible by remember { mutableStateOf(true) }

    // Follow-along page flip (iOS onChange(of: recitingKey)): while the
    // player recites, the pager tracks the playing ayah's printed page —
    // unless the reader manually swiped away since playback started.
    var followPlayback by remember { mutableStateOf(true) }
    var followTargetPage by remember { mutableStateOf(0) }

    // Direct prefs writes off the composition (khatmah frontier, streak);
    // nothing observes these as Compose state.
    LaunchedEffect(pager) {
        snapshotFlow { pager.settledPage }.collect { index ->
            // A settle on a page other than the recitation target means the
            // user swiped away — stop auto-flipping until playback restarts.
            if (NoorPlayer.currentSurah != 0 && followTargetPage > 0 &&
                index + 1 != followTargetPage
            ) {
                followPlayback = false
            }
            withContext(Dispatchers.IO) { ReadingProgress.pageViewed(context, index + 1) }
        }
    }
    // Recompose-driven (snapshotFlow over the player's Compose state — no
    // polling): resolve the playing ayah's page off-main, then animate.
    LaunchedEffect(pager) {
        snapshotFlow { NoorPlayer.currentSurah to NoorPlayer.currentAyah }
            .collect { (surahId, ayah) ->
                if (surahId == 0 || ayah == 0) {
                    // Playback stopped — the next session follows again.
                    followTargetPage = 0
                    followPlayback = true
                    return@collect
                }
                val page = withContext(Dispatchers.IO) {
                    runCatching { PageLayoutDb.get(context).pageFor(surahId, ayah) }
                        .getOrDefault(0)
                }
                if (page !in 1..PageLayoutDb.PAGE_COUNT) return@collect
                followTargetPage = page
                if (followPlayback && page != pager.currentPage + 1) {
                    pager.animateScrollToPage(page - 1)
                }
            }
    }
    // Auto-hide the chrome shortly after arrival, like the iOS reader.
    LaunchedEffect(Unit) {
        delay(2500)
        chromeVisible = false
    }

    val currentPage = pager.currentPage + 1
    // Top-of-page surah for the title — a tiny indexed lookup, off-main.
    val titleSurah by produceState<Surah?>(initialValue = null, currentPage) {
        value = withContext(Dispatchers.IO) {
            val surahId = PageLayoutDb.get(context).firstSurahOnPage(currentPage)
            QuranDb.get(context).surahs().firstOrNull { it.id == surahId }
        }
    }

    Column(modifier.fillMaxSize()) {
        MushafTopBar(
            page = currentPage,
            surah = titleSurah,
            chromeVisible = chromeVisible,
            onToggleChrome = { chromeVisible = !chromeVisible },
            onBack = onBack)
        HorizontalPager(state = pager, modifier = Modifier.weight(1f), beyondViewportPageCount = 1) { index ->
            MadaniPage(page = index + 1, onTap = { chromeVisible = !chromeVisible })
        }
    }
}

/// Fixed-height strip, iOS SurahReaderView.topBar parity: full controls
/// (circular elevated back, surah name over «الجزء · صفحة», play/pause)
/// cross-faded with the minimal line (surah · time · juz/page).
@Composable
private fun MushafTopBar(
    page: Int,
    surah: Surah?,
    chromeVisible: Boolean,
    onToggleChrome: () -> Unit,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    val juz = PageLayoutDb.juzForPage(page)
    val juzLine = "الجزء ${juz.arabicIndic()} · صفحة ${page.arabicIndic()}"
    val fullAlpha by animateFloatAsState(if (chromeVisible) 1f else 0f, label = "chrome")

    fun playFromPage() {
        if (NoorPlayer.currentSurah != 0) {
            NoorPlayer.toggle()
            return
        }
        scope.launch {
            val start = withContext(Dispatchers.IO) {
                PageLayoutDb.get(context).firstAyahOnPage(page)
            } ?: return@launch
            val info = withContext(Dispatchers.IO) {
                QuranDb.get(context).surahs().firstOrNull { it.id == start.surahId }
            } ?: return@launch
            NoorPlayer.play(info.id, info.ayahCount, start.ayah, info.nameArabic)
        }
    }

    Box(
        Modifier
            .fillMaxWidth()
            .height(50.dp)
            .background(NoorColor.bgPrimary.copy(alpha = 0.92f))
            .clickable(onClick = onToggleChrome)
            .padding(horizontal = 14.dp)
    ) {
        // Full chrome row.
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxSize().alpha(fullAlpha)
        ) {
            // Circular elevated back button. RTL: back points RIGHT,
            // matching the iOS auto-mirrored chevron.backward.
            Surface(
                shape = CircleShape,
                color = NoorColor.bgElevated,
                shadowElevation = 3.dp,
                modifier = Modifier.size(38.dp).clickable(enabled = chromeVisible, onClick = onBack)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Text("›", fontSize = 20.sp, fontWeight = FontWeight.SemiBold,
                         color = NoorColor.accentPrimary)
                }
            }
            Spacer(Modifier.weight(1f))
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    surah?.nameArabic ?: "",
                    fontFamily = HafsFont,
                    fontSize = 17.sp,
                    color = NoorColor.inkPrimary,
                    maxLines = 1)
                Text(juzLine, fontSize = 11.sp, color = NoorColor.inkSecondary)
            }
            Spacer(Modifier.weight(1f))
            // Play/pause reflecting the live player state.
            Text(
                if (NoorPlayer.currentSurah != 0 && NoorPlayer.isPlaying) "⏸" else "▶",
                fontSize = 17.sp,
                color = NoorColor.accentPrimary,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .size(38.dp)
                    .clickable(enabled = chromeVisible) { playFromPage() }
                    .padding(top = 7.dp))
        }
        // Minimal reading row: surah · time · juz/page.
        if (!chromeVisible) {
            val time = remember(page) {
                SimpleDateFormat("h:mm", Locale("ar")).format(Date())
            }
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxSize().alpha(1f - fullAlpha)
            ) {
                Text(surah?.nameArabic ?: "", fontFamily = HafsFont, fontSize = 15.sp,
                     color = NoorColor.inkSecondary, maxLines = 1)
                Spacer(Modifier.weight(1f))
                Text(time, fontSize = 12.sp, color = NoorColor.inkSecondary)
                Spacer(Modifier.weight(1f))
                Text(juzLine, fontSize = 12.sp, color = NoorColor.inkSecondary)
            }
        }
    }
}

private class PageContent(
    val lines: List<PageLine>,
    val fontFamily: FontFamily?,
    val basmala: String?,
)

@Composable
private fun MadaniPage(page: Int, onTap: () -> Unit) {
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
        else -> MadaniPageBody(loaded, onTap)
    }
}

@Composable
private fun MadaniPageBody(content: PageContent, onTap: () -> Unit) {
    // Ayah being recited (iOS MadaniPageView highlightKey/isHighlighted):
    // reading the player's Compose state here recomposes just this page.
    val reciting =
        if (NoorPlayer.currentSurah != 0) AyahRef(NoorPlayer.currentSurah, NoorPlayer.currentAyah)
        else null
    androidx.compose.foundation.layout.BoxWithConstraints(
        Modifier
            .fillMaxSize()
            .pointerInput(Unit) { detectTapGestures { onTap() } }
            .padding(horizontal = 6.dp)
    ) {
        // Every printed line must fit: 15 fixed rows bound the base size by
        // height AND width, then each line is measured and scaled down so
        // nothing ever clips horizontally (the iOS minimumScaleFactor).
        val density = LocalDensity.current
        val measurer = rememberTextMeasurer()
        val maxWidthPx = with(density) { maxWidth.toPx() }
        val rowHeight = maxHeight / maxOf(content.lines.size, 15)
        val baseSizePx = with(density) {
            min(maxWidthPx / 9.8f, rowHeight.toPx() * 0.72f)
        }
        val basmalaSize = with(density) { (rowHeight.toPx() * 0.45f).toSp() }
        Column(Modifier.fillMaxSize()) {
            content.lines.forEach { line ->
                // Soft rounded stateReciting wash behind every line that
                // carries the playing ayah (line-level, like iOS page mode).
                val highlighted = reciting != null && reciting in line.ayahRefs
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f)
                        .then(
                            if (highlighted)
                                Modifier.background(
                                    NoorColor.stateReciting, RoundedCornerShape(6.dp))
                            else Modifier
                        )
                ) {
                    when (line.kind) {
                        is LineKind.SurahHeader ->
                            // A calm gold rule marks the surah boundary
                            // (name lives in the top bar, like iOS).
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
                        LineKind.Words -> {
                            // RLO…PDF: the QCF codes are PUA (bidi class L),
                            // so an isolate alone leaves them left-to-right —
                            // the override forces true mushaf order, glyph
                            // by glyph, exactly as printed. Safe because
                            // each code is a whole-word ligature (no
                            // cross-character shaping to disturb).
                            val text = "\u202E" + line.glyphsV2 + "\u202C"
                            val fitted = remember(text, baseSizePx, maxWidthPx, content.fontFamily) {
                                val style = TextStyle(
                                    fontFamily = content.fontFamily,
                                    fontSize = with(density) { baseSizePx.toSp() })
                                val width = measurer.measure(
                                    AnnotatedString(text), style,
                                    softWrap = false, maxLines = 1
                                ).size.width
                                val scale = if (width > maxWidthPx) maxWidthPx / width else 1f
                                with(density) { (baseSizePx * scale).toSp() }
                            }
                            Text(
                                text,
                                fontFamily = content.fontFamily,
                                fontSize = fitted,
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
}
