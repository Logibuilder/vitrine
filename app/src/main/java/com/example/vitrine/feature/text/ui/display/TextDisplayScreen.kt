package com.example.vitrine.feature.text.ui.display

import android.app.Activity
import android.content.pm.ActivityInfo
import android.view.WindowManager
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
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
            .background(LedFrameDefaults.baseColor())
            .clickable(onClick = onExit),
    ) {
        LedFrame(
            contentColor = bgColor,
            modifier = Modifier.fillMaxSize(),
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

/**
 * Pendant l'affichage : force le paysage, garde l'écran allumé et cache les barres système.
 * Tout est restauré en quittant l'affichage, mais pas pendant une rotation
 * (l'activité est alors recréée et l'affichage continue).
 */
@Composable
private fun FullScreenDisplayEffect() {
    val activity = LocalView.current.context as? Activity

    DisposableEffect(activity) {
        val window = activity?.window
        activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window?.let { w ->
            WindowCompat.getInsetsController(w, w.decorView).apply {
                systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                hide(WindowInsetsCompat.Type.systemBars())
            }
        }

        onDispose {
            if (activity?.isChangingConfigurations != true) {
                activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
                window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                window?.let { w ->
                    WindowCompat.getInsetsController(w, w.decorView)
                        .show(WindowInsetsCompat.Type.systemBars())
                }
            }
        }
    }
}