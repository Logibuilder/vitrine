package com.example.vitrine.core.ui.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathMeasure
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.res.colorResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.example.vitrine.R
import kotlin.math.PI
import kotlin.math.cos

/** Valeurs par défaut du [LedFrame], lues depuis res/values/colors_vitrine.xml. */
object LedFrameDefaults {

    /** Couleurs des LEDs, dans l'ordre où elles se suivent sur la guirlande. */
    @Composable
    fun palette(): List<Color> {
        val c1 = colorResource(R.color.led_cyan)
        val c2 = colorResource(R.color.led_violet)
        val c3 = colorResource(R.color.led_pink)
        val c4 = colorResource(R.color.led_amber)
        return remember(c1, c2, c3, c4) { listOf(c1, c2, c3, c4) }
    }

    /** Support de la guirlande. */
    @Composable
    fun baseColor(): Color = colorResource(R.color.led_base)

    /** LED éteinte. */
    @Composable
    fun offColor(): Color = colorResource(R.color.led_off)
}

/**
 * Cadre lumineux, comme une guirlande de LEDs enroulée autour d'un tableau.
 *
 * La bande extérieure (épaisseur [ledBand]) contient des LEDs rondes régulièrement espacées.
 * Une vague de lumière fait le tour du cadre (effet chenillard) et les couleurs glissent lentement.
 * Le contenu est affiché à l'intérieur, sur [contentColor].
 *
 * Les animations sont lues uniquement pendant le dessin : aucune recomposition à chaque image.
 */
@Composable
fun LedFrame(
    contentColor: Color,
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 28.dp,
    ledBand: Dp = 16.dp,
    ledSpacing: Dp = 20.dp,
    chaseDurationMillis: Int = 900,
    colorShiftDurationMillis: Int = 6_000,
    palette: List<Color> = LedFrameDefaults.palette(),
    baseColor: Color = LedFrameDefaults.baseColor(),
    offColor: Color = LedFrameDefaults.offColor(),
    content: @Composable BoxScope.() -> Unit,
) {
    val transition = rememberInfiniteTransition(label = "led-frame")
    val chase = transition.animateFloat(
        initialValue = 0f,
        targetValue = WAVE_PERIOD,
        animationSpec = infiniteRepeatable(
            animation = tween(chaseDurationMillis, easing = LinearEasing),
            repeatMode = RepeatMode.Restart,
        ),
        label = "led-chase",
    )
    val colorShift = transition.animateFloat(
        initialValue = 0f,
        targetValue = (palette.size * COLOR_GROUP).toFloat(),
        animationSpec = infiniteRepeatable(
            animation = tween(colorShiftDurationMillis, easing = LinearEasing),
            repeatMode = RepeatMode.Restart,
        ),
        label = "led-color-shift",
    )

    val innerRadius = (cornerRadius - ledBand).coerceAtLeast(0.dp)

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(cornerRadius))
            .background(baseColor)
            .drawWithCache {
                val band = ledBand.toPx()
                val inset = band / 2f
                val radius = (cornerRadius.toPx() - inset).coerceAtLeast(0f)

                // Ligne médiane de la bande : c'est là que sont posées les LEDs.
                val path = Path().apply {
                    addRoundRect(
                        RoundRect(
                            left = inset,
                            top = inset,
                            right = size.width - inset,
                            bottom = size.height - inset,
                            cornerRadius = CornerRadius(radius),
                        )
                    )
                }
                val measure = PathMeasure().apply { setPath(path, false) }
                val count = (measure.length / ledSpacing.toPx()).toInt().coerceAtLeast(1)
                val step = measure.length / count
                val positions = List(count) { i -> measure.getPosition(i * step) }

                val ledRadius = band * 0.28f
                val glowRadius = band * 0.62f

                onDrawBehind {
                    val c = chase.value
                    val shift = colorShift.value.toInt()

                    positions.forEachIndexed { i, pos ->
                        // Position de la LED dans la vague (0..1), qui avance avec le temps.
                        val d = (((i - c) % WAVE_PERIOD) + WAVE_PERIOD) % WAVE_PERIOD / WAVE_PERIOD
                        val wave = 0.5f + 0.5f * cos(2f * PI.toFloat() * d)
                        val level = 0.12f + 0.88f * wave * wave * wave

                        val color = palette[((i + shift) / COLOR_GROUP) % palette.size]

                        // Halo
                        drawCircle(
                            color = color.copy(alpha = 0.35f * level),
                            radius = glowRadius,
                            center = pos,
                        )
                        // Ampoule
                        drawCircle(color = lerp(offColor, color, level), radius = ledRadius, center = pos)
                        // Reflet blanc quand la LED est bien allumée
                        if (level > 0.6f) {
                            drawCircle(
                                color = Color.White.copy(alpha = (level - 0.6f) * 1.5f),
                                radius = ledRadius * 0.45f,
                                center = pos,
                            )
                        }
                    }
                }
            }
            .padding(ledBand),
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .clip(RoundedCornerShape(innerRadius))
                .background(contentColor),
            content = content,
        )
    }
}

/** Nombre de LEDs entre deux vagues de lumière. */
private const val WAVE_PERIOD = 6f

/** Nombre de LEDs consécutives de la même couleur. */
private const val COLOR_GROUP = 3