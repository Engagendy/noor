package com.engagendy.noor

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/// Whole-edition download state, 1:1 with the iOS `TafsirService.packState`
/// + `TafsirPackRow`. It is a singleton on purpose: a download started from
/// a search result must keep running when the user clears the query and the
/// row disappears (on iOS the screen owns the long-lived service; here the
/// object outlives every composition).
///
/// There is NO second network path — it calls the same per-surah fetch the
/// browser and the ayah sheet cache goes through.
object TafsirPacks {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    var downloadingSlug by mutableStateOf<String?>(null)
        private set
    /// Surah number currently being fetched, 0..114.
    var progress by mutableStateOf(0)
        private set
    var failure by mutableStateOf<String?>(null)
        private set
    /// Bumped every time a surah bundle lands on disk, so search indexes and
    /// coverage lines rebuild instead of going stale.
    var cacheVersion by mutableStateOf(0)
        private set

    internal fun noteCacheChanged() {
        cacheVersion++
    }

    fun download(context: Context, slug: String) {
        if (downloadingSlug != null) return
        val app = context.applicationContext
        downloadingSlug = slug
        failure = null
        progress = 0
        scope.launch {
            try {
                for (surah in 1..Tafsir.SURAH_COUNT) {
                    progress = surah
                    runCatching { Tafsir.downloadSurahBlocking(app, slug, surah) }
                        .onFailure { error ->
                            failure = "$surah: ${error.message}"
                            return@launch
                        }
                    // Gentle pacing for the CDN (same 80 ms as iOS).
                    delay(80)
                }
            } finally {
                downloadingSlug = null
                progress = 0
                noteCacheChanged()
            }
        }
    }
}

/// How much of an edition a search could actually see.
///
/// This exists because the honest answer matters more than the feature:
/// tafsir and غريب القرآن are cached per surah, so a search over them is a
/// search over a DOWNLOADED SUBSET. Every screen that searches an edition
/// shows this, so "no result" can never be mistaken for "no such word".
data class TafsirCoverage(
    val searchedSurahs: Int,
    val entries: Int,
    val budgetReached: Boolean = false,
) {
    val isComplete: Boolean
        get() = searchedSurahs >= Tafsir.SURAH_COUNT && !budgetReached

    /// The line the user reads. Built here rather than purely in the string
    /// file because the digits must be Arabic-Indic in the Arabic interface,
    /// the same rule the surah rows and the matn footer follow.
    fun summary(context: Context): String = if (isComplete) {
        context.getString(R.string.tafsir_coverage_complete,
                          Tafsir.SURAH_COUNT.localizedDigits())
    } else {
        context.getString(R.string.tafsir_coverage_partial,
                          searchedSurahs.localizedDigits(),
                          Tafsir.SURAH_COUNT.localizedDigits())
    }
}

/// Search over the tafsir already cached on this device — the same per-ayah
/// cache `Tafsir.load` / `Tafsir.loadSurah` fill. It NEVER fetches: an
/// offline-first app must not turn a keystroke into a network request, so
/// the corpus is exactly what has been downloaded and the UI says how much
/// that is (`coverage`). Widening it is the user's explicit choice, through
/// the one existing pack download.
///
/// Matching and ranking are `SearchText`, the app's single Arabic matcher.
class TafsirSearchIndex private constructor(
    val slug: String,
    private val docs: List<Doc>,
    val coverage: TafsirCoverage,
) {
    class Doc(val surah: Int, val ayah: Int, val text: String, val norm: String)

    data class Hit(val surah: Int, val ayah: Int, val text: String, val tier: Int)

    fun search(query: String, limit: Int = 100): List<Hit> {
        val normalized = SearchText.normalizeForSearch(query.trim())
        if (normalized.isEmpty()) return emptyList()
        // Cheap containment filter over pre-folded text first; the ranking
        // tier is only computed for the documents that actually matched.
        return docs.asSequence()
            .filter { it.norm.contains(normalized) }
            .map { Hit(it.surah, it.ayah, it.text, SearchText.matchTier(it.text, normalized)) }
            .sortedWith(compareBy({ it.tier }, { it.surah }, { it.ayah }))
            .take(limit)
            .toList()
    }

    /// Total matches ignoring the display cap — so a capped list can say how
    /// many it is not showing rather than dropping them silently.
    fun matchCount(query: String): Int {
        val normalized = SearchText.normalizeForSearch(query.trim())
        if (normalized.isEmpty()) return 0
        return docs.count { it.norm.contains(normalized) }
    }

    companion object {
        /// Folded characters kept in memory. Only a very large commentary
        /// (Tabari, Qurtubi) can reach it, and when it does
        /// `coverage.budgetReached` makes the shortfall visible instead of
        /// silently searching part of the edition.
        const val SCALAR_BUDGET = 6_000_000

        fun empty(slug: String) =
            TafsirSearchIndex(slug, emptyList(), TafsirCoverage(0, 0))

        /// Reads every fully-cached surah of the edition and folds it once.
        /// Hundreds of small files and megabytes of Arabic prose — callers
        /// run this on Dispatchers.IO, never in composition.
        fun build(context: Context, slug: String, budget: Int = SCALAR_BUDGET): TafsirSearchIndex {
            val docs = ArrayList<Doc>()
            var surahs = 0
            var scalars = 0
            var budgetReached = false
            for (surah in Tafsir.cachedSurahNumbers(context, slug)) {
                val entries = Tafsir.cachedSurah(context, slug, surah)
                val folded = entries.map {
                    Doc(surah, it.ayah, it.text, SearchText.normalizeForSearch(it.text))
                }
                val cost = folded.sumOf { it.norm.length }
                if (scalars + cost > budget) {
                    budgetReached = true
                    break
                }
                scalars += cost
                docs.addAll(folded)
                surahs++
            }
            return TafsirSearchIndex(
                slug, docs, TafsirCoverage(surahs, docs.size, budgetReached))
        }
    }
}

/// THE offline-pack control: download state for one edition with its
/// progress. The browser, the Learn search and (through `TafsirPacks`) any
/// future caller show the same row and go through the same download — there
/// is exactly one download path.
@Composable
fun TafsirPackRow(slug: String, forSearch: Boolean = false, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val downloading = TafsirPacks.downloadingSlug == slug
    val failure = TafsirPacks.failure
    val cacheVersion = TafsirPacks.cacheVersion
    val done by produceState(false, slug, cacheVersion, downloading) {
        value = withContext(Dispatchers.IO) { Tafsir.isPackDownloaded(context, slug) }
    }
    Column(modifier.fillMaxWidth()) {
        when {
            downloading -> {
                Text(
                    stringResource(R.string.tafsir_downloading_progress,
                                   TafsirPacks.progress.localizedDigits(),
                                   Tafsir.SURAH_COUNT.localizedDigits()),
                    fontSize = 12.sp, color = NoorColor.inkSecondary)
                LinearProgressIndicator(
                    progress = { TafsirPacks.progress / Tafsir.SURAH_COUNT.toFloat() },
                    color = NoorColor.accentPrimary,
                    trackColor = NoorColor.bgElevated,
                    modifier = Modifier.fillMaxWidth().padding(top = 6.dp))
            }
            done -> OfflineBadge()
            failure != null && TafsirPacks.downloadingSlug == null -> Text(
                failure, fontSize = 12.sp, color = NoorColor.inkSecondary)
            else -> Text(
                if (forSearch)
                    stringResource(R.string.tafsir_download_for_search,
                                   Tafsir.SURAH_COUNT.localizedDigits())
                else stringResource(R.string.tafsir_download_offline),
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = NoorColor.accentPrimary,
                modifier = Modifier
                    .clip(RoundedCornerShape(10.dp))
                    .clickable { TafsirPacks.download(context, slug) }
                    .padding(horizontal = 10.dp, vertical = 14.dp))
        }
    }
}

@Composable
private fun OfflineBadge() {
    Row(verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Icon(painterResource(R.drawable.ic_check), contentDescription = null,
             tint = NoorColor.accentPrimary, modifier = Modifier.size(14.dp))
        Text(stringResource(R.string.tafsir_available_offline),
             fontSize = 12.sp, color = NoorColor.accentPrimary)
    }
}

/// Browse tafsir by surah — until now tafsir was reachable only by tapping a
/// single ayah in the reader, which is no way to read a surah through.
///
/// It adds NO network path and NO cache of its own: everything goes through
/// `Tafsir.loadSurah`, which reads the same per-ayah cache the ayah sheet
/// fills and, when a surah is missing, fetches the same per-surah bundle the
/// pack download uses.
///
/// - `fixedSlug` null → the tafsir browser: the edition is the user's,
///   chosen here and remembered in the same `tafsir.edition` pref the ayah
///   sheet uses. Non-null → a single-purpose entry (the hub's word
///   meanings), which never shows a picker and never touches that pref.
@Composable
fun TafsirBrowserScreen(
    onBack: () -> Unit,
    fixedSlug: String? = null,
    initialSurah: Int = 0,
    initialAyah: Int = 0,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val prefs = remember { KhatmahPlan.prefs(context) }
    var version by remember { mutableIntStateOf(0) }
    val chosenSlug = remember(version) {
        prefs.getString("tafsir.edition", Tafsir.editions[0].slug) ?: Tafsir.editions[0].slug
    }
    val slug = fixedSlug ?: chosenSlug
    val edition = Tafsir.named(slug)
    val isWordMeanings = fixedSlug != null

    // Deep link from the hub's search: open straight at one ayah.
    var openSurah by rememberSaveable(initialSurah) { mutableStateOf(initialSurah) }
    var openAyah by rememberSaveable(initialSurah, initialAyah) { mutableStateOf(initialAyah) }
    var searchText by rememberSaveable { mutableStateOf("") }

    androidx.activity.compose.BackHandler(enabled = openSurah > 0 || searchText.isNotEmpty()) {
        if (openSurah > 0) { openSurah = 0; openAyah = 0 } else searchText = ""
    }

    if (openSurah > 0) {
        TafsirSurahScreen(
            slug = slug,
            surahId = openSurah,
            isWordMeanings = isWordMeanings,
            highlightAyah = openAyah,
            onBack = { openSurah = 0; openAyah = 0 },
            modifier = modifier)
        return
    }

    val surahs = remember { QuranDb.get(context).surahs() }
    val query = searchText.trim()
    val isSearching = query.isNotEmpty()
    val normalizedQuery = remember(query) { SearchText.normalizeForSearch(query) }

    // Rebuilt when the edition changes and after a pack download lands, so
    // the coverage line and the corpus never lag behind the cache. Reading
    // and folding a whole edition is megabytes of prose — never on main.
    val index by produceState<TafsirSearchIndex?>(null, slug, TafsirPacks.cacheVersion) {
        value = null
        value = withContext(Dispatchers.IO) { TafsirSearchIndex.build(context, slug) }
    }
    val results by produceState(emptyList<TafsirSearchIndex.Hit>(), query, index) {
        val built = index
        value = if (!isSearching || built == null) emptyList() else {
            delay(200)  // debounced exactly as the Quran search is
            withContext(Dispatchers.Default) { built.search(query, limit = 100) }
        }
    }

    Column(modifier.fillMaxSize()) {
        LearnHeader(
            title = if (isWordMeanings) stringResource(R.string.learn_gharib_title)
                    else stringResource(R.string.tafsir_browse_title),
            onBack = onBack)
        NoorSearchField(
            value = searchText,
            onValueChange = { searchText = it },
            hint = if (isWordMeanings) stringResource(R.string.gharib_search_hint)
                   else stringResource(R.string.tafsir_search_hint),
            modifier = Modifier.padding(horizontal = 16.dp))

        LazyColumn(Modifier.fillMaxSize()) {
            if (isSearching) {
                // ABOVE the results on purpose: partial coverage is not a
                // footnote, it is the difference between "this word is not in
                // the book" and "you have not downloaded that surah yet".
                item(key = "coverage") {
                    Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp)) {
                        val coverage = index?.coverage
                        if (coverage == null) {
                            Text(stringResource(R.string.tafsir_preparing),
                                 fontSize = 12.sp, color = NoorColor.inkSecondary)
                        } else {
                            Text(coverage.summary(context),
                                 fontSize = 12.sp,
                                 color = if (coverage.isComplete) NoorColor.accentPrimary
                                         else NoorColor.inkSecondary)
                            if (!coverage.isComplete) {
                                TafsirPackRow(slug = slug, forSearch = true,
                                              modifier = Modifier.padding(top = 6.dp))
                            }
                        }
                    }
                    HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
                }
                if (results.isNotEmpty()) {
                    item(key = "resultshead") {
                        Row(
                            horizontalArrangement = Arrangement.SpaceBetween,
                            modifier = Modifier.fillMaxWidth()
                                .padding(horizontal = 20.dp, vertical = 10.dp)
                        ) {
                            Text(stringResource(R.string.tafsir_results), fontSize = 13.sp,
                                 fontWeight = FontWeight.SemiBold, color = NoorColor.inkSecondary)
                            Text(results.size.localizedDigits(), fontSize = 13.sp,
                                 color = NoorColor.inkSecondary)
                        }
                    }
                }
                if (results.isEmpty() && index != null) {
                    item(key = "nohits") {
                        Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 16.dp)) {
                            Text(stringResource(R.string.tafsir_no_matches),
                                 fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                                 color = NoorColor.inkPrimary)
                            // Never let "nothing found" imply "nothing exists".
                            if (index?.coverage?.isComplete == false) {
                                Text(stringResource(R.string.tafsir_no_matches_partial),
                                     fontSize = 12.sp, lineHeight = 18.sp,
                                     color = NoorColor.inkSecondary,
                                     modifier = Modifier.padding(top = 4.dp))
                            }
                        }
                    }
                }
                items(results, key = { "${it.surah}:${it.ayah}" }) { hit ->
                    val name = surahs.firstOrNull { it.id == hit.surah }?.displayName() ?: ""
                    SearchHitRow(
                        text = hit.text,
                        normalizedQuery = normalizedQuery,
                        reference = if (isArabicLocale())
                            "‏$name · ${hit.surah.localizedDigits()}:${hit.ayah.localizedDigits()}"
                        else "$name · ${hit.surah}:${hit.ayah}",
                        isArabic = edition.isArabic,
                        onClick = { openSurah = hit.surah; openAyah = hit.ayah })
                }
            } else {
                if (!isWordMeanings) {
                    item(key = "editions") {
                        Column(Modifier.padding(top = 12.dp)) {
                            Text(stringResource(R.string.tafsir_edition),
                                 fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                                 color = NoorColor.inkSecondary,
                                 modifier = Modifier.padding(horizontal = 20.dp, vertical = 6.dp))
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                                modifier = Modifier
                                    .horizontalScroll(rememberScrollState())
                                    .padding(horizontal = 20.dp)
                            ) {
                                Tafsir.editions.forEach { candidate ->
                                    val on = candidate.slug == slug
                                    Text(
                                        candidate.displayName,
                                        fontSize = 13.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        maxLines = 1,
                                        color = if (on) NoorColor.bgPrimary else NoorColor.accentPrimary,
                                        modifier = Modifier
                                            .clip(RoundedCornerShape(50))
                                            .background(
                                                if (on) NoorColor.accentPrimary
                                                else NoorColor.accentPrimary.copy(alpha = 0.1f),
                                                RoundedCornerShape(50))
                                            .clickable {
                                                prefs.edit()
                                                    .putString("tafsir.edition", candidate.slug)
                                                    .apply()
                                                version++
                                            }
                                            .padding(horizontal = 14.dp, vertical = 10.dp))
                                }
                            }
                            Text(stringResource(R.string.tafsir_edition_footer),
                                 fontSize = 12.sp, lineHeight = 18.sp,
                                 color = NoorColor.inkSecondary,
                                 modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp))
                            TafsirPackRow(slug = slug,
                                          modifier = Modifier.padding(horizontal = 12.dp))
                        }
                    }
                }
                item(key = "surahheader") {
                    Text(stringResource(R.string.tafsir_choose_surah),
                         fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                         color = NoorColor.inkSecondary,
                         modifier = Modifier.padding(horizontal = 20.dp, vertical = 10.dp))
                }
                items(surahs, key = { it.id }) { surah ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { openSurah = surah.id; openAyah = 0 }
                            .padding(horizontal = 20.dp, vertical = 12.dp)
                    ) {
                        Box(
                            contentAlignment = Alignment.Center,
                            modifier = Modifier.size(34.dp)
                                .clip(CircleShape)
                                .background(NoorColor.accentGold.copy(alpha = 0.12f))
                        ) {
                            Text(surah.id.localizedDigits(), fontSize = 13.sp,
                                 color = NoorColor.accentGold)
                        }
                        Column(Modifier.padding(horizontal = 14.dp).weight(1f)) {
                            Text(surah.displayName(), fontSize = 16.sp,
                                 fontWeight = FontWeight.SemiBold, color = NoorColor.inkPrimary)
                            Text(stringResource(R.string.tafsir_ayat_n,
                                                surah.ayahCount.localizedDigits()),
                                 fontSize = 12.sp, color = NoorColor.inkSecondary)
                        }
                    }
                    HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
                }
            }
            item(key = "tail") { Spacer(Modifier.height(28.dp)) }
        }
    }
}

/// One surah's tafsir, ayah after ayah, as a continuous screen.
@Composable
fun TafsirSurahScreen(
    slug: String,
    surahId: Int,
    isWordMeanings: Boolean,
    highlightAyah: Int,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val edition = Tafsir.named(slug)
    val surah = remember(surahId) { QuranDb.get(context).surahs().firstOrNull { it.id == surahId } }
    var searchText by rememberSaveable { mutableStateOf("") }
    androidx.activity.compose.BackHandler(enabled = searchText.isNotEmpty()) { searchText = "" }

    val state by produceState<Result<List<Tafsir.Entry>>?>(null, slug, surahId) {
        value = null
        value = Tafsir.loadSurah(context, slug, surahId)
    }
    val entries = state?.getOrNull().orEmpty()
    val query = searchText.trim()
    val normalizedQuery = remember(query) { SearchText.normalizeForSearch(query) }
    // The whole surah is on the device here, so there is no coverage caveat
    // — that belongs to the edition-wide search above.
    val matches = remember(entries, normalizedQuery) {
        if (normalizedQuery.isEmpty()) emptyList()
        else entries.filter { SearchText.contains(it.text, normalizedQuery) }
    }
    val listState = rememberLazyListState()
    var flashed by remember { mutableStateOf(0) }
    var scrollTarget by remember { mutableStateOf(highlightAyah) }
    LaunchedEffect(entries, scrollTarget) {
        val target = scrollTarget
        if (target <= 0 || entries.isEmpty()) return@LaunchedEffect
        val index = entries.indexOfFirst { it.ayah == target }
        if (index >= 0) {
            flashed = target
            // +1 for the header item.
            listState.animateScrollToItem(index + 1)
        }
        scrollTarget = 0
    }

    Column(modifier.fillMaxSize()) {
        LearnHeader(title = surah?.displayName() ?: "", onBack = onBack)
        NoorSearchField(
            value = searchText,
            onValueChange = { searchText = it },
            hint = stringResource(R.string.tafsir_surah_search_hint),
            modifier = Modifier.padding(horizontal = 16.dp))

        when {
            state == null -> LoadingBlock(
                stringResource(R.string.tafsir_downloading_surah),
                stringResource(R.string.tafsir_downloading_surah_sub))
            state?.isFailure == true -> Text(
                stringResource(R.string.tafsir_unavailable),
                fontSize = 14.sp, color = NoorColor.inkSecondary,
                modifier = Modifier.fillMaxWidth().padding(28.dp))
            entries.isEmpty() -> Text(
                stringResource(R.string.tafsir_empty_surah),
                fontSize = 14.sp, color = NoorColor.inkSecondary,
                modifier = Modifier.fillMaxWidth().padding(28.dp))
            query.isNotEmpty() -> LazyColumn(Modifier.fillMaxSize()) {
                if (matches.isEmpty()) {
                    item {
                        Text(stringResource(R.string.tafsir_no_match_surah),
                             fontSize = 13.sp, color = NoorColor.inkSecondary,
                             modifier = Modifier.fillMaxWidth().padding(20.dp))
                    }
                } else {
                    item {
                        Text(stringResource(R.string.tafsir_ayat_count,
                                            matches.size.localizedDigits(),
                                            entries.size.localizedDigits()),
                             fontSize = 12.sp, color = NoorColor.inkSecondary,
                             modifier = Modifier.padding(horizontal = 20.dp, vertical = 10.dp))
                    }
                    items(matches, key = { it.ayah }) { entry ->
                        SearchHitRow(
                            text = entry.text,
                            normalizedQuery = normalizedQuery,
                            reference = if (isArabicLocale())
                                "‏${surahId.localizedDigits()}:${entry.ayah.localizedDigits()}"
                            else "$surahId:${entry.ayah}",
                            isArabic = edition.isArabic,
                            onClick = { searchText = ""; scrollTarget = entry.ayah })
                    }
                }
            }
            else -> LazyColumn(state = listState, modifier = Modifier.fillMaxSize()) {
                item(key = "head") {
                    if (isWordMeanings) {
                        Text(stringResource(R.string.tafsir_gharib_note),
                             fontSize = 12.sp, lineHeight = 18.sp,
                             color = NoorColor.inkSecondary,
                             modifier = Modifier.padding(horizontal = 20.dp, vertical = 10.dp))
                    } else {
                        Spacer(Modifier.height(6.dp))
                    }
                }
                items(entries, key = { it.ayah }) { entry ->
                    Column(
                        Modifier
                            .fillMaxWidth()
                            .background(
                                if (flashed == entry.ayah)
                                    NoorColor.accentPrimary.copy(alpha = 0.10f)
                                else NoorColor.bgPrimary)
                            .padding(horizontal = 20.dp, vertical = 10.dp)
                    ) {
                        Text("${surahId.localizedDigits()}:${entry.ayah.localizedDigits()}",
                             fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                             color = NoorColor.accentGold)
                        TafsirParagraphs(entry.text, edition.isArabic)
                    }
                    HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
                }
                item(key = "foot") {
                    Column(Modifier.fillMaxWidth().padding(20.dp),
                           horizontalAlignment = Alignment.CenterHorizontally) {
                        OfflineBadge()
                        Text("${edition.displayName} · ${entries.size.localizedDigits()}",
                             fontSize = 12.sp, color = NoorColor.inkSecondary,
                             modifier = Modifier.padding(top = 4.dp))
                    }
                }
            }
        }
    }
}

/// One Text per paragraph: a single multi-thousand-character Arabic string
/// hits a layout path that drops shaping (seen on both platforms).
@Composable
private fun TafsirParagraphs(text: String, isArabic: Boolean) {
    val paragraphs = remember(text) {
        text.split("\n").map { it.trim() }.filter { it.isNotEmpty() }.ifEmpty { listOf(text) }
    }
    CompositionLocalProvider(
        LocalLayoutDirection provides
            if (isArabic) LayoutDirection.Rtl else LayoutDirection.Ltr
    ) {
        Column(Modifier.fillMaxWidth().padding(top = 6.dp)) {
            paragraphs.forEach { paragraph ->
                Text(
                    paragraph,
                    fontSize = if (isArabic) 17.sp else 15.sp,
                    lineHeight = if (isArabic) 32.sp else 24.sp,
                    color = NoorColor.inkPrimary,
                    style = if (isArabic) arabicText() else androidx.compose.ui.text.TextStyle.Default,
                    modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp))
            }
        }
    }
}

@Composable
private fun LoadingBlock(title: String, subtitle: String) {
    Column(
        Modifier.fillMaxWidth().padding(top = 48.dp, start = 24.dp, end = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        CircularProgressIndicator(color = NoorColor.accentPrimary)
        Text(title, fontSize = 13.sp, color = NoorColor.inkSecondary,
             modifier = Modifier.padding(top = 14.dp))
        Text(subtitle, fontSize = 12.sp, lineHeight = 18.sp, color = NoorColor.inkSecondary,
             modifier = Modifier.padding(top = 6.dp))
    }
}
