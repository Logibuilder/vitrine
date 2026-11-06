package com.example.vitrine.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.colorResource
import com.example.vitrine.R

/**
 * Palette de l'application, lue depuis res/values/colors_vitrine.xml.
 * C'est la seule source de couleurs de l'interface : tous les écrans passent par ici.
 * Les getters sont @Composable car colorResource() a besoin du contexte Compose.
 */
object VitrineColors {
    /** Fond des écrans. */
    val Background: Color @Composable get() = colorResource(R.color.vitrine_background)

    /** Fond des cartes et du menu. */
    val Surface: Color @Composable get() = colorResource(R.color.vitrine_surface)

    /** Bordure fine des cartes. */
    val Stroke: Color @Composable get() = colorResource(R.color.vitrine_stroke)

    val TextPrimary: Color @Composable get() = colorResource(R.color.vitrine_text_primary)
    val TextMuted: Color @Composable get() = colorResource(R.color.vitrine_text_muted)

    /** Accent principal : sélection, liens, curseur. */
    val Cyan: Color @Composable get() = colorResource(R.color.vitrine_accent_cyan)

    /** Accent secondaire : début des dégradés. */
    val Violet: Color @Composable get() = colorResource(R.color.vitrine_accent_violet)
}
