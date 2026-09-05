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
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
    androidx.compose.runtime.LaunchedEffect(openSerial) {
        if (openSerial == 0 || openCategoryTitle == null) return@LaunchedEffect
        categories.firstOrNull { it.title == openCategoryTitle }?.let {
            extra = null
            open = it
        }
        // Consumed: a later visit to the tab must not re-open it.
        onOpenConsumed()
    }

    // System back closes the open tool/category, same as its back button.
    androidx.activity.compose.BackHandler(enabled = extra != null || open != null) {
        if (extra != null) extra = null else open = null
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
        DhikrListScreen(current, onBack = { open = null }, modifier = modifier)
        return
    }
    LazyColumn(modifier.fillMaxSize()) {
        item {
            Text(stringResource(R.string.g2_athkar_title), fontSize = 28.sp, fontWeight = FontWeight.Bold,
                 color = NoorColor.inkPrimary,
                 modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp))
        }
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
        items(categories) { category ->
            Row(
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { open = category }
                    .padding(horizontal = 20.dp, vertical = 14.dp)
            ) {
                Text(category.displayTitle(), fontSize = 16.sp, color = NoorColor.inkPrimary)
                Text(category.items.size.localizedDigits(), fontSize = 13.sp,
                     color = NoorColor.inkSecondary)
            }
            HorizontalDivider(color = NoorColor.inkPrimary.copy(alpha = 0.06f))
        }
    }
}

@Composable
fun DhikrListScreen(category: DhikrCategory, onBack: () -> Unit, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val progress = remember { mutableStateMapOf<Int, Int>() }
    // Per-card offline caption, keyed like nowPlayingId; cleared on retry.
    val failed = remember { mutableStateMapOf<String, Boolean>() }
    // Leaving the chapter silences it — the recording belongs to this screen.
    DisposableEffect(Unit) { onDispose { AthkarPlayer.stop() } }

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
        LazyColumn(Modifier.fillMaxSize().padding(horizontal = 16.dp)) {
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
            items(category.items.indices.toList()) { index ->
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
                            if (complete || active) NoorColor.stateReciting else NoorColor.bgElevated,
                            RoundedCornerShape(14.dp)
                        )
                        .clickable {
                            if (!complete) progress[index] = done + 1
                        }
                        .padding(16.dp)
                ) {
                    Text(dhikr.text, fontSize = 18.sp, lineHeight = 32.sp,
                         color = NoorColor.inkPrimary)
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
                            // Branded image card, like the iOS AthkarView share.
                            ShareIconButton {
                                shareRendered(context, dhikr.text, category.title,
                                              attribution = "نور Noor · حصن المسلم")
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
