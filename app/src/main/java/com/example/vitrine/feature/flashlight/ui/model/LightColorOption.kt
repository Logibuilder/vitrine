package com.example.vitrine.feature.flashlight.ui.model

import androidx.annotation.ColorRes
import androidx.annotation.StringRes
import com.example.vitrine.R

/** Une couleur de lumière proposée : son libellé et sa valeur, en ressources. */
internal data class LightColorOption(
    @StringRes val label: Int,
    @ColorRes val color: Int,
)

internal val LightColorOptions = listOf(
    LightColorOption(R.string.light_white, R.color.light_white),
    LightColorOption(R.string.light_warm, R.color.light_warm),
    LightColorOption(R.string.light_cool, R.color.light_cool),
    // Le rouge préserve la vision de nuit (ciel étoilé, lecture dans le noir)
    LightColorOption(R.string.light_red, R.color.light_red),
)
