package com.engagendy.noor

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.ui.draw.clip
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
import androidx.compose.material3.Icon
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
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
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
/// cross-fades between full controls (back · surah + juz/page · play · Aa)
/// and the minimal reading line; a tap on the page toggles it.
///
/// `onSwitchMode(mode, surahId, ayah)`: مصحف or آية آية picked in the "Aa"
/// options panel — the caller persists `reader.mode` and reopens the
/// flow/ayah reader at the current page's first surah/ayah.
@Composable
fun MushafScreen(
    startPage: Int,
    onBack: () -> Unit,
    onSwitchMode: (mode: String, surahId: Int, ayah: Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    val pager = rememberPagerState(
        initialPage = (startPage - 1).coerceIn(0, PageLayoutDb.PAGE_COUNT - 1)
    ) { PageLayoutDb.PAGE_COUNT }
    var chromeVisible by remember { mutableStateOf(true) }
    var showOptions by remember { mutableStateOf(false) }
    var showGoToPage by remember { mutableStateOf(false) }
    // Ayah long-pressed on the page — the iOS ayah-actions sheet.
    var actionRef by remember { mutableStateOf<AyahRef?>(null) }

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

    // مصحف / آية آية picked from the panel: resolve the current page's first
    // surah/ayah off-main, then hand off — the caller persists `reader.mode`
    // and swaps this screen for the flow/ayah reader.
    fun pickMode(newMode: String) {
        showOptions = false
        if (newMode == "page") return  // Already here — just close the panel.
        val page = pager.currentPage + 1
        scope.launch {
            val start = withContext(Dispatchers.IO) {
                PageLayoutDb.get(context).firstAyahOnPage(page)
            } ?: return@launch
            onSwitchMode(newMode, start.surahId, start.ayah)
        }
    }

    Column(modifier.fillMaxSize()) {
        MushafTopBar(
            page = currentPage,
            surah = titleSurah,
            chromeVisible = chromeVisible,
            optionsOpen = showOptions,
            onToggleChrome = { chromeVisible = !chromeVisible },
            onToggleOptions = { showOptions = !showOptions },
            onGoToPage = { showGoToPage = true },
            onBack = onBack)
        Box(Modifier.weight(1f)) {
            HorizontalPager(state = pager, modifier = Modifier.fillMaxSize(), beyondViewportPageCount = 1) { index ->
                MadaniPage(
                    page = index + 1,
                    onTap = { chromeVisible = !chromeVisible },
                    onAyahLongPress = { ref -> actionRef = ref })
            }
            if (showOptions) {
                // Scrim: any tap outside the panel dismisses it (flow-reader parity).
                Box(
                    Modifier
                        .fillMaxSize()
                        .pointerInput(Unit) { detectTapGestures { showOptions = false } }
                )
                // Shared panel; mode "page" hides the text-size row — the
                // printed Madani page has fixed QCF geometry.
                ReaderOptionsPanel(
                    mode = "page",
                    fontSize = 26f,
                    onMode = ::pickMode,
                    onFontSize = {},
                    modifier = Modifier.align(Alignment.TopCenter)
                )
            }
        }
    }
    // Long-pressed ayah → the same actions sheet as the flow reader
    // (play from here, tafsir, share, copy, bookmark). Verse text and surah
    // info resolve off-main from the verified DB.
    actionRef?.let { ref -> MushafAyahActions(ref, onDismiss = { actionRef = null }) }
    // Go-to-page (iOS GoToPageSheet): opened from the juz/page line in the
    // top bar; animates the pager like the iOS withAnimation currentPage set.
    if (showGoToPage) {
        GoToPageDialog(
            onGo = { page ->
                scope.launch { pager.animateScrollToPage(page - 1) }
            },
            onDismiss = { showGoToPage = false })
    }
}

/// Ayah actions from a Madani-page long-press — resolves the verse and
/// surah off-main, then shows the shared AyahActionsSheet + TafsirSheet.
@Composable
private fun MushafAyahActions(ref: AyahRef, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    val loaded by produceState<Pair<Verse, Surah>?>(initialValue = null, ref) {
        value = withContext(Dispatchers.IO) {
            val surah = QuranDb.get(context).surahs().firstOrNull { it.id == ref.surahId }
                ?: return@withContext null
            val verse = QuranDb.get(context).verses(ref.surahId)
                .firstOrNull { it.ayah == ref.ayah } ?: return@withContext null
            verse to surah
        }
    }
    val (verse, surah) = loaded ?: return
    val prefs = remember { KhatmahPlan.prefs(context) }
    var bookmarks by remember {
        mutableStateOf(prefs.getStringSet("quran.bookmarks", emptySet())!!.toSet())
    }
    var showTafsir by remember(ref) { mutableStateOf(false) }

    if (showTafsir) {
        TafsirSheet(
            surahId = surah.id,
            ayah = verse.ayah,
            ayahText = verse.text,
            onDismiss = { showTafsir = false; onDismiss() },
            surahName = surah.nameArabic)
        return
    }
    AyahActionsSheet(
        verse = verse,
        isBookmarked = "${surah.id}:${verse.ayah}" in bookmarks,
        onPlay = {
            scope.launch {
                val pageEnd = withContext(Dispatchers.IO) {
                    runCatching {
                        PageLayoutDb.get(context).pageEndAyah(surah.id, verse.ayah)
                    }.getOrDefault(0)
                }
                NoorPlayer.play(surah.id, surah.ayahCount, verse.ayah, surah.nameArabic, pageEnd)
            }
        },
        onTafsir = { showTafsir = true },
        onShare = {
            scope.launch {
                val bitmap = withContext(Dispatchers.IO) {
                    ShareCard.render(
                        context,
                        "${verse.text} ⁧﴿${verse.ayah.arabicIndic()}﴾⁩",
                        context.getString(R.string.g2_surah_prefix, surah.nameArabic) +
                            " · ${surah.id.localizedDigits()}:${verse.ayah.localizedDigits()}",
                        useQuranFont = true)
                }
                ShareCard.share(context, bitmap)
            }
        },
        onCopy = {
            val clipboard = context.getSystemService(android.content.Context.CLIPBOARD_SERVICE)
                as android.content.ClipboardManager
            clipboard.setPrimaryClip(android.content.ClipData.newPlainText(
                context.getString(R.string.g2_ayah_clip_label),
                "${verse.text} ⁧﴿${verse.ayah.arabicIndic()}﴾⁩ — ${surah.id}:${verse.ayah}"))
        },
        onToggleBookmark = {
            val key = "${surah.id}:${verse.ayah}"
            val next = bookmarks.toMutableSet()
            if (!next.remove(key)) next.add(key)
            bookmarks = next
            prefs.edit().putStringSet("quran.bookmarks", next).apply()
        },
        onDismiss = onDismiss)
}

/// Fixed-height strip, iOS SurahReaderView.topBar parity: full controls
/// (circular elevated back, surah name over «الجزء · صفحة», play/pause, Aa)
/// cross-faded with the minimal line (surah · time · juz/page).
@Composable
private fun MushafTopBar(
    page: Int,
    surah: Surah?,
    chromeVisible: Boolean,
    optionsOpen: Boolean,
    onToggleChrome: () -> Unit,
    onToggleOptions: () -> Unit,
    onGoToPage: () -> Unit,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    val juz = PageLayoutDb.juzForPage(page)
    val juzLine = stringResource(
        R.string.g2_juz_page_line, juz.localizedDigits(), page.localizedDigits())
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
                modifier = Modifier.size(38.dp).clip(CircleShape).clickable(enabled = chromeVisible, onClick = onBack)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    // Explicit right-pointing drawable (not auto-mirrored):
                    // in this forced-RTL app, BACK always points RIGHT.
                    Icon(painterResource(R.drawable.ic_chevron_right),
                         contentDescription = stringResource(R.string.g2_back),
                         tint = NoorColor.accentPrimary,
                         modifier = Modifier.size(18.dp))
                }
            }
            Spacer(Modifier.weight(1f))
            // Center title opens go-to-page while the chrome is visible
            // (iOS: the juz/page line under the title is the button).
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.clickable(enabled = chromeVisible, onClick = onGoToPage)
            ) {
                Text(
                    surah?.nameArabic ?: "",
                    fontFamily = HafsFont,
                    fontSize = 17.sp,
                    color = NoorColor.inkPrimary,
                    maxLines = 1)
                Text(juzLine, fontSize = 11.sp, color = NoorColor.inkSecondary)
            }
            Spacer(Modifier.weight(1f))
            // Play/pause reflecting the live player state — tinted vectors
            // (SF play.fill / pause.fill), never emoji glyphs.
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(38.dp)
                    .clip(CircleShape)
                    .clickable(enabled = chromeVisible) { playFromPage() }
            ) {
                Icon(
                    painterResource(
                        if (NoorPlayer.currentSurah != 0 && NoorPlayer.isPlaying)
                            R.drawable.ic_pause_fill else R.drawable.ic_play_fill),
                    contentDescription = stringResource(R.string.g2_play),
                    tint = NoorColor.accentPrimary,
                    modifier = Modifier.size(17.dp))
            }
            // "Aa" toggles the shared reader-options panel (iOS readerMenu):
            // gold tint while open, accent otherwise.
            Text(
                "Aa",
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                color = if (optionsOpen) NoorColor.accentGold else NoorColor.accentPrimary,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .size(38.dp)
                    .clip(CircleShape)
                    .clickable(enabled = chromeVisible, onClick = onToggleOptions)
                    .padding(top = 7.dp))
        }
        // Minimal reading row: surah · time · juz/page.
        if (!chromeVisible) {
            val time = remember(page) {
                SimpleDateFormat("h:mm", Locale.getDefault()).format(Date())
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
private fun MadaniPage(
    page: Int,
    onTap: () -> Unit,
    onAyahLongPress: (AyahRef) -> Unit = {},
) {
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
                stringResource(R.string.g2_page_font_unavailable),
                fontSize = 15.sp,
                textAlign = TextAlign.Center,
                color = NoorColor.inkSecondary,
                modifier = Modifier.padding(30.dp)
            )
        }
        else -> MadaniPageBody(loaded, onTap, onAyahLongPress)
    }
}

@Composable
private fun MadaniPageBody(
    content: PageContent,
    onTap: () -> Unit,
    onAyahLongPress: (AyahRef) -> Unit = {},
) {
    // Ayah being recited (iOS MadaniPageView highlightKey/isHighlighted):
    // reading the player's Compose state here recomposes just this page.
    val reciting =
        if (NoorPlayer.currentSurah != 0) AyahRef(NoorPlayer.currentSurah, NoorPlayer.currentAyah)
        else null
    androidx.compose.foundation.layout.BoxWithConstraints(
        Modifier
            .fillMaxSize()
            .pointerInput(content.lines) {
                detectTapGestures(
                    onTap = { onTap() },
                    onLongPress = { pos ->
                        // The 15 rows are equal-weight: the pressed row is
                        // pure geometry; its first ayah drives the sheet.
                        if (content.lines.isNotEmpty()) {
                            val row = (pos.y / (size.height / content.lines.size))
                                .toInt().coerceIn(0, content.lines.lastIndex)
                            content.lines[row].ayahRefs.firstOrNull()
                                ?.let(onAyahLongPress)
                        }
                    })
            }
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
