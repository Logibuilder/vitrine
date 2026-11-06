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
    /** Fond des écrans (gris très clair). */
    val Background: Color @Composable get() = colorResource(R.color.vitrine_background)

    /** Fond des cartes et du menu (blanc). */
    val Surface: Color @Composable get() = colorResource(R.color.vitrine_surface)

    /** Élément sélectionné, boutons ronds, zones en retrait. */
    val SurfaceMuted: Color @Composable get() = colorResource(R.color.vitrine_surface_muted)

    /** Contours discrets (pastilles blanches, séparateurs). */
    val Divider: Color @Composable get() = colorResource(R.color.vitrine_divider)

    val TextPrimary: Color @Composable get() = colorResource(R.color.vitrine_text_primary)
    val TextMuted: Color @Composable get() = colorResource(R.color.vitrine_text_muted)

    /** Vert : état actif, curseur, actions. */
    val Accent: Color @Composable get() = colorResource(R.color.vitrine_accent)

    /** Ambre : attention, fonctionnalité à venir. */
    val Warning: Color @Composable get() = colorResource(R.color.vitrine_warning)
}
