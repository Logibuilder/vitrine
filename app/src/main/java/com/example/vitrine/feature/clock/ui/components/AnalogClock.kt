package com.example.vitrine.feature.clock.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.min
import com.example.vitrine.feature.clock.usecase.ClockTime

/** Couleurs du cadran. */
data class AnalogClockColors(
    val face: Color,
    val minorTick: Color,
    val majorTick: Color,
    val hands: Color,
    val secondHand: Color,
    /** Chiffres 12, 3, 6 et 9 ; par défaut, la couleur des aiguilles. */
    val numbers: Color = hands,
)

/**
 * Horloge à aiguilles, plate : un disque, 60 graduations (plus marquées aux heures),
 * les chiffres 12, 3, 6 et 9 pour se repérer, aiguilles des heures et des minutes, trotteuse colorée.
 * Reste ronde quelle que soit la place disponible.
 */
@Composable
fun AnalogClock(
    time: ClockTime,
    showSeconds: Boolean,
    colors: AnalogClockColors,
    modifier: Modifier = Modifier,
) {
    val angles = handAngles(time)
    val textMeasurer = rememberTextMeasurer()

    // Le cadran prend le plus petit côté de la place disponible : il reste rond et ne déborde jamais,
    // que la zone soit en largeur (paysage, carte large) ou en hauteur.
    BoxWithConstraints(
        modifier = modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        val side = min(maxWidth, maxHeight)

        Canvas(Modifier.size(side)) {
            val radius = size.minDimension / 2f
            val unit = radius / 100f // tout est exprimé en % du rayon

            drawCircle(color = colors.face, radius = radius)
            drawTicks(radius, unit, colors)
            drawNumbers(textMeasurer, radius, unit, colors.numbers)

            drawHand(angles.hour, length = 50 * unit, tail = 8 * unit, width = 7 * unit, colors.hands)
            drawHand(angles.minute, length = 76 * unit, tail = 10 * unit, width = 4.5f * unit, colors.hands)
            if (showSeconds) {
                drawHand(angles.second, length = 84 * unit, tail = 16 * unit, width = 1.8f * unit, colors.secondHand)
            }

            // Axe central
            drawCircle(color = if (showSeconds) colors.secondHand else colors.hands, radius = 4.5f * unit)
            drawCircle(color = colors.face, radius = 1.8f * unit)
        }
    }
}

/** 60 graduations : longues et épaisses aux heures, courtes et fines aux minutes. */
private fun DrawScope.drawTicks(radius: Float, unit: Float, colors: AnalogClockColors) {
    repeat(60) { i ->
        val major = i % 5 == 0
        rotate(degrees = i * 6f, pivot = center) {
            drawLine(
                color = if (major) colors.majorTick else colors.minorTick,
                start = Offset(center.x, center.y - radius + 6 * unit),
                end = Offset(center.x, center.y - radius + (if (major) 16 else 10) * unit),
                strokeWidth = (if (major) 3.2f else 1.4f) * unit,
                cap = StrokeCap.Round,
            )
        }
    }
}

/**
 * Chiffres 12, 3, 6 et 9, centrés juste à l'intérieur des graduations des heures.
 * Leur taille suit celle du cadran.
 */
private fun DrawScope.drawNumbers(
    textMeasurer: TextMeasurer,
    radius: Float,
    unit: Float,
    color: Color,
) {
    val style = TextStyle(
        color = color,
        fontSize = (17 * unit).toSp(),
        fontWeight = FontWeight.Medium,
    )
    val distance = radius - 30 * unit
    listOf(
        "12" to Offset(0f, -distance),
        "3" to Offset(distance, 0f),
        "6" to Offset(0f, distance),
        "9" to Offset(-distance, 0f),
    ).forEach { (label, offset) ->
        val layout = textMeasurer.measure(label, style)
        drawText(
            textLayoutResult = layout,
            topLeft = Offset(
                x = center.x + offset.x - layout.size.width / 2f,
                y = center.y + offset.y - layout.size.height / 2f,
            ),
        )
    }
}

/** Aiguille tournée de [degrees] (0 = midi), qui dépasse un peu derrière l'axe ([tail]). */
private fun DrawScope.drawHand(
    degrees: Float,
    length: Float,
    tail: Float,
    width: Float,
    color: Color,
) {
    rotate(degrees = degrees, pivot = center) {
        drawLine(
            color = color,
            start = Offset(center.x, center.y + tail),
            end = Offset(center.x, center.y - length),
            strokeWidth = width,
            cap = StrokeCap.Round,
        )
    }
}

/** Angles des aiguilles, en degrés dans le sens horaire depuis midi. */
internal data class HandAngles(val hour: Float, val minute: Float, val second: Float)

/**
 * Les heures et les minutes avancent en continu (à 9 h 30, l'aiguille des heures est entre 9 et 10) ;
 * la trotteuse saute d'une seconde à l'autre, comme une montre à quartz.
 */
internal fun handAngles(time: ClockTime): HandAngles {
    val seconds = time.secondOfMinute.toFloat()
    val minutes = time.minuteOfHour + seconds / 60f
    val hours = (time.hourOfDay % 12) + minutes / 60f
    return HandAngles(
        hour = hours * 30f,
        minute = minutes * 6f,
        second = seconds * 6f,
    )
}