package com.engagendy.noor

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/// Reciter picker sheet — search + flags, like the iOS reciter list.
/// Sections: Hafs reciters, Warsh reciters (with the text-vs-recitation
/// note), then "Translation audio" (Off + the translated readings).
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReciterPickerSheet(onDismiss: () -> Unit) {
    var query by remember { mutableStateOf("") }
    fun matches(r: ReciterA) = query.isBlank() ||
        r.nameArabic.contains(query) || r.nameEnglish.contains(query, ignoreCase = true)
    val hafs = Reciters.hafs.filter(::matches)
    val warsh = Reciters.warsh.filter(::matches)
    val translations = TranslationVoice.entries.filter {
        query.isBlank() || it == TranslationVoice.NONE ||
            it.nameArabic.contains(query) || it.nameEnglish.contains(query, ignoreCase = true)
    }
    val showTranslations = query.isBlank() || translations.size > 1
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = NoorColor.bgPrimary) {
        Column(Modifier.padding(horizontal = 16.dp)) {
            Text(stringResource(R.string.g2_choose_reciter), fontSize = 17.sp, fontWeight = FontWeight.Bold,
                 color = NoorColor.inkPrimary,
                 modifier = Modifier.padding(bottom = 10.dp))
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                placeholder = { Text(stringResource(R.string.g2_search_reciters), color = NoorColor.inkSecondary) },
                singleLine = true,
                shape = RoundedCornerShape(12.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = NoorColor.accentPrimary,
                    unfocusedBorderColor = NoorColor.inkSecondary.copy(alpha = 0.3f),
                    focusedContainerColor = NoorColor.bgElevated,
                    unfocusedContainerColor = NoorColor.bgElevated,
                ),
                modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
            )
            LazyColumn(Modifier.heightIn(max = 480.dp)) {
                if (hafs.isNotEmpty() && warsh.isNotEmpty()) {
                    item(key = "hafsHeader") { SectionHeader(stringResource(R.string.g2_section_hafs)) }
                }
                items(hafs, key = { it.id }) { ReciterRow(it, onDismiss) }
                if (warsh.isNotEmpty()) {
                    item(key = "warshHeader") { SectionHeader(stringResource(R.string.g2_section_warsh)) }
                    items(warsh, key = { it.id }) { ReciterRow(it, onDismiss) }
                    item(key = "warshNote") { SectionFooter(stringResource(R.string.g2_warsh_note)) }
                }
                if (showTranslations) {
                    item(key = "translationHeader") {
                        SectionHeader(stringResource(R.string.g2_translation_audio))
                    }
                    items(translations, key = { "translation_" + it.name }) { voice ->
                        TranslationRow(voice, onDismiss)
                    }
                    item(key = "translationNote") {
                        SectionFooter(stringResource(R.string.g2_translation_audio_note))
                    }
                }
            }
        }
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
         color = NoorColor.inkSecondary,
         modifier = Modifier.padding(start = 12.dp, end = 12.dp, top = 14.dp, bottom = 6.dp))
}

@Composable
private fun SectionFooter(text: String) {
    Text(text, fontSize = 12.sp, color = NoorColor.inkSecondary,
         modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp))
}

@Composable
private fun ReciterRow(reciter: ReciterA, onDismiss: () -> Unit) {
    val selected = reciter.id == NoorPlayer.reciter.id
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .clickable { NoorPlayer.selectReciter(reciter); onDismiss() }
            .background(
                if (selected) NoorColor.stateReciting
                else NoorColor.bgPrimary,
                RoundedCornerShape(12.dp))
            .padding(horizontal = 12.dp, vertical = 12.dp)
    ) {
        if (reciter.flag.isEmpty()) {
            // Vector fallback — never an emoji glyph as icon.
            androidx.compose.material3.Icon(
                androidx.compose.ui.res.painterResource(R.drawable.ic_mic),
                contentDescription = null,
                tint = NoorColor.accentPrimary,
                modifier = Modifier.size(20.dp))
        } else {
            Text(reciter.flag, fontSize = 20.sp)
        }
        Column(Modifier.weight(1f)) {
            Text(reciter.localizedName, fontSize = 15.sp,
                 fontWeight = if (selected) FontWeight.Bold
                              else FontWeight.Normal,
                 color = NoorColor.inkPrimary)
            Text(reciter.secondaryName, fontSize = 12.sp,
                 color = NoorColor.inkSecondary)
        }
        if (selected) SelectedDot()
    }
}

/// One translated-reading option ("Off" first). Selecting does not close
/// the sheet — it is a modifier on top of the reciter, not a replacement.
@Composable
private fun TranslationRow(voice: TranslationVoice, onDismiss: () -> Unit) {
    val selected = voice == NoorPlayer.translation
    val label = if (voice == TranslationVoice.NONE) stringResource(R.string.g1_off)
                else voice.localizedName
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .clickable { NoorPlayer.selectTranslation(voice); onDismiss() }
            .background(
                if (selected) NoorColor.stateReciting
                else NoorColor.bgPrimary,
                RoundedCornerShape(12.dp))
            .padding(horizontal = 12.dp, vertical = 12.dp)
    ) {
        androidx.compose.material3.Icon(
            androidx.compose.ui.res.painterResource(R.drawable.ic_mic),
            contentDescription = null,
            tint = if (voice == TranslationVoice.NONE) NoorColor.inkSecondary
                   else NoorColor.accentPrimary,
            modifier = Modifier.size(20.dp))
        Text(label, fontSize = 15.sp,
             fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
             color = NoorColor.inkPrimary,
             modifier = Modifier.weight(1f))
        if (selected) SelectedDot()
    }
}

@Composable
private fun SelectedDot() {
    androidx.compose.foundation.layout.Box(
        Modifier.size(10.dp).background(NoorColor.accentPrimary, CircleShape))
}
