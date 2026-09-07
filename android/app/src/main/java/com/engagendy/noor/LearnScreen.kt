package com.engagendy.noor

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext

/// The app's learning area: the memorisation matns (classical didactic
/// poems), the tajweed reference guide, tafsir by surah and غريب القرآن —
/// 1:1 with the iOS `Modules/Learn/LearnView` hub.
///
/// Navigation is manual state, as everywhere else in this app.
@Composable
fun LearnScreen(onBack: () -> Unit, modifier: Modifier = Modifier) {
    // "home" | "tajweed" | "tafsir" | "gharib" | "matn:<id>"
    var route by rememberSaveable { mutableStateOf("home") }
    // A search result jumped at: matn line, or a tafsir surah+ayah.
    var jumpLine by rememberSaveable { mutableStateOf(0) }
    var jumpSurah by rememberSaveable { mutableStateOf(0) }
    var jumpAyah by rememberSaveable { mutableStateOf(0) }
    val context = LocalContext.current

    androidx.activity.compose.BackHandler(enabled = route != "home") { route = "home" }

    when {
        route == "tajweed" -> TajweedGuideScreen(onBack = { route = "home" }, modifier = modifier)
        route == "tafsir" || route == "gharib" -> TafsirBrowserScreen(
            onBack = { route = "home" },
            fixedSlug = if (route == "gharib") Tafsir.GHARIB_SLUG else null,
            initialSurah = jumpSurah,
            initialAyah = jumpAyah,
            modifier = modifier)
        route.startsWith("matn:") -> {
            val id = route.removePrefix("matn:")
            val matn by produceState<Matn?>(null, id) {
                value = withContext(Dispatchers.IO) { MatnStore.matn(context, id) }
            }
            matn?.let {
                MatnReaderScreen(matn = it, openAtLine = jumpLine,
                                 onBack = { route = "home" }, modifier = modifier)
            }
        }
        else -> LearnHub(
            onBack = onBack,
            openMatn = { id, line -> jumpLine = line; route = "matn:$id" },
            openTajweed = { route = "tajweed" },
            openTafsir = { surah, ayah, gharib ->
                jumpSurah = surah; jumpAyah = ayah
                route = if (gharib) "gharib" else "tafsir"
            },
            modifier = modifier)
    }
}

/// One result of a hub search, whatever source it came from.
private data class LearnHit(
    val key: String,
    val text: String,
    val reference: String,
    val isArabic: Boolean,
    val matnId: String? = null,
    val line: Int = 0,
    val surah: Int = 0,
    val ayah: Int = 0,
    val gharib: Boolean = false,
)

/// Results from ONE source (a matn, an edition of tafsir), so it is obvious
/// what came from where — and so a per-surah-cached source can carry its
/// coverage caveat next to its own hits.
private data class LearnGroup(
    val key: String,
    val title: String,
    val hits: List<LearnHit>,
    val total: Int,
    /// What this group could actually see, in the user's words. Null when
    /// the source is bundled and therefore complete (the matns).
    val coverage: String? = null,
    val isComplete: Boolean = true,
    /// Edition to offer for download when coverage is partial — the EXISTING
    /// pack download, never a second path.
    val downloadSlug: String? = null,
)

@Composable
private fun LearnHub(
    onBack: () -> Unit,
    openMatn: (String, Int) -> Unit,
    openTajweed: () -> Unit,
    openTafsir: (Int, Int, Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    // Re-derive the groups when the app language flips: their titles and
    // references carry localized digits and localized names.
    val localeKey = NoorLocale.choice
    var searchText by rememberSaveable { mutableStateOf("") }
    androidx.activity.compose.BackHandler(enabled = searchText.isNotEmpty()) { searchText = "" }
    val query = searchText.trim()
    val isSearching = query.isNotEmpty()
    val normalizedQuery = remember(query) { SearchText.normalizeForSearch(query) }

    // Surah names for the tafsir references — the same cached DB the rest of
    // the app reads.
    val surahs = remember { QuranDb.get(context).surahs() }
    val matns by produceState(emptyList<Matn>()) {
        value = withContext(Dispatchers.IO) { MatnStore.load(context) }
    }
    val matnIndexes = remember(matns) { matns.map { it to MatnSearchIndex(it) } }

    // The editions the hub searches: غريب القرآن (the reason this feature
    // exists) and, when it is a different book, the tafsir edition the user
    // reads. Searching all eight would index editions nobody opened.
    val chosenSlug = remember {
        KhatmahPlan.prefs(context).getString("tafsir.edition", Tafsir.editions[0].slug)
            ?: Tafsir.editions[0].slug
    }
    val slugs = remember(chosenSlug) {
        listOf(Tafsir.GHARIB_SLUG) + listOf(chosenSlug).filter { it != Tafsir.GHARIB_SLUG }
    }
    // Reading and folding an edition is megabytes of Arabic prose — off main,
    // and rebuilt when the cache changes so coverage can never go stale.
    // Building the index NEVER fetches: the corpus is what is on the device.
    val indexes by produceState(emptyList<TafsirSearchIndex>(), slugs, TafsirPacks.cacheVersion) {
        value = withContext(Dispatchers.IO) { slugs.map { TafsirSearchIndex.build(context, it) } }
    }

    val groups by produceState(emptyList<LearnGroup>(), query, matnIndexes, indexes, localeKey, surahs) {
        if (!isSearching) { value = emptyList(); return@produceState }
        delay(200)  // debounced like the Quran search: one query per pause
        value = withContext(Dispatchers.Default) {
            val built = ArrayList<LearnGroup>()
            // Matn hits: bundled whole, so these groups are complete and
            // carry no coverage caveat.
            matnIndexes.forEach { (matn, index) ->
                val hits = index.search(query)
                if (hits.isEmpty()) return@forEach
                built.add(LearnGroup(
                    key = "matn.${matn.id}",
                    title = matn.displayTitle(),
                    hits = hits.take(20).map { hit ->
                        LearnHit(
                            key = "${matn.id}#${hit.line.number}",
                            text = hit.text,
                            reference = context.getString(
                                R.string.learn_line_n, hit.line.number.localizedDigits()),
                            isArabic = true,
                            matnId = matn.id,
                            line = hit.line.number)
                    },
                    total = hits.size))
            }
            indexes.forEach { index ->
                val edition = Tafsir.named(index.slug)
                val hits = index.search(query, limit = 12)
                val total = index.matchCount(query)
                // A group with no hits is still worth showing while coverage
                // is partial: the coverage line is the answer to "why
                // nothing?" — and hiding it would hide the caveat.
                if (hits.isEmpty() && index.coverage.isComplete) return@forEach
                val isGharib = index.slug == Tafsir.GHARIB_SLUG
                built.add(LearnGroup(
                    key = "tafsir.${index.slug}",
                    title = context.getString(
                        if (isGharib) R.string.tafsir_group_gharib
                        else R.string.tafsir_group_tafsir,
                        edition.displayName),
                    hits = hits.map { hit ->
                        LearnHit(
                            key = "${index.slug}#${hit.surah}:${hit.ayah}",
                            text = hit.text,
                            // "سورة البقرة · ٢:٢٥٥" — RLM-prefixed so the
                            // mixed line lays out as one right-to-left
                            // paragraph (as the Quran search does).
                            reference = surahs.firstOrNull { it.id == hit.surah }
                                ?.displayName().orEmpty().let { name ->
                                    if (isArabicLocale())
                                        "‏$name · ${hit.surah.localizedDigits()}:${hit.ayah.localizedDigits()}"
                                    else "$name · ${hit.surah}:${hit.ayah}"
                                },
                            isArabic = edition.isArabic,
                            surah = hit.surah,
                            ayah = hit.ayah,
                            gharib = isGharib)
                    },
                    total = total,
                    coverage = index.coverage.summary(context),
                    isComplete = index.coverage.isComplete,
                    downloadSlug = if (index.coverage.isComplete) null else index.slug))
            }
            built
        }
    }

    Column(modifier.fillMaxSize()) {
        LearnHeader(title = stringResource(R.string.learn_title), onBack = onBack)
        NoorSearchField(
            value = searchText,
            onValueChange = { searchText = it },
            hint = stringResource(R.string.learn_search_hint),
            modifier = Modifier.padding(horizontal = 16.dp))

        LazyColumn(Modifier.fillMaxSize()) {
            if (isSearching) {
                if (groups.isEmpty()) {
                    item {
                        Text(stringResource(R.string.learn_no_matches),
                             fontSize = 13.sp, color = NoorColor.inkSecondary,
                             modifier = Modifier.fillMaxWidth().padding(20.dp))
                    }
                }
                groups.forEach { group ->
                    item(key = "h.${group.key}") {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween,
                            modifier = Modifier.fillMaxWidth()
                                .padding(horizontal = 20.dp, vertical = 10.dp)
                        ) {
                            Text(group.title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                                 color = NoorColor.inkSecondary, modifier = Modifier.weight(1f))
                            Text(group.total.localizedDigits(), fontSize = 13.sp,
                                 color = NoorColor.inkSecondary)
                        }
                    }
                    if (group.coverage != null) {
                        item(key = "c.${group.key}") {
                            Column(Modifier.fillMaxWidth()
                                       .padding(horizontal = 20.dp, vertical = 2.dp)) {
                                Text(group.coverage, fontSize = 12.sp, lineHeight = 18.sp,
                                     color = if (group.isComplete) NoorColor.accentPrimary
                                             else NoorColor.inkSecondary)
                                if (group.downloadSlug != null) {
                                    TafsirPackRow(slug = group.downloadSlug, forSearch = true)
                                }
                            }
                        }
                    }
                    items(group.hits, key = { "r.${group.key}.${it.key}" }) { hit ->
                        SearchHitRow(
                            text = hit.text,
                            normalizedQuery = normalizedQuery,
                            reference = hit.reference,
                            isArabic = hit.isArabic,
                            onClick = {
                                if (hit.matnId != null) openMatn(hit.matnId, hit.line)
                                else openTafsir(hit.surah, hit.ayah, hit.gharib)
                            })
                    }
                    // Nothing is dropped silently — the group says how many
                    // it is showing.
                    if (group.total > group.hits.size) {
                        item(key = "m.${group.key}") {
                            Text(stringResource(R.string.learn_showing_of,
                                                group.hits.size.localizedDigits(),
                                                group.total.localizedDigits()),
                                 fontSize = 12.sp, color = NoorColor.inkSecondary,
                                 modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp))
                        }
                    }
                }
            } else {
                item(key = "matnhead") {
                    Text(stringResource(R.string.learn_section_matns),
                         fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                         color = NoorColor.inkSecondary,
                         modifier = Modifier.padding(start = 20.dp, end = 20.dp, top = 14.dp, bottom = 6.dp))
                }
                items(matns, key = { it.id }) { matn ->
                    LearnRow(
                        icon = R.drawable.ic_book,
                        tint = NoorColor.accentPrimary,
                        title = matn.displayTitle(),
                        subtitle = matn.displayAuthor(),
                        detail = stringResource(R.string.learn_lines,
                                                matn.lines.size.localizedDigits()),
                        onClick = { openMatn(matn.id, 0) })
                }
                item(key = "matnfoot") {
                    Text(stringResource(R.string.learn_matns_footer),
                         fontSize = 12.sp, lineHeight = 18.sp, color = NoorColor.inkSecondary,
                         modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp))
                }
                item(key = "refhead") {
                    Text(stringResource(R.string.learn_section_reference),
                         fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                         color = NoorColor.inkSecondary,
                         modifier = Modifier.padding(start = 20.dp, end = 20.dp, top = 16.dp, bottom = 6.dp))
                }
                item(key = "tajweed") {
                    LearnRow(
                        icon = R.drawable.ic_list,
                        tint = NoorColor.accentGold,
                        title = stringResource(R.string.g1_tajweed_guide),
                        subtitle = stringResource(R.string.learn_tajweed_sub),
                        onClick = openTajweed)
                }
                item(key = "tafsir") {
                    LearnRow(
                        icon = R.drawable.ic_page,
                        tint = NoorColor.accentGold,
                        title = stringResource(R.string.learn_tafsir_title),
                        subtitle = stringResource(R.string.learn_tafsir_sub),
                        onClick = { openTafsir(0, 0, false) })
                }
                item(key = "gharib") {
                    LearnRow(
                        icon = R.drawable.ic_translate,
                        tint = NoorColor.accentGold,
                        title = stringResource(R.string.learn_gharib_title),
                        subtitle = stringResource(R.string.learn_gharib_sub),
                        onClick = { openTafsir(0, 0, true) })
                }
            }
            item(key = "tail") { Spacer(Modifier.height(28.dp)) }
        }
    }
}

/// Screen header shared by the Learn screens: title + a back control, in the
/// UI direction (this is chrome, not Arabic content).
@Composable
internal fun LearnHeader(title: String, onBack: () -> Unit) {
    Row(
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp)
    ) {
        Text(title, fontSize = 22.sp, fontWeight = FontWeight.Bold,
             color = NoorColor.inkPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis,
             modifier = Modifier.weight(1f))
        Text(stringResource(R.string.g1_back), fontSize = 16.sp,
             fontWeight = FontWeight.SemiBold, color = NoorColor.accentPrimary,
             modifier = Modifier
                 .clip(RoundedCornerShape(10.dp))
                 .clickable(onClick = onBack)
                 .padding(horizontal = 12.dp, vertical = 12.dp))
    }
}

@Composable
private fun LearnRow(
    icon: Int,
    tint: androidx.compose.ui.graphics.Color,
    title: String,
    subtitle: String,
    detail: String? = null,
    onClick: () -> Unit,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 20.dp, vertical = 12.dp)
    ) {
        Icon(painterResource(icon), contentDescription = null, tint = tint,
             modifier = Modifier.size(22.dp))
        Column(Modifier.padding(horizontal = 14.dp).weight(1f)) {
            Text(title, fontSize = 16.sp, fontWeight = FontWeight.SemiBold,
                 color = NoorColor.inkPrimary)
            Text(subtitle, fontSize = 12.sp, lineHeight = 18.sp, color = NoorColor.inkSecondary)
            if (detail != null) {
                Text(detail, fontSize = 12.sp, color = NoorColor.inkSecondary)
            }
        }
        Icon(painterResource(NoorIcons.chevronForward()), contentDescription = null,
             tint = NoorColor.accentPrimary, modifier = Modifier.size(16.dp))
    }
    HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
}

/// A search-result row: the ORIGINAL text windowed around the match (the
/// shared `searchSnippet`, never edited — only cut), plus where it is from.
/// Arabic content is an RTL block whatever the interface language.
@Composable
internal fun SearchHitRow(
    text: String,
    normalizedQuery: String,
    reference: String,
    isArabic: Boolean,
    onClick: () -> Unit,
) {
    Column(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 20.dp, vertical = 10.dp)
    ) {
        if (isArabic) {
            ArabicBlock {
                Text(searchSnippet(text, normalizedQuery),
                     fontSize = 16.sp, lineHeight = 28.sp, maxLines = 3,
                     overflow = TextOverflow.Ellipsis, color = NoorColor.inkPrimary,
                     style = arabicText(), modifier = Modifier.fillMaxWidth())
                Text(reference, fontSize = 12.sp, color = NoorColor.inkSecondary,
                     style = arabicText(), modifier = Modifier.fillMaxWidth().padding(top = 4.dp))
            }
        } else {
            Text(searchSnippet(text, normalizedQuery),
                 fontSize = 15.sp, lineHeight = 22.sp, maxLines = 3,
                 overflow = TextOverflow.Ellipsis, color = NoorColor.inkPrimary,
                 modifier = Modifier.fillMaxWidth())
            Text(reference, fontSize = 12.sp, color = NoorColor.inkSecondary,
                 modifier = Modifier.padding(top = 4.dp))
        }
    }
    HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
}
