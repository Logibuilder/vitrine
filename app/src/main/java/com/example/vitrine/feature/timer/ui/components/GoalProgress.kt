package com.example.vitrine.feature.timer.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.unit.dp
import com.example.vitrine.ui.theme.VitrineColors

/**
 * Couleur selon l'avancement vers l'objectif :
 * vert jusqu'à la moitié, puis vert → ambre, puis ambre → rouge ; rouge une fois l'objectif atteint.
 */
@Composable
fun goalColor(progress: Float): Color {
    val green = VitrineColors.Accent
    val amber = VitrineColors.Warning
    val red = VitrineColors.Danger
    return when {
        progress >= 1f -> red
        progress >= 0.75f -> lerp(amber, red, (progress - 0.75f) / 0.25f)
        progress >= 0.5f -> lerp(green, amber, (progress - 0.5f) / 0.25f)
        else -> green
    }
}

/** Barre plate de progression vers l'objectif ; sa couleur suit [goalColor]. */
@Composable
fun GoalProgressBar(
    progress: Float,
    modifier: Modifier = Modifier,
) {
    val fill by animateFloatAsState(progress.coerceIn(0f, 1f), label = "goal-progress")
    val color by animateColorAsState(goalColor(progress), label = "goal-color")
    val shape = RoundedCornerShape(50)

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(6.dp)
            .clip(shape)
            .background(VitrineColors.SurfaceMuted),
    ) {
        Box(
            modifier = Modifier
                .fillMaxHeight()
                .fillMaxWidth(fill)
                .clip(shape)
                .background(color),
        )
    }
}
