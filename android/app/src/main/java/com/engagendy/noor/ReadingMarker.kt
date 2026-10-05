package com.engagendy.noor

import android.content.Context
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.AbsoluteAlignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import kotlin.math.abs
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.roundToInt

/// The one reading marker (iOS ReadingMarker): a ribbon the reader drags
/// onto the line they stopped at, so an interrupted session resumes at that
/// exact line. Unlike bookmarks there is only ever one, and it moves.
///
/// Stored as "page:line:surah:ayah:word" under [PREFS_KEY] — the same value
/// iOS stores: the first word of the marked line, `ayah` being the one in
/// progress there and `word` its 1-based number (the Madani layout's word
/// positions), so the marker lands on the same line in every reading mode.
data class ReadingMarker(
    val page: Int,
    /// Printed line number on [page] (PageLine.line).
    val line: Int,
    val surahId: Int,
    val ayah: Int,
    val word: Int = 1,
) {
    val key: Int get() = surahId * 1000 + ayah
    val raw: String get() = "$page:$line:$surahId:$ayah:${word.coerceAtLeast(1)}"

    companion object {
        const val PREFS_KEY = "reader.marker"

        fun parse(raw: String?): ReadingMarker? {
            val parts = raw?.split(":")?.mapNotNull { it.toIntOrNull() } ?: return null
            // Four parts: a marker saved before word positions existed.
            if ((parts.size != 4 && parts.size != 5) || parts.any { it <= 0 }) return null
            return ReadingMarker(parts[0], parts[1], parts[2], parts[3], parts.getOrElse(4) { 1 })
        }
    }
}

/// App-wide marker state: Compose state for every reader and the Today card,
/// prefs for persistence. Written only from gesture / click handlers.
object ReadingMarkers {
    var current by mutableStateOf<ReadingMarker?>(null)
        private set
    private var loaded = false

    fun load(context: Context) {
        if (loaded) return
        loaded = true
        current = ReadingMarker.parse(KhatmahPlan.prefs(context).getString(ReadingMarker.PREFS_KEY, null))
    }

    fun set(context: Context, marker: ReadingMarker?) {
        current = marker
        KhatmahPlan.prefs(context).edit().apply {
            if (marker == null) remove(ReadingMarker.PREFS_KEY) else putString(ReadingMarker.PREFS_KEY, marker.raw)
        }.apply()
    }

    /// Marks a line by its first word ([word] of the ayah); the printed
    /// page and line come from the layout DB, off-main.
    fun placeAt(context: Context, scope: CoroutineScope, surahId: Int, ayah: Int, word: Int = 1) {
        scope.launch {
            val marker = withContext(Dispatchers.IO) {
                runCatching { PageLayoutDb.get(context).markerFor(surahId, ayah, word) }.getOrNull()
            } ?: return@launch
            set(context, marker)
        }
    }

    /// Character offset of word [word] (1-based, letter tokens only) of an
    /// ayah occupying [start]..[end] in [text] — the inverse of [wordIndex].
    fun offsetOfWord(text: String, start: Int, end: Int, word: Int): Int {
        var count = 0
        var i = start
        while (i < end) {
            while (i < end && (text[i] == ' ' || text[i] == '\n')) i++
            val tokenStart = i
            while (i < end && text[i] != ' ' && text[i] != '\n') i++
            if ((tokenStart until i).any { text[it].isLetter() }) {
                count++
                if (count >= word) return tokenStart
            }
        }
        return start
    }

    /// 1-based word number of the token starting at [offset] in an ayah
    /// whose text begins at [ayahStart]: tokens before it that carry a
    /// letter, plus one. Pause marks that the Tanzil text spaces off are not
    /// words — this is what lines the numbering up with the Madani layout's
    /// positions (iOS QuranFlowItem.wordIndex).
    fun wordIndex(text: String, ayahStart: Int, offset: Int): Int {
        if (offset <= ayahStart) return 1
        return text.substring(ayahStart, offset.coerceAtMost(text.length))
            .split(' ', '\n')
            .count { token -> token.any { it.isLetter() } } + 1
    }
}

/// One line the ribbon can sit on, in the ribbon layer's own pixels.
data class MarkerLine(val top: Float, val bottom: Float, val key: Int, val word: Int, val tag: Int = 0) {
    val center: Float get() = (top + bottom) / 2f
}

/// Lines of a laid-out Quran text, for the ribbon. [offsetY] is the text's
/// top in the ribbon layer; [ayahAt] resolves the ayah key and the offset
/// its text starts at for a character offset (null = not ayah text, e.g. a
/// juz header line). Lines with no letters (a wrapped ayah number) are
/// skipped so two rows never claim the same word.
fun markerLines(
    layout: TextLayoutResult,
    offsetY: Float,
    ayahAt: (Int) -> Pair<Int, Int>?,
): List<MarkerLine> {
    val text = layout.layoutInput.text.text
    return (0 until layout.lineCount).mapNotNull { i ->
        val start = layout.getLineStart(i)
        val end = layout.getLineEnd(i)
        if (text.substring(start, end).none { it.isLetter() }) return@mapNotNull null
        // The line's first letter, not a leading space or ۞.
        val firstLetter = (start until end).firstOrNull { text[it].isLetter() } ?: start
        val (key, ayahStart) = ayahAt(firstLetter) ?: return@mapNotNull null
        MarkerLine(
            top = offsetY + layout.getLineTop(i),
            bottom = offsetY + layout.getLineBottom(i),
            key = key,
            word = ReadingMarkers.wordIndex(text, ayahStart, firstLetter))
    }
}

/// Index of the line holding the marker's word — or, if that exact word is
/// not among [lines], the line holding the closest earlier word of its ayah.
fun markedLineIndex(lines: List<MarkerLine>, marker: ReadingMarker?): Int? {
    marker ?: return null
    var best: Int? = null
    var bestWord = 0
    lines.forEachIndexed { index, line ->
        if (line.key != marker.key) return@forEachIndexed
        if (line.word == marker.word) return index
        if (line.word < marker.word && line.word > bestWord) {
            best = index
            bestWord = line.word
        }
    }
    return best
}

/// The reading-marker ribbon and its gold line wash, laid over a reader
/// (iOS MadaniPageView.markerRibbon / ScrollMarkerRibbon). Fills its parent.
///
/// The ribbon hugs the RIGHT edge (where Arabic lines begin) whatever the UI
/// language. Drag it vertically and it snaps line by line with a live wash
/// and a haptic tick; dropping it calls [onPlace] with that line. With the
/// marked line among [lines] it sits on it; otherwise it parks, faded, by
/// the first line, and a tap calls [onJump] to go back to the marker.
@Composable
fun MarkerRibbonLayer(
    lines: List<MarkerLine>,
    markedIndex: Int?,
    hasMarker: Boolean,
    onPlace: (MarkerLine) -> Unit,
    onJump: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val density = LocalDensity.current
    val haptics = LocalHapticFeedback.current
    var dragIndex by remember { mutableStateOf<Int?>(null) }
    val currentLines by rememberUpdatedState(lines)
    val shownIndex = (dragIndex ?: markedIndex)?.takeIf { it in lines.indices }
    val shown = shownIndex?.let { lines[it] }
    val active = shown != null
    val parkedY = lines.firstOrNull()?.center ?: with(density) { 28.dp.toPx() }
    val ribbonY = shown?.center ?: parkedY
    val currentRibbonY by rememberUpdatedState(ribbonY)
    val touchPx = with(density) { 44.dp.toPx() }
    LaunchedEffect(dragIndex) { if (dragIndex != null) haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove) }

    fun nearest(y: Float): Int? =
        currentLines.indices.minByOrNull { abs(currentLines[it].center - y) }

    BoxWithConstraints(modifier.fillMaxSize()) {
        if (shown != null) {
            val pad = with(density) { 3.dp.toPx() }
            Box(
                Modifier
                    .offset { IntOffset(with(density) { 8.dp.roundToPx() }, (shown.top - pad).roundToInt()) }
                    .size(maxWidth - 16.dp, with(density) { (shown.bottom - shown.top + pad * 2).toDp() })
                    .background(NoorColor.accentGold.copy(alpha = 0.16f), RoundedCornerShape(8.dp))
            )
        }
        val markerLabel = stringResource(R.string.feat_marker)
        val hint = stringResource(R.string.feat_marker_hint)
        Box(
            Modifier
                .align(AbsoluteAlignment.TopRight)
                .offset { IntOffset(0, (ribbonY - touchPx / 2).roundToInt()) }
                .size(44.dp)
                // TalkBack users place it from the ayah actions sheet.
                .semantics {
                    contentDescription = markerLabel
                    stateDescription = hint
                }
                .pointerInput(Unit) {
                    awaitEachGesture {
                        val down = awaitFirstDown()
                        down.consume()
                        // Finger y in the layer: the ribbon box moves with the
                        // drag, so add its current top every event.
                        val startY = currentRibbonY - touchPx / 2 + down.position.y
                        var travelled = 0f
                        var dragging = false
                        var lastY = startY
                        while (true) {
                            val event = awaitPointerEvent()
                            val change = event.changes.firstOrNull { it.id == down.id } ?: break
                            if (!change.pressed) break
                            travelled += abs(change.positionChange().y)
                            lastY = currentRibbonY - touchPx / 2 + change.position.y
                            if (!dragging && travelled > viewConfiguration.touchSlop / 2) dragging = true
                            if (dragging) dragIndex = nearest(lastY)
                            change.consume()
                        }
                        if (dragging) {
                            nearest(lastY)?.let { onPlace(currentLines[it]) }
                        } else if (!active && hasMarker) {
                            onJump()
                        }
                        dragIndex = null
                    }
                }
        ) {
            val gold = NoorColor.accentGold
            Canvas(
                Modifier
                    .align(AbsoluteAlignment.CenterRight)
                    .size(15.dp, 30.dp)
                    .alpha(if (active) 1f else 0.4f)
            ) {
                // Swallow-tailed tab attached at the right edge, notch facing
                // the text (iOS RibbonShape).
                val notch = size.width * 0.45f
                val path = Path().apply {
                    moveTo(size.width, 0f)
                    lineTo(0f, 0f)
                    lineTo(notch, size.height / 2f)
                    lineTo(0f, size.height)
                    lineTo(size.width, size.height)
                    close()
                }
                drawPath(path, gold)
            }
        }
    }
}
