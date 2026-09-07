package com.engagendy.noor

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.withContext

/// Reader for a memorisation matn: sections as headers, numbered lines, the
/// two hemistichs stacked (phone) or side by side (tablet) — a port of the
/// iOS `MatnReaderView`.
///
/// This is NOT Quran, so it deliberately uses the INTERFACE font
/// (`NoorFont.family`, carried by `arabicText()`) — never `QuranFont` /
/// `HafsFont`, which are reserved for the Quran itself. All matn content is
/// rendered verbatim and never goes through a string lookup.
@Composable
fun MatnReaderScreen(
    matn: Matn,
    openAtLine: Int,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val prefs = remember { KhatmahPlan.prefs(context) }
    var fontSize by remember { mutableFloatStateOf(prefs.getFloat("matn.fontSize", 20f)) }
    // Marked lines (the one being memorised) and the resume place, keyed per
    // matn so a second matn keeps its own.
    val markedKey = "matn.${matn.id}.marked"
    val lastLineKey = "matn.${matn.id}.lastLine"
    var marked by remember {
        mutableStateOf(
            (prefs.getString(markedKey, "") ?: "").split(",").mapNotNull { it.toIntOrNull() }.toSet())
    }
    var searchText by rememberSaveable { mutableStateOf("") }
    androidx.activity.compose.BackHandler(enabled = searchText.isNotEmpty()) { searchText = "" }
    val query = searchText.trim()
    val normalizedQuery = remember(query) { SearchText.normalizeForSearch(query) }
    val index = remember(matn) { MatnSearchIndex(matn) }
    val results by androidx.compose.runtime.produceState(
        emptyList<MatnSearchIndex.Hit>(), query, index
    ) {
        value = if (query.isEmpty()) emptyList() else {
            delay(150)  // debounced like the Quran search
            withContext(Dispatchers.Default) { index.search(query) }
        }
    }

    // The reader's flat content, so every row is one list item and a line is
    // addressable by index.
    val items = remember(matn) {
        buildList {
            add(MatnItem.Title)
            matn.sections.forEach { section ->
                add(MatnItem.SectionHead(section))
                matn.lines(section).forEach { add(MatnItem.Line(it)) }
            }
            add(MatnItem.Colophon)
        }
    }
    val lineIndex = remember(items) {
        items.withIndex().mapNotNull { (i, item) ->
            (item as? MatnItem.Line)?.let { it.line.number to i }
        }.toMap()
    }

    val listState = rememberLazyListState()
    var flashed by remember { mutableIntStateOf(0) }
    var jumpTo by remember { mutableIntStateOf(0) }
    var didRestore by remember { mutableStateOf(false) }

    // Open where the search result pointed, else resume where the reader was
    // last left. The marked line is deliberately NOT the resume target — it
    // is the line being memorised, one tap away on the header pin.
    LaunchedEffect(matn.id, openAtLine) {
        if (didRestore) return@LaunchedEffect
        didRestore = true
        val pinned = openAtLine.takeIf { it > 0 }
        val target = pinned ?: prefs.getInt(lastLineKey, 0).takeIf { it > 1 } ?: return@LaunchedEffect
        lineIndex[target]?.let { listState.scrollToItem(it) }
        if (pinned != null) flashed = pinned
    }
    // Where the reader actually is, written OUTSIDE composition and only for
    // real lines, so the title and the colophon never clear the saved place.
    LaunchedEffect(listState, items) {
        snapshotFlow { listState.firstVisibleItemIndex }.collectLatest { i ->
            delay(400)
            (items.getOrNull(i) as? MatnItem.Line)?.let {
                prefs.edit().putInt(lastLineKey, it.line.number).apply()
            }
        }
    }
    LaunchedEffect(jumpTo) {
        if (jumpTo <= 0) return@LaunchedEffect
        lineIndex[jumpTo]?.let { listState.animateScrollToItem(it) }
        flashed = jumpTo
        jumpTo = 0
    }
    LaunchedEffect(flashed) {
        if (flashed > 0) { delay(1600); flashed = 0 }
    }

    fun toggleMark(number: Int) {
        val next = marked.toMutableSet()
        if (!next.add(number)) next.remove(number)
        marked = next
        prefs.edit().putString(markedKey, next.sorted().joinToString(",")).apply()
    }

    BoxWithConstraints(modifier.fillMaxSize()) {
        // One decision for the whole reader, not per line: a matn reads as a
        // column of consistent couplets.
        val twoColumn = maxWidth > 600.dp
        Column(Modifier.fillMaxSize()) {
            Row(
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth().padding(start = 20.dp, end = 8.dp, top = 12.dp)
            ) {
                Text(matn.navigationTitle(), fontSize = 20.sp, fontWeight = FontWeight.Bold,
                     color = NoorColor.inkPrimary, modifier = Modifier.weight(1f))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    val target = marked.minOrNull()
                    if (target != null) {
                        Icon(
                            painterResource(R.drawable.ic_pin),
                            contentDescription = stringResource(R.string.matn_goto_marked),
                            tint = NoorColor.accentGold,
                            modifier = Modifier
                                .size(48.dp)
                                .clip(RoundedCornerShape(24.dp))
                                .clickable { jumpTo = target }
                                .padding(14.dp))
                    }
                    SizeStep("−", stringResource(R.string.matn_smaller)) {
                        fontSize = (fontSize - 2f).coerceAtLeast(15f)
                        prefs.edit().putFloat("matn.fontSize", fontSize).apply()
                    }
                    SizeStep("+", stringResource(R.string.matn_larger)) {
                        fontSize = (fontSize + 2f).coerceAtMost(34f)
                        prefs.edit().putFloat("matn.fontSize", fontSize).apply()
                    }
                    Text(stringResource(R.string.g1_back), fontSize = 16.sp,
                         fontWeight = FontWeight.SemiBold, color = NoorColor.accentPrimary,
                         modifier = Modifier
                             .clip(RoundedCornerShape(10.dp))
                             .clickable(onClick = onBack)
                             .padding(horizontal = 10.dp, vertical = 12.dp))
                }
            }
            NoorSearchField(
                value = searchText,
                onValueChange = { searchText = it },
                hint = stringResource(R.string.matn_search_hint),
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp))

            if (query.isNotEmpty()) {
                // Matching lines, best matches first (whole word, then word
                // prefix, then mid-word — the shared tiers).
                LazyColumn(Modifier.fillMaxSize()) {
                    if (results.isEmpty()) {
                        item {
                            Text(stringResource(R.string.matn_no_lines),
                                 fontSize = 13.sp, color = NoorColor.inkSecondary,
                                 modifier = Modifier.fillMaxWidth().padding(24.dp),
                                 textAlign = TextAlign.Center)
                        }
                    } else {
                        item {
                            // The matn is bundled whole, so this count is the
                            // whole poem — no coverage caveat (unlike tafsir).
                            Text(stringResource(R.string.matn_count,
                                                results.size.localizedDigits(),
                                                matn.lines.size.localizedDigits()),
                                 fontSize = 12.sp, color = NoorColor.inkSecondary,
                                 modifier = Modifier.padding(horizontal = 20.dp, vertical = 10.dp))
                        }
                        items(results.size, key = { results[it].line.number }) { i ->
                            val hit = results[i]
                            SearchHitRow(
                                text = hit.text,
                                normalizedQuery = normalizedQuery,
                                reference = stringResource(R.string.learn_line_n,
                                                           hit.line.number.localizedDigits()),
                                isArabic = true,
                                onClick = { searchText = ""; jumpTo = hit.line.number })
                        }
                    }
                }
            } else {
                LazyColumn(state = listState, modifier = Modifier.fillMaxSize()) {
                    items(items.size, key = { items[it].key }) { i ->
                        when (val item = items[i]) {
                            is MatnItem.Title -> MatnTitle(matn)
                            is MatnItem.SectionHead -> MatnSectionHeader(item.section)
                            is MatnItem.Line -> MatnLineRow(
                                line = item.line,
                                fontSize = fontSize,
                                twoColumn = twoColumn,
                                isMarked = marked.contains(item.line.number),
                                isFlashed = flashed == item.line.number,
                                onToggleMark = { toggleMark(item.line.number) })
                            is MatnItem.Colophon -> MatnColophon(matn)
                        }
                    }
                    item { Spacer(Modifier.height(32.dp)) }
                }
            }
        }
    }
}

private sealed class MatnItem(val key: String) {
    object Title : MatnItem("title")
    class SectionHead(val section: MatnSection) : MatnItem("sec.${section.id}")
    class Line(val line: MatnLine) : MatnItem("line.${line.number}")
    object Colophon : MatnItem("colophon")
}

@Composable
private fun SizeStep(symbol: String, label: String, onClick: () -> Unit) {
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .size(48.dp)
            .clip(RoundedCornerShape(24.dp))
            .clickable(onClick = onClick, onClickLabel = label)
    ) {
        Text(symbol, fontSize = 20.sp, fontWeight = FontWeight.Bold,
             color = NoorColor.accentPrimary)
    }
}

@Composable
private fun MatnTitle(matn: Matn) {
    ArabicBlock(Modifier.padding(horizontal = 16.dp, vertical = 18.dp)) {
        Text(matn.titleAr, fontSize = 21.sp, fontWeight = FontWeight.Bold,
             color = NoorColor.inkPrimary, style = arabicText(TextAlign.Center),
             modifier = Modifier.fillMaxWidth())
        Text(matn.authorAr, fontSize = 15.sp, color = NoorColor.inkSecondary,
             style = arabicText(TextAlign.Center),
             modifier = Modifier.fillMaxWidth().padding(top = 6.dp))
        matn.composedAr?.let {
            Text(it, fontSize = 12.sp, color = NoorColor.inkSecondary,
                 style = arabicText(TextAlign.Center),
                 modifier = Modifier.fillMaxWidth().padding(top = 4.dp))
        }
    }
}

/// The heading starts on the SAME edge as the line gutter below it: both are
/// Arabic content, so both are laid out right-to-left whatever the interface
/// language (`ArabicDirection` + `arabicText()` — never a manual flip, which
/// double-mirrors in the Arabic UI).
@Composable
private fun MatnSectionHeader(section: MatnSection) {
    ArabicDirection {
        Text(
            section.displayTitle(),
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold,
            color = NoorColor.accentPrimary,
            style = arabicText(),
            modifier = Modifier
                .fillMaxWidth()
                .background(NoorColor.bgElevated)
                .padding(horizontal = 16.dp, vertical = 10.dp))
    }
}

/// The row is Arabic verse plus its own gutter, so it reads as ONE block in
/// the verse's direction whatever the interface language: the number/mark
/// gutter sits at the right, where the line starts.
@Composable
private fun MatnLineRow(
    line: MatnLine,
    fontSize: Float,
    twoColumn: Boolean,
    isMarked: Boolean,
    isFlashed: Boolean,
    onToggleMark: () -> Unit,
) {
    ArabicDirection {
        Row(
            verticalAlignment = Alignment.Top,
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    when {
                        isFlashed -> NoorColor.accentPrimary.copy(alpha = 0.18f)
                        isMarked -> NoorColor.accentGold.copy(alpha = 0.10f)
                        else -> NoorColor.bgPrimary
                    })
                .padding(horizontal = 16.dp, vertical = 8.dp)
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .size(48.dp)
                    .clip(RoundedCornerShape(24.dp))
                    .clickable(
                        onClick = onToggleMark,
                        onClickLabel = stringResource(
                            if (isMarked) R.string.matn_unmark else R.string.matn_mark))
                    .padding(vertical = 6.dp)
            ) {
                Icon(painterResource(R.drawable.ic_pin), contentDescription = null,
                     tint = if (isMarked) NoorColor.accentGold
                            else NoorColor.inkSecondary.copy(alpha = 0.35f),
                     modifier = Modifier.size(14.dp))
                Text(line.number.localizedDigits(), fontSize = 12.sp,
                     color = NoorColor.inkSecondary, modifier = Modifier.padding(top = 2.dp))
            }
            if (twoColumn) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(14.dp),
                    modifier = Modifier.weight(1f).padding(start = 10.dp)
                ) {
                    Hemistich(line.first, fontSize, Modifier.weight(1f))
                    Hemistich(line.second, fontSize, Modifier.weight(1f))
                }
            } else {
                // Both hemistichs are full-width Arabic blocks, so stacked
                // they share one starting edge.
                Column(Modifier.weight(1f).padding(start = 10.dp)) {
                    Hemistich(line.first, fontSize, Modifier.fillMaxWidth())
                    Spacer(Modifier.height(6.dp))
                    Hemistich(line.second, fontSize, Modifier.fillMaxWidth())
                }
            }
        }
    }
    HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.05f))
}

@Composable
private fun Hemistich(text: String, fontSize: Float, modifier: Modifier = Modifier) {
    Text(
        text,
        fontSize = fontSize.sp,
        lineHeight = (fontSize * 1.75f).sp,
        color = NoorColor.inkPrimary,
        style = arabicText(),
        modifier = modifier)
}

@Composable
private fun MatnColophon(matn: Matn) {
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(stringResource(R.string.learn_lines, matn.lines.size.localizedDigits()),
             fontSize = 12.sp, color = NoorColor.inkSecondary)
        Text("${matn.sourceName} · ${matn.sourceLicense}", fontSize = 12.sp,
             color = NoorColor.inkSecondary, modifier = Modifier.padding(top = 4.dp))
        // Honesty about the headings: al-Bayquniyyah's source page has none,
        // so ours are editorial and must not pass for the poet's.
        if (matn.sectionsEditorial) {
            Text(stringResource(R.string.matn_sections_editorial), fontSize = 12.sp,
                 lineHeight = 18.sp, color = NoorColor.inkSecondary,
                 textAlign = TextAlign.Center, modifier = Modifier.padding(top = 4.dp))
        }
    }
}
