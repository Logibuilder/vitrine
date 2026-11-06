package com.example.vitrine.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/**
 * Thème unique de l'application : plat et clair, accents vert et ambre.
 * Les couleurs dynamiques (Material You) et le thème sombre sont volontairement désactivés
 * pour que l'application garde la même identité sur tous les téléphones.
 */
@Composable
fun VitrineTheme(content: @Composable () -> Unit) {
    val colorScheme = lightColorScheme(
        primary = VitrineColors.Accent,
        onPrimary = Color.White,
        secondary = VitrineColors.Warning,
        onSecondary = Color.White,
        background = VitrineColors.Background,
        onBackground = VitrineColors.TextPrimary,
        surface = VitrineColors.Surface,
        onSurface = VitrineColors.TextPrimary,
        surfaceVariant = VitrineColors.SurfaceMuted,
        onSurfaceVariant = VitrineColors.TextMuted,
        outline = VitrineColors.Divider,
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
