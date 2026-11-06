package com.example.vitrine.core.ui.components

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.MarqueeSpacing
import androidx.compose.foundation.basicMarquee
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Texte sur une seule ligne, aussi haut que possible dans l'espace disponible.
 * S'il tient dans la largeur, il reste centré et immobile ;
 * sinon il défile en continu, comme un panneau de métro.
 *
 * @param heightFraction part de la hauteur disponible occupée par le texte.
 * @param velocity vitesse de défilement, en dp par seconde.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun MarqueeText(
    text: String,
    color: Color,
    modifier: Modifier = Modifier,
    heightFraction: Float = 0.7f,
    velocity: Dp = 140.dp,
) {
    BoxWithConstraints(
        modifier = modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        val fontSize = with(LocalDensity.current) { (maxHeight * heightFraction).toSp() }

        Text(
            text = text,
            color = color,
            fontSize = fontSize,
            lineHeight = fontSize,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
            softWrap = false,
            modifier = Modifier.basicMarquee(
                iterations = Int.MAX_VALUE,
                initialDelayMillis = 800,
                repeatDelayMillis = 0,
                spacing = MarqueeSpacing.fractionOfContainer(1f / 3f),
                velocity = velocity,
            ),
        )
    }
}