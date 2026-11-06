package com.example.vitrine.feature.clock.ui.display

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.colorResource
import androidx.compose.ui.unit.dp
import com.example.vitrine.R
import com.example.vitrine.core.ui.components.FullScreenDisplayEffect
import com.example.vitrine.core.ui.components.LedFrame
import com.example.vitrine.core.ui.components.LedFrameDefaults
import com.example.vitrine.core.ui.modifier.rotate90
import com.example.vitrine.feature.clock.ui.components.AnalogClock
import com.example.vitrine.feature.clock.ui.components.AnalogClockColors
import com.example.vitrine.feature.clock.ui.components.BigClock
import com.example.vitrine.feature.clock.usecase.ClockTime
import com.example.vitrine.feature.clock.viewmodel.ClockStyle

/**
 * Horloge plein écran : paysage, écran toujours allumé, guirlande de LEDs sur les bords,
 * comme l'affichage du texte géant. Un appui n'importe où ramène à l'écran horloge.
 */
@Composable
fun ClockDisplayScreen(
    time: ClockTime,
    style: ClockStyle,
    showSeconds: Boolean,
    onExit: () -> Unit,
) {
    FullScreenDisplayEffect()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(LedFrameDefaults.displayBaseColor())
            .clickable(onClick = onExit),
    ) {
        LedFrame(
            contentColor = colorResource(R.color.bg_black),
            modifier = Modifier.fillMaxSize(),
            baseColor = LedFrameDefaults.displayBaseColor(),
            offColor = LedFrameDefaults.displayOffColor(),
            cornerRadius = 28.dp,
            ledBand = 20.dp,
            ledSpacing = 24.dp,
        ) {
            BoxWithConstraints(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp),
            ) {
                // Si l'écran n'a pas pu passer en paysage, on tourne l'heure pour suivre sa longueur
                // (inutile pour le cadran, qui est rond)
                val isPortrait = maxHeight > maxWidth
                val white = colorResource(R.color.text_white)
                val muted = colorResource(R.color.vitrine_dark_text_muted)

                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .then(if (isPortrait && style == ClockStyle.DIGITAL) Modifier.rotate90() else Modifier),
                    contentAlignment = Alignment.Center,
                ) {
                    when (style) {
                        ClockStyle.DIGITAL -> BigClock(
                            time = time,
                            showSeconds = showSeconds,
                            color = white,
                            secondaryColor = muted,
                        )
                        ClockStyle.ANALOG -> AnalogClock(
                            time = time,
                            showSeconds = showSeconds,
                            colors = AnalogClockColors(
                                face = colorResource(R.color.vitrine_dark_surface),
                                minorTick = colorResource(R.color.vitrine_dark_divider),
                                majorTick = muted,
                                hands = white,
                                secondHand = colorResource(R.color.vitrine_dark_accent),
                            ),
                        )
                    }
                }
            }
        }
    }
}
