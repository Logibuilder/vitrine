package com.example.vitrine.feature.flashlight.ui.display

import android.app.Activity
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.example.vitrine.R
import com.example.vitrine.core.ui.components.FullScreenDisplayEffect
import com.example.vitrine.feature.flashlight.usecase.SetScreenBrightnessUseCase
import kotlinx.coroutines.delay
import org.koin.compose.koinInject
import kotlin.math.roundToInt

/**
 * Lumière plein écran : tout l'écran de la couleur choisie, luminosité réglée,
 * écran toujours allumé. Glisser vers le haut ou le bas règle l'intensité ;
 * un appui ramène aux réglages.
 */
@Composable
fun LightDisplayScreen(
    color: Color,
    brightness: Float,
    onBrightnessChange: (Float) -> Unit,
    onExit: () -> Unit,
) {
    FullScreenDisplayEffect(forceLandscape = false)
    ScreenBrightnessEffect(brightness)

    val currentBrightness by rememberUpdatedState(brightness)
    var showLevel by remember { mutableStateOf(false) }
    // Le pourcentage s'efface 1,2 s après le dernier réglage
    LaunchedEffect(brightness) {
        if (showLevel) {
            delay(1_200)
            showLevel = false
        }
    }

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .background(color)
            .pointerInput(Unit) { detectTapGestures(onTap = { onExit() }) },
    ) {
        val heightPx = with(LocalDensity.current) { maxHeight.toPx() }

        Box(
            modifier = Modifier
                .fillMaxSize()
                .draggable(
                    orientation = Orientation.Vertical,
                    state = rememberDraggableState { delta ->
                        // Toute la hauteur de l'écran = toute la plage de luminosité ; vers le haut = plus fort
                        showLevel = true
                        onBrightnessChange(currentBrightness - delta / heightPx)
                    },
                ),
        )

        AnimatedVisibility(
            visible = showLevel,
            enter = fadeIn(),
            exit = fadeOut(),
            modifier = Modifier.align(Alignment.Center),
        ) {
            // Texte foncé sur lumière claire, clair sur lumière foncée
            val onLight = if (color.luminance() > 0.5f) Color.Black else Color.White
            Text(
                text = stringResource(R.string.light_level, (brightness * 100).roundToInt()),
                style = MaterialTheme.typography.headlineMedium,
                color = onLight,
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(onLight.copy(alpha = 0.12f))
                    .padding(horizontal = 20.dp, vertical = 10.dp),
            )
        }
    }
}

/** Applique [level] à la luminosité de la fenêtre ; rend la main au téléphone en quittant. */
@Composable
private fun ScreenBrightnessEffect(level: Float) {
    val window = (LocalView.current.context as? Activity)?.window
    val setBrightness: SetScreenBrightnessUseCase = koinInject()

    LaunchedEffect(window, level) { window?.let { setBrightness(it, level) } }
    DisposableEffect(window) {
        onDispose { window?.let { setBrightness(it, null) } }
    }
}
