package com.example.vitrine.feature.clock.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.min
import com.example.vitrine.feature.clock.usecase.ClockTime

/**
 * Heure en très grand, qui s'adapte à la place disponible :
 * « 09:41 » en grand, les secondes et AM/PM en plus petit à côté, la date dessous.
 * Chiffres à chasse fixe : l'heure ne « tremble » pas quand les secondes changent.
 */
@Composable
fun BigClock(
    time: ClockTime,
    showSeconds: Boolean,
    color: Color,
    secondaryColor: Color,
    modifier: Modifier = Modifier,
    showDate: Boolean = true,
) {
    BoxWithConstraints(
        modifier = modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        // Nombre de « caractères » en largeur : HH:MM = 5, + secondes (plus petites) ≈ 1,5
        val widthInChars = 5f + (if (showSeconds) 1.6f else 0f) + (if (time.period != null) 1.2f else 0f)
        val byWidth = maxWidth / (widthInChars * 0.62f)
        val byHeight = maxHeight * (if (showDate) 0.55f else 0.75f)
        val mainSize = with(LocalDensity.current) { min(byWidth, byHeight).toSp() }
        val smallSize = mainSize * 0.38f

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            // « 09:41 », puis les secondes et AM/PM alignés sur la ligne de base des chiffres
            Row {
                ClockText(time.hoursMinutes, mainSize, color, FontWeight.Medium, Modifier.alignByBaseline())
                if (showSeconds) {
                    Spacer(Modifier.width(6.dp))
                    ClockText(time.seconds, smallSize, secondaryColor, FontWeight.Normal, Modifier.alignByBaseline())
                }
                time.period?.let { period ->
                    Spacer(Modifier.width(6.dp))
                    ClockText(period, smallSize, secondaryColor, FontWeight.Medium, Modifier.alignByBaseline())
                }
            }
            if (showDate) {
                ClockText(time.date, smallSize * 0.7f, secondaryColor, FontWeight.Normal)
            }
        }
    }
}

@Composable
private fun ClockText(
    text: String,
    size: TextUnit,
    color: Color,
    weight: FontWeight,
    modifier: Modifier = Modifier,
) {
    Text(
        text = text,
        modifier = modifier,
        maxLines = 1,
        softWrap = false,
        style = TextStyle(
            color = color,
            fontSize = size,
            lineHeight = size,
            fontWeight = weight,
            letterSpacing = size * -0.02f,
            // Chiffres de même largeur : pas de saut quand 1 devient 2
            fontFeatureSettings = "tnum",
        ),
    )
}
