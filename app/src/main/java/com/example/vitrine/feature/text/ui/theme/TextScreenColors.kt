package com.example.vitrine.feature.text.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.colorResource
import com.example.vitrine.R

/**
 * Couleurs de l'interface de la feature texte, lues depuis res/values/colors_vitrine.xml.
 * Les getters sont @Composable car colorResource() a besoin du contexte Compose.
 */
internal object TextScreenColors {
    val Background: Color @Composable get() = colorResource(R.color.vitrine_background)
    val Surface: Color @Composable get() = colorResource(R.color.vitrine_surface)
    val Stroke: Color @Composable get() = colorResource(R.color.vitrine_stroke)
    val TextPrimary: Color @Composable get() = colorResource(R.color.vitrine_text_primary)
    val TextMuted: Color @Composable get() = colorResource(R.color.vitrine_text_muted)
    val Cyan: Color @Composable get() = colorResource(R.color.vitrine_accent_cyan)
    val Violet: Color @Composable get() = colorResource(R.color.vitrine_accent_violet)
}