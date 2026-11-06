package com.example.vitrine.ui.theme

import androidx.annotation.ColorRes
import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.colorResource
import com.example.vitrine.R

/** Vrai quand le thème sombre est actif. Fourni par [VitrineTheme]. */
internal val LocalVitrineDarkTheme = staticCompositionLocalOf { false }

/** Lit la couleur claire ou sombre selon le thème actif (pas celui du téléphone). */
@Composable
private fun themed(@ColorRes light: Int, @ColorRes dark: Int): Color =
    colorResource(if (LocalVitrineDarkTheme.current) dark else light)

/**
 * Palette de l'application, lue depuis res/values/colors_vitrine.xml.
 * C'est la seule source de couleurs de l'interface : tous les écrans passent par ici.
 * Chaque couleur existe en version claire et sombre ; la bonne est choisie selon le thème actif.
 */
object VitrineColors {
    /** Fond des écrans. */
    val Background: Color
        @Composable get() = themed(R.color.vitrine_light_background, R.color.vitrine_dark_background)

    /** Fond des cartes et du menu. */
    val Surface: Color
        @Composable get() = themed(R.color.vitrine_light_surface, R.color.vitrine_dark_surface)

    /** Élément sélectionné, boutons ronds, zones en retrait. */
    val SurfaceMuted: Color
        @Composable get() = themed(R.color.vitrine_light_surface_muted, R.color.vitrine_dark_surface_muted)

    /** Contours discrets, LEDs éteintes de l'aperçu. */
    val Divider: Color
        @Composable get() = themed(R.color.vitrine_light_divider, R.color.vitrine_dark_divider)

    val TextPrimary: Color
        @Composable get() = themed(R.color.vitrine_light_text_primary, R.color.vitrine_dark_text_primary)

    val TextMuted: Color
        @Composable get() = themed(R.color.vitrine_light_text_muted, R.color.vitrine_dark_text_muted)

    /** Vert : état actif, curseur, actions. */
    val Accent: Color
        @Composable get() = themed(R.color.vitrine_light_accent, R.color.vitrine_dark_accent)

    /** Ambre : attention, fonctionnalité à venir. */
    val Warning: Color
        @Composable get() = themed(R.color.vitrine_light_warning, R.color.vitrine_dark_warning)
}
