package com.engagendy.noor

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/// The child's own settings sheet, deliberately NOT behind the parental
/// gate: none of it is a way out of kids mode. Three large sections —
/// language, how the surah plays (listen straight through vs memorise with
/// the age band's repeats), and who recites it. It is titled "Settings"
/// rather than "Sound" because language belongs here too.
///
/// Translation audio, Warsh readings, playback speed and the sleep timer
/// are all out of scope here — the grown-up app keeps those.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun KidsSoundSheet(age: Int, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val repeat = KidsMode.repeatCount(age)
    // Hafs reciters only; the teaching (Muallim) recitation leads the list.
    val reciters = remember {
        val hafs = Reciters.hafs
        val teacher = hafs.filter { it.id == KidsMode.TEACHING_RECITER_ID }
        teacher + hafs.filterNot { it.id == KidsMode.TEACHING_RECITER_ID }
    }
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = NoorColor.bgPrimary) {
        Column(Modifier.padding(horizontal = 16.dp)) {
            Text(
                stringResource(R.string.kids_settings),
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                color = NoorColor.inkPrimary,
                modifier = Modifier.padding(bottom = 12.dp))
            SectionLabel(stringResource(R.string.kids_language))
            // Same mechanism as the grown-up language picker: the per-app
            // locale via AppCompatDelegate (res/xml/locales_config.xml).
            // The activity recreates; the kids shell comes back because
            // `kids.enabled` is read from prefs on every start and the
            // shell's own state is rememberSaveable.
            // Selection comes from the RESOLVED resource language, so it can
            // never disagree with what is on screen (no prefs read here).
            val arabic = isArabicUi()
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                ModeCard(
                    title = "العربية",
                    note = null,
                    selected = arabic,
                    modifier = Modifier.weight(1f)) { setKidsLanguage(context, "ar") }
                ModeCard(
                    title = "English",
                    note = null,
                    selected = !arabic,
                    modifier = Modifier.weight(1f)) { setKidsLanguage(context, "en") }
            }
            Spacer(Modifier.height(18.dp))
            SectionLabel(stringResource(R.string.kids_sound))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                ModeCard(
                    title = stringResource(R.string.kids_mode_listen),
                    note = stringResource(R.string.kids_mode_listen_note),
                    selected = KidsStore.listenMode,
                    modifier = Modifier.weight(1f)) {
                    KidsStore.setListenMode(context, true)
                }
                ModeCard(
                    title = stringResource(R.string.kids_mode_memorise),
                    note = if (repeat > 1)
                        stringResource(R.string.kids_mode_memorise_note, repeat.localizedDigits())
                    else stringResource(R.string.kids_mode_memorise_note_none),
                    selected = !KidsStore.listenMode,
                    modifier = Modifier.weight(1f)) {
                    KidsStore.setListenMode(context, false)
                }
            }
            Spacer(Modifier.height(18.dp))
            SectionLabel(stringResource(R.string.kids_reciter))
            LazyColumn(Modifier.heightIn(max = 380.dp)) {
                items(reciters, key = { it.id }) { reciter ->
                    ReciterCard(
                        name = reciter.localizedName,
                        note = if (reciter.id == KidsMode.TEACHING_RECITER_ID)
                            stringResource(R.string.kids_muallim_note) else null,
                        selected = reciter.id == NoorPlayer.reciter.id,
                        onClick = { NoorPlayer.selectReciter(reciter) })
                }
                item { Spacer(Modifier.height(24.dp)) }
            }
        }
    }
}

/// User action: store the choice like Settings does, then apply the
/// per-app locale — AppCompatDelegate recreates the activity in it.
private fun setKidsLanguage(context: android.content.Context, tag: String) {
    KhatmahPlan.prefs(context).edit().putString("app.language", tag).apply()
    androidx.appcompat.app.AppCompatDelegate.setApplicationLocales(
        androidx.core.os.LocaleListCompat.forLanguageTags(tag))
}

@Composable
private fun SectionLabel(title: String) {
    Text(
        title,
        fontSize = 17.sp,
        fontWeight = FontWeight.Bold,
        color = NoorColor.inkPrimary,
        modifier = Modifier.padding(bottom = 8.dp))
}

@Composable
private fun ModeCard(
    title: String,
    note: String?,
    selected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(18.dp)
    Column(
        verticalArrangement = Arrangement.spacedBy(4.dp),
        modifier = modifier
            .clip(shape)
            .background(if (selected) NoorColor.accentPrimary else NoorColor.bgElevated, shape)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 18.dp)
    ) {
        Text(
            title,
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            color = if (selected) NoorColor.bgPrimary else NoorColor.inkPrimary)
        if (note != null) {
            Text(
                note,
                fontSize = 13.sp,
                color = if (selected) NoorColor.bgPrimary.copy(alpha = 0.85f)
                        else NoorColor.inkSecondary)
        }
    }
}

@Composable
private fun ReciterCard(
    name: String,
    note: String?,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(16.dp)
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .heightIn(min = 56.dp)
            .clip(shape)
            .background(if (selected) NoorColor.stateReciting else NoorColor.bgElevated, shape)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp)
    ) {
        Icon(
            painterResource(R.drawable.ic_mic),
            contentDescription = null,
            tint = if (selected) NoorColor.accentPrimary else NoorColor.inkSecondary,
            modifier = Modifier.size(22.dp))
        Column(Modifier.weight(1f)) {
            Text(
                name,
                fontSize = 18.sp,
                fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
                color = NoorColor.inkPrimary)
            if (note != null) {
                Text(note, fontSize = 13.sp, color = NoorColor.accentGold)
            }
        }
        if (selected) {
            Box(Modifier.size(12.dp).background(NoorColor.accentPrimary, CircleShape))
        }
    }
}
