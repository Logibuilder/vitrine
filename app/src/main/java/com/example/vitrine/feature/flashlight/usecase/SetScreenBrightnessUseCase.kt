package com.example.vitrine.feature.flashlight.usecase

import android.view.Window
import android.view.WindowManager

/**
 * Règle la luminosité de l'écran pour cette fenêtre uniquement
 * (le réglage du téléphone n'est pas modifié, aucune permission n'est nécessaire).
 */
class SetScreenBrightnessUseCase {

    /** [level] entre 0 et 1 ; null rend la main au réglage du téléphone. */
    operator fun invoke(window: Window, level: Float?) {
        window.attributes = window.attributes.apply {
            screenBrightness = level?.let(::clamp) ?: WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
        }
    }

    companion object {
        /** En dessous, certains écrans s'éteignent presque : la lampe ne servirait plus à rien. */
        const val MIN_LEVEL = 0.05f

        fun clamp(level: Float): Float = level.coerceIn(MIN_LEVEL, 1f)
    }
}
