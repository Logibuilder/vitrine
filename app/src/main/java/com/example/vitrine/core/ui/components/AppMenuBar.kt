package com.example.vitrine.core.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.ui.theme.VitrineColors
import com.example.vitrine.ui.theme.VitrineShapes

/**
 * Menu de navigation flottant, en forme de pilule.
 * Chaque fonctionnalité a son icône ; l'élément courant s'élargit dans une pilule d'encre
 * et affiche son nom.
 */
@Composable
fun AppMenuBar(
    current: AppDestination,
    onNavigate: (AppDestination) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(60.dp)
            .softShadow(VitrineShapes.Pill)
            .clip(VitrineShapes.Pill)
            .background(VitrineColors.Surface)
            .border(1.dp, VitrineColors.Divider, VitrineShapes.Pill)
            .padding(6.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        AppDestination.entries.forEach { destination ->
            MenuItem(
                destination = destination,
                selected = destination == current,
                onClick = { if (destination != current) onNavigate(destination) },
            )
        }
    }
}

@Composable
private fun RowScope.MenuItem(
    destination: AppDestination,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val label = stringResource(destination.label)
    // L'élément courant prend environ deux fois plus de place, pour loger son nom
    val weight by animateFloatAsState(if (selected) 2.1f else 1f, label = "menu-item-weight")
    val background by animateColorAsState(
        targetValue = if (selected) VitrineColors.Ink else Color.Transparent,
        label = "menu-item-background",
    )
    val contentColor by animateColorAsState(
        targetValue = if (selected) VitrineColors.OnInk else VitrineColors.TextMuted,
        label = "menu-item-content",
    )

    Row(
        modifier = Modifier
            .weight(weight)
            .fillMaxHeight()
            .clip(VitrineShapes.Pill)
            .background(background)
            .clickable(role = Role.Tab, onClick = onClick)
            .semantics {
                contentDescription = label
                this.selected = selected
            },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        MenuIcon(destination = destination, color = contentColor, modifier = Modifier.size(20.dp))
        if (selected) {
            Spacer(Modifier.width(7.dp))
            Text(
                text = label,
                color = contentColor,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                softWrap = false,
            )
        }
    }
}

/** Icône au trait de chaque fonctionnalité, dessinée en code. */
@Composable
private fun MenuIcon(
    destination: AppDestination,
    color: Color,
    modifier: Modifier = Modifier,
) {
    Canvas(modifier) {
        val stroke = 1.8.dp.toPx()
        when (destination) {
            AppDestination.TEXT -> drawTextIcon(color, stroke)
            AppDestination.CLOCK -> drawClockIcon(color, stroke)
            AppDestination.FLASHLIGHT -> drawBulbIcon(color, stroke)
            AppDestination.TIMER -> drawStopwatchIcon(color, stroke)
        }
    }
}

private fun DrawScope.line(color: Color, stroke: Float, x1: Float, y1: Float, x2: Float, y2: Float) {
    drawLine(
        color = color,
        start = Offset(size.width * x1, size.height * y1),
        end = Offset(size.width * x2, size.height * y2),
        strokeWidth = stroke,
        cap = StrokeCap.Round,
    )
}

/** Lettre « T ». */
private fun DrawScope.drawTextIcon(color: Color, stroke: Float) {
    line(color, stroke, 0.18f, 0.20f, 0.82f, 0.20f)
    line(color, stroke, 0.50f, 0.20f, 0.50f, 0.84f)
    line(color, stroke, 0.38f, 0.84f, 0.62f, 0.84f)
}

/** Cadran et deux aiguilles. */
private fun DrawScope.drawClockIcon(color: Color, stroke: Float) {
    drawCircle(color, radius = size.minDimension * 0.42f, style = Stroke(stroke))
    line(color, stroke, 0.50f, 0.50f, 0.50f, 0.26f)
    line(color, stroke, 0.50f, 0.50f, 0.67f, 0.60f)
}

/** Ampoule : globe et culot. */
private fun DrawScope.drawBulbIcon(color: Color, stroke: Float) {
    drawCircle(
        color = color,
        radius = size.minDimension * 0.30f,
        center = Offset(size.width * 0.5f, size.height * 0.38f),
        style = Stroke(stroke),
    )
    line(color, stroke, 0.38f, 0.80f, 0.62f, 0.80f)
    line(color, stroke, 0.43f, 0.94f, 0.57f, 0.94f)
}

/** Chronomètre : bouton poussoir, boîtier et aiguille. */
private fun DrawScope.drawStopwatchIcon(color: Color, stroke: Float) {
    line(color, stroke, 0.40f, 0.06f, 0.60f, 0.06f)
    line(color, stroke, 0.50f, 0.06f, 0.50f, 0.20f)
    drawCircle(
        color = color,
        radius = size.minDimension * 0.36f,
        center = Offset(size.width * 0.5f, size.height * 0.58f),
        style = Stroke(stroke),
    )
    line(color, stroke, 0.50f, 0.58f, 0.63f, 0.44f)
}
