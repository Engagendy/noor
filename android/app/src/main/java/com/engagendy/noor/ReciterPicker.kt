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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/// Reciter picker sheet — search + flags, like the iOS reciter list.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReciterPickerSheet(onDismiss: () -> Unit) {
    var query by remember { mutableStateOf("") }
    val filtered = if (query.isBlank()) Reciters.all else Reciters.all.filter {
        it.nameArabic.contains(query) ||
            it.nameEnglish.contains(query, ignoreCase = true)
    }
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = NoorColor.bgPrimary) {
        Column(Modifier.padding(horizontal = 16.dp)) {
            Text("اختر القارئ", fontSize = 17.sp, fontWeight = FontWeight.Bold,
                 color = NoorColor.inkPrimary,
                 modifier = Modifier.padding(bottom = 10.dp))
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                placeholder = { Text("ابحث عن قارئ…", color = NoorColor.inkSecondary) },
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
                items(filtered, key = { it.id }) { reciter ->
                    val selected = reciter.id == NoorPlayer.reciter.id
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        modifier = Modifier
                            .fillMaxWidth()
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
                            Text(reciter.nameArabic, fontSize = 15.sp,
                                 fontWeight = if (selected) FontWeight.Bold
                                              else FontWeight.Normal,
                                 color = NoorColor.inkPrimary)
                            Text(reciter.nameEnglish, fontSize = 12.sp,
                                 color = NoorColor.inkSecondary)
                        }
                        if (selected) {
                            androidx.compose.foundation.layout.Box(
                                Modifier.size(10.dp)
                                    .background(NoorColor.accentPrimary, CircleShape))
                        }
                    }
                }
            }
        }
    }
}
