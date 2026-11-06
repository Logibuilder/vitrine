package com.example.vitrine.core.ui.components

import androidx.compose.animation.Crossfade
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathOperation
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import com.example.vitrine.R
import com.example.vitrine.ui.theme.VitrineColors
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/**
 * Bouton rond qui bascule l'interface entre clair et sombre.
 * L'icône montre l'apparence actuelle : soleil (clair) ou lune (sombre).
 */
@Composable
fun ThemeToggleButton(
    isDark: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val actionLabel = stringResource(R.string.theme_change)
    val stateLabel = stringResource(if (isDark) R.string.theme_mode_dark else R.string.theme_mode_light)
    val iconColor = VitrineColors.TextPrimary

    Box(
        modifier = modifier
            .size(40.dp)
            .clip(CircleShape)
            .background(VitrineColors.Surface)
            .clickable(role = Role.Button, onClick = onClick)
            .semantics {
                contentDescription = actionLabel
                stateDescription = stateLabel
            },
        contentAlignment = Alignment.Center,
    ) {
        Crossfade(targetState = isDark, label = "theme-icon") { dark ->
            Canvas(Modifier.size(18.dp)) {
                if (dark) drawMoonIcon(iconColor) else drawSunIcon(iconColor)
            }
        }
    }
}

/** Disque entouré de 8 rayons. */
private fun DrawScope.drawSunIcon(color: Color) {
    val stroke = 1.6.dp.toPx()
    val half = size.minDimension / 2f
    drawCircle(color = color, radius = half * 0.40f)
    repeat(8) { i ->
        val angle = i * PI / 4
        val dx = cos(angle).toFloat()
        val dy = sin(angle).toFloat()
        drawLine(
            color = color,
            start = Offset(center.x + dx * half * 0.66f, center.y + dy * half * 0.66f),
            end = Offset(center.x + dx * (half - stroke / 2), center.y + dy * (half - stroke / 2)),
            strokeWidth = stroke,
            cap = StrokeCap.Round,
        )
    }
}

/** Croissant : un disque dont on retire un disque décalé. */
private fun DrawScope.drawMoonIcon(color: Color) {
    val radius = size.minDimension / 2f * 0.9f
    val disc = Path().apply { addOval(Rect(center = center, radius = radius)) }
    val cut = Path().apply {
        addOval(
            Rect(
                center = Offset(center.x + radius * 0.55f, center.y - radius * 0.45f),
                radius = radius * 0.85f,
            )
        )
    }
    drawPath(Path.combine(PathOperation.Difference, disc, cut), color = color)
}
