package com.example.vitrine.feature.text.ui.display

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.example.vitrine.core.ui.components.FullScreenDisplayEffect
import com.example.vitrine.core.ui.components.LedFrame
import com.example.vitrine.core.ui.components.LedFrameDefaults
import com.example.vitrine.core.ui.components.MarqueeText
import com.example.vitrine.core.ui.modifier.rotate90

/**
 * Affichage plein écran : paysage, barres système cachées, écran toujours allumé,
 * guirlande de LEDs sur les bords et message sur une ligne qui défile si besoin.
 * Un appui n'importe où ramène à l'édition.
 */
@Composable
fun TextDisplayScreen(
    text: String,
    textColor: Color,
    bgColor: Color,
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
            contentColor = bgColor,
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
                    .padding(12.dp),
            ) {
// Si l'écran n'a pas pu passer en paysage (tablette, multi-fenêtre…),
// on tourne le texte de 90° pour qu'il suive la longueur du téléphone.
                val isPortrait = maxHeight > maxWidth

                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .then(if (isPortrait) Modifier.rotate90() else Modifier),
                    contentAlignment = Alignment.Center,
                ) {
                    MarqueeText(text = text, color = textColor)
                }
            }
        }
    }
}
