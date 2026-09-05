package com.engagendy.noor

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.border
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun QuranScreen(
    modifier: Modifier = Modifier,
    mushafPage: Int = 0,
    resumeSurahId: Int = 0,
    onMushafClosed: () -> Unit = {},
    onSurahClosed: () -> Unit = {},
) {
    val context = LocalContext.current
    val db = remember { QuranDb.get(context) }
    val surahs = remember { db.surahs() }
    val prefs = remember { KhatmahPlan.prefs(context) }
    // Persisted reading mode — same raw values as iOS ("mushaf"/"page"/"ayah").
    var readerMode by remember {
        mutableStateOf(prefs.getString("reader.mode", "mushaf") ?: "mushaf")
    }
    // Flow reader: opened from the list or from Today (continue reading).
    var openSurah by remember(resumeSurahId) {
        mutableStateOf(surahs.firstOrNull { it.id == resumeSurahId })
    }
    // Exact arrival ayah (search hit, juz start, bookmark); 0 = surah start.
    var openAyah by remember(resumeSurahId) { mutableStateOf(0) }
    // Madani page mode: opened from Today (frontier) or the mushaf button.
    var openMushafAt by remember(mushafPage) { mutableStateOf(mushafPage) }
    // Bookmarks live in prefs as "surah:ayah" strings; prefs are the source
    // of truth (MushafScreen toggles them too), state is a display mirror.
    var bookmarks by remember {
        mutableStateOf(prefs.getStringSet("quran.bookmarks", emptySet())!!.toSet())
    }
    fun toggleBookmark(surahId: Int, ayah: Int) {
        val ref = "$surahId:$ayah"
        val next = prefs.getStringSet("quran.bookmarks", emptySet())!!.toMutableSet()
        if (!next.add(ref)) next.remove(ref)
        bookmarks = next
        prefs.edit().putStringSet("quran.bookmarks", next).apply()
    }
    // Re-sync after the Madani view closes: it may have toggled bookmarks
    // from its own actions sheet while this screen stayed in composition.
    // MushafScreen is reachable two ways (openMushafAt, or openSurah while
    // reader.mode == "page"), so key on both closers.
    LaunchedEffect(openMushafAt, openSurah) {
        if (openMushafAt == 0 && openSurah == null) {
            bookmarks = prefs.getStringSet("quran.bookmarks", emptySet())!!.toSet()
        }
    }

    // From inside the Madani view's options panel: مصحف / آية آية chosen —
    // persist the mode and reopen the flow/ayah reader at the location of
    // the page the user was on (its first surah/ayah).
    fun leaveMushaf(newMode: String, surahId: Int, ayah: Int) {
        prefs.edit().putString("reader.mode", newMode).apply()
        readerMode = newMode
        openMushafAt = 0
        onMushafClosed()
        openAyah = ayah
        openSurah = surahs.firstOrNull { it.id == surahId }
    }

    // System back pops one level, same as each screen's رجوع button.
    // Enabled only while something is open so back never gets trapped here.
    androidx.activity.compose.BackHandler(enabled = openMushafAt > 0 || openSurah != null) {
        if (openMushafAt > 0) {
            openMushafAt = 0; onMushafClosed()
        } else {
            openSurah = null; openAyah = 0; onSurahClosed()
        }
    }

    // Immersive reading: the tab bar steps aside while either reader is open
    // (iOS hides it outright) and comes back when the reader closes.
    val readerOpen = openMushafAt > 0 || openSurah != null
    LaunchedEffect(readerOpen) { ReaderChrome.readerOpen = readerOpen }
    DisposableEffect(Unit) { onDispose { ReaderChrome.readerOpen = false } }

    if (openMushafAt > 0) {
        MushafScreen(
            startPage = openMushafAt,
            onBack = { openMushafAt = 0; onMushafClosed() },
            onSwitchMode = ::leaveMushaf,
            modifier = modifier)
        return
    }

    val current = openSurah
    if (current != null) {
        // The reader OPENS in the persisted mode: Madani mode from the surah
        // list goes straight to the printed page (exact ayah's page when
        // arriving from search/juz/bookmarks).
        if (readerMode == "page") {
            // First DB access copies the asset — keep it off the main thread.
            val firstPage by produceState(0, current.id, openAyah) {
                value = withContext(Dispatchers.IO) {
                    val layout = PageLayoutDb.get(context)
                    if (openAyah > 0) layout.pageFor(current.id, openAyah)
                    else layout.firstPage(current.id)
                }
            }
            if (firstPage > 0) {
                MushafScreen(
                    startPage = firstPage,
                    onBack = { openSurah = null; openAyah = 0; onSurahClosed() },
                    onSwitchMode = ::leaveMushaf,
                    modifier = modifier)
            } else {
                Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = NoorColor.accentPrimary)
                }
            }
        } else {
            ReaderScreen(
                surah = current,
                mode = readerMode,
                scrollToAyah = openAyah,
                bookmarks = bookmarks,
                onToggleBookmark = { ayah -> toggleBookmark(current.id, ayah) },
                onModeChange = { newMode ->
                    // User action from the options panel — persist + switch.
                    prefs.edit().putString("reader.mode", newMode).apply()
                    readerMode = newMode
                },
                onBack = { openSurah = null; openAyah = 0; onSurahClosed() },
                onOpenReference = { surahId, ayah ->
                    openAyah = ayah
                    openSurah = surahs.firstOrNull { it.id == surahId }
                },
                modifier = modifier)
        }
        return
    }

    // ---- Surah index (iOS SurahListView): search + السور/الأجزاء/المحفوظات.
    var searchText by remember { mutableStateOf("") }
    // On the index with active search results, back clears the search first.
    androidx.activity.compose.BackHandler(enabled = searchText.isNotEmpty()) { searchText = "" }
    var indexTab by remember { mutableStateOf("surah") }
    var expandedJuz by remember { mutableStateOf(setOf<Int>()) }
    val juzStarts = remember { db.juzStarts() }
    val quarterStarts = remember { db.quarterStarts() }
    fun surahName(id: Int): String = surahs.firstOrNull { it.id == id }?.nameArabic ?: "$id"
    fun referenceLabel(s: DivisionStart) =
        "${surahName(s.surahId)} · ${s.surahId.localizedDigits()}:${s.ayah.localizedDigits()}"
    fun openReference(surahId: Int, ayah: Int) {
        openAyah = ayah
        openSurah = surahs.firstOrNull { it.id == surahId }
    }

    // Word search runs off-main over the normalized index (LIKE, like iOS).
    val query = searchText.trim()
    val hits by produceState(emptyList<SearchHit>(), query) {
        value = if (query.length >= 2) {
            withContext(Dispatchers.IO) { db.searchVerses(query) }
        } else emptyList()
    }
    // "2:255"-style reference (Arabic-Indic digits welcome): jump by number.
    val westernQuery = query.map { c -> if (c in '٠'..'٩') ('0' + (c - '٠')) else c }
        .joinToString("")
    val referenceSurah = westernQuery.split(":").firstOrNull()?.toIntOrNull()
    val filteredSurahs =
        if (query.isEmpty()) surahs
        else if (referenceSurah != null) surahs.filter { it.id == referenceSurah }
        else surahs.filter {
            it.nameArabic.contains(query) ||
                it.nameTransliterated.contains(query, ignoreCase = true)
        }

    Column(modifier.fillMaxSize()) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp)
        ) {
            Text(
                stringResource(R.string.g2_quran_title),
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = NoorColor.inkPrimary
            )
            Text(
                stringResource(R.string.g2_mushaf),
                color = NoorColor.accentPrimary,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.clickable {
                    openMushafAt = KhatmahPlan.prefs(context)
                        .getInt("reader.lastPage", 0).coerceAtLeast(1)
                }.padding(8.dp)
            )
        }
        // Custom search field, RTL placeholder — like the iOS index header.
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .height(40.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(NoorColor.bgElevated)
                .border(1.dp, NoorColor.inkPrimary.copy(alpha = 0.08f), RoundedCornerShape(12.dp))
                .padding(horizontal = 12.dp)
        ) {
            Box(Modifier.weight(1f)) {
                if (searchText.isEmpty()) {
                    Text(
                        stringResource(R.string.g2_search_quran_hint),
                        fontSize = 15.sp,
                        color = NoorColor.inkSecondary.copy(alpha = 0.8f)
                    )
                }
                BasicTextField(
                    value = searchText,
                    onValueChange = { searchText = it },
                    singleLine = true,
                    textStyle = TextStyle(fontSize = 15.sp, color = NoorColor.inkPrimary),
                    modifier = Modifier.fillMaxWidth()
                )
            }
            if (searchText.isNotEmpty()) {
                Icon(
                    painterResource(R.drawable.ic_close),
                    contentDescription = stringResource(R.string.g2_clear_search),
                    tint = NoorColor.inkSecondary,
                    modifier = Modifier
                        .size(28.dp)
                        .clip(CircleShape)
                        .clickable { searchText = "" }
                        .padding(6.dp)
                )
            }
        }
        // Segmented السور / الأجزاء / المحفوظات (iOS index tabs).
        Row(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 10.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(NoorColor.bgElevated)
                .padding(3.dp)
        ) {
            IndexSegment(stringResource(R.string.g2_tab_surahs), selected = indexTab == "surah",
                         modifier = Modifier.weight(1f)) { indexTab = "surah" }
            IndexSegment(stringResource(R.string.g2_tab_juz), selected = indexTab == "juz",
                         modifier = Modifier.weight(1f)) { indexTab = "juz" }
            IndexSegment(stringResource(R.string.g2_tab_bookmarks), selected = indexTab == "bookmarks",
                         modifier = Modifier.weight(1f)) { indexTab = "bookmarks" }
        }

        when (indexTab) {
            "juz" -> LazyColumn(Modifier.fillMaxSize()) {
                juzStarts.forEach { juz ->
                    item(key = "juz${juz.idx}") {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier
                                    .weight(1f)
                                    .clickable { openReference(juz.surahId, juz.ayah) }
                                    .padding(horizontal = 20.dp, vertical = 10.dp)
                            ) {
                                Box(
                                    contentAlignment = Alignment.Center,
                                    modifier = Modifier
                                        .size(36.dp)
                                        .border(1.dp, NoorColor.accentGold, CircleShape)
                                ) {
                                    Text(juz.idx.localizedDigits(), fontSize = 13.sp,
                                         color = NoorColor.accentGold)
                                }
                                Column(Modifier.padding(horizontal = 14.dp)) {
                                    Text(
                                        stringResource(R.string.g2_juz_n, juz.idx.localizedDigits()),
                                        fontSize = 16.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        color = NoorColor.inkPrimary
                                    )
                                    Text(
                                        referenceLabel(juz),
                                        fontSize = 12.sp,
                                        color = NoorColor.inkSecondary
                                    )
                                }
                            }
                            // Chevron expands the 8 hizb quarters.
                            Text(
                                if (juz.idx in expandedJuz) "⌃" else "⌄",
                                fontSize = 16.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = NoorColor.accentPrimary,
                                modifier = Modifier
                                    .clickable {
                                        expandedJuz =
                                            if (juz.idx in expandedJuz) expandedJuz - juz.idx
                                            else expandedJuz + juz.idx
                                    }
                                    .padding(horizontal = 20.dp, vertical = 14.dp)
                            )
                        }
                        HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
                    }
                    if (juz.idx in expandedJuz) {
                        val range = ((juz.idx - 1) * 8 + 1)..(juz.idx * 8)
                        items(quarterStarts.filter { it.idx in range }, key = { "q${it.idx}" }) { q ->
                            val hizb = (q.idx - 1) / 4 + 1
                            val quarterName = when ((q.idx - 1) % 4 + 1) {
                                2 -> stringResource(R.string.g2_hizb_quarter)
                                3 -> stringResource(R.string.g2_hizb_half)
                                4 -> stringResource(R.string.g2_hizb_three_quarters)
                                else -> stringResource(R.string.g2_hizb_start)
                            }
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable { openReference(q.surahId, q.ayah) }
                                    .padding(horizontal = 24.dp, vertical = 8.dp)
                            ) {
                                Text("۞", fontSize = 15.sp, color = NoorColor.accentGold)
                                Text(
                                    quarterName,
                                    fontSize = 14.sp,
                                    color = NoorColor.inkPrimary,
                                    modifier = Modifier.padding(horizontal = 10.dp)
                                )
                                Text(
                                    stringResource(R.string.g2_hizb_n, hizb.localizedDigits()),
                                    fontSize = 12.sp,
                                    color = NoorColor.inkSecondary,
                                    modifier = Modifier.weight(1f)
                                )
                                Text(
                                    referenceLabel(q),
                                    fontSize = 12.sp,
                                    color = NoorColor.inkSecondary
                                )
                            }
                        }
                    }
                }
            }
            "bookmarks" -> {
                val refs = bookmarks.mapNotNull { ref ->
                    val parts = ref.split(":")
                    val s = parts.getOrNull(0)?.toIntOrNull() ?: return@mapNotNull null
                    val a = parts.getOrNull(1)?.toIntOrNull() ?: return@mapNotNull null
                    s to a
                }.sortedWith(compareBy({ it.first }, { it.second }))
                if (refs.isEmpty()) {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text(
                            stringResource(R.string.g2_bookmarks_empty),
                            fontSize = 15.sp,
                            color = NoorColor.inkSecondary
                        )
                    }
                } else {
                    LazyColumn(Modifier.fillMaxSize()) {
                        items(refs, key = { "${it.first}:${it.second}" }) { (s, a) ->
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable { openReference(s, a) }
                                    .padding(horizontal = 20.dp, vertical = 12.dp)
                            ) {
                                Text("★", fontSize = 15.sp, color = NoorColor.accentGold)
                                Text(
                                    "${surahName(s)} · ${s.localizedDigits()}:${a.localizedDigits()}",
                                    fontSize = 15.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = NoorColor.inkPrimary,
                                    modifier = Modifier.weight(1f).padding(horizontal = 12.dp)
                                )
                                Icon(
                                    painterResource(R.drawable.ic_close),
                                    contentDescription = stringResource(R.string.g2_remove_bookmark),
                                    tint = NoorColor.inkSecondary,
                                    modifier = Modifier
                                        .size(28.dp)
                                        .clip(CircleShape)
                                        .clickable { toggleBookmark(s, a) }
                                        .padding(6.dp)
                                )
                            }
                            HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
                        }
                    }
                }
            }
            else -> LazyColumn(Modifier.fillMaxSize()) {
                items(filteredSurahs, key = { it.id }) { surah ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { openSurah = surah; openAyah = 0 }
                            .padding(horizontal = 20.dp, vertical = 12.dp)
                    ) {
                        Box(
                            contentAlignment = Alignment.Center,
                            modifier = Modifier
                                .size(36.dp)
                                .border(1.dp, NoorColor.accentGold, CircleShape)
                        ) {
                            Text(surah.id.localizedDigits(), fontSize = 13.sp, color = NoorColor.accentGold)
                        }
                        Column(Modifier.padding(horizontal = 14.dp).weight(1f)) {
                            Text(
                                surah.nameArabic,
                                fontFamily = HafsFont,
                                fontSize = 20.sp,
                                color = NoorColor.inkPrimary
                            )
                            Text(
                                stringResource(
                                    R.string.g2_surah_meta,
                                    surah.ayahCount.localizedDigits(),
                                    stringResource(
                                        if (surah.revelation == "Meccan") R.string.g2_makki
                                        else R.string.g2_madani)),
                                fontSize = 12.sp,
                                color = NoorColor.inkSecondary
                            )
                        }
                    }
                    HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
                }
                // Word search: matching ayat below the surah matches.
                if (hits.isNotEmpty()) {
                    item {
                        Text(
                            stringResource(R.string.g2_ayat),
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = NoorColor.inkSecondary,
                            modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp)
                        )
                    }
                    items(hits, key = { "h${it.surahId}:${it.ayah}" }) { hit ->
                        Column(
                            Modifier
                                .fillMaxWidth()
                                .clickable { openReference(hit.surahId, hit.ayah) }
                                .padding(horizontal = 20.dp, vertical = 8.dp)
                        ) {
                            Text(
                                hit.text,
                                fontFamily = QuranFont,
                                fontSize = 17.sp,
                                maxLines = 2,
                                overflow = TextOverflow.Ellipsis,
                                color = NoorColor.inkPrimary
                            )
                            Text(
                                "‏${surahName(hit.surahId)} · ${hit.surahId.localizedDigits()}:${hit.ayah.localizedDigits()}",
                                fontSize = 12.sp,
                                color = NoorColor.inkSecondary,
                                modifier = Modifier.padding(top = 4.dp)
                            )
                        }
                        HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
                    }
                }
            }
        }
    }
}

@Composable
private fun IndexSegment(
    label: String,
    selected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Box(
        contentAlignment = Alignment.Center,
        modifier = modifier
            .clip(RoundedCornerShape(8.dp))
            .background(if (selected) NoorColor.accentPrimary else NoorColor.bgElevated)
            .clickable(onClick = onClick)
            .padding(vertical = 8.dp)
    ) {
        Text(
            label,
            fontSize = 13.sp,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
            color = if (selected) NoorColor.bgPrimary else NoorColor.inkPrimary
        )
    }
}

/// The flow / ayah-by-ayah reader, with the iOS-style "Aa" options panel:
/// segmented reading-mode picker + text-size stepper on an elevated card.
@Composable
fun ReaderScreen(
    surah: Surah,
    mode: String,
    onModeChange: (String) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    scrollToAyah: Int = 0,
    bookmarks: Set<String> = emptySet(),
    onToggleBookmark: (Int) -> Unit = {},
    onOpenReference: ((surahId: Int, ayah: Int) -> Unit)? = null,
) {
    val context = LocalContext.current
    val db = remember { QuranDb.get(context) }
    val verses = remember(surah.id) { db.verses(surah.id) }
    val prefs = remember { KhatmahPlan.prefs(context) }
    val scope = rememberCoroutineScope()
    // Video share state lives here, above the self-dismissing actions sheet.
    val videoShare = rememberAyahVideoShare(scope)
    var showOptions by remember { mutableStateOf(false) }
    var showGoToPage by remember { mutableStateOf(false) }
    // Options panel is a plain overlay: back closes it before the caller's
    // handler pops the reader (sheets/dialogs consume back themselves).
    androidx.activity.compose.BackHandler(enabled = showOptions) { showOptions = false }
    var fontSize by remember { mutableFloatStateOf(prefs.getFloat("reader.fontSize", 26f)) }
    // Structure metadata (juz/quarter starts, sajdah ayat) keyed s*1000+a.
    val sajdaKeys = remember { db.sajdaKeys() }
    val quarterKeys = remember {
        db.quarterStarts().map { it.surahId * 1000 + it.ayah }.toSet()
    }
    val juzAt = remember { db.juzStarts().associateBy({ it.surahId * 1000 + it.ayah }, { it.idx }) }
    val juz = remember(surah.id, scrollToAyah) { db.juzFor(surah.id, scrollToAyah.coerceAtLeast(1)) }
    // Resume position: one direct prefs write per surah open, off-main —
    // never observed as Compose state (same rule as the Madani pager).
    LaunchedEffect(surah.id) {
        withContext(Dispatchers.IO) {
            ReadingProgress.surahViewed(context, surah.id)
        }
    }
    val hasBasmala = surah.id != 9 && surah.id != 1
    // Basmala header text comes from the verified DB (1:1), never typed —
    // same source the Madani page uses.
    val basmala = remember { db.basmala() }
    // Ayah being recited in THIS surah (iOS recitingKey) — Compose state
    // from the player, so the highlight tracks playback automatically.
    val recitingAyah =
        if (NoorPlayer.currentSurah == surah.id) NoorPlayer.currentAyah else 0
    // Recitation wins over the arrival highlight (iOS: recitingKey ?? selectedKey).
    val highlightAyah = if (recitingAyah > 0) recitingAyah else scrollToAyah
    // Continuous mushaf-style flow: one attributed stream with gold ayah
    // markers, ۞ at hizb-quarter starts, ۩ on sajdah ayat and a small juz
    // header line where a new juz begins — all indexing marks, never text
    // edits. Each verse span is annotated so a tap resolves its ayah.
    val flow = remember(surah.id, fontSize, highlightAyah) {
        buildAnnotatedString {
            verses.forEach { verse ->
                val key = surah.id * 1000 + verse.ayah
                juzAt[key]?.let { idx ->
                    if (length > 0) append("\n")
                    withStyle(SpanStyle(
                        color = NoorColor.accentGold,
                        fontSize = (fontSize * 0.5f).sp,
                        fontWeight = FontWeight.SemiBold)) {
                        append("— " + context.getString(R.string.g2_juz_n, idx.localizedDigits()) + " —")
                    }
                    append("\n")
                }
                pushStringAnnotation(tag = "ayah", annotation = verse.ayah.toString())
                if (key in quarterKeys) {
                    withStyle(SpanStyle(color = NoorColor.accentGold)) { append("۞ ") }
                }
                if (highlightAyah == verse.ayah) {
                    withStyle(SpanStyle(background = NoorColor.stateReciting)) {
                        append(verse.text)
                    }
                } else {
                    append(verse.text)
                }
                if (key in sajdaKeys) {
                    withStyle(SpanStyle(color = NoorColor.accentGold)) { append(" ۩") }
                }
                withStyle(SpanStyle(
                    color = NoorColor.accentGold,
                    fontSize = (fontSize * 0.62f).sp)) {
                    append(" ⁧﴿${verse.ayah.arabicIndic()}﴾⁩ ")
                }
                pop()
            }
        }
    }
    // Ayah picked for the actions sheet / tafsir (0 = none).
    var actionAyah by remember(surah.id) { mutableStateOf(0) }
    var tafsirAyah by remember(surah.id) { mutableStateOf(0) }
    var textLayout by remember { mutableStateOf<TextLayoutResult?>(null) }
    val listState = rememberLazyListState()

    fun ayahAt(position: Offset) {
        val layout = textLayout ?: return
        val offset = layout.getOffsetForPosition(position)
        flow.getStringAnnotations("ayah", offset, offset).firstOrNull()?.let {
            actionAyah = it.item.toIntOrNull() ?: 0
        }
    }

    fun startPlayback(fromAyah: Int = 1) {
        scope.launch {
            // "This page only" boundary comes from the layout DB — off-main.
            val pageEnd = withContext(Dispatchers.IO) {
                runCatching {
                    PageLayoutDb.get(context).pageEndAyah(surah.id, fromAyah)
                }.getOrDefault(0)
            }
            NoorPlayer.play(surah.id, surah.ayahCount, fromAyah, surah.nameArabic, pageEnd)
        }
    }

    fun shareAyah(verse: Verse) {
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
    }

    fun copyAyah(verse: Verse) {
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText(
            context.getString(R.string.g2_ayah_clip_label),
            "${verse.text} ⁧﴿${verse.ayah.arabicIndic()}﴾⁩ — ${surah.id}:${verse.ayah}"))
    }

    // Open-at-ayah: ayah mode scrolls to the block; flow mode scrolls the
    // single flow item to the ayah's first line once the layout is known.
    // Keyed on scrollToAyah too: go-to-page / search / hizb references can
    // resolve inside the surah already open, changing only the ayah.
    LaunchedEffect(mode, surah.id, scrollToAyah) {
        if (mode == "ayah" && scrollToAyah > 0) {
            val idx = verses.indexOfFirst { it.ayah == scrollToAyah }
            if (idx >= 0) listState.scrollToItem((if (hasBasmala) 1 else 0) + idx)
        }
    }
    var didScrollFlow by remember(surah.id, scrollToAyah) { mutableStateOf(false) }
    LaunchedEffect(textLayout, mode, scrollToAyah) {
        val layout = textLayout
        if (mode == "ayah" || didScrollFlow || scrollToAyah <= 0 || layout == null) return@LaunchedEffect
        val target = flow.getStringAnnotations("ayah", 0, flow.length)
            .firstOrNull { it.item == scrollToAyah.toString() }?.start ?: return@LaunchedEffect
        didScrollFlow = true
        val top = layout.getLineTop(layout.getLineForOffset(target)).toInt()
        listState.scrollToItem(if (hasBasmala) 1 else 0, top)
    }
    // Follow-along scroll (iOS onChange(of: recitingKey) → scrollTo):
    // as recitation advances, keep the playing ayah in view. Driven by
    // the player's Compose state via snapshotFlow — no polling. The span
    // offsets are stable across highlight rebuilds (styles add no text).
    LaunchedEffect(mode, surah.id) {
        androidx.compose.runtime.snapshotFlow {
            if (NoorPlayer.currentSurah == surah.id) NoorPlayer.currentAyah else 0
        }.collect { ayah ->
            if (ayah <= 0) return@collect
            if (mode == "ayah") {
                val idx = verses.indexOfFirst { it.ayah == ayah }
                if (idx >= 0) listState.animateScrollToItem((if (hasBasmala) 1 else 0) + idx)
            } else {
                val layout = textLayout ?: return@collect
                val target = flow.getStringAnnotations("ayah", 0, flow.length)
                    .firstOrNull { it.item == ayah.toString() }?.start ?: return@collect
                val top = layout.getLineTop(layout.getLineForOffset(target)).toInt()
                listState.animateScrollToItem(if (hasBasmala) 1 else 0, top)
            }
        }
    }

    // The iOS ayah-actions sheet: play from here, tafsir, share, copy, bookmark.
    val actionVerse = verses.firstOrNull { it.ayah == actionAyah }
    if (actionVerse != null) {
        AyahActionsSheet(
            verse = actionVerse,
            isBookmarked = "${surah.id}:${actionVerse.ayah}" in bookmarks,
            onPlay = { startPlayback(actionVerse.ayah) },
            onTafsir = { tafsirAyah = actionVerse.ayah },
            onShare = { shareAyah(actionVerse) },
            onShareVideo = { videoShare.start(actionVerse, surah) },
            onCopy = { copyAyah(actionVerse) },
            onToggleBookmark = { onToggleBookmark(actionVerse.ayah) },
            onDismiss = { actionAyah = 0 })
    }
    AyahVideoProgressDialog(videoShare)

    if (tafsirAyah > 0) {
        val verse = verses.firstOrNull { it.ayah == tafsirAyah }
        if (verse != null) {
            TafsirSheet(
                surahId = surah.id,
                ayah = verse.ayah,
                ayahText = verse.text,
                onDismiss = { tafsirAyah = 0 },
                surahName = surah.nameArabic)
        }
    }

    // Go-to-page (iOS GoToPageSheet, surfaced in the flow reader too):
    // resolve the printed page's first ayah off-main, then reopen there.
    if (showGoToPage && onOpenReference != null) {
        GoToPageDialog(
            onGo = { page ->
                scope.launch {
                    val start = withContext(Dispatchers.IO) {
                        PageLayoutDb.get(context).firstAyahOnPage(page)
                    } ?: return@launch
                    onOpenReference(start.surahId, start.ayah)
                }
            },
            onDismiss = { showGoToPage = false })
    }

    Column(modifier.fillMaxSize()) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 8.dp)
        ) {
            // Circular elevated back button, like the iOS reader chrome.
            Surface(
                shape = CircleShape,
                color = NoorColor.bgElevated,
                shadowElevation = 3.dp,
                modifier = Modifier.size(38.dp).clip(CircleShape).clickable(onClick = onBack)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    // Direction-aware: back points RIGHT in Arabic, LEFT in
                    // English (the fixed drawable was reversed under English).
                    Icon(painterResource(NoorIcons.chevronBackward()),
                         contentDescription = stringResource(R.string.g2_back),
                         tint = NoorColor.accentPrimary,
                         modifier = Modifier.size(18.dp))
                }
            }
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                // iOS parity: outside آية آية mode, the juz line under the
                // title opens go-to-page (mode != .ayah on iOS).
                modifier = Modifier
                    .weight(1f)
                    .clickable(enabled = mode != "ayah" && onOpenReference != null) {
                        showGoToPage = true
                    }
            ) {
                Text(
                    surah.nameArabic,
                    fontFamily = HafsFont,
                    fontSize = 20.sp,
                    color = NoorColor.inkPrimary,
                    textAlign = TextAlign.Center
                )
                Text(
                    stringResource(R.string.g2_juz_n, juz.localizedDigits()),
                    fontSize = 11.sp,
                    color = NoorColor.inkSecondary
                )
            }
            // Play/pause reflecting the live player state — tinted vectors
            // (SF play.fill / pause.fill), never emoji glyphs.
            Icon(
                painterResource(
                    if (NoorPlayer.currentSurah != 0 && NoorPlayer.isPlaying)
                        R.drawable.ic_pause_fill else R.drawable.ic_play_fill),
                contentDescription = stringResource(R.string.g2_play),
                tint = NoorColor.accentPrimary,
                modifier = Modifier.clip(CircleShape).clickable {
                    if (NoorPlayer.currentSurah != 0) NoorPlayer.toggle()
                    else startPlayback()
                }.padding(10.dp).size(17.dp)
            )
            // "Aa" opens the reader-options floating panel.
            Text(
                "Aa",
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                color = if (showOptions) NoorColor.accentGold else NoorColor.accentPrimary,
                modifier = Modifier.clip(CircleShape).clickable { showOptions = !showOptions }.padding(10.dp)
            )
        }
        Box(Modifier.weight(1f)) {
            LazyColumn(Modifier.fillMaxSize().padding(horizontal = 18.dp), state = listState) {
                if (hasBasmala) {
                    item {
                        Text(
                            basmala ?: "",
                            fontFamily = QuranFont,
                            fontSize = (fontSize * 0.85f).sp,
                            textAlign = TextAlign.Center,
                            color = NoorColor.inkPrimary,
                            modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp)
                        )
                    }
                }
                if (mode == "ayah") {
                    // آية آية: each ayah its own block with the gold number badge,
                    // ۩ on sajdah ayat, and a juz header where a new juz starts.
                    items(verses, key = { it.ayah }) { verse ->
                        val key = surah.id * 1000 + verse.ayah
                        Column {
                            juzAt[key]?.let { idx ->
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp)
                                ) {
                                    HorizontalDivider(
                                        color = NoorColor.accentGold.copy(alpha = 0.35f),
                                        modifier = Modifier.weight(1f))
                                    Text(
                                        stringResource(R.string.g2_juz_n, idx.localizedDigits()),
                                        fontSize = 12.sp,
                                        color = NoorColor.accentGold,
                                        modifier = Modifier.padding(horizontal = 10.dp))
                                    HorizontalDivider(
                                        color = NoorColor.accentGold.copy(alpha = 0.35f),
                                        modifier = Modifier.weight(1f))
                                }
                            }
                            Text(
                                buildAnnotatedString {
                                    if (key in quarterKeys) {
                                        withStyle(SpanStyle(color = NoorColor.accentGold)) {
                                            append("۞ ")
                                        }
                                    }
                                    append(verse.text)
                                    if (key in sajdaKeys) {
                                        withStyle(SpanStyle(color = NoorColor.accentGold)) {
                                            append(" ۩")
                                        }
                                    }
                                    withStyle(SpanStyle(
                                        color = NoorColor.accentGold,
                                        fontSize = (fontSize * 0.62f).sp)) {
                                        append("  ⁧﴿${verse.ayah.arabicIndic()}﴾⁩")
                                    }
                                },
                                fontFamily = QuranFont,
                                fontSize = fontSize.sp,
                                lineHeight = (fontSize * 2.2f).sp,
                                color = NoorColor.inkPrimary,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(
                                        if (verse.ayah == highlightAyah) NoorColor.stateReciting
                                        else NoorColor.bgPrimary.copy(alpha = 0f))
                                    .clickable { actionAyah = verse.ayah }
                                    .padding(horizontal = 12.dp, vertical = 8.dp)
                            )
                        }
                    }
                } else {
                    item {
                        Text(
                            flow,
                            fontFamily = QuranFont,
                            fontSize = fontSize.sp,
                            lineHeight = (fontSize * 2.2f).sp,
                            color = NoorColor.inkPrimary,
                            textAlign = TextAlign.Justify,
                            onTextLayout = { textLayout = it },
                            modifier = Modifier
                                .padding(bottom = 40.dp)
                                .pointerInput(surah.id) {
                                    detectTapGestures(
                                        onTap = { ayahAt(it) },
                                        onLongPress = { ayahAt(it) })
                                }
                        )
                    }
                }
            }
            if (showOptions) {
                // Scrim: any tap outside the panel dismisses it.
                Box(
                    Modifier
                        .fillMaxSize()
                        .pointerInput(Unit) { detectTapGestures { showOptions = false } }
                )
                ReaderOptionsPanel(
                    mode = mode,
                    fontSize = fontSize,
                    onMode = { newMode ->
                        showOptions = false
                        onModeChange(newMode)
                    },
                    onFontSize = { size ->
                        fontSize = size
                        prefs.edit().putFloat("reader.fontSize", size).apply()
                    },
                    modifier = Modifier.align(Alignment.TopCenter)
                )
            }
        }
    }
}

/// Floating elevated card under the top bar — the iOS reader options panel:
/// segmented مصحف / المدني / آية آية picker + Quran text-size stepper
/// (hidden in Madani page mode, whose printed geometry is fixed).
/// Shared by the flow reader and MushafScreen.
@Composable
fun ReaderOptionsPanel(
    mode: String,
    fontSize: Float,
    onMode: (String) -> Unit,
    onFontSize: (Float) -> Unit,
    modifier: Modifier = Modifier,
) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = NoorColor.bgElevated,
        shadowElevation = 10.dp,
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp)
            .padding(top = 4.dp)
    ) {
        Column(Modifier.padding(16.dp)) {
            // Segmented reading-mode picker.
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(NoorColor.bgPrimary)
                    .padding(3.dp)
            ) {
                ModeSegment(stringResource(R.string.g2_reading_mode_mushaf), selected = mode == "mushaf",
                            modifier = Modifier.weight(1f)) { onMode("mushaf") }
                ModeSegment(stringResource(R.string.g2_reading_mode_page), selected = mode == "page",
                            modifier = Modifier.weight(1f)) { onMode("page") }
                ModeSegment(stringResource(R.string.g2_reading_mode_ayah), selected = mode == "ayah",
                            modifier = Modifier.weight(1f)) { onMode("ayah") }
            }
            // The printed Madani page has fixed geometry — size buttons
            // only apply to the flow and ayah modes.
            if (mode != "page") {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth().padding(top = 14.dp)
                ) {
                    Text(
                        stringResource(R.string.g2_quran_text_size),
                        fontSize = 14.sp,
                        color = NoorColor.inkSecondary,
                        modifier = Modifier.weight(1f)
                    )
                    SizeButton("−") { onFontSize((fontSize - 2f).coerceAtLeast(20f)) }
                    Text(
                        fontSize.toInt().localizedDigits(),
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = NoorColor.accentPrimary,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(horizontal = 12.dp)
                    )
                    SizeButton("+") { onFontSize((fontSize + 2f).coerceAtMost(40f)) }
                }
            }
        }
    }
}

@Composable
private fun ModeSegment(
    label: String,
    selected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Box(
        contentAlignment = Alignment.Center,
        modifier = modifier
            .clip(RoundedCornerShape(8.dp))
            .background(if (selected) NoorColor.accentPrimary else NoorColor.bgPrimary)
            .clickable(onClick = onClick)
            .padding(vertical = 8.dp)
    ) {
        Text(
            label,
            fontSize = 13.sp,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
            color = if (selected) NoorColor.bgPrimary else NoorColor.inkPrimary
        )
    }
}

@Composable
private fun SizeButton(symbol: String, onClick: () -> Unit) {
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .size(34.dp)
            .clip(CircleShape)
            .background(NoorColor.bgPrimary)
            .clickable(onClick = onClick)
    ) {
        Text(symbol, fontSize = 18.sp, color = NoorColor.accentPrimary)
    }
}
