package com.engagendy.noor

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

/// Great-circle initial bearing to the Kaaba — 1:1 with the iOS QiblaMath.
object QiblaMath {
    const val KAABA_LAT = 21.4225
    const val KAABA_LON = 39.8262

    fun bearing(lat: Double, lon: Double): Double {
        val phi1 = Math.toRadians(lat)
        val phi2 = Math.toRadians(KAABA_LAT)
        val deltaLambda = Math.toRadians(KAABA_LON - lon)
        val y = sin(deltaLambda) * cos(phi2)
        val x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLambda)
        return (Math.toDegrees(atan2(y, x)) + 360) % 360
    }
}

/// Qibla finder — port of the iOS QiblaView. The Kaaba sits at the top; a
/// gold arc shows how far to turn (it shrinks as you rotate). Facing the
/// qibla (±6°): everything turns green, pulses, and the device vibrates.
/// Compass heading comes from the ROTATION_VECTOR sensor; without one the
/// static bearing is shown.
@Composable
fun QiblaScreen(onClose: () -> Unit) {
    val context = LocalContext.current
    val prefs = remember { PrayerPrefs(context) }
    val city = remember { prefs.city }
    val bearing = remember { QiblaMath.bearing(city.latitude, city.longitude) }

    var heading by remember { mutableStateOf<Double?>(null) }
    DisposableEffect(Unit) {
        val manager = context.getSystemService(SensorManager::class.java)
        val sensor = manager?.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        val listener = object : SensorEventListener {
            private val rotation = FloatArray(9)
            private val orientation = FloatArray(3)
            override fun onSensorChanged(event: SensorEvent) {
                SensorManager.getRotationMatrixFromVector(rotation, event.values)
                SensorManager.getOrientation(rotation, orientation)
                heading = (Math.toDegrees(orientation[0].toDouble()) + 360) % 360
            }
            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }
        if (sensor != null) {
            manager.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_UI)
        }
        onDispose { manager?.unregisterListener(listener) }
    }

    // How far to turn, -180..180 (0 = facing the qibla).
    val turn = heading?.let {
        var delta = (bearing - it) % 360
        if (delta > 180) delta -= 360
        if (delta < -180) delta += 360
        delta
    }
    val hasCompass = turn != null
    val isAligned = turn != null && abs(turn) < 6

    // Success pulse + haptic when alignment is reached.
    var pulse by remember { mutableStateOf(false) }
    LaunchedEffect(isAligned) {
        if (isAligned) {
            pulse = true
            vibrate(context)
            kotlinx.coroutines.delay(400)
            pulse = false
        }
    }
    val pulseScale by animateFloatAsState(if (pulse) 1.06f else 1f,
        animationSpec = tween(350), label = "pulse")
    val smoothTurn by animateFloatAsState((turn ?: 0.0).toFloat(),
        animationSpec = tween(250), label = "turn")

    val green = NoorColor.accentPrimary
    val gold = NoorColor.accentGold

    Column(
        Modifier.fillMaxSize().background(NoorColor.bgPrimary),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 14.dp)
        ) {
            Text("القبلة", fontSize = 22.sp, fontWeight = FontWeight.Bold,
                 color = NoorColor.inkPrimary)
            Icon(painterResource(R.drawable.ic_close), contentDescription = "إغلاق",
                 tint = NoorColor.inkSecondary,
                 modifier = Modifier.size(44.dp).clickable(onClick = onClose).padding(10.dp))
        }
        Spacer(Modifier.height(8.dp))
        Text(city.nameArabic, fontSize = 13.sp, color = NoorColor.inkSecondary)
        Spacer(Modifier.height(22.dp))

        // Compass never mirrors, even in RTL.
        CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
            Box(Modifier.size(330.dp), contentAlignment = Alignment.Center) {
                // The Kaaba — the target, fixed at the top.
                Text("🕋", fontSize = if (pulse) 50.sp else 44.sp,
                     modifier = Modifier.align(Alignment.TopCenter).padding(top = 6.dp))
                Canvas(Modifier.size(280.dp)) {
                    val center = Offset(size.width / 2, size.height / 2)
                    // Turn arc: sweeps from the top by the remaining angle.
                    if (hasCompass && !isAligned) {
                        val sweep = abs(smoothTurn)
                        drawArc(
                            color = gold,
                            startAngle = -90f,
                            sweepAngle = if (smoothTurn >= 0) sweep else -sweep,
                            useCenter = false,
                            topLeft = Offset(center.x - 112.dp.toPx(), center.y - 112.dp.toPx()),
                            size = Size(224.dp.toPx(), 224.dp.toPx()),
                            style = Stroke(width = 12.dp.toPx(), cap = StrokeCap.Round))
                    }
                    // Outer ring: green when aligned.
                    drawCircle(
                        color = if (isAligned) green
                                else NoorColor.inkSecondary.copy(alpha = 0.15f),
                        radius = 125.dp.toPx() * pulseScale,
                        center = center,
                        style = Stroke(width = (if (isAligned) 3.dp else 1.5.dp).toPx()))
                    // Mihrab arch (same geometry as the app icon), rotated by turn.
                    rotate(if (hasCompass) smoothTurn else 0f, center) {
                        val w = 74.dp.toPx()
                        val h = 96.dp.toPx()
                        val left = center.x - w / 2
                        val top = center.y - h / 2
                        fun px(x: Float, y: Float) =
                            Offset(left + (x - 11f) / 42f * w, top + (y - 6f) / 52f * h)
                        val path = Path().apply {
                            moveTo(px(11f, 58f).x, px(11f, 58f).y)
                            lineTo(px(11f, 42f).x, px(11f, 42f).y)
                            cubicTo(px(11f, 25f).x, px(11f, 25f).y,
                                    px(20f, 13f).x, px(20f, 13f).y,
                                    px(32f, 6f).x, px(32f, 6f).y)
                            cubicTo(px(44f, 13f).x, px(44f, 13f).y,
                                    px(53f, 25f).x, px(53f, 25f).y,
                                    px(53f, 42f).x, px(53f, 42f).y)
                            lineTo(px(53f, 58f).x, px(53f, 58f).y)
                            close()
                        }
                        drawPath(path, color = if (isAligned) green else gold,
                                 style = Stroke(width = 4.dp.toPx(), join = StrokeJoin.Round))
                    }
                }
            }
        }

        Spacer(Modifier.height(10.dp))
        when {
            isAligned -> Text("أنت باتجاه القبلة", fontSize = 24.sp,
                fontWeight = FontWeight.SemiBold, color = green)
            hasCompass -> {
                Text(if (smoothTurn >= 0) "اذهب نحو اليمين" else "اذهب نحو اليسار",
                     fontSize = 22.sp, fontWeight = FontWeight.SemiBold,
                     color = NoorColor.inkPrimary)
                Spacer(Modifier.height(5.dp))
                Text("°${abs(smoothTurn).roundToInt().arabicIndic()}",
                     fontSize = 16.sp, color = NoorColor.inkSecondary)
            }
            else -> {
                Text("°${bearing.roundToInt().arabicIndic()}", fontSize = 34.sp,
                     fontWeight = FontWeight.SemiBold, color = NoorColor.inkPrimary)
                Spacer(Modifier.height(5.dp))
                Text("الاتجاه من الشمال الحقيقي", fontSize = 13.sp,
                     color = NoorColor.inkSecondary)
            }
        }
    }
}

private fun vibrate(context: Context) {
    val vibrator = if (Build.VERSION.SDK_INT >= 31) {
        context.getSystemService(VibratorManager::class.java)?.defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Vibrator::class.java)
    } ?: return
    vibrator.vibrate(VibrationEffect.createOneShot(60, VibrationEffect.DEFAULT_AMPLITUDE))
}
