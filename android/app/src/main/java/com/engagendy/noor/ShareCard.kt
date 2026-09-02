package com.engagendy.noor

import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Typeface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextDirectionHeuristics
import android.text.TextPaint
import androidx.core.content.FileProvider
import androidx.core.content.res.ResourcesCompat
import java.io.File
import kotlin.math.cos
import kotlin.math.sin

/// Status-ready branded image card, 1:1 with the iOS NoorShareCard:
/// paper background, gold frame, corner stars, Arabic text, reference
/// + the green «نور Noor» footer. Rendered at 2× for crisp sharing.
object ShareCard {

    private const val WIDTH = 1240
    private const val PADDING = 72f
    private val paper = Color.parseColor("#FAF6EE")
    private val gold = Color.parseColor("#BA8A2E")
    private val green = Color.parseColor("#0E6B5C")
    private val ink = Color.parseColor("#1F2933")
    private val gray = Color.parseColor("#5C6670")

    private fun layout(text: String, paint: TextPaint, width: Int): StaticLayout =
        StaticLayout.Builder.obtain(text, 0, text.length, paint, width)
            .setAlignment(Layout.Alignment.ALIGN_CENTER)
            .setTextDirection(TextDirectionHeuristics.RTL)
            .setLineSpacing(0f, 1.55f)
            .setIncludePad(true)
            .build()

    /// Draws the card into a bitmap. Call from Dispatchers.IO.
    fun render(
        context: Context,
        arabicText: String,
        reference: String,
        attribution: String = "نور Noor",
        useQuranFont: Boolean = false,
        translation: String? = null,
    ): Bitmap {
        val textWidth = (WIDTH - 2 * PADDING).toInt()

        val arabicPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = ink
            textSize = if (useQuranFont) 60f else 48f
            typeface = if (useQuranFont)
                ResourcesCompat.getFont(context, R.font.amiri_quran) ?: Typeface.DEFAULT
            else Typeface.DEFAULT
        }
        val translationPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = gray
            textSize = 34f
            typeface = Typeface.create(Typeface.SERIF, Typeface.NORMAL)
        }
        val referencePaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = green
            textSize = 28f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        val attributionPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = green
            textSize = 24f
        }
        val arabicLayout = layout(arabicText, arabicPaint, textWidth)
        val translationLayout = translation?.takeIf { it.isNotBlank() }
            ?.let { layout(it, translationPaint, textWidth) }
        val referenceLayout = layout(reference, referencePaint, textWidth)
        val attributionLayout = layout(attribution, attributionPaint, textWidth)

        val lampGap = 130f
        val translationBlock = translationLayout?.let { it.height + 28f } ?: 0f
        val height = (PADDING + lampGap + arabicLayout.height + translationBlock + 36f +
            referenceLayout.height + 8f + attributionLayout.height + PADDING).toInt()

        val bitmap = Bitmap.createBitmap(WIDTH, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(paper)

        // Quiet star-lattice ornament across the paper, per the iOS
        // NoorShareCard IslamicLattice background (2× render scale).
        val lattice = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = gold
            alpha = 14
            style = Paint.Style.STROKE
            strokeWidth = 2f
        }
        val tile = 148f
        var row = 0
        while (row * tile - tile / 2f < height + tile) {
            var column = 0
            while (column * tile - tile / 2f < WIDTH + tile) {
                val offsetX = if (row % 2 == 0) 0f else tile / 2f
                val x = column * tile - tile / 2f + offsetX + tile * 0.41f
                val y = row * tile - tile / 2f + tile * 0.41f
                canvas.drawPath(eightPointStar(x, y, tile * 0.41f), lattice)
                column += 1
            }
            row += 1
        }

        // Gold frame, inset like the iOS card.
        val frame = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = gold
            style = Paint.Style.STROKE
            strokeWidth = 3f
        }
        canvas.drawRect(20f, 20f, WIDTH - 20f, height - 20f, frame)

        // Corner eight-point stars.
        val star = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = gold
            alpha = 140
            style = Paint.Style.FILL
        }
        for ((x, y) in listOf(44f to 44f, WIDTH - 44f to 44f, 44f to height - 44f, WIDTH - 44f to height - 44f)) {
            canvas.drawPath(eightPointStar(x, y, 16f), star)
        }

        // Mihrab lamp mark: green arch + hanging gold lamp.
        val cx = WIDTH / 2f
        val archTop = PADDING + 8f
        val arch = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = green
            style = Paint.Style.STROKE
            strokeWidth = 5f
            strokeCap = Paint.Cap.ROUND
        }
        val archPath = Path().apply {
            moveTo(cx - 40f, archTop + 88f)
            lineTo(cx - 40f, archTop + 40f)
            cubicTo(cx - 40f, archTop, cx + 40f, archTop, cx + 40f, archTop + 40f)
            lineTo(cx + 40f, archTop + 88f)
        }
        canvas.drawPath(archPath, arch)
        val lamp = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = gold }
        canvas.drawLine(cx, archTop + 10f, cx, archTop + 34f, arch.apply { strokeWidth = 3f })
        canvas.drawCircle(cx, archTop + 46f, 12f, lamp)

        var y = PADDING + lampGap
        canvas.withTranslation(PADDING, y) { arabicLayout.draw(this) }
        y += arabicLayout.height
        if (translationLayout != null) {
            y += 28f
            canvas.withTranslation(PADDING, y) { translationLayout.draw(this) }
            y += translationLayout.height
        }
        y += 36f
        canvas.withTranslation(PADDING, y) { referenceLayout.draw(this) }
        y += referenceLayout.height + 8f
        canvas.withTranslation(PADDING, y) { attributionLayout.draw(this) }
        return bitmap
    }

    private inline fun Canvas.withTranslation(x: Float, y: Float, block: Canvas.() -> Unit) {
        save(); translate(x, y); block(); restore()
    }

    private fun eightPointStar(cx: Float, cy: Float, radius: Float): Path {
        val path = Path()
        for (i in 0 until 16) {
            val r = if (i % 2 == 0) radius else radius * 0.42f
            val angle = Math.PI * i / 8 - Math.PI / 2
            val x = cx + r * cos(angle).toFloat()
            val y = cy + r * sin(angle).toFloat()
            if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
        }
        path.close()
        return path
    }

    /// Saves the bitmap into the shared cache and opens the system share
    /// sheet. Call from the main thread with a pre-rendered bitmap.
    fun share(context: Context, bitmap: Bitmap, text: String? = null) {
        val dir = File(context.cacheDir, "shared").apply { mkdirs() }
        // Fresh file name each time — some targets cache by URI and would
        // otherwise show a stale card.
        dir.listFiles()?.forEach { it.delete() }
        val file = File(dir, "noor-share-${System.currentTimeMillis()}.png")
        file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            if (!text.isNullOrBlank()) putExtra(Intent.EXTRA_TEXT, text)
            // ClipData + the read grant are what actually let the receiving
            // app open the image; without them many targets show text only.
            clipData = ClipData.newRawUri("noor", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val chooser = Intent.createChooser(intent, null).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(chooser)
    }
}
