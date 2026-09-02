package com.engagendy.noor

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlin.math.cos
import kotlin.math.sin

/// One eight-pointed star (two overlapping rotated squares), the khatam of
/// classical Islamic geometry — 1:1 port of the iOS DesignSystem
/// EightPointStar shape (Core/DesignSystem/Components.swift).
internal fun eightPointStarPath(left: Float, top: Float, side: Float): Path {
    val path = Path()
    val cx = left + side / 2f
    val cy = top + side / 2f
    val outer = side / 2f
    val inner = outer * 0.6f
    for (i in 0 until 16) {
        val angle = i * Math.PI.toFloat() / 8f - Math.PI.toFloat() / 2f
        val radius = if (i % 2 == 0) outer else inner
        val x = cx + cos(angle) * radius
        val y = cy + sin(angle) * radius
        if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
    }
    path.close()
    return path
}

/// A quiet tiled star-lattice for card/surface backgrounds — meant to sit
/// at very low opacity behind content (ornament, never noise; not behind
/// Quran text). Port of the iOS DesignSystem IslamicLattice, with the same
/// alternate-row offset for the classic star-and-cross rhythm.
@Composable
fun IslamicLattice(
    tint: Color,
    tile: Dp = 56.dp,
    modifier: Modifier = Modifier,
    lineWidth: Dp = 1.dp,
) {
    Canvas(modifier) {
        val t = tile.toPx()
        val stroke = Stroke(width = lineWidth.toPx())
        val columns = (size.width / t).toInt() + 2
        val rows = (size.height / t).toInt() + 2
        for (row in 0 until rows) {
            for (column in 0 until columns) {
                val offsetX = if (row % 2 == 0) 0f else t / 2f
                val left = column * t - t / 2f + offsetX
                val top = row * t - t / 2f
                drawPath(eightPointStarPath(left, top, t * 0.82f), color = tint, style = stroke)
            }
        }
    }
}
