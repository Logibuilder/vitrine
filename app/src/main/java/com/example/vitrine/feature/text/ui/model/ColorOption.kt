package com.example.vitrine.feature.text.ui.model

import androidx.annotation.ColorRes
import androidx.annotation.StringRes
import com.example.vitrine.R

/** Une couleur proposée à l'utilisateur : son libellé et sa valeur, tous deux en ressources. */
internal data class ColorOption(
    @StringRes val label: Int,
    @ColorRes val color: Int,
)

internal val TextColorOptions = listOf(
    ColorOption(R.string.color_white, R.color.text_white),
    ColorOption(R.string.color_yellow, R.color.text_yellow),
    ColorOption(R.string.color_green, R.color.text_green),
    ColorOption(R.string.color_red, R.color.text_red),
)

internal val BackgroundColorOptions = listOf(
    ColorOption(R.string.color_black, R.color.bg_black),
    ColorOption(R.string.color_night_blue, R.color.bg_night_blue),
    ColorOption(R.string.color_night_red, R.color.bg_night_red),
    ColorOption(R.string.color_white, R.color.bg_white),
)