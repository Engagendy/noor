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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import kotlin.random.Random

/// "Ask a grown-up" — the only door out of kids mode.
///
/// A randomly generated two-digit multiplication guards every exit: turning
/// kids mode off in Settings, and the grown-up control inside the kids
/// shell. A wrong answer clears the field, shows a gentle hint and rolls a
/// NEW question, so a child cannot brute-force one memorised answer.
///
/// The question is rendered with `localizedDigits()` (Arabic-Indic in the
/// Arabic UI); the typed answer is parsed digit-by-digit, so an Arabic-Indic
/// keypad works too — no locale-dependent string formatting anywhere.
@Composable
fun ParentalGate(onPass: () -> Unit, onDismiss: () -> Unit) {
    fun roll(): Pair<Int, Int> = Random.nextInt(11, 20) to Random.nextInt(3, 10)
    var question by remember { mutableStateOf(roll()) }
    var answer by remember { mutableStateOf("") }
    var showHint by remember { mutableStateOf(false) }
    val focusRequester = remember { FocusRequester() }

    // Any decimal digit (٠–٩ included) → its value; null while incomplete.
    val typed = remember(answer) {
        val digits = answer.mapNotNull { ch ->
            Character.getNumericValue(ch).takeIf { it in 0..9 }
        }
        if (digits.isEmpty() || digits.size != answer.length) null
        else digits.fold(0) { acc, d -> acc * 10 + d }
    }

    fun submit() {
        if (typed == question.first * question.second) {
            onPass()
            onDismiss()
        } else {
            answer = ""
            showHint = true
            question = roll()
        }
    }

    Dialog(onDismissRequest = onDismiss) {
        Surface(shape = RoundedCornerShape(20.dp), color = NoorColor.bgPrimary) {
            Column(Modifier.padding(20.dp)) {
                Text(
                    stringResource(R.string.kids_gate_title),
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = NoorColor.inkPrimary)
                Spacer(Modifier.height(16.dp))
                Text(
                    stringResource(
                        R.string.kids_gate_question,
                        question.first.localizedDigits(),
                        question.second.localizedDigits()),
                    fontSize = 30.sp,
                    fontWeight = FontWeight.Bold,
                    color = NoorColor.accentPrimary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth())
                Spacer(Modifier.height(16.dp))
                BasicTextField(
                    value = answer,
                    onValueChange = { new -> answer = new.filter { it.isDigit() }.take(4) },
                    textStyle = TextStyle(
                        fontSize = 24.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = NoorColor.inkPrimary,
                        fontFamily = NoorFont.family,
                        textAlign = TextAlign.Center),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Number,
                        imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = { submit() }),
                    decorationBox = { inner ->
                        Box(
                            contentAlignment = Alignment.Center,
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(NoorColor.bgElevated, RoundedCornerShape(14.dp))
                                .padding(16.dp)
                        ) {
                            if (answer.isEmpty()) {
                                Text(
                                    stringResource(R.string.kids_gate_answer),
                                    fontSize = 17.sp,
                                    color = NoorColor.inkSecondary)
                            }
                            inner()
                        }
                    },
                    modifier = Modifier.fillMaxWidth().focusRequester(focusRequester))
                if (showHint) {
                    Text(
                        stringResource(R.string.kids_gate_hint),
                        fontSize = 13.sp,
                        color = NoorColor.accentGold,
                        modifier = Modifier.padding(top = 10.dp))
                }
                Spacer(Modifier.height(18.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    GateButton(
                        label = stringResource(R.string.g2_cancel),
                        filled = false,
                        modifier = Modifier.weight(1f),
                        onClick = onDismiss)
                    GateButton(
                        label = stringResource(R.string.kids_gate_check),
                        filled = true,
                        enabled = typed != null,
                        modifier = Modifier.weight(1f),
                        onClick = ::submit)
                }
            }
        }
    }
    LaunchedEffect(Unit) { focusRequester.requestFocus() }
}

@Composable
private fun GateButton(
    label: String,
    filled: Boolean,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(14.dp)
    Box(
        contentAlignment = Alignment.Center,
        modifier = modifier
            .heightIn(min = 48.dp)
            .clip(shape)
            .background(
                when {
                    !filled -> NoorColor.bgElevated
                    enabled -> NoorColor.accentPrimary
                    else -> NoorColor.inkSecondary.copy(alpha = 0.3f)
                },
                shape)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp)
    ) {
        Text(
            label,
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold,
            color = if (filled) NoorColor.bgPrimary else NoorColor.inkPrimary)
    }
}

/// "How old is your child?" — the sheet shown when the Settings toggle is
/// switched ON. Cancelling leaves kids mode OFF (the caller keeps the
/// toggle state); confirming writes `kids.age` + `kids.enabled`.
@Composable
fun KidsAgeDialog(
    initialAge: Int = KidsMode.DEFAULT_AGE,
    onConfirm: (Int) -> Unit,
    onDismiss: () -> Unit,
) {
    var age by remember { mutableIntStateOf(initialAge.coerceIn(KidsMode.MIN_AGE, KidsMode.MAX_AGE)) }
    Dialog(onDismissRequest = onDismiss) {
        Surface(shape = RoundedCornerShape(20.dp), color = NoorColor.bgPrimary) {
            Column(Modifier.padding(20.dp)) {
                Text(
                    stringResource(R.string.kids_age_question),
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = NoorColor.inkPrimary)
                Spacer(Modifier.height(16.dp))
                // Large age chips, 4…12 — three per row so every target is
                // comfortably past 48dp for small fingers.
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    KidsMode.ages.chunked(3).forEach { row ->
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            row.forEach { value ->
                                AgeChip(
                                    value = value,
                                    selected = value == age,
                                    modifier = Modifier.weight(1f)) { age = value }
                            }
                            // Keep the last row's chips the same width.
                            repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
                        }
                    }
                }
                Spacer(Modifier.height(20.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    GateButton(
                        label = stringResource(R.string.g2_cancel),
                        filled = false,
                        modifier = Modifier.weight(1f),
                        onClick = onDismiss)
                    GateButton(
                        label = stringResource(R.string.kids_start),
                        filled = true,
                        modifier = Modifier.weight(1f),
                        onClick = { onConfirm(age) })
                }
            }
        }
    }
}

@Composable
private fun AgeChip(
    value: Int,
    selected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(16.dp)
    // Content description for an age chip: "7 years" in the UI language.
    val label = stringResource(R.string.kids_age_years, value.localizedDigits())
    Box(
        contentAlignment = Alignment.Center,
        modifier = modifier
            .height(64.dp)
            .clip(shape)
            .background(if (selected) NoorColor.accentPrimary else NoorColor.bgElevated, shape)
            .clickable(onClick = onClick)
            .semantics { contentDescription = label }
    ) {
        Text(
            value.localizedDigits(),
            fontSize = 26.sp,
            fontWeight = FontWeight.Bold,
            color = if (selected) NoorColor.bgPrimary else NoorColor.inkPrimary)
    }
}

/// One gold eight-pointed star (the khatam of the design system) — filled
/// when earned, outlined when still to be won. No cartoon imagery: the
/// reward uses the same geometry as the rest of Noor.
@Composable
fun GoldStar(earned: Boolean, size: androidx.compose.ui.unit.Dp = 20.dp) {
    androidx.compose.foundation.Canvas(Modifier.size(size)) {
        val path = eightPointStarPath(0f, 0f, this.size.minDimension)
        if (earned) {
            drawPath(path, color = NoorColor.accentGold)
        } else {
            drawPath(
                path,
                color = NoorColor.inkSecondary.copy(alpha = 0.35f),
                style = androidx.compose.ui.graphics.drawscope.Stroke(width = 1.5.dp.toPx()))
        }
    }
}

/// The 0–3 star row shown on a surah card and in the reader.
@Composable
fun StarRow(count: Int, size: androidx.compose.ui.unit.Dp = 20.dp) {
    val label = stringResource(R.string.kids_stars_of_three, count.localizedDigits())
    Row(
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.semantics { contentDescription = label }
    ) {
        repeat(KidsMode.MAX_STARS) { index -> GoldStar(earned = index < count, size = size) }
    }
}
