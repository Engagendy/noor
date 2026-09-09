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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.blur
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
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
import androidx.compose.runtime.saveable.rememberSaveable
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
import kotlinx.coroutines.flow.drop
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
    // Bumped on every navigation request into the reader, so re-opening the
    // SAME surah (picked from the reader's drawer) still resets it.
    var openSerial by remember { mutableStateOf(0) }
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
        openSerial++
    }

    // The learning area (matns, tajweed guide, tafsir, غريب القرآن) — pushed
    // from this tab exactly as iOS pushes `LearnRoute.home` on the Quran
    // stack. It owns its own back handling.
    var showLearn by rememberSaveable { mutableStateOf(false) }
    if (showLearn) {
        LearnScreen(onBack = { showLearn = false }, modifier = modifier)
        return
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

    // Immersive reading: while either reader is open the tab bar follows the
    // reader's chrome (iOS parity) — tap the page and the top strip and the
    // bar return together. The chrome starts visible on every arrival; only
    // the Madani reader hides it (its auto-hide and its tap toggle write the
    // same shared state), so the flow / ayah-by-ayah reader — whose top bar
    // is permanently visible — simply keeps its tab bar.
    val readerOpen = openMushafAt > 0 || openSurah != null
    LaunchedEffect(readerOpen) {
        if (readerOpen) ReaderChrome.readerAppeared() else ReaderChrome.readerDisappeared()
    }
    DisposableEffect(Unit) { onDispose { ReaderChrome.readerDisappeared() } }

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
                navToken = openSerial,
                allSurahs = surahs,
                bookmarks = bookmarks,
                // Continuous reading: the ayah's OWN surah comes back from
                // the reader — never `current`, which is only where it opened.
                onToggleBookmark = { surahId, ayah -> toggleBookmark(surahId, ayah) },
                onModeChange = { newMode ->
                    // User action from the options panel — persist + switch.
                    prefs.edit().putString("reader.mode", newMode).apply()
                    readerMode = newMode
                },
                onBack = { openSurah = null; openAyah = 0; onSurahClosed() },
                onOpenReference = { surahId, ayah ->
                    openAyah = ayah
                    openSurah = surahs.firstOrNull { it.id == surahId }
                    openSerial++
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
        openSerial++
    }

    // Word search runs off-main over the normalized index (LIKE, like iOS),
    // then ranked; a short debounce keeps fast typing from re-querying per
    // keystroke (produceState cancels the previous run on every new query).
    val query = searchText.trim()
    val normalizedQuery = remember(query) { SearchText.normalizeForSearch(query) }
    val results by produceState(VerseSearchResults(emptyList(), false), query) {
        value = if (query.length >= 2) {
            kotlinx.coroutines.delay(180)
            withContext(Dispatchers.IO) { db.searchVerses(query) }
        } else VerseSearchResults(emptyList(), false)
    }
    val hits = results.hits
    // "2:255"-style reference (Arabic-Indic digits welcome): jump by number.
    val westernQuery = query.map { c -> if (c in '٠'..'٩') ('0' + (c - '٠')) else c }
        .joinToString("")
    // Accepted reference forms: "2:255", "2 255", "2-255", "2.255", "2/255"
    // — in either digit system, since westernQuery already folded the digits.
    val reference = remember(westernQuery) {
        Regex("""^(\d{1,3})\s*[:\s./-]\s*(\d{1,3})$""").find(westernQuery.trim())?.let { m ->
            m.groupValues[1].toInt() to m.groupValues[2].toInt()
        }
    }
    val referenceHit = reference?.let { (sid, a) ->
        surahs.firstOrNull { it.id == sid && a in 1..it.ayahCount }?.let { it to a }
    }
    val referenceSurah = reference?.first
        ?: westernQuery.substringBefore(':').trim().toIntOrNull()
    val filteredSurahs =
        if (query.isEmpty()) surahs
        else if (referenceSurah != null) surahs.filter { it.id == referenceSurah }
        // Surah names match in all three forms the DB carries: Arabic
        // (diacritic-insensitive), transliteration, and English meaning.
        else surahs.filter {
            SearchText.contains(it.nameArabic, normalizedQuery) ||
                SearchText.contains(it.nameTransliterated, normalizedQuery) ||
                SearchText.contains(it.nameEnglish, normalizedQuery)
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
            // Entry to the learning area. A labelled pill beside the title,
            // not a fourth segment: the segmented control below is an INDEX
            // of the mushaf (Surah / Juz / Bookmarks), and "Learn" is not an
            // index of anything.
            Text(
                stringResource(R.string.learn_open),
                fontSize = 14.sp,
                color = NoorColor.accentPrimary,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(NoorColor.accentPrimary.copy(alpha = 0.12f))
                    .clickable(onClickLabel = stringResource(R.string.learn_hint)) {
                        showLearn = true
                    }
                    .padding(horizontal = 14.dp, vertical = 8.dp)
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
        NoorSearchField(
            value = searchText,
            onValueChange = { searchText = it },
            hint = stringResource(R.string.g2_search_quran_hint),
            modifier = Modifier.padding(horizontal = 16.dp),
        )
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
                // Exact reference typed ("2:255" / Arabic-Indic): open it directly.
                if (referenceHit != null) {
                    val (refSurah, refAyah) = referenceHit
                    item(key = "reference") {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { openReference(refSurah.id, refAyah) }
                                .padding(horizontal = 20.dp, vertical = 14.dp)
                        ) {
                            Text("۝", fontSize = 18.sp, color = NoorColor.accentGold)
                            Text(
                                refSurah.displayName() + " · " +
                                    refSurah.id.localizedDigits() + ":" + refAyah.localizedDigits(),
                                fontSize = 16.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = NoorColor.inkPrimary,
                                modifier = Modifier.weight(1f).padding(horizontal = 12.dp)
                            )
                            Icon(
                                painterResource(NoorIcons.chevronForward()),
                                contentDescription = null,
                                tint = NoorColor.inkSecondary,
                                modifier = Modifier.size(18.dp)
                            )
                        }
                        HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
                    }
                }
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
                                color = NoorColor.inkPrimary,
                                style = arabicText()
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
                    if (results.truncated) {
                        item(key = "truncated") {
                            Text(
                                stringResource(R.string.g2_search_truncated,
                                               hits.size.localizedDigits()),
                                fontSize = 12.sp,
                                color = NoorColor.inkSecondary,
                                modifier = Modifier.padding(horizontal = 20.dp, vertical = 2.dp)
                            )
                        }
                    }
                    items(hits, key = { "h${it.surahId}:${it.ayah}" }) { hit ->
                        Column(
                            Modifier
                                .fillMaxWidth()
                                .clickable { openReference(hit.surahId, hit.ayah) }
                                .padding(horizontal = 20.dp, vertical = 8.dp)
                        ) {
                            Text(
                                // Snippet centred on the match, term emphasised.
                                searchSnippet(hit.text, normalizedQuery),
                                fontFamily = QuranFont,
                                fontSize = 17.sp,
                                maxLines = 2,
                                overflow = TextOverflow.Ellipsis,
                                color = NoorColor.inkPrimary,
                                style = arabicText(),
                                modifier = Modifier.fillMaxWidth()
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

/// The app's search field (Quran index, athkar list): rounded, bordered,
/// placeholder in the UI direction, with a 28dp clipped clear button.
@Composable
internal fun NoorSearchField(
    value: String,
    onValueChange: (String) -> Unit,
    hint: String,
    modifier: Modifier = Modifier,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
            .fillMaxWidth()
            .height(40.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(NoorColor.bgElevated)
            .border(1.dp, NoorColor.inkPrimary.copy(alpha = 0.08f), RoundedCornerShape(12.dp))
            .padding(horizontal = 12.dp)
    ) {
        Box(Modifier.weight(1f)) {
            if (value.isEmpty()) {
                Text(
                    hint,
                    fontSize = 15.sp,
                    color = NoorColor.inkSecondary.copy(alpha = 0.8f)
                )
            }
            BasicTextField(
                value = value,
                onValueChange = onValueChange,
                singleLine = true,
                textStyle = TextStyle(fontSize = 15.sp, color = NoorColor.inkPrimary,
                                      fontFamily = NoorFont.family),
                cursorBrush = androidx.compose.ui.graphics.SolidColor(NoorColor.accentPrimary),
                modifier = Modifier.fillMaxWidth()
            )
        }
        if (value.isNotEmpty()) {
            Icon(
                painterResource(R.drawable.ic_close),
                contentDescription = stringResource(R.string.g2_clear_search),
                tint = NoorColor.inkSecondary,
                modifier = Modifier
                    .size(28.dp)
                    .clip(CircleShape)
                    .clickable { onValueChange("") }
                    .padding(6.dp)
            )
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

/// A search-result snippet: the ORIGINAL verified text windowed around the
/// match (never edited — only cut, with ellipses added), with the matched
/// term in the accent colour. Falls back to the plain text when the match
/// cannot be located.
internal fun searchSnippet(
    text: String,
    normalizedQuery: String,
    radius: Int = 45,
): androidx.compose.ui.text.AnnotatedString {
    val range = SearchText.matchRange(text, normalizedQuery)
        ?: return androidx.compose.ui.text.AnnotatedString(text)
    var start = (range.first - radius).coerceAtLeast(0)
    var end = (range.last + 1 + radius).coerceAtMost(text.length)
    // Never cut a word in half.
    while (start > 0 && !text[start - 1].isWhitespace()) start--
    while (end < text.length && !text[end].isWhitespace()) end++
    return buildAnnotatedString {
        if (start > 0) append("… ")
        append(text.substring(start, range.first))
        withStyle(SpanStyle(color = NoorColor.accentPrimary, fontWeight = FontWeight.Bold)) {
            append(text.substring(range.first, range.last + 1))
        }
        append(text.substring(range.last + 1, end))
        if (end < text.length) append(" …")
    }
}

/// One surah rendered as the continuous mushaf-style flow: gold ayah
/// markers, ۞ at hizb-quarter starts, ۩ on sajdah ayat and a small juz
/// header where a new juz begins — all indexing marks, never text edits.
/// Each verse span is annotated so a tap resolves its ayah.
///
/// Pure and deterministic: the highlight only adds a span style, so the
/// character offsets do not depend on it.
internal fun buildSurahFlow(
    context: Context,
    db: QuranDb,
    surahId: Int,
    verses: List<Verse>,
    juzAt: Map<Int, Int>,
    quarterKeys: Set<Int>,
    sajdaKeys: Set<Int>,
    fontSize: Float,
    highlightAyah: Int,
) = buildAnnotatedString {
    verses.forEach { verse ->
        val key = surahId * 1000 + verse.ayah
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
        // Ayah 1 of surahs 2..114 stores the basmala as a leading prefix;
        // the reader draws its own basmala line above, so render only the
        // ayah's own words (see QuranDb KDoc).
        val body = db.textWithoutLeadingBasmala(verse)
        if (highlightAyah == verse.ayah) {
            withStyle(SpanStyle(background = NoorColor.stateReciting)) { append(body) }
        } else {
            append(body)
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

/// Surahs 1 and 9 never get a separate basmala line (1's is its ayah 1).
private fun hasBasmalaLine(surahId: Int) = surahId != 9 && surahId != 1

/// Structure metadata shared by every reader page (juz/quarter starts,
/// sajdah ayat, the verified basmala) — read once, passed down.
private data class ReaderMeta(
    val juzAt: Map<Int, Int>,
    val quarterKeys: Set<Int>,
    val sajdaKeys: Set<Int>,
    val basmala: String?,
)

/// The flow / ayah-by-ayah reader, with the iOS-style "Aa" options panel:
/// segmented reading-mode picker + text-size stepper on an elevated card.
///
/// Moving between surahs is a HORIZONTAL SWIPE over a 114-page pager (page
/// index = surah id − 1), exactly like the Madani page mode — each page owns
/// its own vertical scroll, so the two gestures never fight. The drawer
/// handles distant jumps. Everything the chrome shows and every per-ayah
/// action therefore keys off the CURRENT PAGE's surah, never [surah], which
/// is only where the reader opened.
///
/// [navToken] changes on every navigation request from the caller, so
/// re-opening the SAME surah still moves the pager back to it.
@Composable
fun ReaderScreen(
    surah: Surah,
    mode: String,
    onModeChange: (String) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    scrollToAyah: Int = 0,
    navToken: Int = 0,
    allSurahs: List<Surah> = emptyList(),
    bookmarks: Set<String> = emptySet(),
    onToggleBookmark: (surahId: Int, ayah: Int) -> Unit = { _, _ -> },
    onOpenReference: ((surahId: Int, ayah: Int) -> Unit)? = null,
) {
    val context = LocalContext.current
    val db = remember { QuranDb.get(context) }
    val surahs = remember(allSurahs) { allSurahs.ifEmpty { db.surahs() } }
    val prefs = remember { KhatmahPlan.prefs(context) }
    val scope = rememberCoroutineScope()
    // Video share state lives here, above the self-dismissing actions sheet.
    val videoShare = rememberShareVideoShare(scope)
    var showOptions by remember { mutableStateOf(false) }
    var showGoToPage by remember { mutableStateOf(false) }
    var showSurahList by remember { mutableStateOf(false) }
    // Overlays close before the caller's handler pops the reader (sheets and
    // dialogs consume back themselves). Registered after the caller's, so
    // these win while open.
    androidx.activity.compose.BackHandler(enabled = showOptions) { showOptions = false }
    androidx.activity.compose.BackHandler(enabled = showSurahList) { showSurahList = false }
    var fontSize by remember { mutableFloatStateOf(prefs.getFloat("reader.fontSize", 26f)) }
    // Reader options, mirrored from prefs exactly like iOS's @AppStorage
    // (reader.translation / reader.wordByWord / reader.hifz). Prefs are read
    // once into state and written only from the panel's click handlers.
    var showTranslation by remember { mutableStateOf(prefs.getBoolean("reader.translation", false)) }
    var wordByWord by remember { mutableStateOf(prefs.getBoolean("reader.wordByWord", false)) }
    var hifzMode by remember { mutableStateOf(prefs.getBoolean("reader.hifz", false)) }
    // Ayat the reader has tapped to reveal while hifz mode hides the text
    // (iOS revealedKeys); cleared whenever the mode is flipped.
    var revealedKeys by remember { mutableStateOf(emptySet<Int>()) }
    // Fetch/parse the chosen Tanzil edition the moment a translation is
    // wanted — downloaded once, then offline for good.
    LaunchedEffect(showTranslation) { if (showTranslation) TranslationStore.ensure(context) }
    // Structure metadata (juz/quarter starts, sajdah ayat) keyed s*1000+a,
    // plus the basmala line straight from the verified DB (1:1), never typed.
    val meta = remember {
        ReaderMeta(
            juzAt = db.juzStarts().associateBy({ it.surahId * 1000 + it.ayah }, { it.idx }),
            quarterKeys = db.quarterStarts().map { it.surahId * 1000 + it.ayah }.toSet(),
            sajdaKeys = db.sajdaKeys(),
            basmala = db.basmala())
    }
    val juzStarts = remember { db.juzStarts() }
    // Juz for a reference, from the in-memory starts — no DB hit per swipe.
    fun juzOf(surahId: Int, ayah: Int): Int =
        juzStarts.lastOrNull {
            it.surahId < surahId || (it.surahId == surahId && it.ayah <= ayah)
        }?.idx ?: 1

    // One page per surah. Compose's pager honours the layout direction, so
    // the swipe mirrors itself in Arabic exactly as the Madani pager does.
    val pager = androidx.compose.foundation.pager.rememberPagerState(
        initialPage = (surah.id - 1).coerceIn(0, 113)
    ) { 114 }
    // Caller-driven navigation (search hit, bookmark, juz, go-to-page,
    // "continue reading") jumps the pager; the drawer scrolls it directly.
    LaunchedEffect(surah.id, navToken) {
        if (pager.currentPage != surah.id - 1) pager.scrollToPage(surah.id - 1)
    }
    val currentSurah = surahs.firstOrNull { it.id == pager.currentPage + 1 } ?: surah
    val juz = juzOf(
        currentSurah.id,
        if (currentSurah.id == surah.id) scrollToAyah.coerceAtLeast(1) else 1)
    // Resume position: one direct prefs write per settled surah, off-main —
    // never observed as Compose state (same rule as the Madani pager), and
    // driven from an effect, never from composition.
    // A settle on a surah other than the one being recited means the reader
    // swiped away — stop auto-following until playback restarts (mirrors the
    // Madani pager's followPlayback).
    var followPlayback by remember { mutableStateOf(true) }
    LaunchedEffect(pager) {
        androidx.compose.runtime.snapshotFlow { pager.settledPage }.collect { page ->
            if (NoorPlayer.currentSurah != 0 && page + 1 != NoorPlayer.currentSurah) {
                followPlayback = false
            }
            withContext(Dispatchers.IO) { ReadingProgress.surahViewed(context, page + 1) }
        }
    }
    // Verses, loaded off-main and cached by surah id. Access-ordered and
    // capped, so only the pages around the reader hold verse data.
    val verseCache = remember {
        java.util.Collections.synchronizedMap(
            object : LinkedHashMap<Int, List<Verse>>(8, 0.75f, true) {
                override fun removeEldestEntry(eldest: MutableMap.MutableEntry<Int, List<Verse>>) =
                    size > 7
            })
    }
    val versesFor: suspend (Int) -> List<Verse> = { id ->
        verseCache[id] ?: withContext(Dispatchers.IO) { db.verses(id) }.also { verseCache[id] = it }
    }

    // Ayah picked for the actions sheet / tafsir — the SURAH travels with
    // the verse, so bookmark/share/copy/video/tafsir can never be filed
    // under the surah the reader happened to open at.
    var actionTarget by remember { mutableStateOf<Pair<Surah, Verse>?>(null) }
    var tafsirTarget by remember { mutableStateOf<Pair<Surah, Verse>?>(null) }

    fun startPlayback(s: Surah, fromAyah: Int = 1) {
        scope.launch {
            // "This page only" boundary comes from the layout DB — off-main.
            val pageEnd = withContext(Dispatchers.IO) {
                runCatching {
                    PageLayoutDb.get(context).pageEndAyah(s.id, fromAyah)
                }.getOrDefault(0)
            }
            NoorPlayer.play(s.id, s.ayahCount, fromAyah, s.nameArabic, pageEnd)
        }
    }

    fun shareAyah(s: Surah, verse: Verse) {
        scope.launch {
            val bitmap = withContext(Dispatchers.IO) {
                ShareCard.render(
                    context,
                    "${verse.text} ⁧﴿${verse.ayah.arabicIndic()}﴾⁩",
                    context.getString(R.string.g2_surah_prefix, s.nameArabic) +
                        " · ${s.id.localizedDigits()}:${verse.ayah.localizedDigits()}",
                    useQuranFont = true)
            }
            ShareCard.share(context, bitmap)
        }
    }

    fun copyAyah(s: Surah, verse: Verse) {
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText(
            context.getString(R.string.g2_ayah_clip_label),
            "${verse.text} ⁧﴿${verse.ayah.arabicIndic()}﴾⁩ — ${s.id}:${verse.ayah}"))
    }

    // Continuous playback crossing into the next surah (NoorPlayer's
    // advanceToNextSurah) flips the pager to that surah; the page then
    // scrolls to the reciting ayah itself. Same follow-along contract as
    // the Madani pager, driven by the player's Compose state — no polling.
    LaunchedEffect(pager) {
        androidx.compose.runtime.snapshotFlow { NoorPlayer.currentSurah }.collect { playing ->
            if (playing == 0) {
                followPlayback = true  // next session follows again
                return@collect
            }
            if (followPlayback && playing in 1..114 && pager.currentPage != playing - 1) {
                pager.animateScrollToPage(playing - 1)
            }
        }
    }
    // The reader swiped away, then drove the player by hand (previous / next
    // / play, or tapped the pill's reference): jump back to the recitation.
    LaunchedEffect(pager) {
        androidx.compose.runtime.snapshotFlow { NoorPlayer.resyncRequest }
            .drop(1)
            .collect {
                val playing = NoorPlayer.currentSurah
                followPlayback = true
                if (playing in 1..114 && pager.currentPage != playing - 1) {
                    pager.animateScrollToPage(playing - 1)
                }
            }
    }

    // The iOS ayah-actions sheet: play from here, tafsir, share, copy,
    // bookmark. It dismisses itself BEFORE firing, so everything the action
    // needs (scope, videoShare, tafsirTarget) lives at screen level.
    actionTarget?.let { (actionSurah, actionVerse) ->
        AyahActionsSheet(
            verse = actionVerse,
            isBookmarked = "${actionSurah.id}:${actionVerse.ayah}" in bookmarks,
            onPlay = { startPlayback(actionSurah, actionVerse.ayah) },
            onTafsir = { tafsirTarget = actionSurah to actionVerse },
            onShare = { shareAyah(actionSurah, actionVerse) },
            onShareVideo = { videoShare.start(actionVerse, actionSurah) },
            onCopy = { copyAyah(actionSurah, actionVerse) },
            onToggleBookmark = { onToggleBookmark(actionSurah.id, actionVerse.ayah) },
            onDismiss = { actionTarget = null })
    }
    ShareVideoProgressDialog(videoShare)

    tafsirTarget?.let { (tafsirSurah, verse) ->
        TafsirSheet(
            surahId = tafsirSurah.id,
            ayah = verse.ayah,
            ayahText = verse.text,
            onDismiss = { tafsirTarget = null },
            surahName = tafsirSurah.nameArabic)
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

    Box(modifier.fillMaxSize()) {
    Column(Modifier.fillMaxSize()) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 8.dp)
        ) {
            // The surah drawer replaces the old back button: jump to any
            // surah without going back to the index (swipe covers the
            // neighbours). Exiting the reader is the drawer's first row,
            // and system back.
            SurahListButton {
                showOptions = false
                showSurahList = true
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
                    currentSurah.nameArabic,
                    fontFamily = HafsFont,
                    fontSize = 20.sp,
                    color = NoorColor.inkPrimary,
                    textAlign = TextAlign.Center,
                    style = arabicText(TextAlign.Center)
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
                    else startPlayback(currentSurah)
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
            androidx.compose.foundation.pager.HorizontalPager(
                state = pager,
                beyondViewportPageCount = 1,
                modifier = Modifier.fillMaxSize()
            ) { page ->
                val pageSurah = surahs.firstOrNull { it.id == page + 1 }
                if (pageSurah != null) {
                    SurahPage(
                        surah = pageSurah,
                        mode = mode,
                        fontSize = fontSize,
                        // The arrival ayah belongs to the surah the caller
                        // asked for — never to a surah swiped into.
                        scrollToAyah = if (pageSurah.id == surah.id) scrollToAyah else 0,
                        meta = meta,
                        versesFor = versesFor,
                        showTranslation = showTranslation,
                        wordByWord = wordByWord,
                        hifzMode = hifzMode,
                        revealedKeys = revealedKeys,
                        onReveal = { key -> revealedKeys = revealedKeys + key },
                        onAyahTap = { s, verse -> actionTarget = s to verse })
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
                    // A translation line, a word gloss and a hifz blur are
                    // all per-ayah furniture: they exist only in آية آية
                    // mode, so switching one on takes the reader there
                    // (iOS SurahReaderView.readerMenu does the same).
                    showTranslation = showTranslation,
                    onShowTranslation = { on ->
                        showTranslation = on
                        prefs.edit().putBoolean("reader.translation", on).apply()
                        if (on && mode != "ayah") onModeChange("ayah")
                    },
                    wordByWord = wordByWord,
                    onWordByWord = { on ->
                        wordByWord = on
                        prefs.edit().putBoolean("reader.wordByWord", on).apply()
                        if (on && mode != "ayah") onModeChange("ayah")
                    },
                    hifzMode = hifzMode,
                    onHifzMode = { on ->
                        hifzMode = on
                        revealedKeys = emptySet()
                        prefs.edit().putBoolean("reader.hifz", on).apply()
                        if (on && mode != "ayah") onModeChange("ayah")
                    },
                    downloadSurah = currentSurah,
                    modifier = Modifier.align(Alignment.TopCenter)
                )
            }
        }
    }
    SurahDrawer(
        visible = showSurahList,
        surahs = surahs,
        currentSurahId = currentSurah.id,
        onPick = { picked ->
            showSurahList = false
            // Distant jump: move the pager itself, so the reader keeps its
            // pages and the swipe neighbours stay correct.
            scope.launch { pager.scrollToPage(picked.id - 1) }
        },
        onClose = { showSurahList = false },
        onExitReader = { showSurahList = false; onBack() })
    }
}

/// One surah = one pager page: its basmala line (except surahs 1 and 9) and
/// its ayat, with its OWN vertical scroll state so swiping horizontally and
/// scrolling vertically never fight. Verses load off-main through the
/// caller's cache.
@Composable
private fun SurahPage(
    surah: Surah,
    mode: String,
    fontSize: Float,
    scrollToAyah: Int,
    meta: ReaderMeta,
    versesFor: suspend (Int) -> List<Verse>,
    showTranslation: Boolean = false,
    wordByWord: Boolean = false,
    hifzMode: Boolean = false,
    revealedKeys: Set<Int> = emptySet(),
    onReveal: (Int) -> Unit = {},
    onAyahTap: (Surah, Verse) -> Unit,
) {
    val context = LocalContext.current
    val db = remember { QuranDb.get(context) }
    val listState = rememberLazyListState()
    val verses by produceState(emptyList<Verse>(), surah.id) { value = versesFor(surah.id) }
    var textLayout by remember(surah.id) { mutableStateOf<TextLayoutResult?>(null) }
    val hasBasmala = hasBasmalaLine(surah.id)
    // Ayah being recited in THIS surah (iOS recitingKey) — Compose state
    // from the player, so the highlight tracks playback automatically.
    val recitingAyah = if (NoorPlayer.currentSurah == surah.id) NoorPlayer.currentAyah else 0
    // Recitation wins over the arrival highlight (iOS: recitingKey ?? selectedKey).
    val highlightAyah = if (recitingAyah > 0) recitingAyah else scrollToAyah
    val flow = remember(surah.id, verses, fontSize, highlightAyah, mode) {
        if (mode == "ayah") androidx.compose.ui.text.AnnotatedString("")
        else buildSurahFlow(context, db, surah.id, verses, meta.juzAt, meta.quarterKeys,
                            meta.sajdaKeys, fontSize, highlightAyah)
    }

    // Scrolls this page to an ayah: flow mode lands on the ayah's first
    // line, ayah mode on its block.
    suspend fun scrollTo(ayah: Int, animate: Boolean) {
        if (ayah <= 0 || verses.isEmpty()) return
        if (mode == "ayah") {
            val idx = verses.indexOfFirst { it.ayah == ayah }
            if (idx < 0) return
            val target = (if (hasBasmala) 1 else 0) + idx
            if (animate) listState.animateScrollToItem(target) else listState.scrollToItem(target)
            return
        }
        val layout = textLayout ?: return
        val offset = flow.getStringAnnotations("ayah", 0, flow.length)
            .firstOrNull { it.item == ayah.toString() }?.start ?: return
        val top = layout.getLineTop(layout.getLineForOffset(offset)).toInt()
        val item = if (hasBasmala) 1 else 0
        if (animate) listState.animateScrollToItem(item, top) else listState.scrollToItem(item, top)
    }

    // Open-at-ayah: waits for the verses (and, in flow mode, the paragraph
    // layout) before scrolling.
    LaunchedEffect(surah.id, mode, scrollToAyah, verses, textLayout) {
        if (scrollToAyah <= 0 || verses.isEmpty()) return@LaunchedEffect
        if (mode != "ayah" && textLayout == null) return@LaunchedEffect
        scrollTo(scrollToAyah, animate = false)
    }
    // Follow-along scroll (iOS onChange(of: recitingKey) → scrollTo): as the
    // recitation advances, keep the playing ayah in view.
    LaunchedEffect(surah.id, mode) {
        androidx.compose.runtime.snapshotFlow {
            if (NoorPlayer.currentSurah == surah.id) NoorPlayer.currentAyah else 0
        }.collect { ayah -> if (ayah > 0) scrollTo(ayah, animate = true) }
    }

    // The whole Quran text area is an RTL block, in the English UI too.
    ArabicDirection {
        LazyColumn(Modifier.fillMaxSize().padding(horizontal = 18.dp), state = listState) {
            if (hasBasmala) {
                item("basmala") {
                    Text(
                        meta.basmala ?: "",
                        fontFamily = QuranFont,
                        fontSize = (fontSize * 0.85f).sp,
                        textAlign = TextAlign.Center,
                        style = arabicText(TextAlign.Center),
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
                        meta.juzAt[key]?.let { idx ->
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
                        // Hifz mode hides every ayah except the one being
                        // recited until it is tapped, so the reader can test
                        // their memorisation (iOS blur + revealedKeys).
                        val hidden = hifzMode && key !in revealedKeys &&
                            verse.ayah != recitingAyah
                        Column(
                            Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(10.dp))
                                .background(
                                    if (verse.ayah == highlightAyah) NoorColor.stateReciting
                                    else NoorColor.bgPrimary.copy(alpha = 0f))
                                .clickable {
                                    // First tap on a hidden ayah reveals it;
                                    // the actions sheet needs a second tap.
                                    if (hidden) onReveal(key) else onAyahTap(surah, verse)
                                }
                                .padding(horizontal = 12.dp, vertical = 8.dp)
                                .hifzHidden(hidden)
                        ) {
                            if (wordByWord) {
                                WordByWordAyah(
                                    surahId = surah.id,
                                    ayah = verse.ayah,
                                    fontSize = fontSize)
                            } else {
                                Text(
                                    buildAnnotatedString {
                                        if (key in meta.quarterKeys) {
                                            withStyle(SpanStyle(color = NoorColor.accentGold)) {
                                                append("۞ ")
                                            }
                                        }
                                        // Same basmala de-duplication as the flow
                                        // layout (QuranDb KDoc).
                                        append(db.textWithoutLeadingBasmala(verse))
                                        if (key in meta.sajdaKeys) {
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
                                    // RTL paragraph whatever the UI language: the
                                    // ayah-number chip lands at the line end (left).
                                    style = arabicText(),
                                    modifier = Modifier.fillMaxWidth()
                                )
                            }
                            if (showTranslation) {
                                // The translation reads in ITS own direction
                                // (LTR for English, RTL for Urdu) inside the
                                // Arabic block that wraps the whole page.
                                TranslationLine(surah.id, verse.ayah)
                            }
                        }
                    }
                }
            } else {
                item("flow") {
                    Text(
                        flow,
                        fontFamily = QuranFont,
                        fontSize = fontSize.sp,
                        lineHeight = (fontSize * 2.2f).sp,
                        color = NoorColor.inkPrimary,
                        textAlign = TextAlign.Justify,
                        style = arabicText(TextAlign.Justify),
                        onTextLayout = { textLayout = it },
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(bottom = 40.dp)
                            .pointerInput(surah.id, flow) {
                                fun pick(position: Offset) {
                                    val layout = textLayout ?: return
                                    val offset = layout.getOffsetForPosition(position)
                                    flow.getStringAnnotations("ayah", offset, offset)
                                        .firstOrNull()?.item?.toIntOrNull()?.let { ayah ->
                                            verses.firstOrNull { it.ayah == ayah }
                                                ?.let { onAyahTap(surah, it) }
                                        }
                                }
                                detectTapGestures(
                                    onTap = { pick(it) },
                                    onLongPress = { pick(it) })
                            }
                    )
                }
            }
        }
    }
}


/// Floating elevated card under the top bar — the iOS reader options panel
/// (SurahReaderView.optionsPanel): segmented مصحف / المدني / آية آية picker,
/// show-translation, word-by-word and hifz toggles, the surah-audio download
/// button, and the Quran text-size stepper.
///
/// MADANI RULE (iOS parity, 2026-09): a Madani page draws QCF page-font
/// glyphs on a rigid 15-row grid — it can show neither a translation line,
/// nor a word gloss, nor a blurred ayah, and its geometry is fixed. Those
/// controls used to be offered there and silently threw the reader into
/// another mode, a surprising way to lose your page. In "page" mode the
/// panel therefore shows only the mode picker and the audio download.
///
/// Shared by the flow reader and MushafScreen.
@Composable
fun ReaderOptionsPanel(
    mode: String,
    fontSize: Float,
    onMode: (String) -> Unit,
    onFontSize: (Float) -> Unit,
    modifier: Modifier = Modifier,
    showTranslation: Boolean = false,
    onShowTranslation: ((Boolean) -> Unit)? = null,
    wordByWord: Boolean = false,
    onWordByWord: ((Boolean) -> Unit)? = null,
    hifzMode: Boolean = false,
    onHifzMode: ((Boolean) -> Unit)? = null,
    /// The surah whose recitation the download button fetches — null hides it.
    downloadSurah: Surah? = null,
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
            if (mode != "page") {
                if (onShowTranslation != null) {
                    // The download state of the chosen Tanzil edition is
                    // reported under the switch: flipping it on with no
                    // network would otherwise look like a dead toggle.
                    OptionToggle(
                        label = stringResource(R.string.g2_show_translation),
                        checked = showTranslation,
                        subtitle = when {
                            !showTranslation -> null
                            TranslationStore.state == TranslationStore.State.DOWNLOADING ->
                                stringResource(R.string.g2_translation_downloading)
                            TranslationStore.state == TranslationStore.State.FAILED ->
                                stringResource(R.string.g2_translation_failed)
                            else -> null
                        },
                        onChange = onShowTranslation)
                }
                if (onWordByWord != null) {
                    OptionToggle(
                        label = stringResource(R.string.g2_word_by_word),
                        checked = wordByWord,
                        onChange = onWordByWord)
                }
                if (onHifzMode != null) {
                    OptionToggle(
                        label = stringResource(R.string.g2_hifz_mode),
                        checked = hifzMode,
                        onChange = onHifzMode)
                }
            }
            if (downloadSurah != null) DownloadAudioRow(downloadSurah)
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

/// One switch row of the options panel, in the panel's own visual language
/// (14sp secondary label, accent track) — 48dp tall, and the whole row is
/// the target, so the label toggles it too.
@Composable
private fun OptionToggle(
    label: String,
    checked: Boolean,
    onChange: (Boolean) -> Unit,
    subtitle: String? = null,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp)
            .padding(top = 8.dp)
            .clip(RoundedCornerShape(8.dp))
            .toggleable(value = checked, role = Role.Switch, onValueChange = onChange)
    ) {
        Column(Modifier.weight(1f).padding(end = 12.dp)) {
            Text(label, fontSize = 14.sp, color = NoorColor.inkPrimary)
            if (subtitle != null) {
                Text(subtitle, fontSize = 12.sp, lineHeight = 16.sp, color = NoorColor.inkSecondary)
            }
        }
        Switch(
            checked = checked,
            // The row owns the gesture (and the accessibility state); the
            // switch itself is decoration, so it is not a second target.
            onCheckedChange = null,
            colors = SwitchDefaults.colors(
                checkedTrackColor = NoorColor.accentPrimary,
                checkedThumbColor = NoorColor.bgElevated))
    }
}

/// "Download surah audio" — the iOS optionsPanel button, on top of the
/// player's own ayah cache: every ayah of the surah (and of the selected
/// translated reading) fetched up front, so the surah plays offline.
@Composable
private fun DownloadAudioRow(surah: Surah) {
    val scope = rememberCoroutineScope()
    val phase = SurahDownloader.phase
    // Opening the panel on another surah must not inherit the last run's
    // "downloaded" state.
    LaunchedEffect(surah.id) { SurahDownloader.reset() }
    // Whether it is ALREADY on disk — one stat per ayah, off-main.
    val onDisk by produceState(false, surah.id, phase, NoorPlayer.reciter, NoorPlayer.translation) {
        value = withContext(Dispatchers.IO) {
            SurahDownloader.isDownloaded(surah.id, surah.ayahCount)
        }
    }
    val downloading = phase == SurahDownloader.Phase.DOWNLOADING
    val done = phase == SurahDownloader.Phase.DONE || (!downloading && onDisk)
    val label = when {
        downloading -> stringResource(
            R.string.g2_audio_downloading,
            SurahDownloader.completed.localizedDigits(),
            SurahDownloader.total.localizedDigits())
        done -> stringResource(R.string.g2_audio_downloaded)
        phase == SurahDownloader.Phase.FAILED -> stringResource(R.string.g2_audio_download_failed)
        else -> stringResource(R.string.g2_download_surah_audio)
    }
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp)
            .padding(top = 10.dp)
            .clip(RoundedCornerShape(8.dp))
            .clickable(enabled = !downloading && !done) {
                scope.launch { SurahDownloader.download(surah.id, surah.ayahCount) }
            }
            .semantics { contentDescription = label }
    ) {
        if (downloading) {
            CircularProgressIndicator(
                color = NoorColor.accentPrimary,
                strokeWidth = 2.dp,
                modifier = Modifier.size(16.dp))
        } else {
            Icon(
                painterResource(if (done) R.drawable.ic_check else R.drawable.ic_headphones),
                contentDescription = null,
                tint = NoorColor.accentPrimary,
                modifier = Modifier.size(16.dp))
        }
        Text(
            label,
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            color = NoorColor.accentPrimary,
            modifier = Modifier.padding(start = 10.dp))
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


/// Hifz mode: hide an ayah until it is tapped. A real blur needs
/// RenderEffect (API 31+); on older devices — minSdk here is 26 — the text
/// is faded out instead, so the toggle is never a no-op on any device.
private fun Modifier.hifzHidden(hidden: Boolean): Modifier =
    if (!hidden) this
    else if (android.os.Build.VERSION.SDK_INT >= 31) this.blur(7.dp)
    else this.alpha(0.06f)

/// The chosen translation of one ayah, under its Arabic text. Reads in its
/// OWN direction (LTR for English, RTL for Urdu) inside the RTL Quran block.
///
/// This slot is NEVER allowed to render nothing while the reader has asked
/// for a translation. It used to `?: return` on a missing text, so a store
/// that was still downloading — or had failed — made every ayah silently
/// skip the line and the switch looked dead. A feature that fails visibly
/// can be diagnosed; one that fails silently makes the app look broken.
@Composable
private fun TranslationLine(surahId: Int, ayah: Int) {
    val text = TranslationStore.text(surahId, ayah)
    if (text != null) {
        CompositionLocalProvider(
            LocalLayoutDirection provides
                (if (TranslationStore.isRTL) LayoutDirection.Rtl else LayoutDirection.Ltr)
        ) {
            Text(
                text,
                fontSize = 14.sp,
                lineHeight = 21.sp,
                color = NoorColor.inkSecondary,
                textAlign = TextAlign.Start,
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
        }
        return
    }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    // Status lines are app chrome, not scripture: they read in the UI
    // language's direction, not the RTL direction of the Quran block.
    CompositionLocalProvider(LocalLayoutDirection provides noorLayoutDirection()) {
        when (TranslationStore.state) {
            TranslationStore.State.DOWNLOADING ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
                ) {
                    CircularProgressIndicator(
                        strokeWidth = 1.5.dp,
                        color = NoorColor.accentPrimary,
                        modifier = Modifier.size(13.dp))
                    Text(
                        stringResource(R.string.g2_translation_downloading),
                        fontSize = 13.sp,
                        color = NoorColor.inkSecondary)
                }
            // Ready, yet this ayah has no line: the edition itself is short
            // of it. Nothing to retry, and a false error would be worse.
            TranslationStore.State.READY -> Unit
            // Not downloaded / failed — offer the way out, right here.
            else ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .clickable { scope.launch { TranslationStore.ensure(context) } }
                        .heightIn(min = 44.dp)
                ) {
                    Text(
                        stringResource(R.string.g2_translation_retry),
                        fontSize = 13.sp,
                        lineHeight = 19.sp,
                        color = NoorColor.accentPrimary,
                        textAlign = TextAlign.Start,
                        modifier = Modifier.fillMaxWidth())
                }
        }
    }
}

/// Word-by-word view of one ayah: every word in the Quran font with its
/// English gloss beneath, wrapping right-to-left like the mushaf — the iOS
/// WordByWordView, on the same page-layout DB (its `translation` column).
@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
private fun WordByWordAyah(surahId: Int, ayah: Int, fontSize: Float) {
    val context = LocalContext.current
    // Off-main: one small indexed query per ayah, cached by the state.
    val words by produceState(emptyList<WordGloss>(), surahId, ayah) {
        value = withContext(Dispatchers.IO) {
            runCatching { PageLayoutDb.get(context).words(surahId, ayah) }.getOrDefault(emptyList())
        }
    }
    androidx.compose.foundation.layout.FlowRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        // The enclosing ArabicDirection already lays the row out RTL, so the
        // words wrap in reading order without any manual placement.
        for (word in words) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .clip(RoundedCornerShape(6.dp))
                    .background(NoorColor.bgElevated.copy(alpha = 0.6f))
                    .padding(horizontal = 6.dp, vertical = 4.dp)
                    .widthIn(max = 130.dp)
            ) {
                Text(
                    word.text,
                    fontFamily = QuranFont,
                    fontSize = (fontSize * 0.92f).sp,
                    lineHeight = (fontSize * 1.5f).sp,
                    color = NoorColor.inkPrimary,
                    style = arabicText(TextAlign.Center))
                CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
                    Text(
                        word.translation,
                        fontSize = 11.sp,
                        lineHeight = 14.sp,
                        color = NoorColor.inkSecondary,
                        textAlign = TextAlign.Center)
                }
            }
        }
        // The ayah number closes the ayah, as in the plain ayah block.
        Text(
            "⁧﴿${ayah.arabicIndic()}﴾⁩",
            fontFamily = QuranFont,
            fontSize = (fontSize * 0.62f).sp,
            color = NoorColor.accentGold,
            style = arabicText(),
            modifier = Modifier.padding(top = 4.dp))
    }
}
