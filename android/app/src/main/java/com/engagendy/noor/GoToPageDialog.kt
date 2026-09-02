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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog

/// Jump anywhere in the mushaf — iOS GoToPageSheet parity: type a page
/// number (Arabic-Indic accepted, ١–٦٠٤) with a numeric keyboard and an
/// انتقال button (disabled while out of range, like iOS), or tap a juz in
/// the 6-column grid. Tap outside to dismiss.
@Composable
fun GoToPageDialog(
    onGo: (page: Int) -> Unit,
    onDismiss: () -> Unit,
) {
    var pageText by remember { mutableStateOf("") }
    // iOS typedPage: map any decimal digit (including ٠–٩) to its value.
    val typedPage = remember(pageText) {
        val digits = pageText.mapNotNull { ch ->
            Character.getNumericValue(ch).takeIf { it in 0..9 }
        }
        if (digits.isEmpty() || digits.size != pageText.length) null
        else digits.fold(0) { acc, d -> acc * 10 + d }
            .takeIf { it in 1..PageLayoutDb.PAGE_COUNT }
    }
    val focusRequester = remember { FocusRequester() }

    fun jump(page: Int) {
        onGo(page)
        onDismiss()
    }

    Dialog(onDismissRequest = onDismiss) {
        Surface(shape = RoundedCornerShape(16.dp), color = NoorColor.bgPrimary) {
            Column(Modifier.padding(18.dp)) {
                Text(
                    stringResource(R.string.g2_go_to_page),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = NoorColor.inkPrimary)
                Spacer(Modifier.height(14.dp))
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    BasicTextField(
                        value = pageText,
                        onValueChange = { new ->
                            pageText = new.filter { it.isDigit() }.take(4)
                        },
                        textStyle = TextStyle(
                            fontSize = 22.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = NoorColor.inkPrimary),
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(
                            keyboardType = KeyboardType.Number,
                            imeAction = ImeAction.Go),
                        keyboardActions = KeyboardActions(
                            onGo = { typedPage?.let(::jump) }),
                        decorationBox = { inner ->
                            Box(
                                contentAlignment = Alignment.CenterStart,
                                modifier = Modifier
                                    .background(
                                        NoorColor.bgElevated, RoundedCornerShape(12.dp))
                                    .padding(14.dp)
                            ) {
                                if (pageText.isEmpty()) {
                                    Text(
                                        stringResource(R.string.g2_page_number_hint),
                                        fontSize = 17.sp,
                                        color = NoorColor.inkSecondary)
                                }
                                inner()
                            }
                        },
                        modifier = Modifier.weight(1f).focusRequester(focusRequester))
                    Box(
                        contentAlignment = Alignment.Center,
                        modifier = Modifier
                            .height(50.dp)
                            .background(
                                if (typedPage == null)
                                    NoorColor.inkSecondary.copy(alpha = 0.3f)
                                else NoorColor.accentPrimary,
                                RoundedCornerShape(12.dp))
                            .clickable(enabled = typedPage != null) {
                                typedPage?.let(::jump)
                            }
                            .padding(horizontal = 22.dp)
                    ) {
                        Text(
                            stringResource(R.string.g2_go),
                            fontSize = 16.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = NoorColor.bgPrimary)
                    }
                }
                Spacer(Modifier.height(18.dp))
                Text(
                    stringResource(R.string.g2_or_jump_juz),
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = NoorColor.inkSecondary)
                Spacer(Modifier.height(8.dp))
                // 6-column juz grid (RTL: juz ١ starts at the right edge).
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    (1..30).chunked(6).forEach { rowJuz ->
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            rowJuz.forEach { juz ->
                                Box(
                                    contentAlignment = Alignment.Center,
                                    modifier = Modifier
                                        .weight(1f)
                                        .height(42.dp)
                                        .background(
                                            NoorColor.bgElevated,
                                            RoundedCornerShape(10.dp))
                                        .clickable {
                                            jump(PageLayoutDb.juzStartPage(juz))
                                        }
                                ) {
                                    Text(
                                        juz.localizedDigits(),
                                        fontSize = 15.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        color = NoorColor.inkPrimary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    LaunchedEffect(Unit) { focusRequester.requestFocus() }
}
