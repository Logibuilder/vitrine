package com.example.vitrine.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/**
 * Thème unique de l'application : sombre, avec les accents violet et cyan.
 * Les couleurs dynamiques (Material You) et le thème clair sont volontairement désactivés
 * pour que l'application garde la même identité sur tous les téléphones.
 */
@Composable
fun VitrineTheme(content: @Composable () -> Unit) {
    val colorScheme = darkColorScheme(
        primary = VitrineColors.Cyan,
        onPrimary = VitrineColors.Background,
        secondary = VitrineColors.Violet,
        onSecondary = Color.White,
        background = VitrineColors.Background,
        onBackground = VitrineColors.TextPrimary,
        surface = VitrineColors.Surface,
        onSurface = VitrineColors.TextPrimary,
        surfaceVariant = VitrineColors.Surface,
        onSurfaceVariant = VitrineColors.TextMuted,
        outline = VitrineColors.Stroke,
    )

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        shapes = Shapes(
            small = VitrineShapes.Control,
            medium = VitrineShapes.Menu,
            large = VitrineShapes.Card,
        ),
        content = content,
    )
}
