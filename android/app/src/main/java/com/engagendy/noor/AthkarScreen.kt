package com.engagendy.noor

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.res.painterResource
import android.widget.Toast
import kotlinx.coroutines.launch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import org.json.JSONArray

/// `audio`: Hisn al-Muslim recording of this dhikr alone (see AthkarAudio).
data class Dhikr(val text: String, val count: Int, val audio: String? = null)
/// `chapterAudio`: one recording of the whole chapter.
data class DhikrCategory(
    val title: String,
    val titleEn: String?,
    val items: List<Dhikr>,
    val chapterAudio: String? = null,
) {
    /// Arabic title is the data key (deep links match on it); English UI shows
    /// the translated chapter name, falling back to Arabic if a row lacks one.
    @Composable fun displayTitle(): String = if (isArabicUi()) title else (titleEn ?: title)
}

object AthkarStore {
    fun load(context: Context): List<DhikrCategory> {
        val raw = context.assets.open("athkar.json").bufferedReader().readText()
        val array = JSONArray(raw)
        return buildList {
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                val itemsJson = obj.getJSONArray("items")
                val items = buildList {
                    for (j in 0 until itemsJson.length()) {
                        val item = itemsJson.getJSONObject(j)
                        add(Dhikr(item.getString("text"), item.optInt("count", 1),
                                  item.optString("audio", "").ifBlank { null }))
                    }
                }
                add(DhikrCategory(obj.getString("category"), obj.optString("category_en", "").ifBlank { null }, items,
                                  obj.optString("chapter_audio", "").ifBlank { null }))
            }
        }
    }
}

/// One dhikr matching a search, with where it lives.
data class DhikrHit(val category: DhikrCategory, val itemIndex: Int, val text: String)

/// Athkar search results: chapters whose (Arabic or English) name matched,
/// then individual athkar whose text matched.
data class AthkarResults(
    val categories: List<DhikrCategory> = emptyList(),
    val items: List<DhikrHit> = emptyList(),
) {
    val isEmpty: Boolean get() = categories.isEmpty() && items.isEmpty()
}

/// Diacritic-insensitive (Arabic) / case-insensitive (English) search over
/// the chapter names and every dhikr's text — the athkar data carries no
/// reference/source field, so text is the whole searchable body. Pure and
/// off-main: called from a background dispatcher.
internal fun searchAthkar(categories: List<DhikrCategory>, query: String): AthkarResults {
    val needle = SearchText.normalizeForSearch(query.trim())
    if (needle.length < 2) return AthkarResults()
    val cats = categories.filter {
        SearchText.contains(it.title, needle) ||
            (it.titleEn != null && SearchText.contains(it.titleEn, needle))
    }
    val items = buildList {
        categories.forEach { category ->
            category.items.forEachIndexed { index, dhikr ->
                if (SearchText.contains(dhikr.text, needle)) {
                    add(DhikrHit(category, index, dhikr.text))
                }
            }
        }
    }
    return AthkarResults(cats, items)
}

/// Extra athkar tools — parity with the iOS Athkar module screens.
enum class AthkarExtra(val titleRes: Int) {
    RUQYAH(R.string.g2_ruqyah),
    DUAS(R.string.g2_selected_duas),
    NAMES(R.string.g2_names_of_allah),
    TASBIH(R.string.g2_tasbih),
}

/// `openCategoryTitle` + `openSerial`: a deep link (notification tap) into
/// one category — keyed on the serial, not the title, so a second tap on
/// the same category re-opens it after the reader backed out.
@Composable
fun AthkarScreen(
    modifier: Modifier = Modifier,
    openCategoryTitle: String? = null,
    openSerial: Int = 0,
    onOpenConsumed: () -> Unit = {},
) {
    val context = LocalContext.current
    val categories = remember { AthkarStore.load(context) }
    var open by remember { mutableStateOf<DhikrCategory?>(null) }
    var extra by remember { mutableStateOf<AthkarExtra?>(null) }
    var searchText by remember { mutableStateOf("") }
    // Item to scroll to + highlight when a category is opened from a dhikr
    // hit; the serial re-triggers it for a repeated tap on the same row.
    var targetItem by remember { mutableStateOf(-1) }
    var targetSerial by remember { mutableStateOf(0) }
    fun openCategory(category: DhikrCategory, itemIndex: Int = -1) {
        targetItem = itemIndex
        targetSerial++
        open = category
    }
    androidx.compose.runtime.LaunchedEffect(openSerial) {
        if (openSerial == 0 || openCategoryTitle == null) return@LaunchedEffect
        categories.firstOrNull { it.title == openCategoryTitle }?.let {
            extra = null
            openCategory(it)
        }
        // Consumed: a later visit to the tab must not re-open it.
        onOpenConsumed()
    }

    // System back closes the open tool/category, same as its back button.
    androidx.activity.compose.BackHandler(
        enabled = extra != null || open != null || searchText.isNotEmpty()
    ) {
        if (extra != null) extra = null
        else if (open != null) open = null
        else searchText = ""
    }

    when (extra) {
        AthkarExtra.RUQYAH -> { RuqyahScreen(onBack = { extra = null }, modifier); return }
        AthkarExtra.DUAS -> { SelectedDuasScreen(onBack = { extra = null }, modifier); return }
        AthkarExtra.NAMES -> { AsmaulHusnaScreen(onBack = { extra = null }, modifier); return }
        AthkarExtra.TASBIH -> { TasbihScreen(onBack = { extra = null }, modifier); return }
        null -> Unit
    }

    val current = open
    if (current != null) {
        DhikrListScreen(current, onBack = { open = null }, modifier = modifier,
                        scrollToIndex = targetItem, scrollSerial = targetSerial)
        return
    }

    // Search runs off-main, debounced, and re-runs only when the query
    // settles (produceState cancels the previous pass on each keystroke).
    val query = searchText.trim()
    val normalizedQuery = remember(query) { SearchText.normalizeForSearch(query) }
    val results by produceState(AthkarResults(), query, categories) {
        value = if (query.length >= 2) {
            delay(180)
            withContext(Dispatchers.Default) { searchAthkar(categories, query) }
        } else AthkarResults()
    }
    val searching = query.length >= 2
    LazyColumn(modifier.fillMaxSize()) {
        item {
            Text(stringResource(R.string.g2_athkar_title), fontSize = 28.sp, fontWeight = FontWeight.Bold,
                 color = NoorColor.inkPrimary,
                 modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp))
        }
        item {
            NoorSearchField(
                value = searchText,
                onValueChange = { searchText = it },
                hint = stringResource(R.string.g2_search_athkar_hint),
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 2.dp),
            )
        }
        if (!searching) {
            item {
                // Two-per-row cards for the extra tools.
                AthkarExtra.entries.chunked(2).forEach { pair ->
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 5.dp)
                    ) {
                        pair.forEach { item ->
                            Text(
                                stringResource(item.titleRes),
                                fontSize = 15.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = NoorColor.accentPrimary,
                                modifier = Modifier
                                    .weight(1f)
                                    .clip(RoundedCornerShape(14.dp))
                                    .background(NoorColor.stateReciting, RoundedCornerShape(14.dp))
                                    .clickable { extra = item }
                                    .padding(horizontal = 14.dp, vertical = 16.dp)
                            )
                        }
                    }
                }
            }
            items(categories, key = { "c${it.title}" }) { category ->
                CategoryRow(category) { openCategory(category) }
            }
        } else {
            if (results.categories.isNotEmpty()) {
                item(key = "catsHeader") { SearchSectionHeader(stringResource(R.string.g2_search_chapters)) }
                items(results.categories, key = { "rc${it.title}" }) { category ->
                    CategoryRow(category) { openCategory(category) }
                }
            }
            if (results.items.isNotEmpty()) {
                item(key = "itemsHeader") { SearchSectionHeader(stringResource(R.string.g2_search_athkar_results)) }
                items(results.items, key = { "ri${it.category.title}#${it.itemIndex}" }) { hit ->
                    Column(
                        Modifier
                            .fillMaxWidth()
                            .clickable { openCategory(hit.category, hit.itemIndex) }
                            .padding(horizontal = 20.dp, vertical = 10.dp)
                    ) {
                        Text(
                            // Snippet around the match, matched term emphasised.
                            searchSnippet(hit.text, normalizedQuery),
                            fontSize = 16.sp,
                            lineHeight = 26.sp,
                            maxLines = 2,
                            overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
                            color = NoorColor.inkPrimary,
                            style = arabicText(),
                            modifier = Modifier.fillMaxWidth()
                        )
                        Text(
                            hit.category.displayTitle(),
                            fontSize = 12.sp,
                            color = NoorColor.inkSecondary,
                            modifier = Modifier.padding(top = 4.dp)
                        )
                    }
                    HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
                }
            }
            if (results.isEmpty) {
                item(key = "empty") {
                    Text(
                        stringResource(R.string.g2_search_no_results),
                        fontSize = 15.sp,
                        color = NoorColor.inkSecondary,
                        modifier = Modifier.fillMaxWidth().padding(24.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun SearchSectionHeader(label: String) {
    Text(label, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
         color = NoorColor.inkSecondary,
         modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp))
}

@Composable
private fun CategoryRow(category: DhikrCategory, onClick: () -> Unit) {
    Row(
        horizontalArrangement = Arrangement.SpaceBetween,
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 20.dp, vertical = 14.dp)
    ) {
        Text(category.displayTitle(), fontSize = 16.sp, color = NoorColor.inkPrimary)
        Text(category.items.size.localizedDigits(), fontSize = 13.sp,
             color = NoorColor.inkSecondary)
    }
    HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
}

/// [textScale] enlarges the dhikr text (kids mode passes its age band's
/// scale); [showShare] hides the share button where sharing must not be
/// reachable (kids mode).
@Composable
fun DhikrListScreen(
    category: DhikrCategory,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    textScale: Float = 1f,
    showShare: Boolean = true,
    /// Arrived from a search hit: scroll to this item and flash it.
    scrollToIndex: Int = -1,
    scrollSerial: Int = 0,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val progress = remember { mutableStateMapOf<Int, Int>() }
    // Per-card offline caption, keyed like nowPlayingId; cleared on retry.
    val failed = remember { mutableStateMapOf<String, Boolean>() }
    // Leaving the chapter silences it — the recording belongs to this screen.
    DisposableEffect(Unit) { onDispose { AthkarPlayer.stop() } }
    val listState = rememberLazyListState()
    // Share affordances. Both the picker sheet's state and the video flow it
    // starts live HERE, above the sheet: DhikrShareSheet dismisses itself
    // before firing its action (same rule as AyahActionsSheet).
    var sharing by remember { mutableStateOf(-1) }
    val videoShare = rememberShareVideoShare(scope)
    // Search landing: scroll the matched dhikr into view and tint it briefly
    // so the user can see WHICH item matched.
    var highlighted by remember { mutableStateOf(-1) }
    androidx.compose.runtime.LaunchedEffect(scrollSerial, scrollToIndex) {
        if (scrollToIndex !in category.items.indices) return@LaunchedEffect
        val offset = if (category.chapterAudio != null) 1 else 0
        listState.animateScrollToItem(scrollToIndex + offset)
        highlighted = scrollToIndex
        delay(2500)
        highlighted = -1
    }

    // Download (or reuse the cached file) then play; a tap on the playing
    // card toggles pause/resume instead.
    fun playOrToggle(id: String, file: String) {
        if (AthkarPlayer.nowPlayingId == id) {
            if (!AthkarPlayer.isLoading) AthkarPlayer.toggle()
            return
        }
        failed.remove(id)
        AthkarPlayer.beginLoading(context, id)
        scope.launch {
            val local = AthkarAudio.ensureLocal(context, file)
            if (AthkarPlayer.nowPlayingId != id) return@launch  // superseded
            if (local == null) {
                AthkarPlayer.cancelLoading(id)
                failed[id] = true
            } else if (!AthkarPlayer.play(context, local, id)) {
                Toast.makeText(context, R.string.feat_athkar_audio_failed, Toast.LENGTH_SHORT).show()
            }
        }
    }

    Column(modifier.fillMaxSize()) {
        Row(
            horizontalArrangement = Arrangement.SpaceBetween,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp)
        ) {
            Text(category.displayTitle(), fontSize = 18.sp, fontWeight = FontWeight.Bold,
                 color = NoorColor.inkPrimary)
            Text(stringResource(R.string.g2_back), color = NoorColor.accentPrimary, fontWeight = FontWeight.SemiBold,
                 modifier = Modifier.clickable(onClick = onBack).padding(8.dp))
        }
        LazyColumn(state = listState,
                   modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp)) {
            val chapterAudio = category.chapterAudio
            if (chapterAudio != null) {
                item(key = "chapter") {
                    val active = AthkarPlayer.nowPlayingId == CHAPTER_ID
                    val playing = active && AthkarPlayer.isPlaying
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier
                            .padding(top = 2.dp, bottom = 6.dp)
                            .clip(RoundedCornerShape(24.dp))
                            .background(NoorColor.stateReciting, RoundedCornerShape(24.dp))
                            .clickable { playOrToggle(CHAPTER_ID, chapterAudio) }
                            .padding(start = 14.dp, end = 18.dp, top = 12.dp, bottom = 12.dp)
                    ) {
                        if (active && AthkarPlayer.isLoading) {
                            CircularProgressIndicator(
                                color = NoorColor.accentPrimary, strokeWidth = 2.dp,
                                modifier = Modifier.size(20.dp))
                        } else {
                            Icon(
                                painterResource(if (playing) R.drawable.ic_pause_fill else R.drawable.ic_play_fill),
                                contentDescription = null,
                                tint = NoorColor.accentPrimary,
                                modifier = Modifier.size(20.dp))
                        }
                        Text(
                            stringResource(if (playing) R.string.feat_athkar_pause_chapter
                                           else R.string.feat_athkar_play_chapter),
                            fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                            color = NoorColor.accentPrimary)
                    }
                    if (failed[CHAPTER_ID] == true) {
                        Text(stringResource(R.string.feat_athkar_audio_offline), fontSize = 12.sp,
                             color = NoorColor.inkSecondary,
                             modifier = Modifier.padding(start = 6.dp, bottom = 4.dp))
                    }
                }
            }
            items(category.items.indices.toList(), key = { "i$it" }) { index ->
                val dhikr = category.items[index]
                val done = progress[index] ?: 0
                val complete = done >= dhikr.count
                val id = index.toString()
                val active = AthkarPlayer.nowPlayingId == id
                val playing = active && AthkarPlayer.isPlaying
                Column(
                    Modifier
                        .fillMaxWidth()
                        .padding(vertical = 6.dp)
                        .clip(RoundedCornerShape(14.dp))
                        .background(
                            when {
                                index == highlighted -> NoorColor.accentGold.copy(alpha = 0.22f)
                                complete || active -> NoorColor.stateReciting
                                else -> NoorColor.bgElevated
                            },
                            RoundedCornerShape(14.dp)
                        )
                        .clickable {
                            if (!complete) progress[index] = done + 1
                        }
                        .padding(16.dp)
                ) {
                    Text(dhikr.text, fontSize = (18f * textScale).sp,
                         lineHeight = (32f * textScale).sp,
                         color = NoorColor.inkPrimary, style = arabicText(),
                         modifier = Modifier.fillMaxWidth())
                    Row(
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
                    ) {
                        Text(
                            if (complete) stringResource(R.string.g2_done)
                            else "${done.localizedDigits()} / ${dhikr.count.localizedDigits()}",
                            fontSize = 13.sp,
                            color = if (complete) NoorColor.accentPrimary else NoorColor.inkSecondary,
                        )
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            val audio = dhikr.audio
                            if (audio != null) {
                                DhikrPlayButton(
                                    playing = playing,
                                    loading = active && AthkarPlayer.isLoading,
                                    onClick = { playOrToggle(id, audio) })
                            }
                            // Branded image card, or the same card as a video
                            // with this dhikr's recitation — like the iOS
                            // AthkarView NoorShareSheet.
                            if (showShare) {
                                ShareIconButton { sharing = index }
                            }
                        }
                    }
                    if (failed[id] == true) {
                        Text(stringResource(R.string.feat_athkar_audio_offline), fontSize = 12.sp,
                             color = NoorColor.inkSecondary,
                             modifier = Modifier.padding(top = 4.dp))
                    }
                }
            }
        }
    }

    if (sharing in category.items.indices) {
        val dhikr = category.items[sharing]
        DhikrShareSheet(
            hasVideo = dhikr.audio != null,
            onShareImage = {
                shareRendered(context, dhikr.text, category.title,
                              attribution = "نور Noor · حصن المسلم")
            },
            onShareVideo = { videoShare.start(dhikr, category.title) },
            onDismiss = { sharing = -1 })
    }
    ShareVideoProgressDialog(videoShare)
}

/// Share picker for one dhikr: the branded card as an image, or as a video
/// with Hamad Al-Duraihim's Hisn al-Muslim recording under it. The video row
/// only appears when this dhikr HAS a recording — never a dead button — and
/// only per-dhikr audio is offered (the chapter recordings run 6+ minutes).
/// Like AyahActionsSheet, each row dismisses the sheet BEFORE acting.
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
private fun DhikrShareSheet(
    hasVideo: Boolean,
    onShareImage: () -> Unit,
    onShareVideo: () -> Unit,
    onDismiss: () -> Unit,
) {
    androidx.compose.material3.ModalBottomSheet(
        onDismissRequest = onDismiss, containerColor = NoorColor.bgPrimary
    ) {
      // The sheet is its own window and does not inherit the app's language
      // (see AyahActionsSheet) — re-provide it or every row falls back to
      // the Arabic default strings in the English UI.
      NoorLocaleProvider {
        Column(
            verticalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .padding(bottom = 32.dp)
        ) {
            ActionRow(stringResource(R.string.feat_share_image), icon = R.drawable.ic_share,
                      prominent = true) { onDismiss(); onShareImage() }
            if (hasVideo) {
                ActionRow(
                    stringResource(R.string.feat_share_video),
                    icon = R.drawable.ic_share,
                    caption = stringResource(R.string.feat_share_video_caption,
                                             stringResource(R.string.feat_dhikr_reciter)),
                ) { onDismiss(); onShareVideo() }
            }
        }
      }
    }
}

private const val CHAPTER_ID = "chapter"

/// 48dp round play/pause target with a clipped ripple; spinner while the
/// recording downloads.
@Composable
private fun DhikrPlayButton(playing: Boolean, loading: Boolean, onClick: () -> Unit) {
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .size(48.dp)
            .clip(CircleShape)
            .clickable(enabled = !loading, onClick = onClick)
    ) {
        if (loading) {
            CircularProgressIndicator(
                color = NoorColor.accentPrimary, strokeWidth = 2.dp,
                modifier = Modifier.size(20.dp))
        } else {
            Icon(
                painterResource(if (playing) R.drawable.ic_pause_fill else R.drawable.ic_play_fill),
                contentDescription = stringResource(if (playing) R.string.feat_athkar_pause
                                                    else R.string.feat_athkar_play),
                tint = NoorColor.accentPrimary,
                modifier = Modifier.size(22.dp))
        }
    }
}
