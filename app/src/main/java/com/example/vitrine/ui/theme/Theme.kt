package com.example.vitrine.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider

/**
 * Thème de l'application : plat, accents vert et ambre, clair ou sombre.
 *
 * [darkTheme] vaut par défaut le thème du téléphone ; MainActivity le remplace
 * par le choix de l'utilisateur (automatique, clair ou sombre).
 * Les couleurs dynamiques (Material You) restent désactivées pour garder la même identité partout.
 */
@Composable
fun VitrineTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    CompositionLocalProvider(LocalVitrineDarkTheme provides darkTheme) {
        MaterialTheme(
            colorScheme = vitrineColorScheme(darkTheme),
            typography = Typography,
            shapes = Shapes(
                small = VitrineShapes.Control,
                medium = VitrineShapes.Menu,
                large = VitrineShapes.Card,
            ),
            content = content,
        )
    }
}

/** Schéma Material construit à partir de [VitrineColors], pour les composants Material3. */
@Composable
private fun vitrineColorScheme(darkTheme: Boolean) = if (darkTheme) {
    darkColorScheme(
        primary = VitrineColors.Accent,
        onPrimary = VitrineColors.Background,
        secondary = VitrineColors.Warning,
        onSecondary = VitrineColors.Background,
        background = VitrineColors.Background,
        onBackground = VitrineColors.TextPrimary,
        surface = VitrineColors.Surface,
        onSurface = VitrineColors.TextPrimary,
        surfaceVariant = VitrineColors.SurfaceMuted,
        onSurfaceVariant = VitrineColors.TextMuted,
        outline = VitrineColors.Divider,
    )
} else {
    lightColorScheme(
        primary = VitrineColors.Accent,
        onPrimary = VitrineColors.Surface,
        secondary = VitrineColors.Warning,
        onSecondary = VitrineColors.Surface,
        background = VitrineColors.Background,
        onBackground = VitrineColors.TextPrimary,
        surface = VitrineColors.Surface,
        onSurface = VitrineColors.TextPrimary,
        surfaceVariant = VitrineColors.SurfaceMuted,
        onSurfaceVariant = VitrineColors.TextMuted,
        outline = VitrineColors.Divider,
    )
}
