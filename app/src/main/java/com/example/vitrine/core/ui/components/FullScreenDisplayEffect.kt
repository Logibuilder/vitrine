package com.example.vitrine.core.ui.components

import android.app.Activity
import android.content.pm.ActivityInfo
import android.view.WindowManager
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat

/**
 * À placer dans un écran d'affichage plein écran (texte géant, horloge…).
 * Tant que l'écran est affiché : paysage forcé, écran toujours allumé, barres système cachées.
 * Tout est restauré en quittant l'écran, mais pas pendant une rotation
 * (l'activité est alors recréée et l'affichage continue).
 */
@Composable
fun FullScreenDisplayEffect() {
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
